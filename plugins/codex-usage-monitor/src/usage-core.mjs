import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import readline from "node:readline";

export const REFERENCE_TOKENS = 123_300_000;
export const REFERENCE_USD = 71.4701;
export const DEFAULT_USD_PER_MILLION_TOKENS = Number(
  ((REFERENCE_USD / REFERENCE_TOKENS) * 1_000_000).toFixed(10),
);
export const DEFAULT_DASHBOARD_PORT = 48763;

const SESSION_FILE_PATTERN = /^rollout-.*\.jsonl$/;
const TOKEN_KEYS = [
  "inputTokens",
  "cachedInputTokens",
  "outputTokens",
  "reasoningOutputTokens",
  "totalTokens",
];

function createUsageBucket() {
  return {
    inputTokens: 0,
    cachedInputTokens: 0,
    outputTokens: 0,
    reasoningOutputTokens: 0,
    totalTokens: 0,
  };
}

function toNumber(value) {
  return Number.isFinite(value) ? value : 0;
}

function normalizeUsage(raw = {}) {
  return {
    inputTokens: toNumber(raw.input_tokens),
    cachedInputTokens: toNumber(raw.cached_input_tokens),
    outputTokens: toNumber(raw.output_tokens),
    reasoningOutputTokens: toNumber(raw.reasoning_output_tokens),
    totalTokens: toNumber(raw.total_tokens),
  };
}

function cloneUsage(usage) {
  return {
    inputTokens: usage.inputTokens,
    cachedInputTokens: usage.cachedInputTokens,
    outputTokens: usage.outputTokens,
    reasoningOutputTokens: usage.reasoningOutputTokens,
    totalTokens: usage.totalTokens,
  };
}

function addUsage(target, delta) {
  for (const key of TOKEN_KEYS) {
    target[key] += delta[key];
  }
}

function positiveDiff(previous, current) {
  const diff = createUsageBucket();
  for (const key of TOKEN_KEYS) {
    diff[key] = Math.max(0, current[key] - previous[key]);
  }
  return diff;
}

function isMeaningfulUsage(usage) {
  return usage.totalTokens > 0 || usage.inputTokens > 0 || usage.outputTokens > 0;
}

export function usageToUsd(tokens, usdPerMillionTokens = DEFAULT_USD_PER_MILLION_TOKENS) {
  return Number(((tokens / 1_000_000) * usdPerMillionTokens).toFixed(6));
}

export function formatDateKey(date) {
  const year = date.getFullYear();
  const month = `${date.getMonth() + 1}`.padStart(2, "0");
  const day = `${date.getDate()}`.padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function toLocalDateKey(timestamp) {
  return formatDateKey(new Date(timestamp));
}

async function collectSessionFiles(sessionsRoot) {
  const collected = [];

  async function walk(directory) {
    let entries = [];
    try {
      entries = await fs.promises.readdir(directory, { withFileTypes: true });
    } catch {
      return;
    }

    for (const entry of entries) {
      const resolved = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        await walk(resolved);
        continue;
      }
      if (entry.isFile() && SESSION_FILE_PATTERN.test(entry.name)) {
        collected.push(resolved);
      }
    }
  }

  await walk(sessionsRoot);
  collected.sort();
  return collected;
}

export function buildApiActivityFromText(logText) {
  if (!logText) {
    return {
      status: "unknown",
      activeRequests: 0,
      source: "missing-log",
      lastTransitionAt: null,
    };
  }

  let activeRequests = 0;
  let lastTransitionAt = null;
  for (const line of logText.split(/\r?\n/)) {
    if (!line.includes("model_client.stream_responses_api")) {
      continue;
    }
    const match = line.match(/^(\d{4}-\d{2}-\d{2}T[^\s]+)/);
    if (match) {
      lastTransitionAt = match[1];
    }
    if (line.includes("codex_core::client: new")) {
      activeRequests += 1;
    } else if (line.includes("codex_core::client: close")) {
      activeRequests = Math.max(0, activeRequests - 1);
    }
  }

  return {
    status: activeRequests > 0 ? "busy" : "idle",
    activeRequests,
    source: "codex-tui.log",
    lastTransitionAt,
  };
}

export async function deriveApiActivity(logPath) {
  try {
    const logText = await fs.promises.readFile(logPath, "utf8");
    return buildApiActivityFromText(logText);
  } catch {
    return {
      status: "unknown",
      activeRequests: 0,
      source: "missing-log",
      lastTransitionAt: null,
    };
  }
}

export function buildSessionSummaryFromRecords(records, todayKey) {
  const totalUsage = createUsageBucket();
  const todayUsage = createUsageBucket();
  let previousTotalUsage = null;
  let lastTurnUsage = createUsageBucket();
  let currentSessionUsage = createUsageBucket();
  let latestEventAt = null;
  let sessionMeta = null;
  let turnCount = 0;

  for (const record of records) {
    if (record?.type === "session_meta") {
      sessionMeta = record.payload ?? null;
      continue;
    }

    if (record?.type !== "event_msg" || !record.payload) {
      continue;
    }

    if (record.payload.type === "task_started") {
      turnCount += 1;
      continue;
    }

    if (record.payload.type !== "token_count") {
      continue;
    }

    const totalTokenUsage = record.payload.info?.total_token_usage;
    if (!totalTokenUsage) {
      continue;
    }

    const currentTotalUsage = normalizeUsage(totalTokenUsage);
    const deltaUsage = previousTotalUsage
      ? positiveDiff(previousTotalUsage, currentTotalUsage)
      : currentTotalUsage;

    previousTotalUsage = currentTotalUsage;
    currentSessionUsage = cloneUsage(currentTotalUsage);

    if (!isMeaningfulUsage(deltaUsage)) {
      continue;
    }

    addUsage(totalUsage, deltaUsage);
    if (record.timestamp && toLocalDateKey(record.timestamp) === todayKey) {
      addUsage(todayUsage, deltaUsage);
    }

    lastTurnUsage = normalizeUsage(record.payload.info?.last_token_usage ?? deltaUsage);
    latestEventAt = record.timestamp ?? latestEventAt;
  }

  return {
    sessionMeta,
    totalUsage,
    todayUsage,
    currentSessionUsage,
    lastTurnUsage,
    latestEventAt,
    turnCount,
  };
}

async function parseSessionFile(filePath, todayKey) {
  const records = [];
  const stream = fs.createReadStream(filePath, { encoding: "utf8" });
  const input = readline.createInterface({
    input: stream,
    crlfDelay: Number.POSITIVE_INFINITY,
  });

  for await (const line of input) {
    const trimmed = line.trim();
    if (!trimmed) {
      continue;
    }
    try {
      records.push(JSON.parse(trimmed));
    } catch {
      // Ignore malformed lines and continue with the rest of the session export.
    }
  }

  const fileStats = await fs.promises.stat(filePath);
  const summary = buildSessionSummaryFromRecords(records, todayKey);
  return {
    filePath,
    fileSize: fileStats.size,
    sessionId: summary.sessionMeta?.id ?? path.basename(filePath, ".jsonl"),
    startedAt: summary.sessionMeta?.timestamp ?? null,
    cwd: summary.sessionMeta?.cwd ?? null,
    latestEventAt: summary.latestEventAt,
    totalUsage: summary.totalUsage,
    todayUsage: summary.todayUsage,
    currentSessionUsage: summary.currentSessionUsage,
    lastTurnUsage: summary.lastTurnUsage,
    turnCount: summary.turnCount,
  };
}

function createEmptySessionView() {
  return {
    sessionId: null,
    startedAt: null,
    latestEventAt: null,
    cwd: null,
    totalUsage: createUsageBucket(),
    currentSessionUsage: createUsageBucket(),
    lastTurnUsage: createUsageBucket(),
    turnCount: 0,
  };
}

export async function buildSnapshot(options = {}) {
  const homeDirectory = options.codexHome ?? path.join(os.homedir(), ".codex");
  const sessionsRoot = options.sessionsRoot ?? path.join(homeDirectory, "sessions");
  const logPath = options.logPath ?? path.join(homeDirectory, "log", "codex-tui.log");
  const usdPerMillionTokens = options.usdPerMillionTokens ?? DEFAULT_USD_PER_MILLION_TOKENS;
  const todayKey = options.todayKey ?? formatDateKey(new Date());

  const totalUsage = createUsageBucket();
  const todayUsage = createUsageBucket();
  const sessionFiles = await collectSessionFiles(sessionsRoot);
  const sessionSummaries = [];

  for (const sessionFile of sessionFiles) {
    const summary = await parseSessionFile(sessionFile, todayKey);
    addUsage(totalUsage, summary.totalUsage);
    addUsage(todayUsage, summary.todayUsage);
    sessionSummaries.push(summary);
  }

  const latestSession = sessionSummaries.at(-1) ?? createEmptySessionView();
  const apiActivity = await deriveApiActivity(logPath);

  return {
    generatedAt: new Date().toISOString(),
    localDateKey: todayKey,
    pricing: {
      usdPerMillionTokens,
      referenceTokens: REFERENCE_TOKENS,
      referenceUsd: REFERENCE_USD,
      source: "fixed-local-ratio",
    },
    coverage: {
      sessionsFound: sessionSummaries.length,
      sessionFiles,
      sessionsRoot,
      logPath,
    },
    status: {
      api: apiActivity,
      degraded: {
        sessionSourceMissing: sessionSummaries.length === 0,
        logSourceMissing: apiActivity.status === "unknown",
      },
    },
    totals: {
      ...totalUsage,
      estimatedUsd: usageToUsd(totalUsage.totalTokens, usdPerMillionTokens),
    },
    today: {
      ...todayUsage,
      estimatedUsd: usageToUsd(todayUsage.totalTokens, usdPerMillionTokens),
    },
    currentSession: {
      sessionId: latestSession.sessionId,
      startedAt: latestSession.startedAt,
      latestEventAt: latestSession.latestEventAt,
      cwd: latestSession.cwd,
      turnCount: latestSession.turnCount,
      ...latestSession.currentSessionUsage,
      estimatedUsd: usageToUsd(latestSession.currentSessionUsage.totalTokens, usdPerMillionTokens),
    },
    lastTurn: {
      ...latestSession.lastTurnUsage,
      estimatedUsd: usageToUsd(latestSession.lastTurnUsage.totalTokens, usdPerMillionTokens),
    },
    notes: [
      "Token totals are computed from local session export deltas.",
      "USD is an estimate from the fixed ratio 123.3M tokens == $71.4701.",
    ],
  };
}

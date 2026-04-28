const POLL_INTERVAL_MS = 3000;

const formatCompactNumber = new Intl.NumberFormat("en-US", {
  notation: "compact",
  maximumFractionDigits: 1,
});

const formatExactNumber = new Intl.NumberFormat("en-US");

const formatMoney = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  minimumFractionDigits: 2,
  maximumFractionDigits: 4,
});

function setText(selector, value) {
  const element = document.querySelector(selector);
  if (element) {
    element.textContent = value;
  }
}

function formatTimestamp(value) {
  if (!value) {
    return "--";
  }
  return new Date(value).toLocaleString();
}

function renderApiStatus(api) {
  const card = document.querySelector("[data-api-card]");
  if (!card) {
    return;
  }

  card.classList.remove("is-busy", "is-idle", "is-unknown");
  const normalizedStatus = api?.status ?? "unknown";
  card.classList.add(`is-${normalizedStatus}`);

  const label =
    normalizedStatus === "busy"
      ? "Busy"
      : normalizedStatus === "idle"
        ? "Idle"
        : "Unknown";

  setText("[data-api-status]", `${label} • ${api?.activeRequests ?? 0} active`);
  setText("[data-active-requests]", formatExactNumber.format(api?.activeRequests ?? 0));
}

function renderMetric(snapshot) {
  setText("[data-total-tokens]", formatCompactNumber.format(snapshot.totals.totalTokens));
  setText(
    "[data-total-tokens-detail]",
    `${formatExactNumber.format(snapshot.totals.totalTokens)} total tokens`,
  );

  setText("[data-total-usd]", formatMoney.format(snapshot.totals.estimatedUsd));
  setText(
    "[data-ratio-detail]",
    `$${snapshot.pricing.usdPerMillionTokens.toFixed(4)} per 1M tokens`,
  );

  setText("[data-today-tokens]", formatCompactNumber.format(snapshot.today.totalTokens));
  setText(
    "[data-today-tokens-detail]",
    `${formatExactNumber.format(snapshot.today.totalTokens)} tokens today`,
  );

  setText("[data-today-usd]", formatMoney.format(snapshot.today.estimatedUsd));
  setText("[data-local-date]", `Local day: ${snapshot.localDateKey}`);

  setText(
    "[data-session-tokens]",
    formatExactNumber.format(snapshot.currentSession.totalTokens),
  );
  setText(
    "[data-last-turn-tokens]",
    formatExactNumber.format(snapshot.lastTurn.totalTokens),
  );
  setText("[data-turn-count]", formatExactNumber.format(snapshot.currentSession.turnCount ?? 0));
  setText(
    "[data-current-session-id]",
    snapshot.currentSession.sessionId ? `Session ${snapshot.currentSession.sessionId.slice(-8)}` : "No session",
  );
  setText(
    "[data-session-meta]",
    snapshot.currentSession.startedAt
      ? `Started ${formatTimestamp(snapshot.currentSession.startedAt)}${snapshot.currentSession.cwd ? ` • ${snapshot.currentSession.cwd}` : ""}`
      : "No readable current session metadata yet.",
  );

  setText("[data-input-tokens]", formatExactNumber.format(snapshot.totals.inputTokens));
  setText(
    "[data-cached-input-tokens]",
    formatExactNumber.format(snapshot.totals.cachedInputTokens),
  );
  setText("[data-output-tokens]", formatExactNumber.format(snapshot.totals.outputTokens));
  setText(
    "[data-reasoning-output-tokens]",
    formatExactNumber.format(snapshot.totals.reasoningOutputTokens),
  );

  setText("[data-generated-at]", `Synced ${formatTimestamp(snapshot.generatedAt)}`);
  setText(
    "[data-coverage-note]",
    `Parsed ${snapshot.coverage.sessionsFound} session export${snapshot.coverage.sessionsFound === 1 ? "" : "s"} from ${snapshot.coverage.sessionsRoot}.`,
  );

  const footnote = snapshot.status.degraded.sessionSourceMissing || snapshot.status.degraded.logSourceMissing
    ? "One or more local sources are unavailable. Token totals come from readable session exports; API state comes from codex-tui.log."
    : "Reading local session exports and codex-tui.log only. USD is an estimate from your fixed token ratio.";
  setText("[data-footnote]", footnote);
}

async function refresh() {
  const response = await fetch(`./usage-snapshot.json?ts=${Date.now()}`, {
    cache: "no-store",
  });

  if (!response.ok) {
    throw new Error(`Snapshot request failed with ${response.status}`);
  }

  const snapshot = await response.json();
  renderApiStatus(snapshot.status.api);
  renderMetric(snapshot);
}

async function boot() {
  try {
    await refresh();
  } catch (error) {
    setText("[data-api-status]", "Unavailable");
    setText(
      "[data-footnote]",
      `Unable to load the local snapshot: ${error instanceof Error ? error.message : String(error)}`,
    );
  }

  window.setInterval(async () => {
    try {
      await refresh();
    } catch (error) {
      setText(
        "[data-footnote]",
        `Refresh failed: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }, POLL_INTERVAL_MS);
}

boot();

import assert from "node:assert/strict";
import {
  DEFAULT_USD_PER_MILLION_TOKENS,
  buildApiActivityFromText,
  buildSessionSummaryFromRecords,
  usageToUsd,
} from "../src/usage-core.mjs";

function runTest(name, callback) {
  try {
    callback();
    console.log(`PASS ${name}`);
  } catch (error) {
    console.error(`FAIL ${name}`);
    console.error(error instanceof Error ? error.stack : String(error));
    process.exitCode = 1;
  }
}

runTest("buildSessionSummaryFromRecords accumulates positive token deltas only", () => {
  const records = [
    {
      type: "session_meta",
      payload: {
        id: "session-1",
        timestamp: "2026-04-28T01:00:00.000Z",
      },
    },
    {
      type: "event_msg",
      timestamp: "2026-04-28T01:05:00.000Z",
      payload: {
        type: "token_count",
        info: {
          total_token_usage: {
            input_tokens: 100,
            cached_input_tokens: 20,
            output_tokens: 10,
            reasoning_output_tokens: 2,
            total_tokens: 110,
          },
          last_token_usage: {
            input_tokens: 100,
            cached_input_tokens: 20,
            output_tokens: 10,
            reasoning_output_tokens: 2,
            total_tokens: 110,
          },
        },
      },
    },
    {
      type: "event_msg",
      timestamp: "2026-04-28T01:07:00.000Z",
      payload: {
        type: "token_count",
        info: {
          total_token_usage: {
            input_tokens: 100,
            cached_input_tokens: 20,
            output_tokens: 10,
            reasoning_output_tokens: 2,
            total_tokens: 110,
          },
          last_token_usage: {
            input_tokens: 0,
            cached_input_tokens: 0,
            output_tokens: 0,
            reasoning_output_tokens: 0,
            total_tokens: 0,
          },
        },
      },
    },
    {
      type: "event_msg",
      timestamp: "2026-04-28T01:10:00.000Z",
      payload: {
        type: "token_count",
        info: {
          total_token_usage: {
            input_tokens: 180,
            cached_input_tokens: 32,
            output_tokens: 24,
            reasoning_output_tokens: 4,
            total_tokens: 204,
          },
          last_token_usage: {
            input_tokens: 80,
            cached_input_tokens: 12,
            output_tokens: 14,
            reasoning_output_tokens: 2,
            total_tokens: 94,
          },
        },
      },
    },
  ];

  const summary = buildSessionSummaryFromRecords(records, "2026-04-28");
  assert.equal(summary.totalUsage.totalTokens, 204);
  assert.equal(summary.totalUsage.inputTokens, 180);
  assert.equal(summary.totalUsage.cachedInputTokens, 32);
  assert.equal(summary.lastTurnUsage.totalTokens, 94);
  assert.equal(summary.todayUsage.totalTokens, 204);
});

runTest("buildApiActivityFromText tracks unmatched open requests", () => {
  const logText = [
    "2026-04-28T03:00:00.000Z INFO model_client.stream_responses_api codex_core::client: new",
    "2026-04-28T03:00:05.000Z INFO model_client.stream_responses_api codex_core::client: close",
    "2026-04-28T03:01:00.000Z INFO model_client.stream_responses_api codex_core::client: new",
  ].join("\n");

  const status = buildApiActivityFromText(logText);
  assert.equal(status.status, "busy");
  assert.equal(status.activeRequests, 1);
  assert.equal(status.lastTransitionAt, "2026-04-28T03:01:00.000Z");
});

runTest("usageToUsd uses the fixed ratio", () => {
  assert.equal(usageToUsd(123_300_000, DEFAULT_USD_PER_MILLION_TOKENS), 71.4701);
  assert.equal(usageToUsd(61_650_000, DEFAULT_USD_PER_MILLION_TOKENS), 35.73505);
});

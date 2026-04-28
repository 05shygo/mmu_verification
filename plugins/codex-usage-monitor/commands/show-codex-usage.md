# /show-codex-usage

Collect the latest local Codex usage snapshot and summarize it in chat.

## Workflow

1. Run `node ./scripts/build-usage-snapshot.mjs --stdout`.
2. Parse the JSON result.
3. Report:
   - total tokens and estimated USD
   - today's tokens and estimated USD
   - API status and active request count
   - any degraded or missing data source notes
4. Mention `ui/usage-snapshot.json` and `ui/index.html` when relevant.

## Output

Use a compact monitor-style summary, not a long explanation.

---
description: Start the local Codex usage dashboard server and return the live URL.
---

# /serve-codex-usage-dashboard

Start the local Codex usage dashboard server.

## Workflow

1. Run `node ./scripts/serve-dashboard.mjs`.
2. Surface the local URL printed by the server.
3. Explain that the dashboard auto-refreshes from local Codex session exports.

## Notes

- The dashboard is local-only and does not call external services.
- If the user wants a static snapshot instead, use `/show-codex-usage`.

---
name: usage-monitor
description: Use when the user wants local Codex token totals, today's usage, estimated USD, API busy or idle status, or the live usage dashboard for their machine.
---

# Usage Monitor

This plugin bundles a local telemetry reader plus a polished dashboard.

## Default actions

- For a point-in-time snapshot, run:

```powershell
node ./scripts/build-usage-snapshot.mjs --stdout
```

- For the live dashboard, run:

```powershell
node ./scripts/serve-dashboard.mjs
```

## Reporting rules

- Prefer the local session export data over guesswork.
- Describe USD as an estimate.
- If session files or logs are missing, say which source degraded.
- Keep the answer compact unless the user asks for a deeper breakdown.

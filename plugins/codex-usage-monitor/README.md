# Codex Usage Monitor

`codex-usage-monitor` is a local-first Codex plugin bundle that reads `~/.codex/sessions/**/*.jsonl` and `~/.codex/log/codex-tui.log` to show:

- total token usage
- total estimated USD
- today's token usage
- today's estimated USD
- current API busy or idle state

## What ships

- `.codex-plugin/plugin.json` for Codex plugin discovery
- `hooks.json` to keep a local snapshot file fresh after tool activity
- `commands/` to query the current snapshot or launch the dashboard
- `skills/usage-monitor/` for natural-language routing
- `ui/` for the polished dashboard
- `scripts/` and `src/` for the local telemetry engine

## Data model

The monitor uses the local Codex session exports as the primary token source:

- it reads `event_msg` records where `payload.type == "token_count"`
- it computes per-session deltas from `info.total_token_usage`
- it aggregates those deltas across all readable sessions
- it estimates USD from the fixed ratio `123.3M tokens == $71.4701`

The live API state is derived from `codex-tui.log` by counting unmatched
Responses API `client: new` and `client: close` log entries.

## Commands

- `/show-codex-usage`
  Returns the current snapshot in chat after running the local collector.

- `/serve-codex-usage-dashboard`
  Starts a small local HTTP server that serves the real-time dashboard.

## Local usage

From the plugin root:

```powershell
node .\scripts\build-usage-snapshot.mjs --stdout
node .\scripts\serve-dashboard.mjs
```

The dashboard defaults to `http://127.0.0.1:48763/`.

`ui/usage-snapshot.json` is generated on demand by the snapshot script and the
installed hook. It is intentionally not committed as runtime state.

## Current limitation

The bundled UI is a local dashboard, not a host-native Codex side panel. The
local plugin samples available on this machine do not show a stable custom
always-on panel API for third-party local plugins, so this bundle stays within
the documented local plugin surfaces: manifest, skills, commands, hooks, and
supporting UI assets.

# FARABAD Logger Dual-Write Runbook

## Purpose
Enable and verify dual-write logging so FARABAD log lines continue to go to server RPT while also forwarding to a configured extension sink.

## Enable dual-write
Set both sinks to `true` in server config (typically `initServer.sqf` overrides or equivalent pre-bootstrap missionNamespace setup):

```sqf
missionNamespace setVariable ["FARABAD_log_toRPT", true, true];
missionNamespace setVariable ["FARABAD_log_toExtension", true, true];
```

Operator shorthand:
- `toRPT=true`
- `toExtension=true`

Quick operator check before restart:
- `toRPT=true` **and** `toExtension=true` must both be set for dual-write mode.

> Keep `FARABAD_log_toRPT=true` during rollout so RPT remains the fallback source of truth.

## Validation checklist
After restart (or after applying overrides before bootstrap), validate both sinks:

1. Confirm FARABAD log lines are still present in server RPT.
   - Expected format includes prefix like: `[FARABAD][<CHANNEL>][<LEVEL>] ...`
2. Confirm extension output file/target receives new entries for the same activity window.
3. Cross-check timestamps/messages between RPT and extension output to verify dual-write behavior.
4. Confirm no gameplay or script-flow regression while logging is active.

Validation must pass both of these explicit conditions:
- RPT still contains FARABAD lines while dual-write is on.
- Extension file/sink receives FARABAD entries during the same test window.

## Rollback (no code revert)
If extension sink is unhealthy, disable extension forwarding only:

```sqf
missionNamespace setVariable ["FARABAD_log_toExtension", false, true];
```

Operator shorthand:
- `toExtension=false`

This preserves RPT logging and does not require reverting code changes.

## Expected failure behavior
When extension calls fail at runtime:

- FARABAD logger emits a one-time warning to RPT indicating extension logging is being disabled for the session.
- Extension forwarding is automatically switched off (`FARABAD_log_toExtension=false`) for safety.
- Gameplay flow is unaffected (fail-soft behavior; no mission-critical interruption).
- RPT logging continues (assuming `FARABAD_log_toRPT=true`).

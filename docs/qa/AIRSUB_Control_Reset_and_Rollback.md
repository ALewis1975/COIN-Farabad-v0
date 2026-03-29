# AIRSUB Control Reset + Rollback Runbook

## Purpose
Operational runbook for resetting AIRSUB control state and rolling back safely if needed.

## Runtime Mode + Scope Declaration
- **Default mode:** Runtime-enabled (`airbase_v1_runtime_enabled=true`).
- **Dormant mode (explicit opt-out):** Set `airbase_v1_runtime_enabled=false` to block AIRBASE scheduler/runtime entrypoints.
- **Authoritative entrypoint scope:** `airbasePostInit`, `airbaseInit`, `airbaseTick`, and server RPC/runtime handlers in `functions/ambiance/fn_airbase*.sqf` that mutate or execute AIRBASE state.
- **Static enforcement:** `tests/static/airbase_planning_mode_checks.sh` fails when planning-only defaults are broken or entrypoint gate checks are missing.

## Server Admin Reset Handler
- RPC entrypoint: `ARC_fnc_tocRequestAirbaseResetControlState`
- Server reset function: `ARC_fnc_airbaseAdminResetControlState`
- Default behavior: clear runway lock + pending control state while preserving history/events.
- Optional behavior: pass `preserveHistory=false` to also clear history/events.

## State Keys Cleared by Reset

### Always cleared
- `airbase_v1_runwayState` -> `OPEN`
- `airbase_v1_runwayOwner` -> `""`
- `airbase_v1_runwayUntil` -> `-1`
- `airbase_v1_clearanceRequests` -> `[]`
- `airbase_v1_queue` -> `[]`
- `airbase_v1_manualPriority` -> `[]`
- `airbase_v1_holdDepartures` -> `false`
- `airbase_v1_notifyState` -> empty map

### Cleared only when `preserveHistory=false`
- `airbase_v1_clearanceHistory` -> `[]`
- `airbase_v1_events` -> `[]`

## Rollback Procedure (if reset causes unwanted behavior)

1. **Stop issuing additional AIR actions** until state converges.
2. **Reinitialize AIRSUB runtime contract defaults** via:
   - `[] call ARC_fnc_airbaseInit;` (server)
   - ensure `airbase_v1_runwayState/Owner/Until` contract values are restored.
3. **Rebuild publish snapshot** so clients re-sync:
   - `[] call ARC_fnc_publicBroadcastState;` (server)
4. **If scheduler execution was in-flight**, force release runway lock:
   - `["", "", "", "ROLLBACK", true, "ROLLBACK"] call ARC_fnc_airbaseRunwayLockRelease;`
5. **Optional full control-plane wipe** if stale pending entries persist:
   - `[false, objNull] call ARC_fnc_airbaseAdminResetControlState;`
6. **Verify** in AIR panel and server RPT:
   - runway = `OPEN`
   - queue length = 0 (or expected restored entries)
   - no orphaned pending clearance requests.

## Dedicated-Server Deferred Verification

Deferred until dedicated environment is available:
- Restart-persistence behavior after AIR control reset.
- JIP synchronization after reset during active request churn.
- Reconnect/respawn ownership checks for privileged reset RPC.

## Recovery Notes
- If rollback must be reverted to pre-reset mission state, restore from persistence save + rerun `ARC_fnc_publicBroadcastState`.
- If only UI is stale, a broadcast refresh is usually sufficient; do not hard reset unless control-plane data is inconsistent.

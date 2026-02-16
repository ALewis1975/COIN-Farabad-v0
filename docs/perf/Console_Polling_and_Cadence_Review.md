# Console Polling and Cadence Review

This review inventories recurring loops that directly power the Farabad Console experience (UI refresh, data propagation to clients, and console access resilience).

## Recurring loop inventory

| Loop | File / function location | Interval + locality | Current justification | Risk level | Optimization recommendation |
|---|---|---|---|---|---|
| Console panel repaint loop | `functions/ui/fn_uiConsoleOnLoad.sqf` (`ARC_fnc_uiConsoleOnLoad`) | `uiSleep 1.2` (client, while console dialog is open) | Keeps all tabs current with live mission state and role changes, and intentionally pauses repaint while edit/combo controls are focused to avoid UX disruption. | **Medium** (constant polling while dialog is open; can over-refresh when no state changed). | Prefer event-driven invalidation: publish a `ARC_console_dirty` flag (or timestamp hash) from relevant state updates and repaint only when changed; keep a slower fallback cadence (e.g., 2–3s) for safety. |
| Snapshot watcher loop | `initPlayerLocal.sqf` (spawned `ARC_clientSnapshotWatcherRunning` guard block) | `uiSleep 0.5` (client, indefinite) | Ensures briefing/TOC views refresh immediately whenever `ARC_pub_stateUpdatedAt` changes, including JIP safety. | **Medium-High** (2 Hz poll per client for full mission duration; scales with player count). | Replace with push model (`publicVariableEventHandler` or dedicated client RPC on snapshot publish). If polling is retained, back off to 1.0–2.0s and only poll while relevant UI/screen is visible. |
| Console keepalive loop (steady state) | `initPlayerLocal.sqf` (spawned `ARC_consoleKeepaliveRunning` block) | Initial: 12x every 5s (first minute), then every 30s (client, indefinite) | Re-applies console keybind/init after locality swaps, mod interference, or UI rebuilds. | **Low-Medium** (lightweight but permanent periodic reinit). | Keep startup retries, but convert steady-state to event-driven hooks (`Respawn`, `InventoryOpened/Closed`, known framework reload hooks) and disable the 30s loop once a health check remains stable for N cycles. |
| TOC action keepalive loop | `initPlayerLocal.sqf` (final spawned TOC addAction keepalive block) | Initial: 12x every 5s, then every 30s (client, indefinite) + `GetInMan`/`GetOutMan` EH triggers | Ensures late-spawned TOC objects/mobile terminals have actions and recovers if other scripts clear actions. | **Medium** (duplicative periodic scans plus EH-triggered updates). | Lean harder on event-driven path already present: keep `GetInMan/GetOutMan`, add object-locality/object-creation hooks where possible, and reduce long-run cadence to 60–120s as a safety net. |
| Active execution loop (server) | `functions/core/fn_execLoop.sqf` (`ARC_fnc_execLoop`) | `sleep 5` (server, indefinite) | Drives active incident execution responsiveness and deferred cleanup scheduling. Console boards reflect outcomes produced here. | **Medium** (5s server loop is reasonable, but always-on cadence even during idle moments). | Use adaptive cadence: run at 2–5s when an active incident exists, relax to 10–15s when idle; alternatively move cleanup to its own scheduled loop with dynamic budget. |
| Incident orchestration loop (server) | `functions/core/fn_incidentLoop.sqf` (`ARC_fnc_incidentLoop`) | `sleep 60` normal, `sleep 10` during pause windows (server, indefinite) | Guarantees lifecycle progression by periodically ensuring active incident availability and respecting global pause controls. | **Low** (coarse cadence, modest overhead). | Keep cadence; optional improvement is event-triggered immediate tick on explicit admin/state transitions to reduce reliance on wait-for-next-interval behavior. |

## Priority recommendations

1. **Highest ROI:** Replace the 0.5s snapshot polling watcher with push-driven client refresh notifications.
2. **Second:** Add dirty-flag repaint invalidation for the 1.2s console UI loop.
3. **Third:** Retain startup resilience loops, but phase down perpetual 30s keepalive loops to event hooks + slower fallback cadence.

## Suggested target cadence profile (if full event conversion is deferred)

- Console repaint loop: **1.2s → 2.0s** (when no detected state change), immediate repaint on dirty flag.
- Snapshot watcher: **0.5s → 1.0–2.0s** until event-driven replacement lands.
- Keepalive loops: **30s → 60–120s** after first stable minute, with on-demand reinit events.
- Server exec loop: **adaptive 5s active / 10–15s idle**.

# AIR / TOWER — PR-by-PR Work Breakdown

Date: 2026-04-06  
Status: Accepted

## Branch model

Use narrow work branches cut from `dev` and land them in this order:

1. work/airtower-pr01-arma-native-doc-sync
2. work/airtower-pr02-shell-scaffold
3. work/airtower-pr03-airfield-ops-board
4. work/airtower-pr04-clearances-safety
5. work/airtower-pr05-air-input-flow
6. work/airtower-pr06-snapshot-freshness
7. work/airtower-pr07-dashboard-air-summary
8. work/airtower-pr08-map-pane
9. work/airtower-pr09-remoteexec-hardening
10. work/airtower-pr10-world-overlay
11. work/airtower-pr11-debug-cleanup

## PR 1 — work/airtower-pr01-arma-native-doc-sync
Mode: F  
Goal: Add the Arma-native audit matrix, the implementation matrix, and this PR breakdown as a docs-only plan set.

Scope:
- docs/architecture/AIR_TOWER_Arma_Native_Audit_Matrix.md
- docs/architecture/AIR_TOWER_Arma_Native_Implementation_Matrix.md
- docs/architecture/AIR_TOWER_PR_BY_PR_BREAKDOWN.md

Acceptance:
- No runtime files touched
- Scope exceptions are documented before code PRs begin

Rollback:
- Revert the docs commit only

## PR 2 — work/airtower-pr02-shell-scaffold
Mode: C  
Goal: Add AIR-dedicated grouped controls inside the existing console shell without changing user-visible behavior.

Primary files:
- config/CfgDialogs.hpp
- functions/ui/fn_uiConsoleRefresh.sqf
- functions/ui/fn_uiConsoleAirPaint.sqf
- config/CfgFunctions.hpp (only if helper extraction is needed)

Acceptance:
- No second AIR / TOWER dialog
- Layout remains stable on multiple UI scales and aspect ratios
- Current behavior remains functionally equivalent

## PR 3 — work/airtower-pr03-airfield-ops-board
Mode: B  
Goal: Replace the list-driven AIRFIELD_OPS layout with a fixed operational board.

Primary files:
- functions/ui/fn_uiConsoleAirPaint.sqf
- functions/ui/fn_uiConsoleRefresh.sqf
- config/CfgFunctions.hpp (only if helpers are extracted)

Acceptance:
- Status strip, decision band, arrivals, runway, departures, and detail pane are fixed sections
- Default focus lands on live operational state, not view metadata
- 3-second scan passes

## PR 4 — work/airtower-pr04-clearances-safety
Mode: A  
Goal: Remove unsafe fallback actions from inert CLEARANCES selections.

Primary files:
- functions/ui/fn_uiConsoleActionAirPrimary.sqf
- functions/ui/fn_uiConsoleActionAirSecondary.sqf
- functions/ui/fn_uiConsoleAirPaint.sqf

Acceptance:
- Non-action rows do not fire queue or airfield-wide control actions
- Only explicit eligible contexts can trigger HOLD / RELEASE or queue decisions

## PR 5 — work/airtower-pr05-air-input-flow
Mode: B  
Goal: Add controlled keyboard flow and confirmations for high-consequence AIR actions.

Primary files:
- functions/ui/fn_uiConsoleOnLoad.sqf
- functions/ui/fn_uiConsoleAirKeyDown.sqf (new)
- config/CfgFunctions.hpp
- Minimal touches to AIR action handlers if required

Acceptance:
- Narrow AIR-only hotkeys
- Confirm destructive actions
- No broad display hijacking

## PR 6 — work/airtower-pr06-snapshot-freshness
Mode: A  
Goal: Make freshness and degraded-state signaling real rather than placeholder values.

Primary files:
- functions/core/fn_publicBroadcastState.sqf
- functions/ui/fn_uiConsoleAirPaint.sqf
- functions/ui/fn_uiConsoleDashboardPaint.sqf (if needed)

Acceptance:
- Fresh, stale, and degraded states are computed and displayed correctly
- Late clients reconstruct current state safely

## PR 7 — work/airtower-pr07-dashboard-air-summary
Mode: B  
Goal: Finish the commander-facing air summary on DASH.

Primary files:
- functions/ui/fn_uiConsoleDashboardPaint.sqf
- functions/core/fn_publicBroadcastState.sqf (only if new summary fields are needed)

Acceptance:
- Command staff can answer runway availability, next inbound, next outbound, and top blocker from DASH

## PR 8 — work/airtower-pr08-map-pane
Mode: B  
Goal: Add a CT_MAP-driven spatial traffic pane to AIRFIELD_OPS.

Primary files:
- config/CfgDialogs.hpp
- functions/ui/fn_uiConsoleRefresh.sqf
- functions/ui/fn_uiConsoleAirPaint.sqf or fn_uiConsoleAirMapPaint.sqf (new)
- functions/ui/fn_uiConsoleMainListSelChanged.sqf
- functions/core/fn_publicBroadcastState.sqf
- config/CfgFunctions.hpp

Acceptance:
- Map shows runway and selected traffic context
- Selection recenters map correctly

## PR 9 — work/airtower-pr09-remoteexec-hardening
Mode: I  
Goal: Complete CfgRemoteExec allowlist work for AIR / TOWER paths.

Primary files:
- description.ext
- docs/security/RemoteExec_Hardening_Plan.md (if maintained)
- tests/TEST-LOG.md

Acceptance:
- All AIR client-to-server request wrappers are correctly allowlisted
- JIP flags are explicit where needed

## PR 10 — work/airtower-pr10-world-overlay
Mode: B  
Goal: Add local tower and pilot overlays for the few cues that belong outside the dialog.

Primary files:
- initPlayerLocal.sqf
- config/CfgFunctions.hpp
- functions/ui/fn_airbaseOverlayInit.sqf (new)
- functions/ui/fn_airbaseOverlayDraw3D.sqf (new)
- HUD config include point if required by the mission shell

Acceptance:
- Highest-value cues only
- Overlay is local, sparse, and context-gated

## PR 11 — work/airtower-pr11-debug-cleanup
Mode: C  
Goal: Remove obsolete fallback render logic and isolate DEBUG from operator UX.

Primary files:
- functions/ui/fn_uiConsoleAirPaint.sqf
- functions/ui/fn_uiConsoleRefresh.sqf
- functions/core/fn_publicBroadcastState.sqf

Acceptance:
- Operator view is clean
- Debug-only telemetry stays in DEBUG
- Legacy compatibility branches are retired only after earlier PRs stabilize

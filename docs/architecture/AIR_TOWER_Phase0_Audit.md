# AIR / TOWER — Phase 0 Audit

**Date:** 2026-04-06  
**Branch:** `copilot/design-architecture-plan-air-tower`  
**Scope:** Exhaustive owner-file map, keep/change/delete decisions, and regression risk assessment for the AIR / TOWER surface redesign.  
**Mode:** F — Documentation-Only Changes

---

## 1) Owner-File Map

### 1.1 UI Layer (client-side, `hasInterface` only)

| File | Lines | Role | Touches AIR |
|------|------:|------|:-----------:|
| `functions/ui/fn_uiConsoleOnLoad.sqf` | 372 | Dialog bootstrap; builds tab list, sets 11 AIR permission vars in `uiNamespace`, detects tower/pilot role, starts refresh loop | **YES** — lines 156–208, 239–243 |
| `functions/ui/fn_uiConsoleRefresh.sqf` | ~418 | Tab dispatch; layout/button config per tab, calls paint functions | **YES** — case "AIR" lines 227–277 |
| `functions/ui/fn_uiConsoleAirPaint.sqf` | 951 | Main AIR renderer; reads `ARC_pub_state.airbase`, builds list rows (STATUS, EXEC, REQ, FLT, EVT, LANE, RWY, DEC), builds selection detail HTML, manages button labels/enables | **PRIMARY** |
| `functions/ui/fn_uiConsoleActionAirPrimary.sqf` | 177 | Primary button handler: PILOT → submit request / cancel; TOWER → REQ approve, FLT expedite, LANE claim, default HOLD | **PRIMARY** |
| `functions/ui/fn_uiConsoleActionAirSecondary.sqf` | 141 | Secondary button handler: PILOT → mode switch / refresh; TOWER → REQ deny, FLT cancel, LANE release, HDR → mode switch, default RELEASE | **PRIMARY** |
| `functions/ui/fn_uiConsoleMainListSelChanged.sqf` | 62 | List selection change; updates `ARC_console_airSelectedFid` / `airSelectedRow` / `airSelectedRowType` | **YES** — lines 41–42 |
| `functions/ui/fn_uiConsoleSelectTab.sqf` | ~30 | Tab selection handler; sets active tab, triggers refresh | indirect |

### 1.2 Server-Side Snapshot Publishing

| File | Lines | Role | Touches AIR |
|------|------:|------|:-----------:|
| `functions/core/fn_publicBroadcastState.sqf` | ~520+ | Builds `ARC_pub_state` from all subsystems; airbase sub-block at lines 441–479 publishes `["airbase", [...]]` with 28+ fields | **PRIMARY** — airbase sub-block |

### 1.3 Authorization

| File | Lines | Role | Touches AIR |
|------|------:|------|:-----------:|
| `functions/core/fn_airbaseTowerAuthorize.sqf` | 183 | Token-based auth: checks CCIC, BnCmd, LC tokens against `groupId + roleDescription`; returns `[BOOL, level, reason]` | **PRIMARY** |
| `functions/core/fn_tocRequestAirbaseResetControlState.sqf` | ~20 | TOC request to reset control state | **YES** |

### 1.4 Airbase Runtime (server-side `isServer` only)

| File | Lines | Purpose |
|------|------:|---------|
| `functions/ambiance/fn_airbaseInit.sqf` | 878 | Main init: FID generator, queue/record stores, default configs |
| `functions/ambiance/fn_airbaseTick.sqf` | 1,304 | Main scheduler tick loop |
| `functions/ambiance/fn_airbasePostInit.sqf` | 41 | `postInit = 1` entry; calls init if runtime enabled |
| `functions/ambiance/fn_airbaseRuntimeEnabled.sqf` | 18 | Guard: returns `airbase_v1_runtime_enabled` |
| `functions/ambiance/fn_airbasePlaneDepart.sqf` | 658 | Full departure sequence |
| `functions/ambiance/fn_airbaseSpawnArrival.sqf` | 235 | Spawn arrival aircraft |
| `functions/ambiance/fn_airbaseAttackTowDepart.sqf` | 144 | Attack-tow departure variant |
| `functions/ambiance/fn_airbaseRestoreParkedAsset.sqf` | 72 | Restore parked asset after despawn |
| `functions/ambiance/fn_airbaseRunwayLockSweep.sqf` | 74 | Sweep stale runway locks |
| `functions/ambiance/fn_airbaseRunwayLockReserve.sqf` | 81 | Reserve runway |
| `functions/ambiance/fn_airbaseRunwayLockOccupy.sqf` | 80 | Mark runway occupied |
| `functions/ambiance/fn_airbaseRunwayLockRelease.sqf` | 80 | Release runway lock |
| `functions/ambiance/fn_airbaseSubmitClearanceRequest.sqf` | 361 | Server: process clearance request |
| `functions/ambiance/fn_airbaseCancelClearanceRequest.sqf` | 120 | Server: cancel clearance |
| `functions/ambiance/fn_airbaseMarkClearanceEmergency.sqf` | 109 | Server: escalate to emergency |
| `functions/ambiance/fn_airbaseRequestClearanceDecision.sqf` | 262 | Server: approve/deny decision |
| `functions/ambiance/fn_airbaseClearanceSortRequests.sqf` | 43 | Sort clearance queue |
| `functions/ambiance/fn_airbaseBuildRouteDecision.sqf` | 147 | Route validation for clearance |
| `functions/ambiance/fn_airbaseRequestHoldDepartures.sqf` | 51 | Server: hold departures |
| `functions/ambiance/fn_airbaseRequestReleaseDepartures.sqf` | 50 | Server: release departures |
| `functions/ambiance/fn_airbaseRequestPrioritizeFlight.sqf` | 98 | Server: expedite queued flight |
| `functions/ambiance/fn_airbaseRequestCancelQueuedFlight.sqf` | 245 | Server: cancel queued flight |
| `functions/ambiance/fn_airbaseQueueMoveToFront.sqf` | 18 | Queue utility |
| `functions/ambiance/fn_airbaseQueueRemoveByFid.sqf` | 17 | Queue utility |
| `functions/ambiance/fn_airbaseRecordSetQueuedStatus.sqf` | 39 | Record utility |
| `functions/ambiance/fn_airbaseRequestSetLaneStaffing.sqf` | 128 | Server: set lane controller |
| `functions/ambiance/fn_airbaseOrbatPopulate.sqf` | 516 | ORBAT population |
| `functions/ambiance/fn_airbaseCrewIdleStart.sqf` | 60 | Crew idle animation |
| `functions/ambiance/fn_airbaseCrewIdleStop.sqf` | 12 | Crew idle cleanup |
| `functions/ambiance/fn_airbaseDiaryUpdate.sqf` | 37 | Diary record |
| `functions/ambiance/fn_airbaseSecurityInit.sqf` | 29 | Security zone init |
| `functions/ambiance/fn_airbaseSecurityPatrol.sqf` | 81 | Security patrol loop |
| `functions/ambiance/fn_airbaseGroundTrafficInit.sqf` | 309 | Ground traffic init |
| `functions/ambiance/fn_airbaseGroundTrafficBuildPool.sqf` | 61 | Ground traffic pool |
| `functions/ambiance/fn_airbaseGroundTrafficTick.sqf` | 227 | Ground traffic tick |
| `functions/ambiance/fn_airbaseAdminResetControlState.sqf` | 129 | Admin: reset all control state |

### 1.5 Client RPC Wrappers

| File | Purpose |
|------|---------|
| `fn_airbaseClientSubmitClearanceRequest.sqf` | `remoteExec` → server submit |
| `fn_airbaseClientCancelClearanceRequest.sqf` | `remoteExec` → server cancel |
| `fn_airbaseClientMarkClearanceEmergency.sqf` | `remoteExec` → server emergency |
| `fn_airbaseClientRequestClearanceDecision.sqf` | `remoteExec` → server approve/deny |
| `fn_airbaseClientRequestHoldDepartures.sqf` | `remoteExec` → server hold |
| `fn_airbaseClientRequestReleaseDepartures.sqf` | `remoteExec` → server release |
| `fn_airbaseClientRequestPrioritizeFlight.sqf` | `remoteExec` → server expedite |
| `fn_airbaseClientRequestCancelQueuedFlight.sqf` | `remoteExec` → server cancel flight |
| `fn_airbaseClientRequestSetLaneStaffing.sqf` | `remoteExec` → server staffing |

### 1.6 Config

| File | Relevance |
|------|-----------|
| `config/CfgFunctions.hpp` | Registers all `ARC_fnc_airbase*` and `ARC_fnc_uiConsoleAir*` functions |
| `config/CfgDialogs.hpp` | Console dialog `ARC_FarabadConsoleDialog` (IDD 78000); **no AIR-specific controls** — AIR uses shared IDCs 78011 (list), 78012 (details), 78021/78022 (buttons) |

---

## 2) uiNamespace AIR Variables (11 permission + 8 state)

### Permission Flags (set in `fn_uiConsoleOnLoad.sqf`, consumed everywhere)

| Variable | Type | Source |
|----------|------|--------|
| `ARC_console_airCanHold` | BOOL | `ARC_fnc_airbaseTowerAuthorize` "HOLD" |
| `ARC_console_airCanRelease` | BOOL | `ARC_fnc_airbaseTowerAuthorize` "RELEASE" |
| `ARC_console_airCanPrioritize` | BOOL | `ARC_fnc_airbaseTowerAuthorize` "PRIORITIZE" |
| `ARC_console_airCanCancel` | BOOL | `ARC_fnc_airbaseTowerAuthorize` "CANCEL" |
| `ARC_console_airCanStaff` | BOOL | `ARC_fnc_airbaseTowerAuthorize` "STAFF" |
| `ARC_console_airCanHoldRelease` | BOOL | derived: `canHold OR canRelease` |
| `ARC_console_airCanQueueManage` | BOOL | derived: `canPrioritize OR canCancel` |
| `ARC_console_airCanControl` | BOOL | derived: `canHoldRelease OR canQueueManage OR canStaff` |
| `ARC_console_airCanRead` | BOOL | `canControl OR isOmni OR canTocFull OR isBnCmd` |
| `ARC_console_airCanPilot` | BOOL | pilot group token or vehicle check |
| `ARC_console_airMode` | STRING | "TOWER" or "PILOT" |

### State Variables (set in `fn_uiConsoleAirPaint.sqf`)

| Variable | Type | Purpose |
|----------|------|---------|
| `ARC_console_airLastStateUpdatedAt` | NUMBER | Last `ARC_pub_stateUpdatedAt` processed |
| `ARC_console_airHoldDepartures` | BOOL | Current hold state from snapshot |
| `ARC_console_airSelectedFid` | STRING | Selected flight ID |
| `ARC_console_airSelectedRow` | ARRAY | Parsed row data from list selection |
| `ARC_console_airSelectedRowType` | STRING | Row type prefix (FLT/REQ/HDR/PACT/etc.) |
| `ARC_console_airDetailsDefaultPos` | ARRAY | Default details panel position for auto-fit |
| `ARC_console_casreqSnapshot` | ARRAY | Cached CASREQ snapshot from pub_state |
| `ARC_console_casreqId` | STRING | Active CASREQ ID |

---

## 3) Published Snapshot Shape (`ARC_pub_state.airbase`)

Current fields (28 total, from `fn_publicBroadcastState.sqf` lines 441–479):

```
depQueued                     : NUMBER
depInProgress                 : NUMBER
arrQueued                     : NUMBER
totalQueued                   : NUMBER
execActive                    : BOOL
execFid                       : STRING
holdDepartures                : BOOL
runwayState                   : STRING  (OPEN/OCCUPIED/RESERVED)
runwayOwner                   : STRING
runwayUntil                   : NUMBER
nextItems                     : ARRAY   (queued flights: [fid, kind, asset, routeMeta])
recordsCount                  : NUMBER
clearanceSeq                  : NUMBER
clearancePendingCount         : NUMBER
clearanceEmergencyCount       : NUMBER
clearanceAwaitingTowerCount   : NUMBER
clearancePending              : ARRAY   (pending clearance views)
clearanceControllerPending    : ARRAY   (same as above)
clearanceHistoryTail          : ARRAY   (recent decisions)
towerStaffing                 : ARRAY   (lane records)
recentEvents                  : ARRAY   (event view)
blockedRouteAttemptsRecent    : NUMBER
blockedRouteLatestReason      : STRING
blockedRouteLatestSourceId    : STRING
blockedRouteTail              : ARRAY
arrivalRunwayMarker           : STRING
arrivalLandGateM              : NUMBER
arrivalWarnAdvisoryM          : NUMBER
arrivalWarnCautionM           : NUMBER
arrivalWarnUrgentM            : NUMBER
inboundTaxiMarkers            : ARRAY
controllerTimeoutTowerS       : NUMBER
controllerTimeoutGroundS      : NUMBER
controllerTimeoutArrivalS     : NUMBER
automationDelayTowerS         : NUMBER
automationDelayGroundS        : NUMBER
automationDelayArrivalS       : NUMBER
```

---

## 4) Current Row Types in AIR List

| Row type prefix | Source section | Content | Audience |
|:---------------:|:-------------:|---------|:--------:|
| `STATUS` | Airspace Status | Runway + Hold + Exec summary line | All |
| `EXEC` | Active Departure | Currently executing flight | All |
| `REQ` | Pending Clearances | Clearance requests pending tower decision | Tower/Pilot |
| `FLT` | Scheduled Flights | Queued flights (arrival/departure) | Tower |
| `EVT` | Recent Events | Last 5 filtered airbase events | All |
| `LANE` | ATC Staffing | Tower/Ground/Arrival lane status | Tower |
| `RWY` | Runway & Hold | Detailed runway lock state | Tower |
| `DEC` | Recent Decisions | Last 5 clearance decision history | Tower |
| `HDR` | Section headers | Non-selectable dividers | — |
| `PACT` | Pilot Actions | Request Taxi/Takeoff/Inbound/Emergency/Cancel | Pilot |
| `PWRN` | Pilot ATC Warnings | Own inbound request with distance warnings | Pilot |

---

## 5) Keep / Change / Delete Map

### KEEP (no modification needed)

| Component | Reason |
|-----------|--------|
| Farabad Console shell (`ARC_FarabadConsoleDialog`, IDD 78000) | Shared infrastructure; hard non-goal to replace |
| `ARC_console_forceTab` entry pattern | Existing station-aware open mechanism |
| `fn_uiConsoleOnLoad.sqf` tab list + permission detection | Well-tested gating logic |
| `fn_airbaseTowerAuthorize.sqf` full authorization logic | Correct and complete auth model |
| All `fn_airbaseClient*.sqf` RPC wrappers | Clean client→server pattern |
| All `fn_airbase*.sqf` server-side runtime functions | Not in scope for UI redesign |
| `ARC_pub_state.airbase` publishing in `fn_publicBroadcastState.sqf` | Still needed for non-AIR consumers |
| `config/CfgDialogs.hpp` shared controls (78011/78012/78021/78022) | Reuse; no AIR-specific controls exist |
| 11 permission flags in `uiNamespace` | Correct role model |
| PILOT submode + action handlers for pilot clearance requests | Correct pilot workflow |

### CHANGE (modify in place)

| Component | What changes | Why |
|-----------|-------------|-----|
| `fn_uiConsoleAirPaint.sqf` | Replace monolithic list-based rendering with layered operational board (status strip → decisions → arrivals/departures/runway → detail pane) | 3-second scan clarity; separation of concerns |
| `fn_uiConsoleAirPaint.sqf` details pane | Stop dumping the entire snapshot + route validation + CASREQ contract into default detail view | Operator vs debug separation |
| `fn_uiConsoleRefresh.sqf` AIR case | Add submode switching (AIRFIELD_OPS / CLEARANCES / DEBUG) alongside existing TOWER/PILOT modes | Role-first information architecture |
| `fn_uiConsoleActionAirPrimary.sqf` | Reorganize button labels for submode context (remove "NO HOLD AUTH" dead buttons; use clean READ-ONLY labels) | No dead buttons rule |
| `fn_uiConsoleActionAirSecondary.sqf` | Same cleanup as primary; add submode toggle action | No dead buttons rule |
| `fn_publicBroadcastState.sqf` (airbase sub-block) | Add a parallel normalized `airbase_ui_snapshot_v1` alongside existing raw block, OR publish as a separate `missionNamespace` variable | UI contract separation |
| `config/CfgFunctions.hpp` | Register new AIR/TOWER functions if created | Function registration requirement |

### DELETE from default operator view (move to DEBUG submode)

| Content | Current location | Reason |
|---------|-----------------|--------|
| Route validation section (blockedRouteAttemptsRecent, latestReason, latestSourceId) | Details pane, always visible | Developer-facing telemetry |
| CASREQ snapshot contract text (casreqId, rev, district, state) | Details pane, always visible | Internal contract language |
| Raw owner IDs and lane UIDs | Lane detail view | Admin-only data |
| Clearance history tail raw dump | List and detail pane | Debug audit trail |
| Internal field names in labels (e.g., `runwayLaneDecision`, `routeMarkerChain`) | Selection detail HTML | Raw contract jargon |
| "NO HOLD AUTH" / "NO QUEUE AUTH" / "NO ACCESS" disabled buttons | Button labels | Dead buttons violating UX rule |

---

## 6) Current UX Failures (mapped to vision document)

| # | Failure | Evidence |
|---|---------|----------|
| 1 | **No 3-second scan clarity** | 11+ list sections (STATUS, EXEC, REQ, FLT, EVT, LANE, RWY, DEC) in one scrollable list; user must scroll to find any single fact |
| 2 | **No first-class arrival picture** | Arrivals appear only as items inside `nextItems` (FLT rows) mixed with departures; no "ARRIVALS" section header or explicit empty state |
| 3 | **No strong visual hierarchy** | All sections use identical `-- HEADER --` text delimiters; no color-coded status chips; no R/A/G visual system |
| 4 | **No clear R/A/G status system** | No color-coded indicators; all text is monochrome structured text |
| 5 | **Developer/internal language in default view** | Details pane shows: "Blocked-route attempts (recent)", "CASREQ Snapshot Contract", "Route Validation", "routeMarkerChain", "runwayLaneDecision" |
| 6 | **Unclear audience** | Same 951-line paint function serves commander (needs summary), ATC (needs queue), tester (needs internals), and pilot (needs own request status) |
| 7 | **Dead buttons** | "NO HOLD AUTH", "NO QUEUE AUTH", "NO ACCESS", "APPROVE (N/A)", "DENY (N/A)", "EXPEDITE (N/A)", "CANCEL (N/A)" all render as disabled buttons |

---

## 7) Regression Risks

### HIGH RISK

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Breaking console refresh loop | All tabs stop updating | Keep refresh dispatch signature identical; only change AIR case internals |
| Mixing new snapshot reads with old `ARC_pub_state.airbase` raw reads | Stale/mismatched data | UI must consume ONLY the new normalized snapshot once migration starts; old reads must be fully replaced, not layered |
| Authority leakage in clearance actions | Unauthorized approve/deny | Action handlers already validate permissions; preserve all `canAirQueueManage` / `canAirStaff` / `canAirHoldRelease` guards exactly |
| Breaking PILOT submode | Pilots lose clearance request capability | Keep `fn_uiConsoleActionAirPrimary.sqf` PILOT path intact; test separately |

### MEDIUM RISK

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Details pane auto-fit regression | Text overflows or becomes unreadable | Preserve `BIS_fnc_ctrlFitToTextHeight` + position clamp pattern |
| List selection persistence across refreshes | Selected row jumps unpredictably | Preserve `_prevSelData` → restore pattern from current paint function |
| Tab permission detection regression | AIR tab appears/disappears incorrectly | Do not change `fn_uiConsoleOnLoad.sqf` permission detection block |
| CASREQ snapshot drift | AIR/TOWER shows stale or wrong CAS data | Preserve read-only consumption of `ARC_pub_state.casreq`; do NOT add local inference |
| New UI snapshot not populated at JIP | JIP clients see empty AIR tab | Ensure new snapshot is published with `true` (broadcast to all) and JIP-safe |

### LOW RISK

| Risk | Impact | Mitigation |
|------|--------|-----------|
| sqflint compat violations in new code | CI failure | Follow `docs/qa/SQFLINT_COMPAT_GUIDE.md`: no `#`, no `findIf`, no direct `trim`, no `isNotEqualTo` |
| CfgFunctions registration missed for new functions | Function not compiled | Checklist item before merge |
| Ground traffic / security patrol disruption | Ambient base behavior breaks | These functions are not touched by UI redesign |

---

## 8) Existing Anchors to Preserve

### ORBAT / Role Anchors
- `FarabadTower_LA` — AI tower assist unit
- `farabad_tower_ws_ccic` — Watch Supervisor / CIC role
- `farabad_tower_lc` — Local Controller role
- `FARABAD TOWER` — Tower groupId token
- `FARABAD GROUND` — Ground groupId token
- `FARABAD APPROACH` — Approach groupId token

### Config Anchors
- `airbase_v1_tower_ccicTokens` — CCIC matching tokens
- `airbase_v1_tower_lcTokens` — LC matching tokens
- `airbase_v1_tower_bnCommandTokens` — BnCmd matching tokens
- `airbase_v1_pilotGroupTokens` — Pilot group tokens
- `airbase_v1_tower_lc_allowedActions` — LC action whitelist
- `airbase_v1_runtime_enabled` — Runtime master switch

### Marker Anchors
- `mkr_airbaseCenter` — Airbase bubble center

---

## 9) Files NOT Touched by UI Redesign

The following files are **explicitly out of scope** and must not be modified:

- All `functions/ambiance/fn_airbase*.sqf` server-side runtime functions (init, tick, depart, spawn, runway lock, queue utilities, security, ground traffic, ORBAT)
- `mission.sqm` — no Eden changes
- `description.ext` — no mission config changes
- `initServer.sqf` — no bootstrap changes (unless adding new snapshot publication)
- `initPlayerLocal.sqf` — no client bootstrap changes
- All non-AIR console tab painters and action handlers
- All CASREQ, CIVSUB, THREAT, TASKENG functions

---

## 10) Audit Summary

| Metric | Count |
|--------|------:|
| Total AIR/TOWER owner files (UI + runtime + auth) | 54 |
| UI-layer files directly modified by redesign | 5 |
| Server-side files touched (snapshot publisher) | 1 |
| Config files touched | 1 (CfgFunctions if new functions added) |
| Client RPC wrappers (keep as-is) | 9 |
| Server runtime files (do NOT touch) | 35 |
| uiNamespace variables (11 perm + 8 state) | 19 |
| Current list row types | 11 |
| Current published snapshot fields | 37 |
| UX failures identified | 7 |
| Regression risks (H/M/L) | 4 / 5 / 3 |

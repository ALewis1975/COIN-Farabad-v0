# AIR / TOWER — Arma-Native Phase-by-Phase Implementation Matrix

Date: 2026-04-06  
Status: Accepted  
Companion docs:
- Audit baseline: `AIR_TOWER_Phase0_Audit.md`
- Vision + architecture: `AIR_TOWER_Vision_Architecture_Plan.md`
- Snapshot contract: `AIR_TOWER_UI_Snapshot_Contract_v1.md`
- Button behavior: `AIR_TOWER_Button_Behavior_Matrix.md`
- Arma-native audit: `AIR_TOWER_Arma_Native_Audit_Matrix.md`
- PR-by-PR breakdown: `AIR_TOWER_PR_BY_PR_BREAKDOWN.md`
- RemoteExec hardening: `../security/RemoteExec_Hardening_Plan.md`

---

## 1) Overview

This document converts the AIR / TOWER Arma-native audit into a phase-by-phase implementation plan sized for narrow pull requests. Each phase maps 1:1 to a PR in `AIR_TOWER_PR_BY_PR_BREAKDOWN.md`.

### Summary table

| Phase | PR | Mode | Goal | Status | Exit gate |
|:-----:|:--:|:----:|------|:------:|-----------|
| 0 | 1 | F | Baseline + scope lock | Done | Agreed scope, branch order, acceptance gates |
| 1 | 2 | C | UI shell scaffold | Not started | AIR gets dedicated grouped controls; no second dialog |
| 2 | 3 | B | AIRFIELD_OPS board conversion | Not started | 3-second scan works; default focus on ops state |
| 3 | 4 | A | CLEARANCES safety hardening | Not started | No unsafe global action from inert selection |
| 4 | 5 | B | AIR input flow + confirmations | Not started | Narrow hotkeys; confirm destructive actions |
| 5 | 6 | A | Snapshot freshness + degraded-state correctness | Not started | Fresh/stale/degraded real; late clients safe |
| 6 | 7 | B | DASH air summary completion | Not started | Commanders read air status from DASH alone |
| 7 | 8 | B | AIR map pane integration | Not started | CT_MAP traffic pane; selection recenters map |
| 8 | 9 | I | RemoteExec hardening completion | Not started | Allowlist complete; JIP flags explicit |
| 9 | 10 | B | World overlay layer | Not started | Sparse in-world cues; no UI clutter |
| 10 | 11 | C | Debug isolation + legacy cleanup | Not started | Operator view clean; debug isolated; legacy retired |

### Recommended rollout order

0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10

Each phase is gated by its predecessor's exit criteria. No phase ships until the prior phase is validated per `tests/TEST-LOG.md`.

---

## 2) Audit finding → phase mapping

The Arma-native audit (`AIR_TOWER_Arma_Native_Audit_Matrix.md`) identified six deficiency areas. The table below maps each audit finding to the phase(s) that address it.

| Audit area | Score | Primary phase(s) | Secondary phase(s) |
|---|:---:|---|---|
| Control choice (CT_LISTNBOX, CT_TREE, CT_MAP, CT_CONTROLS_GROUP) | C | Phase 1 (shell scaffold) | Phase 2 (ops board), Phase 7 (map pane) |
| SafeZone behavior (GUI_GRID review) | C | Phase 1 (shell scaffold) | — |
| Event flow (keyboard, confirmations) | C+ | Phase 4 (input flow) | Phase 3 (clearances safety) |
| Multiplayer locality (stale-state, RemoteExec) | B- | Phase 5 (snapshot freshness) | Phase 8 (RemoteExec hardening) |
| World-space overlays (Draw3D) | D | Phase 9 (world overlay) | — |
| Map integration (CT_MAP traffic) | D+ | Phase 7 (map pane) | — |

### UX failure → phase mapping

From `AIR_TOWER_Phase0_Audit.md` §6:

| # | UX failure | Phase |
|:---:|-----------|:-----:|
| 1 | No 3-second scan clarity | 2 |
| 2 | No first-class arrival picture | 2 |
| 3 | No strong visual hierarchy | 1, 2 |
| 4 | No clear R/A/G status system | 2 |
| 5 | Developer/internal language in default view | 2, 10 |
| 6 | Unclear audience separation | 2, 3, 6, 10 |
| 7 | Dead buttons | 3, 4 |

---

## 3) File-touch heat map

Files touched across phases. Higher touch-count files carry higher regression risk and require extra care.

| File | Phases | Touch count | Risk tier |
|------|--------|:-----------:|:---------:|
| `functions/ui/fn_uiConsoleAirPaint.sqf` | 1,2,3,5,7,10 | 6 | **HIGH** |
| `functions/core/fn_publicBroadcastState.sqf` | 2,5,6,7 | 4 | **HIGH** |
| `functions/ui/fn_uiConsoleRefresh.sqf` | 1,2,7,10 | 4 | HIGH |
| `config/CfgFunctions.hpp` | 1,4,7,9 | 4 | MEDIUM |
| `config/CfgDialogs.hpp` | 1,7 | 2 | MEDIUM |
| `functions/ui/fn_uiConsoleActionAirPrimary.sqf` | 3,4 | 2 | MEDIUM |
| `functions/ui/fn_uiConsoleActionAirSecondary.sqf` | 3,4 | 2 | MEDIUM |
| `functions/ui/fn_uiConsoleDashboardPaint.sqf` | 5,6 | 2 | MEDIUM |
| `functions/ui/fn_uiConsoleOnLoad.sqf` | 3,4 | 2 | MEDIUM |
| `functions/ui/fn_uiConsoleMainListSelChanged.sqf` | 2,7 | 2 | LOW |
| `description.ext` | 8 | 1 | MEDIUM |
| `initPlayerLocal.sqf` | 9 | 1 | LOW |
| `tests/TEST-LOG.md` | all | all | — |

### Files explicitly NOT touched (out-of-scope invariant)

All 35 server-side `fn_airbase*.sqf` runtime functions, all 9 `fn_airbaseClient*.sqf` RPC wrappers, all non-AIR console painters, `mission.sqm`, `initServer.sqf`, all CASREQ/CIVSUB/THREAT/TASKENG functions.

---

## 4) Per-phase detail

---

### Phase 0 — Baseline + scope lock

**PR:** `work/airtower-pr01-arma-native-doc-sync`  
**Mode:** F — Documentation-Only  
**Status:** Done

**Goal:** Freeze contract, publish audit matrix, implementation matrix, and PR roadmap.

**Files:**
| File | Change |
|------|--------|
| `docs/architecture/AIR_TOWER_Arma_Native_Audit_Matrix.md` | New |
| `docs/architecture/AIR_TOWER_Arma_Native_Implementation_Matrix.md` | New |
| `docs/architecture/AIR_TOWER_PR_BY_PR_BREAKDOWN.md` | New |
| `docs/planning/Task_Decomposition.md` | Add AIR/TOWER roadmap cross-reference |

**Acceptance criteria:**
- [x] No runtime files touched
- [x] Scope exceptions documented before code PRs begin

**Dependencies:** None.

**Risks:** None. Docs-only.

---

### Phase 1 — UI shell scaffold

**PR:** `work/airtower-pr02-shell-scaffold`  
**Mode:** C — Safe Refactor (no behavior change)

**Goal:** Add AIR-dedicated grouped controls (`CT_CONTROLS_GROUP`) inside the existing Farabad Console shell. Review and confirm SafeZone/GUI_GRID layout discipline. No second dialog. No user-visible behavior change.

**Audit findings addressed:**
- Control choice (C → target B+): introduce grouped control infrastructure
- SafeZone behavior (C → target B): validate layout against GUI_GRID assumptions

**Files:**
| File | Change |
|------|--------|
| `config/CfgDialogs.hpp` | Add AIR-specific `CT_CONTROLS_GROUP` controls inside `ARC_FarabadConsoleDialog` (IDD 78000); assign new IDCs in AIR range |
| `functions/ui/fn_uiConsoleRefresh.sqf` | Update AIR case to initialize new grouped controls; route paint to new control references |
| `functions/ui/fn_uiConsoleAirPaint.sqf` | Adapt paint to write into grouped controls instead of shared list/detail IDCs only |
| `config/CfgFunctions.hpp` | Register helper functions if any are extracted |

**Acceptance criteria:**
- [ ] No second AIR / TOWER dialog created
- [ ] Layout stable on 16:9, 16:10, and 4:3 aspect ratios
- [ ] Current behavior remains functionally equivalent (smoke test: open AIR tab, verify all existing sections render)
- [ ] sqflint + compat scan pass on all changed files
- [ ] No new controls visible to user yet — scaffold only

**Dependencies:** Phase 0 complete.

**Risks:**
| Risk | Severity | Mitigation |
|------|:--------:|-----------|
| Breaking console refresh loop | HIGH | Keep refresh dispatch signature identical; only change AIR case internals |
| New IDC collision with existing controls | MEDIUM | Use dedicated AIR IDC range (78100–78199) documented in CfgDialogs |
| Layout breaks on non-standard resolutions | MEDIUM | Test on multiple SafeZone configs |

---

### Phase 2 — AIRFIELD_OPS board conversion

**PR:** `work/airtower-pr03-airfield-ops-board`  
**Mode:** B — Feature Delivery

**Goal:** Replace the list-driven AIRFIELD_OPS layout with a fixed operational board matching the Vision Plan §4 information architecture: status strip → decision band → arrivals/runway/departures → detail pane. Default focus lands on live operational state, not view metadata.

**Audit findings addressed:**
- Control choice (continued from Phase 1)
- UX failures #1 (3-second scan), #2 (arrivals), #3 (visual hierarchy), #4 (R/A/G), #5 (developer language, partial)

**Files:**
| File | Change |
|------|--------|
| `functions/ui/fn_uiConsoleAirPaint.sqf` | Replace monolithic list rendering with layered operational board; implement R/A/G status strip, decision band, arrivals/departures/runway sections per Vision Plan §4.2–4.6 |
| `functions/ui/fn_uiConsoleRefresh.sqf` | Update AIR case for AIRFIELD_OPS submode; set default focus |
| `functions/ui/fn_uiConsoleMainListSelChanged.sqf` | Update selection handler for new row structure |
| `functions/core/fn_publicBroadcastState.sqf` | Add translator block: `airbase_v1_*` state → `ARC_pub_airbaseUiSnapshot` per Snapshot Contract v1 |

**Acceptance criteria:**
- [ ] Status strip shows 5 R/A/G chips (runway, arrivals, departures, tower mode, alerts)
- [ ] Decision band shows pending decisions or is hidden when none
- [ ] Arrivals block shows explicit traffic rows or `"No arrivals inbound"`
- [ ] Departures block shows queued flights or `"No departures queued"`
- [ ] Runway block shows current owner, movement, hold state
- [ ] 3-second scan test: new user can answer runway/inbound/outbound/decision state within 3 seconds
- [ ] No debug/developer text in default view
- [ ] Proper empty states per Vision Plan §4 empty-state rules
- [ ] Freshness wording follows rules: "Updated Xs ago" ≠ "State unchanged for Xm"
- [ ] Existing `ARC_pub_state.airbase` block unchanged (other consumers depend on it)
- [ ] `ARC_pub_airbaseUiSnapshot` published with `true` (broadcast) and JIP-safe
- [ ] sqflint + compat scan pass

**Dependencies:** Phase 1 complete (shell scaffold provides grouped controls).

**Risks:**
| Risk | Severity | Mitigation |
|------|:--------:|-----------|
| Mixing new snapshot reads with old raw reads | HIGH | UI must consume ONLY `ARC_pub_airbaseUiSnapshot` once migration starts; old reads fully replaced |
| List selection persistence regression | MEDIUM | Preserve `_prevSelData` → restore pattern |
| JIP snapshot not populated for late joiners | MEDIUM | Ensure `missionNamespace setVariable` uses `true` for broadcast |
| Details pane auto-fit regression | MEDIUM | Preserve `BIS_fnc_ctrlFitToTextHeight` + position clamp pattern |

---

### Phase 3 — CLEARANCES safety hardening

**PR:** `work/airtower-pr04-clearances-safety`  
**Mode:** A — Bug Fix (behavior correction)

**Goal:** Remove unsafe fallback actions from inert CLEARANCES selections. Ensure only explicit eligible contexts can trigger HOLD/RELEASE or queue-wide actions. Implement button behavior per `AIR_TOWER_Button_Behavior_Matrix.md`.

**Audit findings addressed:**
- Event flow (C+ → target B): safe action dispatch in CLEARANCES
- UX failure #7 (dead buttons): eliminate `NO HOLD AUTH`, `NO QUEUE AUTH`, `NO ACCESS` labels

**Files:**
| File | Change |
|------|--------|
| `functions/ui/fn_uiConsoleActionAirPrimary.sqf` | Reorganize dispatch: non-action rows return early; CLEARANCES context uses row-type dispatch per Button Behavior Matrix §2 |
| `functions/ui/fn_uiConsoleActionAirSecondary.sqf` | Same cleanup; add submode toggle action |
| `functions/ui/fn_uiConsoleAirPaint.sqf` | Update button labels for submode context; replace dead-button labels with `READ-ONLY` per Button Behavior Matrix §4 |
| `functions/ui/fn_uiConsoleOnLoad.sqf` | Set `ARC_console_airSubmode` default; wire submode permission gates |

**Acceptance criteria:**
- [ ] Non-action rows (`HDR`, `STATUS`, `MODE`) do not fire HOLD/RELEASE or queue actions
- [ ] `REQ` rows → APPROVE / DENY only
- [ ] `FLT` rows → EXPEDITE / CANCEL only
- [ ] `LANE` rows → CLAIM / RELEASE only
- [ ] No `NO HOLD AUTH` / `NO QUEUE AUTH` / `NO ACCESS` labels appear anywhere
- [ ] Unauthorized users see clean `READ-ONLY` label per Button Behavior Matrix §3
- [ ] All existing `canAirQueueManage` / `canAirStaff` / `canAirHoldRelease` permission guards preserved exactly
- [ ] PILOT submode path intact and tested separately
- [ ] sqflint + compat scan pass

**Dependencies:** Phase 2 complete (board structure defines which rows exist).

**Risks:**
| Risk | Severity | Mitigation |
|------|:--------:|-----------|
| Authority leakage in clearance actions | HIGH | Preserve all permission guards; add explicit row-type guards |
| Breaking PILOT submode | HIGH | Keep PILOT path separate; test independently |
| Button state desync after submode toggle | MEDIUM | Re-evaluate button state on every refresh, not only on selection change |

---

### Phase 4 — AIR input flow + confirmations

**PR:** `work/airtower-pr05-air-input-flow`  
**Mode:** B — Feature Delivery

**Goal:** Add narrow AIR-specific keyboard flow and confirmations for high-consequence actions. No broad display hijacking.

**Audit findings addressed:**
- Event flow (C+ → target B+): purpose-built keyboard flow and action confirmations

**Files:**
| File | Change |
|------|--------|
| `functions/ui/fn_uiConsoleOnLoad.sqf` | Register AIR-specific key-down handler when AIR tab is active |
| `functions/ui/fn_uiConsoleAirKeyDown.sqf` | **New** — narrow key-down dispatcher for AIR hotkeys |
| `config/CfgFunctions.hpp` | Register `ARC_fnc_uiConsoleAirKeyDown` |
| AIR action handlers (minimal) | Add confirmation prompt before destructive actions (HOLD, queue cancel, emergency) |

**Acceptance criteria:**
- [ ] AIR-only hotkeys (e.g., H=HOLD, R=RELEASE, Enter=CONFIRM) active only when AIR tab is focused
- [ ] Destructive actions (HOLD departures, cancel queued flight, emergency mark) require explicit confirmation
- [ ] Confirmation uses structured text prompt, not raw `hint`
- [ ] Key handler does not hijack keys when non-AIR tabs are active
- [ ] Key handler does not interfere with existing console keyboard behavior
- [ ] sqflint + compat scan pass

**Dependencies:** Phase 3 complete (action dispatch structure must be stable).

**Risks:**
| Risk | Severity | Mitigation |
|------|:--------:|-----------|
| Broad display key hijacking | HIGH | Register handler only for AIR tab; unregister on tab switch |
| Conflicting with existing Arma keybinds | MEDIUM | Use narrow key set; check against default Arma binds |
| Confirmation dialog blocking refresh loop | MEDIUM | Use non-blocking structured text, not modal `createDialog` |

---

### Phase 5 — Snapshot freshness + degraded-state correctness

**PR:** `work/airtower-pr06-snapshot-freshness`  
**Mode:** A — Bug Fix (behavior correction)

**Goal:** Replace placeholder freshness values with real computed freshness. Implement FRESH/STALE/DEGRADED signaling per Snapshot Contract v1. Ensure safe late-client reconstruction.

**Audit findings addressed:**
- Multiplayer locality (B- → target B+): real stale-state handling, safe JIP reconstruction

**Files:**
| File | Change |
|------|--------|
| `functions/core/fn_publicBroadcastState.sqf` | Compute `freshnessState` from `serverTime` vs last airbase tick timestamp; publish staleness threshold values |
| `functions/ui/fn_uiConsoleAirPaint.sqf` | Render freshness indicator using real `freshnessState`; show degraded warning when DEGRADED |
| `functions/ui/fn_uiConsoleDashboardPaint.sqf` | Surface freshness state in air summary if already present |

**Acceptance criteria:**
- [ ] `freshnessState` is `FRESH` when snapshot age < configured threshold (e.g., 15s)
- [ ] `freshnessState` is `STALE` when snapshot age > threshold but < degraded limit (e.g., 60s)
- [ ] `freshnessState` is `DEGRADED` when snapshot age > degraded limit or snapshot is missing
- [ ] UI displays actual age text: "Updated Xs ago" (never "State unchanged for Xm" — those are different concepts per Snapshot Contract §6)
- [ ] Late-joining client sees current airfield state immediately (JIP snapshot test)
- [ ] Tower Mode chip shows RED when `freshnessState == "DEGRADED"`
- [ ] No local state inference — UI never reconstructs state from partial messages
- [ ] sqflint + compat scan pass

**Dependencies:** Phase 2 complete (snapshot publisher and UI reader must exist).

**Risks:**
| Risk | Severity | Mitigation |
|------|:--------:|-----------|
| Freshness threshold misconfiguration | MEDIUM | Use config variables with sensible defaults; document thresholds |
| `serverTime` drift between server and client | MEDIUM | Compute age server-side and publish it; client only displays |
| JIP snapshot race condition | MEDIUM | Publish snapshot with `true` broadcast flag; validate in local MP test |

---

### Phase 6 — DASH air summary completion

**PR:** `work/airtower-pr07-dashboard-air-summary`  
**Mode:** B — Feature Delivery

**Goal:** Add commander-ready air summary to DASH/COP. Command staff can answer: runway availability, next inbound, next outbound, top blocker — without opening AIR/TOWER.

**Audit findings addressed:**
- UX failure #6 (unclear audience): commander gets summary on DASH, not full tower board

**Files:**
| File | Change |
|------|--------|
| `functions/ui/fn_uiConsoleDashboardPaint.sqf` | Add compact Air Summary widget: runway state chip, next inbound callsign/ETA, next outbound callsign/state, top blocker if any |
| `functions/core/fn_publicBroadcastState.sqf` | Add summary-specific fields to `ARC_pub_airbaseUiSnapshot` if not already present (e.g., `nextInboundSummary`, `nextOutboundSummary`, `topBlocker`) |

**Acceptance criteria:**
- [ ] DASH shows runway availability (OPEN/RESERVED/OCCUPIED/BLOCKED with R/A/G)
- [ ] DASH shows next inbound callsign + phase, or "No inbound"
- [ ] DASH shows next outbound callsign + state, or "No outbound"
- [ ] DASH shows top blocker description if any, or nothing
- [ ] Commander does not need to open AIR/TOWER to assess air status
- [ ] Air summary reads from `ARC_pub_airbaseUiSnapshot`, not raw `ARC_pub_state.airbase`
- [ ] sqflint + compat scan pass

**Dependencies:** Phase 5 complete (freshness must be real before surfacing to commanders).

**Risks:**
| Risk | Severity | Mitigation |
|------|:--------:|-----------|
| DASH layout regression | MEDIUM | Add air summary to existing DASH layout without moving other widgets |
| Stale air summary misleading commanders | MEDIUM | Show freshness indicator alongside summary; requires Phase 5 |
| CASREQ contract drift into DASH | LOW | Air summary shows only airfield-relevant CAS timing impacts per Vision Plan §9.2 |

---

### Phase 7 — AIR map pane integration

**PR:** `work/airtower-pr08-map-pane`  
**Mode:** B — Feature Delivery

**Goal:** Add `CT_MAP` control inside AIRFIELD_OPS for spatial traffic awareness. Selection in the traffic list recenters the map. Runway geometry visible.

**Audit findings addressed:**
- Map integration (D+ → target B): CT_MAP traffic pane replaces text-only board
- Control choice (continued): CT_MAP is the right Arma control for spatial data

**Files:**
| File | Change |
|------|--------|
| `config/CfgDialogs.hpp` | Add `CT_MAP` control in AIR controls group |
| `functions/ui/fn_uiConsoleRefresh.sqf` | Initialize map control; set default center/zoom to airbase marker |
| `functions/ui/fn_uiConsoleAirPaint.sqf` or `fn_uiConsoleAirMapPaint.sqf` (**new**) | Draw traffic markers on map; update on selection change; show runway geometry |
| `functions/ui/fn_uiConsoleMainListSelChanged.sqf` | Recenter map on selected traffic position |
| `functions/core/fn_publicBroadcastState.sqf` | Add position data to arrivals/departures in snapshot if not already present |
| `config/CfgFunctions.hpp` | Register `ARC_fnc_uiConsoleAirMapPaint` if extracted |

**Acceptance criteria:**
- [ ] CT_MAP shows runway marker and airbase area
- [ ] Inbound traffic positions shown on map (when position data available)
- [ ] Outbound traffic positions shown on map (when position data available)
- [ ] Selecting a traffic row recenters map to that traffic's position
- [ ] Map does not interfere with existing list/detail layout
- [ ] Map zoom defaults to airbase area; user can zoom/pan
- [ ] sqflint + compat scan pass

**Dependencies:** Phase 2 complete (board structure provides the traffic data); Phase 1 complete (grouped controls provide layout space for map).

**Risks:**
| Risk | Severity | Mitigation |
|------|:--------:|-----------|
| CT_MAP performance with many markers | MEDIUM | Limit to max 6 arrivals + 6 departures (bounded by Snapshot Contract §4) |
| Map control IDC collision | LOW | Use dedicated IDC in AIR range (78100–78199) |
| Position data unavailable for virtual traffic | MEDIUM | Show marker at airbase center with "position unknown" tooltip for virtual-only flights |

---

### Phase 8 — RemoteExec hardening completion

**PR:** `work/airtower-pr09-remoteexec-hardening`  
**Mode:** I — Security Hardening

**Goal:** Complete `CfgRemoteExec` allowlist for all AIR client→server request paths. Set explicit JIP flags. Validate against `docs/security/RemoteExec_Hardening_Plan.md`.

**Audit findings addressed:**
- Multiplayer locality (B- → target A-): allowlist complete, JIP explicit, sender validation on all AIR RPCs

**Files:**
| File | Change |
|------|--------|
| `description.ext` | Add/update `CfgRemoteExec` allowlist entries for all 9 `ARC_fnc_airbaseClient*` wrappers and any new AIR functions |
| `docs/security/RemoteExec_Hardening_Plan.md` | Update status for AIR endpoints; mark allowlist entries as implemented |
| `tests/TEST-LOG.md` | Record allowlist validation results |

**AIR RPC surface (from Phase0 Audit §1.5):**
| Endpoint | Target | JIP | Sender validation |
|----------|:------:|:---:|:-----------------:|
| `ARC_fnc_airbaseClientSubmitClearanceRequest` | 2 | 0 | Required |
| `ARC_fnc_airbaseClientCancelClearanceRequest` | 2 | 0 | Required |
| `ARC_fnc_airbaseClientMarkClearanceEmergency` | 2 | 0 | Required |
| `ARC_fnc_airbaseClientRequestClearanceDecision` | 2 | 0 | Required |
| `ARC_fnc_airbaseClientRequestHoldDepartures` | 2 | 0 | Required |
| `ARC_fnc_airbaseClientRequestReleaseDepartures` | 2 | 0 | Required |
| `ARC_fnc_airbaseClientRequestPrioritizeFlight` | 2 | 0 | Required |
| `ARC_fnc_airbaseClientRequestCancelQueuedFlight` | 2 | 0 | Required |
| `ARC_fnc_airbaseClientRequestSetLaneStaffing` | 2 | 0 | Required |

**Acceptance criteria:**
- [ ] All 9 AIR client→server wrappers listed in `CfgRemoteExec` with `mode = 1` (whitelist) and `jip = 0`
- [ ] Any new AIR functions added in Phases 1–7 also allowlisted
- [ ] Server-side handlers validate `remoteExecutedOwner` where applicable (per Copilot Instructions §3)
- [ ] JIP flags are explicit: `0` for all ephemeral AIR RPCs; `true` only if persistent late-join state requires it
- [ ] No `call` command in allowlist for AIR paths
- [ ] Hardening plan document updated with AIR completion status

**Dependencies:** Phases 1–7 complete (all AIR functions must be finalized before locking allowlist).

**Risks:**
| Risk | Severity | Mitigation |
|------|:--------:|-----------|
| Missing allowlist entry blocks legitimate action | HIGH | Test every action path in local MP before merge |
| Over-permissive allowlist entry | HIGH | Use `mode = 1` whitelist policy; no wildcard entries |
| JIP flag misconfiguration | MEDIUM | Explicit `jip = 0` for all AIR RPCs; only override with documented justification |

---

### Phase 9 — World overlay layer

**PR:** `work/airtower-pr10-world-overlay`  
**Mode:** B — Feature Delivery

**Goal:** Add local, sparse tower/pilot overlays for the highest-value cues only. Uses `Draw3D` event handler (not dialog controls). Overlays are context-gated: visible only when relevant.

**Audit findings addressed:**
- World-space overlays (D → target B-): Draw3D-based runway and conflict cueing

**Files:**
| File | Change |
|------|--------|
| `initPlayerLocal.sqf` | Register Draw3D event handler for airbase overlays (context-gated) |
| `functions/ui/fn_airbaseOverlayInit.sqf` | **New** — initialize overlay state and register Draw3D handler |
| `functions/ui/fn_airbaseOverlayDraw3D.sqf` | **New** — render sparse overlay cues: runway state marker, inbound direction, conflict warning |
| `config/CfgFunctions.hpp` | Register `ARC_fnc_airbaseOverlayInit` and `ARC_fnc_airbaseOverlayDraw3D` |

**Acceptance criteria:**
- [ ] Overlay shows runway state (OPEN/OCCUPIED/BLOCKED) as world-space marker near runway
- [ ] Overlay shows inbound direction indicator when arrival is on approach
- [ ] Overlay shows conflict/emergency warning when active
- [ ] Overlay is local only (no network traffic; reads from published snapshot)
- [ ] Overlay is sparse: maximum 3–5 simultaneous cues
- [ ] Overlay is context-gated: only visible when player is near airbase or has tower role
- [ ] Overlay does not render when console dialog is open (avoid clutter)
- [ ] Draw3D handler is efficient: no per-frame allocations, bounded iterations
- [ ] sqflint + compat scan pass

**Dependencies:** Phase 5 complete (snapshot freshness must be real for overlay accuracy); Phase 2 complete (snapshot provides traffic data).

**Risks:**
| Risk | Severity | Mitigation |
|------|:--------:|-----------|
| Draw3D performance impact | MEDIUM | Gate by distance; limit to 3–5 cues; skip when dialog open |
| Overlay visual clutter | MEDIUM | Sparse design: only highest-value cues; no traffic list duplication |
| Overlay desynced from dialog state | LOW | Both read from same `ARC_pub_airbaseUiSnapshot`; no local inference |

---

### Phase 10 — Debug isolation + legacy cleanup

**PR:** `work/airtower-pr11-debug-cleanup`  
**Mode:** C — Safe Refactor (no behavior change)

**Goal:** Isolate DEBUG telemetry from operator UX. Retire old fallback rendering branches. Move debug-only content (route validation, raw owner IDs, CASREQ contract text, blocked-route telemetry) exclusively into DEBUG submode.

**Audit findings addressed:**
- UX failure #5 (developer language in default view): fully isolated
- UX failure #6 (unclear audience): final cleanup

**Files:**
| File | Change |
|------|--------|
| `functions/ui/fn_uiConsoleAirPaint.sqf` | Remove legacy list-based fallback rendering; ensure DEBUG submode is the only path for debug content |
| `functions/ui/fn_uiConsoleRefresh.sqf` | Remove old AIR case fallback branches |
| `functions/core/fn_publicBroadcastState.sqf` | Ensure `debug` block in snapshot is admin-gated; remove any redundant debug publishing |

**Acceptance criteria:**
- [ ] Operator AIRFIELD_OPS view contains zero debug/developer text
- [ ] Route validation, snapshot revision, owner IDs, blocked-route telemetry, CASREQ contract text only visible in DEBUG submode
- [ ] DEBUG submode gated by admin/test role per Vision Plan §5 Mode 3
- [ ] No legacy list-based rendering paths remain (old monolithic paint branches removed)
- [ ] Behavior parity confirmed: no operator-visible change from Phase 2–9 baseline
- [ ] sqflint + compat scan pass

**Dependencies:** Phases 1–9 all complete and stabilized. This phase is a cleanup pass — only safe after all feature work is validated.

**Risks:**
| Risk | Severity | Mitigation |
|------|:--------:|-----------|
| Premature removal of fallback branches | HIGH | Only execute after all prior phases pass dedicated MP validation |
| Loss of debug capability for testers | MEDIUM | Confirm DEBUG submode is functional and accessible before removing old paths |
| Regression in edge-case rendering | MEDIUM | Full regression pass against acceptance tests from Phases 2–9 |

---

## 5) Acceptance test cross-reference

### Human-use tests (from Vision Plan §11)

| Test | Criteria | Validated by phase |
|------|----------|--------------------|
| 3-second scan | User answers runway/inbound/outbound/decision state in 3s | 2 |
| Arrival presence | Explicit inbound rows or "No arrivals inbound" | 2 |
| Role sanity | Commander/ATC/tester each see correct detail level | 2, 3, 6, 10 |
| No-jargon | Default view has no raw contract/debug field names | 2, 10 |

### Technical tests (from Vision Plan §11)

| Test | Criteria | Validated by phase |
|------|----------|--------------------|
| Dedicated MP single-writer | All state changes go through server | 5, 8 |
| JIP snapshot reconstruction | New client sees current state immediately | 5 |
| Read-only vs control permissions | Unauthorized users cannot trigger actions | 3 |
| No local inference | UI never reconstructs from partial messages | 2, 5 |
| Bubble/despawn safety | Virtual schedule continues; UI reflects virtual state | 2 |
| Snapshot freshness | Stale/missing shows degraded indicator | 5 |
| No duplicate UI shell | Single console dialog, single AIR tab | 1 |

### Regression tests (from Vision Plan §11)

| Test | Criteria | Validated by phase |
|------|----------|--------------------|
| Existing console tabs | Non-AIR tabs function normally | 1, 2 |
| Airbase ambient schedule | Departures/arrivals continue without regression | 2 |
| No duplicate schedulers | Single tick loop, single state store | 2 |
| No CASREQ drift | CASREQ contract unchanged | 2, 6 |
| sqflint clean | All files pass `sqflint -e w` + strict compat scan | all |
| CfgFunctions complete | All new functions registered | 1, 4, 7, 9 |

---

## 6) Static validation checklist (per phase)

Every phase must complete these checks before merge:

```
python3 scripts/dev/sqflint_compat_scan.py --strict <changed .sqf files>
sqflint -e w <changed .sqf files>
python3 scripts/dev/validate_state_migrations.py
python3 scripts/dev/validate_marker_index.py
bash scripts/dev/check_test_log_commits.sh
```

Results recorded in `tests/TEST-LOG.md` with PASS/FAIL/BLOCKED status per check.

---

## 7) Notes

- This plan intentionally keeps the existing Farabad Console shell and AIR tab.
- The main scope expansion versus the earlier AIR / TOWER audit is that `config/CfgDialogs.hpp`, `description.ext`, and `initPlayerLocal.sqf` are now eligible touch points when required by Arma-native dialog, HUD, and networking behavior.
- Phase numbering (0–10) maps 1:1 to PR numbering (1–11) in `AIR_TOWER_PR_BY_PR_BREAKDOWN.md`.
- Deferred checks (dedicated server persistence, JIP synchronization, late-client recovery, respawn/reconnect edge cases) are tracked in `docs/qa/Pre_Dedicated_Mission_Completion_Audit_2026-04-06.md` and must be validated before release.

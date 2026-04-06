# AIR / TOWER — Vision + Architecture Plan

**Date:** 2026-04-06  
**Branch:** `copilot/design-architecture-plan-air-tower`  
**Status:** Design-only; no code patch in this step  
**Mode:** F — Documentation-Only Changes  
**Depends on:** `docs/architecture/AIR_TOWER_Phase0_Audit.md` (audit baseline)

---

## 1) Vision Sentence

AIR / TOWER becomes a **simple airfield status and decision board** that tells the user:
1. What is happening now
2. What is next
3. What needs action
4. What is unsafe

without requiring the user to read a wall of text.

---

## 2) Design Principles

### 2.1 Non-Negotiable UX Rules

| # | Rule | Enforcement |
|---|------|-------------|
| 1 | **3-second rule** | Runway state, inbound state, outbound state, and decision-needed state must be answerable in 3 seconds |
| 2 | **Role-first** | Commander sees summary; ATC sees queue + decisions; Tester sees internals; these are NOT the same product |
| 3 | **Arrivals are first-class** | Explicit inbound aircraft rows or explicit "No arrivals inbound" — never silent absence |
| 4 | **Color + text together** | R/A/G indicators always include explicit text labels (never color alone) |
| 5 | **Operator language** | Default view uses military/operational terminology, not raw contract field names |
| 6 | **Explicit empty states** | "No departures queued" is acceptable; blank space is not |
| 7 | **No dead buttons** | If user has no authority: hide the action or show clean "READ-ONLY" label; no "NO HOLD AUTH" disabled buttons |

### 2.2 Hard Non-Goals

- Do NOT rewrite the Farabad Console shell
- Do NOT rewrite the airbase backend (fn_airbaseTick, fn_airbaseInit, etc.)
- Do NOT expose debug telemetry by default
- Do NOT replace COP / DASH for commanders
- Do NOT stuff raw CASREQ internals into the tower page
- Do NOT invent new role names conflicting with ORBAT
- Do NOT build a second standalone AIR/TOWER dialog

---

## 3) Audience Model

### A) Battalion Commander / TOC / Command Staff

**Needs:** Runway availability, next inbound/outbound, delays or closure, emergency/priority traffic, MEDEVAC/CAS/logistics timing impact.

**Gets:**
- Small **Air Summary widget** on COP / DASH (Phase 5)
- Read-only AIR / TOWER overview if they open the tab

**Does NOT get by default:** Route validation internals, raw queue mechanics, CASREQ contract fields.

### B) Tower / Approach / ATC Operator

**Needs:** Runway state and owner, inbound queue, outbound queue, pending clearances, next decision required, control mode and staffing.

**Gets:**
- Main AIR / TOWER operational board (AIRFIELD OPS submode)
- Contextual actions in CLEARANCES submode (role-gated)

### C) Pilot / Field User

**Needs:** Runway availability, traffic picture, own request status, hold/taxi/delay expectations.

**Gets:**
- Read-only overview
- Own-flight request context (existing PILOT submode preserved)

### D) Mission Tester / Admin

**Needs:** Raw snapshot revision, route validation failures, owner IDs, state ages, queue internals, policy flags.

**Gets:**
- Separate **DEBUG submode** (never the default)

---

## 4) Information Architecture

### 4.1 Screen Model (preserved from Farabad Console)

```
┌─────────────────────────────────────────────────────────┐
│  FARABAD CONSOLE — AIR / TOWER                          │
├──────────┬──────────────────────────────┬───────────────┤
│          │  Layer 1: Status Strip       │               │
│  Left    │  Layer 2: Decision Band      │  Right:       │
│  Tab     │  Layer 3: Operating Board    │  Selection    │
│  Nav     │    Arrivals | Runway | Deps  │  Detail       │
│          │  Layer 4: (scroll area)      │               │
│          │                              │               │
├──────────┴──────────────────────────────┴───────────────┤
│  Bottom: Action Row (Primary | Secondary buttons)       │
└─────────────────────────────────────────────────────────┘
```

### 4.2 Layer 1 — Top Status Strip (always visible)

Five status chips in one row:

| Chip | States | R/A/G |
|------|--------|:-----:|
| **Runway** | OPEN / RESERVED / OCCUPIED / BLOCKED | G / A / R / R |
| **Arrivals** | NORMAL / HOLDING / PRIORITY / CONFLICT | G / A / A / R |
| **Departures** | NORMAL / DELAYED / HOLD | G / A / R |
| **Tower Mode** | MANNED / AUTO / DEGRADED | G / A / R |
| **Alerts** | NONE / CAUTION / CRITICAL | G / A / R |

Implementation: structured text with inline color tokens + explicit text. Example:
```
<t color='#33CC33'>● RUNWAY: OPEN</t>  <t color='#FFB833'>● ARRIVALS: HOLDING</t>  ...
```

### 4.3 Layer 2 — Decision Band (conditional)

Narrow high-priority band, only shown when a decision is required:

- "Decision required: LANDING REQUEST HAWG 11"
- "Priority inbound: DUSTOFF"
- "Runway blocked"

If no decisions are pending: band is hidden (not "none" — just absent).

### 4.4 Layer 3 — Main Operating Board

Three operational blocks in the main list area:

#### Arrivals Block
| Column | Source |
|--------|--------|
| Callsign | `nextItems[].fid` where kind=ARR, or clearance request callsign |
| Type | Aircraft type from meta |
| Phase | INBOUND / HOLDING / ON APPROACH / CLEARED TO LAND |
| ETA/Age | From clearance request timestamp |
| Priority | 0=normal, 1=priority, 100+=emergency |
| Status | R/A/G chip |

Empty state: `"No arrivals inbound"`

#### Runway / Active Movement Block
| Field | Source |
|-------|--------|
| Current owner | `runwayOwner` callsign |
| Current action | DEPARTING / LANDING / CLEAR |
| Hold state | HOLD ACTIVE or OPEN |

#### Departures Block
| Column | Source |
|--------|--------|
| Callsign | `nextItems[].fid` where kind=DEP |
| Type | Aircraft type from meta |
| State | QUEUED / TAXI / HOLD SHORT / CLEARED |
| ETD/Age | Queue timestamp |
| Priority | 0=normal, 1=priority |
| Status | R/A/G chip |

Empty state: `"No departures queued"`

### 4.5 Layer 4 — Selection Detail (right pane)

Shows details for the selected row only:
- Who it is (callsign, type, flight ID)
- What state it is in (phase, age, priority)
- What constraints matter (lane decision, hold state)
- What action is possible for the current user

**Does NOT dump** all system metadata here by default.

### 4.6 Layer 5 — Lower Priority (collapsed / low-emphasis)

Only in scrollable area below main board:
- Recent events (5 max, filtered)
- Staffing detail (3 lanes)
- Clearance history (5 max)

---

## 5) Submode Model

### Mode 1 — AIRFIELD OPS (default)

**Audience:** Everyone  
**Content:** Status strip + decision band + arrivals/departures/runway + selection detail  
**Actions:** None (read-only) unless user has tower role → then "HOLD/RELEASE" global control

### Mode 2 — CLEARANCES (role-gated)

**Audience:** FARABAD TOWER / FARABAD GROUND / FARABAD APPROACH roles  
**Content:** Pending clearances list with approve/deny/hold/resume actions  
**Actions:** APPROVE, DENY, EXPEDITE, CANCEL (per existing action handlers)  
**Gate:** Only visible when `ARC_console_airCanControl` is true

### Mode 3 — DEBUG (admin/test only)

**Audience:** Dev/admin/test (via explicit toggle)  
**Content:**
- Route validation failures
- Snapshot revision/age
- Raw owner IDs
- Fallback reason strings
- CASREQ contract text
- Blocked-route telemetry
- Internal metadata (routeMarkerChain, runwayLaneDecision, etc.)

**Gate:** Hidden by default; activated by admin toggle or debug mode flag

---

## 6) R/A/G Semantics (locked)

### Runway
| Color | State |
|:-----:|-------|
| Green | OPEN |
| Amber | RESERVED / HOLD ACTIVE |
| Red | OCCUPIED / BLOCKED / EMERGENCY |

### Arrivals
| Color | State |
|:-----:|-------|
| Green | No conflict, normal inbound sequencing |
| Amber | Holding, delayed, or awaiting decision |
| Red | Emergency, conflict, runway unavailable |

### Departures
| Color | State |
|:-----:|-------|
| Green | Normal sequencing |
| Amber | Backlog or hold |
| Red | Blocked or conflict |

### Tower Mode
| Color | State |
|:-----:|-------|
| Green | Manned / healthy |
| Amber | AI auto / fallback / response timeout |
| Red | Degraded / invalid state / stale snapshot |

### Sync / Freshness
| Color | State |
|:-----:|-------|
| Green | Fresh within target window |
| Amber | Stale beyond expected refresh |
| Red | Degraded or missing snapshot |

**Freshness wording rules:**
- "Updated 8s ago" = freshness (how recent)
- "State unchanged for 45m" = stability (no change)
- Never conflate the two

---

## 7) UI Data Contract: `airbase_ui_snapshot_v1`

### 7.1 Publication Model

The server publishes a **normalized UI-ready snapshot** as a separate `missionNamespace` variable, distinct from the existing `ARC_pub_state.airbase` raw block.

```sqf
missionNamespace setVariable ["ARC_pub_airbaseUiSnapshot", _snapshot, true];
missionNamespace setVariable ["ARC_pub_airbaseUiSnapshotUpdatedAt", serverTime, true];
```

### 7.2 Top-Level Schema

```
airbase_ui_snapshot_v1
├── v                    : NUMBER (1)
├── rev                  : NUMBER (monotonic revision)
├── updatedAt            : NUMBER (serverTime)
├── freshnessState       : STRING (FRESH / STALE / DEGRADED)
├── stationContext        : STRING (TOC / TOWER / FIELD)
├── submode              : STRING (AIRFIELD_OPS / CLEARANCES / DEBUG)
├── runway               : OBJECT
│   ├── state            : STRING (OPEN / RESERVED / OCCUPIED / BLOCKED)
│   ├── ownerCallsign    : STRING
│   ├── activeMovement   : STRING (DEPARTING / LANDING / CLEAR)
│   ├── holdState        : BOOL
│   └── age              : NUMBER (seconds since last state change)
├── alerts[]             : ARRAY (max 5)
│   └── [text, severity, sourceId]
├── decisionQueue[]      : ARRAY (max 5)
│   └── [text, requestId, callsign, priority, type]
├── arrivals[]           : ARRAY (max 6)
│   └── [flightId, callsign, category, phase, etaS, priority, status]
├── departures[]         : ARRAY (max 6)
│   └── [flightId, callsign, category, state, etdS, priority, status]
├── pendingClearances[]  : ARRAY (max 6)
│   └── [requestId, requestType, callsign, requestedAt, priority, decisionNeeded]
├── staffing             : ARRAY
│   └── [lane, mode, operatorName]  (3 lanes: tower, ground, arrival)
├── recentEvents[]       : ARRAY (max 8)
│   └── [timestamp, label]
├── actionsAllowed       : OBJECT
│   ├── canHold          : BOOL
│   ├── canRelease       : BOOL
│   ├── canApprove       : BOOL
│   ├── canDeny          : BOOL
│   ├── canExpedite      : BOOL
│   ├── canCancel        : BOOL
│   ├── canStaff         : BOOL
│   └── isReadOnly       : BOOL
└── debug                : OBJECT (optional; admin only)
    ├── snapshotRev      : NUMBER
    ├── snapshotAge      : NUMBER
    ├── blockedRouteCount : NUMBER
    ├── blockedRouteReason : STRING
    ├── blockedRouteSource : STRING
    ├── blockedRouteTail  : ARRAY
    ├── casreqId         : STRING
    ├── casreqRev        : NUMBER
    ├── casreqDistrict   : STRING
    ├── casreqState      : STRING
    ├── rawOwnerIds      : ARRAY
    └── routeValidation  : ARRAY
```

### 7.3 Bounded Defaults

| Collection | Max |
|-----------|----:|
| alerts | 5 |
| decisionQueue | 5 |
| arrivals | 6 |
| departures | 6 |
| pendingClearances | 6 |
| recentEvents | 8 |

### 7.4 Migration Strategy

**Phase 2 (read-only AIRFIELD OPS):**
- `fn_publicBroadcastState.sqf` gains a new block that translates existing `airbase_v1_*` state into `airbase_ui_snapshot_v1`
- Existing `ARC_pub_state.airbase` block remains unchanged (other consumers may depend on it)
- `fn_uiConsoleAirPaint.sqf` switches to reading only from `ARC_pub_airbaseUiSnapshot`
- Old direct reads of `ARC_pub_state.airbase` are removed from AIR paint function

**Future:**
- When AIRBASESUB runtime is modernized, the translator layer adapts; UI remains untouched

---

## 8) Role and Authority Model

### 8.1 Preserved Anchors

| Anchor | Type | Source |
|--------|------|--------|
| `FarabadTower_LA` | AI unit variable name | mission.sqm Eden |
| `farabad_tower_ws_ccic` | Role identifier | AIRBASESUB planning spec §0.7 |
| `farabad_tower_lc` | Role identifier | AIRBASESUB planning spec §0.7 |
| `FARABAD TOWER` | Group token | ORBAT §12.1 |
| `FARABAD GROUND` | Group token | ORBAT §12.1 |
| `FARABAD APPROACH` | Group token | ORBAT §12.2 |

### 8.2 Default Authority Behavior

| Role | Default view | Submodes available | Actions |
|------|-------------|-------------------|---------|
| Tower CCIC | AIRFIELD OPS | OPS + CLEARANCES + DEBUG | Full control |
| Tower LC | AIRFIELD OPS | OPS + CLEARANCES | PRIORITIZE, CANCEL, STAFF |
| BN Commander | AIRFIELD OPS | OPS only | Read-only (override configurable) |
| TOC S3 / S2 | AIRFIELD OPS | OPS only | Read-only |
| Pilot | PILOT submode | PILOT only | Submit/cancel own requests |
| OMNI | AIRFIELD OPS | OPS + CLEARANCES + DEBUG | Full |
| No role | — | Tab hidden | — |

### 8.3 Button Behavior by Context

| Context | No authority | Read-only | Control authority |
|---------|:------------:|:---------:|:-----------------:|
| Button visible? | No (tab hidden) | Yes | Yes |
| Button enabled? | — | No | Yes |
| Button label | — | "READ-ONLY" | Action name |
| Disabled text | — | Clean label, no jargon | — |

---

## 9) Integration Architecture

### 9.1 Translator/Publisher Seam

```
┌──────────────────────┐     ┌───────────────────────────┐     ┌─────────────────────┐
│  Airbase Runtime      │────▶│  Translator/Publisher      │────▶│  AIR / TOWER UI     │
│  (fn_airbaseTick)     │     │  (in fn_publicBroadcast    │     │  (fn_uiConsoleAir   │
│  airbase_v1_* state   │     │   State.sqf, new block)    │     │   Paint.sqf)        │
│                       │     │                            │     │                     │
│  NOT modified         │     │  Reads: airbase_v1_*       │     │  Reads ONLY:        │
│                       │     │  Publishes:                │     │  ARC_pub_airbaseUi  │
│                       │     │    ARC_pub_airbaseUi       │     │    Snapshot          │
│                       │     │    Snapshot                │     │                     │
└──────────────────────┘     └───────────────────────────┘     └─────────────────────┘
```

### 9.2 CASREQ Integration Rule

AIR / TOWER may surface only airfield-relevant CAS timing impacts:
- Priority slot requested
- Recovery window conflict
- Inbound CAS flight ETA

Raw CASREQ contract/debug text is **never** shown in default AIRFIELD OPS view. Available only in DEBUG submode.

---

## 10) Phased Delivery Plan

### Phase 0 — AUDIT MODE ✅ (this document + audit)

**Goal:** Compare live branch to baseline before patching.  
**Deliverables:**
- ✅ Owner-file map → `docs/architecture/AIR_TOWER_Phase0_Audit.md`
- ✅ Keep/change/delete map
- ✅ Regression risk list
- ✅ Architecture vision → this document

### Phase 1 — UX Contract

**Goal:** Lock the human-facing information architecture before code.  
**Deliverables:**
- Wireframe / content hierarchy (sections 4.1–4.6 above)
- R/A/G rules (section 6)
- Role matrix (section 8)
- Snapshot contract (section 7)

**Acceptance:**
- Contract document reviewed and approved
- No code changes in this phase

### Phase 2 — Read-Only AIRFIELD OPS View

**Goal:** Ship a clean overview with arrivals, departures, runway state, and alerts.

**Files modified:**
- `functions/core/fn_publicBroadcastState.sqf` — add translator block
- `functions/ui/fn_uiConsoleAirPaint.sqf` — replace content with layered board
- `functions/ui/fn_uiConsoleRefresh.sqf` — update AIR case for submode switching

**Acceptance:**
- 3-second scan test passes
- Explicit arrival presence or "No arrivals inbound"
- No debug text in default view
- Proper empty states and freshness wording
- No actions yet unless already safe (HOLD/RELEASE preserved)

### Phase 3 — CLEARANCES Mode

**Goal:** Add role-gated tower actions without cluttering the overview.

**Files modified:**
- `functions/ui/fn_uiConsoleAirPaint.sqf` — add CLEARANCES submode paint
- `functions/ui/fn_uiConsoleActionAirPrimary.sqf` — adapt for submode context
- `functions/ui/fn_uiConsoleActionAirSecondary.sqf` — adapt for submode context
- `functions/ui/fn_uiConsoleRefresh.sqf` — submode button wiring

**Acceptance:**
- Pending clearance list visible only in CLEARANCES submode
- Contextual actions only for authorized roles
- Timeout/fallback behavior surfaced clearly

### Phase 4 — DEBUG Overlay

**Goal:** Restore tester/admin visibility without poisoning operator UX.

**Files modified:**
- `functions/ui/fn_uiConsoleAirPaint.sqf` — add DEBUG submode paint
- `functions/core/fn_publicBroadcastState.sqf` — include debug object in snapshot (admin-gated)

**Acceptance:**
- Route validation, snapshot revision, owner IDs, blocked-route telemetry visible
- Only accessible to admin/test roles
- Never the default view

### Phase 5 — Commander Air Summary

**Goal:** Give command staff what they actually need without requiring them to open AIR/TOWER.

**Files modified:**
- `functions/ui/fn_uiConsoleDashPaint.sqf` — add Air Summary widget
- `functions/core/fn_publicBroadcastState.sqf` — ensure summary data available

**Acceptance:**
- Compact air summary on COP / DASH
- Runway summary, next inbound, next outbound, delays/closure/emergency impact
- No need for BC to live inside the tower board

---

## 11) Acceptance Tests

### Human-Use Tests

| # | Test | Criteria |
|---|------|----------|
| 1 | 3-second scan | New user answers runway state, inbound state, outbound state, decision-needed in 3 seconds |
| 2 | Arrival presence | Screen shows explicit inbound traffic rows or explicit "none" state |
| 3 | Role sanity | Commander, ATC, and tester each see right detail level and nothing more |
| 4 | No-jargon | Default view contains no raw contract/debug field names |

### Technical Tests

| # | Test | Criteria |
|---|------|----------|
| 1 | Dedicated MP single-writer | All state changes go through server |
| 2 | JIP snapshot reconstruction | New client joining sees current airfield state immediately |
| 3 | Read-only vs control permissions | Unauthorized users cannot trigger actions |
| 4 | No local inference | UI never reconstructs state from partial messages |
| 5 | Bubble/despawn safety | Virtual schedule continues; UI reflects virtual state |
| 6 | Snapshot freshness | Stale/missing snapshot shows degraded indicator |
| 7 | No duplicate UI shell | Single console dialog, single AIR tab |

### Regression Tests

| # | Test | Criteria |
|---|------|----------|
| 1 | Existing console tabs | All non-AIR tabs still function normally |
| 2 | Airbase ambient schedule | Departures and arrivals continue without UI regression |
| 3 | No duplicate schedulers | Single tick loop, single state store |
| 4 | No CASREQ drift | CASREQ contract unchanged |
| 5 | sqflint clean | All new/modified files pass `sqflint -e w` and strict compat scan |
| 6 | CfgFunctions complete | All new functions registered |

---

## 12) File Impact Summary

### Files Modified (across all phases)

| File | Phase | Change |
|------|:-----:|--------|
| `functions/core/fn_publicBroadcastState.sqf` | 2, 4 | Add translator block for `airbase_ui_snapshot_v1` |
| `functions/ui/fn_uiConsoleAirPaint.sqf` | 2, 3, 4 | Replace monolithic paint with layered submode-aware rendering |
| `functions/ui/fn_uiConsoleRefresh.sqf` | 2, 3 | Update AIR case for submode switching and button wiring |
| `functions/ui/fn_uiConsoleActionAirPrimary.sqf` | 3 | Adapt button dispatch for submode context |
| `functions/ui/fn_uiConsoleActionAirSecondary.sqf` | 3 | Adapt button dispatch for submode context |
| `functions/ui/fn_uiConsoleDashPaint.sqf` | 5 | Add Air Summary widget |
| `config/CfgFunctions.hpp` | 2+ | Register any new functions |

### Files NOT Modified (explicit)

All 35 server-side airbase runtime functions, all client RPC wrappers, all non-AIR UI functions, `CfgDialogs.hpp`, `mission.sqm`, `description.ext`, `initServer.sqf`, `initPlayerLocal.sqf`.

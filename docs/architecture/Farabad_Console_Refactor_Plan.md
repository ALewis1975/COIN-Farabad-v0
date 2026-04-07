# Farabad Console — Architecture Refactor Plan

**Date:** 2026-04-07  
**Status:** Approved design; implementation pending  
**Mode:** F — Documentation-Only Changes (this document)  
**Supersedes:** `AIR_TOWER_Vision_Architecture_Plan.md` (AIR-only scope)  
**Depends on:** `Console_VM_v1.md`, `Console_Tab_Migration_Plan.md`, `Farabad_Tablet_2011_Style.md`

---

## 0) Why This Document Exists

The AIR / TOWER screen has been through 8+ implementation phases and 1,000+ LOC of
painter code, yet still presents the same core problems visible in the latest
screenshot:

1. **Text-wall rendering** — flat list of FLT-xxxx IDs, events, and staffing lines
   with no visual hierarchy between actionable rows and informational noise.
2. **Map vs. detail collision** — the CT_MAP control (IDC 78137) fights the detail
   pane for space; marker text overlaps detail text.
3. **Status strip truncation** — the TWR chip renders empty because the 5-chip row
   overflows its container at common resolutions.
4. **Dead/ambiguous buttons** — "READ ONLY" disabled button visible alongside
   "UPDATE" and "REFRESH" with unclear distinction.
5. **Opaque identifiers** — "FLT-0004", "FLT-0003" repeated without callsigns in
   the RECENT EVENTS section.

These are not AIR-specific bugs. They are **console shell and layout problems**
that AIR inherits from the shared pane model. Fixing them inside AIR alone
would mean every future tab hits the same issues.

This plan re-scopes the effort from "AIR/TOWER polish" to **Farabad Console
architecture refactor**, treating AIR as the first proving ground.

---

## 1) Design Principles (Console-Wide)

These rules apply to **every tab**, not just AIR.

### 1.1 Non-Negotiable UX Rules

| # | Rule | Enforcement |
|---|------|-------------|
| 1 | **3-second rule** | The answer to "what needs my attention?" must be visually obvious within 3 seconds on any tab |
| 2 | **Role-first** | Each tab renders a role-appropriate view; commanders see summary, operators see queues, testers see debug — never the same wall of text for all |
| 3 | **Explicit empty states** | Every data section shows a human-readable empty message, never blank space |
| 4 | **Color + text together** | R/A/G indicators always include text labels (never color alone) |
| 5 | **No dead buttons** | If user has no authority, hide the button or show a clean "READ-ONLY" label — no disabled buttons with cryptic labels |
| 6 | **Summary before detail** | Main board shows the operational picture; detail pane shows the selected item; debug telemetry is never the default |
| 7 | **Operator language** | Labels use military/operational terminology, not raw variable names or contract field names |
| 8 | **Pane regions are exclusive** | A visual panel (map, chart) occupies a declared region slot — it never overlaps or displaces the detail pane |

### 1.2 Hard Non-Goals

- Do NOT rewrite the airbase backend (`fn_airbaseTick`, `fn_airbaseInit`, etc.)
- Do NOT rewrite action routing or permission logic (preserved as-is)
- Do NOT change the dialog class or create a second standalone dialog
- Do NOT alter `remoteExec` RPC contracts or `CfgRemoteExec` allowlist
- Do NOT modify server-side state authority model

---

## 2) Current Architecture Inventory

### 2.1 Scale

| Category | Count | Notes |
|----------|------:|-------|
| UI functions (`functions/ui/fn_uiConsole*.sqf`) | 48 | Painters + lifecycle + actions |
| Core UI support (`functions/core/fn_console*.sqf`) | 3 | VM build, adapter, QA audit |
| Dialog IDC controls (`config/CfgDialogs.hpp`) | 78 | Shell + panes + tab-specific |
| Tabs | 9 | DASH, BOARDS, INTEL, OPS, AIR, HANDOFF, CMD, HQ, S1 |
| Action handlers | 25+ | Tab-specific button dispatch |
| Total painter LOC | ~7,600 | Sum of all `*Paint.sqf` files |
| Total console LOC | ~10,200 | All console-related files |

### 2.2 Current Pane Model

```
┌─────────────────────────────────────────────────────────────┐
│ FARABAD CONSOLE — title (78091)                              │
│ NET: FIELD    GPS: ACTIVE    BATT: OK    SYNC: LIVE          │
│ (78060)       (78061)        (78062)     (78063)             │
├──────────┬───────────────────────┬──────────────────────────┤
│ Tabs     │ Center pane           │ Right pane               │
│ 78001    │                       │                          │
│ (27%)    │ 78015 MainGroup       │ 78016 DetailsGroup       │
│          │   78010 Main (ST)     │   78012 Details (ST)     │
│          │   78011 MainList (LB) │                          │
│          │                       │                          │
│          │ [OPS: 78030-78038]    │                          │
│          │ [S2:  78050-78055]    │                          │
│          │ [AIR: 78130-78137]    │                          │
├──────────┴───────────────────────┴──────────────────────────┤
│ 78021 Primary  78022 Secondary  78023 Refresh  78024 Close  │
└─────────────────────────────────────────────────────────────┘
```

### 2.3 Current Layout Split

| Tab group | Center:Right ratio | Tabs |
|-----------|:------------------:|------|
| Ops-facing | 50 : 50 | DASH, BOARDS, OPS, CMD, HQ |
| Detail-facing | 47 : 53 | INTEL, AIR, HANDOFF, S1 |

### 2.4 Current Data Sources Per Tab

| Tab | Primary data source | Uses Console VM? |
|-----|--------------------|-----------------:|
| DASH | Mixed `ARC_active*` + `ARC_pub_*` | Yes (flag-gated `ARC_console_dashboard_v2`) |
| BOARDS | Direct `ARC_active*` + `ARC_pub_*` | No |
| INTEL | `ARC_pub_intelLog` + active task | No |
| OPS | `ARC_active*` + `ARC_pub_orders` | Yes (flag-gated `ARC_console_ops_v2`) |
| AIR | `ARC_pub_airbaseUiSnapshot` | No |
| HANDOFF | Incident handoff state | No |
| CMD | Incident + queue + orders | Partial (`cmd` via adapter) |
| HQ | `ARC_pub_missionScore` + admin | No |
| S1 | Personnel roster | No |

---

## 3) Identified Problems (Root Cause Analysis)

### 3.1 Shell / Layout Problems

| # | Problem | Root cause | Impact |
|---|---------|-----------|--------|
| L1 | **Map overlaps detail pane** | No declared "visual panel" region; AIR CT_MAP (78137) is positioned ad hoc over the detail area | AIR detail text is obscured by map markers |
| L2 | **Status strip chips truncate** | AIR 5-chip strip (78130) has fixed fractional widths that overflow at ≤1080p; no responsive breakpoint | TWR chip renders empty on common resolutions |
| L3 | **Tab-specific layout hacks** | Each tab case in `fn_uiConsoleRefresh.sqf` manually shows/hides controls; no declared layout mode per tab | Adding any new visual element requires touching the 449-line refresh function |
| L4 | **Regression guards accumulate** | 5+ separate "restore position" guards in refresh for different tabs' layout side effects | Fragile; any new tab can break an existing tab's layout |
| L5 | **No standard region slots** | The shell has MainGroup/MainList/DetailsGroup, but tabs invent ad-hoc regions (OPS 3-frame, AIR strip+band+map) | No consistent region contract for painters to target |

### 3.2 Content / Presentation Problems

| # | Problem | Root cause | Impact |
|---|---------|-----------|--------|
| C1 | **Text-wall list** | AIR painter dumps arrivals, runway, departures, events, staffing, history into one flat listbox (78011) | User cannot distinguish operational rows from noise |
| C2 | **Opaque IDs in events** | RECENT EVENTS section shows "FLT-0004" without resolving callsign | Events are unreadable without cross-referencing the flight list |
| C3 | **Dead button ambiguity** | "READ ONLY" disabled primary sits next to enabled "UPDATE" and "REFRESH" — three overlapping concepts | User cannot tell which button does what |
| C4 | **No per-section empty states** | When arrivals are empty, one line says "No arrivals inbound" but the visual weight matches a real row | Empty states are not visually distinct from data rows |
| C5 | **Debug data in default view** | Debug telemetry rows (snapshot revision, route failures) appear in the same list as operational data | Non-testers see noise; testers cannot find debug data easily |

### 3.3 Data Architecture Problems

| # | Problem | Root cause | Impact |
|---|---------|-----------|--------|
| D1 | **Mixed data sourcing** | Most tabs read raw `missionNamespace` vars; only DASH and OPS have Console VM paths (flag-gated) | No single contract; each painter re-implements type guards and fallback logic |
| D2 | **No section freshness on most tabs** | Console VM has per-section freshness; direct reads do not | Stale data is invisible on most tabs |
| D3 | **Snapshot parsing duplicated** | AIR painter has 60+ lines of `_getPair` calls; Dashboard has similar patterns | Every painter re-parses the same data differently |

---

## 4) Target Architecture

### 4.1 Declared Layout Regions

Every tab declares which **region slots** it uses. The shell owns the
positioning; painters only fill content.

```
┌─────────────────────────────────────────────────────────────────┐
│ FARABAD CONSOLE — title                                          │
│ [Status Strip: 4 indicators — always visible]                    │
├──────────┬──────────────────────────────────┬───────────────────┤
│          │ Region A: TAB STATUS STRIP        │                   │
│  Tabs    │ (opt. per-tab: R/A/G chips, band) │                   │
│  (left)  ├──────────────────────────────────┤  Region D:        │
│          │ Region B: MAIN BOARD              │  DETAIL PANE      │
│          │ (list, structured text, or frames) │  (selected item)  │
│          ├──────────────────────────────────┤                   │
│          │ Region C: VISUAL PANEL (optional) │                   │
│          │ (map, chart — declared height)     │                   │
├──────────┴──────────────────────────────────┴───────────────────┤
│ Region E: ACTION ROW (up to 4 buttons, context-sensitive)        │
└─────────────────────────────────────────────────────────────────┘
```

**Region rules:**

| Region | Control type | Who positions it | Who fills it |
|--------|-------------|-----------------|-------------|
| A — Tab Status Strip | RscControlsGroup or RscStructuredText | Shell layout engine | Painter (or hidden) |
| B — Main Board | RscListbox (78011) or RscStructuredText (78010) or custom frames | Shell layout engine | Painter |
| C — Visual Panel | RscMapControl, RscPicture, or hidden | Shell layout engine (declared height) | Painter (or hidden) |
| D — Detail Pane | RscStructuredText (78012) in 78016 | Shell layout engine | Painter |
| E — Action Row | RscButton × 4 (78021-78024) | Shell layout engine | Refresh dispatch |

### 4.2 Tab Layout Declaration

Each tab declares its layout needs as a simple config array:

```sqf
// Tab layout declarations (conceptual — actual location: fn_uiConsoleRefresh)
// [tabId, useStatusStrip, mainBoardMode, useVisualPanel, visualPanelHeightFrac, splitRatio]
private _tabLayouts = [
    ["DASH",    false, "STRUCTURED_TEXT", false, 0,    0.50],
    ["BOARDS",  false, "STRUCTURED_TEXT", false, 0,    0.50],
    ["INTEL",   false, "LIST",            false, 0,    0.47],
    ["OPS",     false, "FRAMES_3",        false, 0,    0.50],
    ["AIR",     true,  "LIST",            true,  0.35, 0.47],
    ["HANDOFF", false, "STRUCTURED_TEXT", false, 0,    0.47],
    ["CMD",     false, "STRUCTURED_TEXT", false, 0,    0.50],
    ["HQ",      false, "LIST",            false, 0,    0.50],
    ["S1",      false, "LIST",            false, 0,    0.47]
];
```

The shell layout engine reads the active tab's declaration and:
1. Positions Regions A–E based on the declared modes
2. Shows/hides Region A (tab status strip) and Region C (visual panel)
3. Adjusts Region B height to account for A and C
4. Applies the declared center:right split ratio
5. **No tab-specific show/hide logic in the refresh dispatch**

### 4.3 Console VM Extension

Extend `fn_consoleVmBuild.sqf` to include sections for all tabs:

| VM Section | New? | Consuming Tabs | Source Keys |
|-----------|:----:|---------------|------------|
| `incident` | Existing | DASH, BOARDS, OPS, CMD, HANDOFF | `ARC_active*` |
| `followOn` | Existing | DASH, CMD | `ARC_activeIncidentFollowOn*` |
| `ops` | Existing | DASH, BOARDS, INTEL, OPS, CMD | `ARC_pub_orders`, `ARC_pub_queuePending`, etc. |
| `stateSummary` | Existing | DASH, HQ, S1 | `ARC_pub_state` sustainment pairs |
| `access` | Existing | Permission checks | Token arrays |
| `civsub` | Existing | Future | `civsub_v1_*` |
| **`airbase`** | **NEW** | **AIR** | `ARC_pub_airbaseUiSnapshot` (pass-through) |
| **`personnel`** | **NEW** | **S1** | Personnel roster vars |
| **`handoff`** | **NEW** | **HANDOFF** | Handoff state vars |
| **`intelFeed`** | **NEW** | **INTEL** | `ARC_pub_intelLog` + filters |

Each section carries:
- `data`: the section payload
- `freshness`: `[["updatedAt", _ts], ["staleAfterS", _ttl]]`

### 4.4 Shared Presentation Helpers

Replace per-painter duplicated logic with shared helpers:

| Helper | Purpose | Replaces |
|--------|---------|----------|
| `ARC_fnc_uiConsoleFormatRow` | Format a list row from a tuple with column alignment | Per-painter `format` strings |
| `ARC_fnc_uiConsoleFormatDetail` | Build detail pane HTML from a key-value card schema | Per-painter detail-line arrays |
| `ARC_fnc_uiConsoleFormatStatusChip` | Build R/A/G chip HTML with text + color | AIR-specific `_statusColor` helper |
| `ARC_fnc_uiConsoleFormatEmptyState` | Render a distinct empty-state row | Per-painter "No X" strings |
| `ARC_fnc_uiConsoleFormatAgo` | "Xs ago" / "Xm Ys ago" formatter | AIR `_fmtAgo`, duplicated in 3 painters |
| `ARC_fnc_uiConsoleButtonState` | Set button label + enabled + tooltip in one call | 4-line patterns repeated 50+ times |
| `ARC_fnc_uiConsoleGetPair` | Read a key-value pair from a pair-array | `_getPair` closures duplicated in 5+ files |

---

## 5) PR Breakdown (Sequenced)

### PR 1 — Shell Layout Contract (Mode C: Safe Refactor)

**Scope:** `fn_uiConsoleRefresh.sqf`, `fn_uiConsoleApplyLayout.sqf`, `CfgDialogs.hpp`

**Changes:**
1. Add Region C (Visual Panel) as a declared control in `CfgDialogs.hpp`
   - New IDC 78140: `ConsoleVisualPanel` (RscControlsGroup)
   - Positioned between Region B and Region D
   - Hidden by default; height 0 when unused
2. Refactor `fn_uiConsoleApplyLayout.sqf` to accept a tab layout declaration
   - Read `[useStatusStrip, mainBoardMode, useVisualPanel, visualPanelHeightFrac, splitRatio]`
   - Position all 5 regions from declaration, not from per-tab special cases
3. Refactor `fn_uiConsoleRefresh.sqf` tab switch block
   - Replace per-tab show/hide logic with: read layout declaration → call layout engine → call painter
   - Remove accumulated regression guards (absorbed into layout engine)
   - Preserve all existing button label/enable logic per tab (no behavior change)
4. Move AIR CT_MAP (78137) into Region C slot
   - Position from layout engine, not from ad-hoc painter coordinates
   - Declared height: 35% of content area when active

**Acceptance criteria:**
- All 9 tabs render identically to before (visual parity)
- AIR map no longer overlaps detail pane
- No new IDC collisions
- `fn_uiConsoleRefresh.sqf` shrinks by ~100 lines (regression guards removed)

**Files changed:** 3 | **Estimated LOC delta:** -80 net (simpler dispatch)

---

### PR 2 — Shared Helpers + Console VM Expansion (Mode C: Safe Refactor)

**Scope:** `functions/ui/fn_uiConsole*.sqf` (new helpers), `fn_consoleVmBuild.sqf`, `CfgFunctions.hpp`

**Changes:**
1. Create 7 shared helper functions (see §4.4)
2. Register helpers in `CfgFunctions.hpp`
3. Add `airbase` section to Console VM payload
   - Pass-through of `ARC_pub_airbaseUiSnapshot` with freshness metadata
4. Add `personnel`, `handoff`, `intelFeed` stub sections (data only, no consumers yet)

**Acceptance criteria:**
- Helpers compile and are callable
- VM payload includes `airbase` section with correct freshness
- No existing tab behavior changes (helpers are additive, not yet consumed)

**Files changed:** ~10 | **Estimated LOC delta:** +350 (new helpers + VM sections)

---

### PR 3 — AIR / TOWER Rebuilt on Shell Contract (Mode B: Feature Delivery)

**Scope:** `fn_uiConsoleAirPaint.sqf`, `fn_uiConsoleAirMapPaint.sqf`, `fn_uiConsoleRefresh.sqf` (AIR case only)

**Changes:**
1. AIR painter reads from Console VM `airbase` section (with fallback to direct snapshot)
2. Replace 60+ `_getPair` calls with shared `ARC_fnc_uiConsoleGetPair`
3. Replace duplicated formatters with shared helpers
4. **Fix status strip chip overflow:**
   - Reduce chip text to abbreviated labels: `RWY: OCC`, `ARR: 0`, `DEP: 3`, `TWR: AUTO`, `ALR: NONE`
   - Chip widths scale from container width, not fixed fractions
5. **Fix RECENT EVENTS text wall:**
   - Resolve FLT-xxxx to callsign using arrival/departure tuples
   - Limit events to 5 most recent (already in snapshot contract, enforce in painter)
   - Prefix events with timestamp in `Xm Ys` format, not "Xm Ys ago"
6. **Fix detail pane layout:**
   - Detail pane renders below map (Region D below Region C)
   - Map occupies Region C (35% height); detail pane fills remaining Region D space
   - Selected flight detail shows: callsign, type, phase, priority, time tracked, status
7. **Fix button labels:**
   - Remove "REFRESH" button (redundant with auto-refresh); replace with mode-switch label
   - Primary: action label or "READ-ONLY"
   - Secondary: next-view label or "UPDATE"
8. **Add empty-state visual distinction:**
   - "No arrivals inbound" and "No departures queued" use shared empty-state formatter
   - Visually distinct from data rows (dimmed text, no lbData)

**Acceptance criteria:**
- AIR tab passes 3-second rule (runway state, inbound count, outbound count visible immediately)
- Map does not overlap detail text
- All 5 status chips visible and labeled at 1080p
- Recent events show callsigns, not raw FLT-xxxx
- Existing AIR actions (HOLD, RELEASE, APPROVE, DENY, etc.) work identically
- Hotkeys (H, R, E, D, M, Enter, Esc) work identically
- Confirmation flow preserved

**Files changed:** 3–4 | **Estimated LOC delta:** -200 net (shared helpers replace inline code)

---

### PR 4 — DASH + OPS + CMD Migration (Mode C: Safe Refactor)

**Scope:** `fn_uiConsoleDashboardPaint.sqf`, `fn_uiConsoleOpsPaint.sqf`, `fn_uiConsoleCommandPaint.sqf`

**Changes:**
1. Migrate all three painters to Console VM primary reads (remove `ARC_console_dashboard_v2` / `ARC_console_ops_v2` feature flags — make VM the only path)
2. Replace duplicated format/parse logic with shared helpers
3. Add per-section freshness badges (stale indicator when section age > TTL)
4. Apply explicit empty states for all data sections

**Acceptance criteria:**
- DASH, OPS, CMD render identically to current VM-on behavior
- Feature flags removed (VM is the only path)
- Stale data shows a visual indicator
- No blank sections — all show explicit empty messages

**Files changed:** 3 | **Estimated LOC delta:** -150 net

---

### PR 5 — INTEL + BOARDS + HANDOFF + HQ + S1 Cleanup (Mode C: Safe Refactor)

**Scope:** Remaining 5 tab painters

**Changes:**
1. INTEL: migrate to VM `intelFeed` section; replace inline log parsing
2. BOARDS: migrate to VM `ops` + `incident` sections
3. HANDOFF: migrate to VM `handoff` section
4. HQ: migrate to VM `stateSummary` section; add score freshness
5. S1: migrate to VM `personnel` section
6. All: adopt shared helpers for rows, detail cards, empty states, buttons

**Acceptance criteria:**
- All 5 tabs render identically to before
- All tabs read from Console VM (no direct missionNamespace reads in painters)
- Shared helpers used consistently

**Files changed:** 5–7 | **Estimated LOC delta:** -300 net

---

### PR 6 — Validation Gates + Test Harness (Mode E: Test-Only)

**Scope:** `tests/`, `scripts/dev/`, `docs/qa/`

**Changes:**
1. Add `scripts/dev/check_console_idc_collisions.sh` — static check for duplicate IDCs
2. Add `scripts/dev/check_console_painter_contract.sh` — verify each painter calls shared helpers
3. Create `docs/qa/Console_Tab_Regression_Checklist.md` — per-tab visual regression checklist with screenshot slots
4. Update `tests/TEST-LOG.md` with entries for each PR's validation

**Acceptance criteria:**
- Static checks pass on current codebase
- Regression checklist covers all 9 tabs with role variants
- Test log is current

**Files changed:** 4–5 | **Estimated LOC delta:** +200

---

## 6) Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|:----------:|:------:|-----------|
| Layout engine change breaks a non-AIR tab | Medium | High | PR 1 has visual parity as exit gate; screenshot comparison per tab |
| Console VM expansion introduces stale data | Low | Medium | Freshness metadata on every section; fallback to direct reads until proven |
| Shared helpers have edge cases in SQF | Medium | Low | Each helper gets a test in `tests/run_all.sqf` |
| Removing feature flags breaks DASH/OPS | Low | High | PR 4 only removes flags after confirming VM path is already active (`initServer.sqf` line 109-110 sets both to `true`) |
| IDC collision from new Region C control | Low | High | IDC 78140 verified free (AIR range 78130-78149, only 78130-78137 allocated) |

---

## 7) IDC Allocation Plan

### Current allocation

| Range | Owner | Used | Free |
|-------|-------|:----:|:----:|
| 78001 | Tabs | 1 | — |
| 78010–78016 | Core panes | 6 | — |
| 78021–78024 | Action buttons | 4 | — |
| 78030–78038 | OPS frames | 9 | — |
| 78050–78055 | S2/INTEL controls | 6 | — |
| 78060–78063 | Status indicators | 4 | — |
| 78090–78099 | Shell/frame | 10 | — |
| 78130–78137 | AIR controls | 8 | 78138–78149 (12 free) |

### New allocations (this plan)

| IDC | Control | PR | Purpose |
|-----|---------|:--:|---------|
| 78140 | `ConsoleVisualPanel` | PR 1 | Region C container (RscControlsGroup) |
| 78141 | Reserved | — | Future Region C variant |
| 78142–78149 | Reserved | — | Future AIR/shell expansion |

---

## 8) Migration Sequence Diagram

```
PR 1 (Shell)     PR 2 (VM+Helpers)   PR 3 (AIR)      PR 4 (DASH/OPS/CMD)  PR 5 (Rest)   PR 6 (QA)
    │                  │                  │                  │                  │              │
    ▼                  ▼                  ▼                  ▼                  ▼              ▼
┌────────┐      ┌────────────┐     ┌──────────┐      ┌──────────┐      ┌──────────┐   ┌─────────┐
│ Layout │      │ Shared     │     │ AIR tab  │      │ 3 tabs   │      │ 5 tabs   │   │ Checks  │
│ engine │─────▶│ helpers +  │────▶│ rebuilt  │─────▶│ migrated │─────▶│ migrated │──▶│ + test  │
│ refactor│     │ VM expand  │     │ on shell │      │ to VM    │      │ to VM    │   │ harness │
└────────┘      └────────────┘     └──────────┘      └──────────┘      └──────────┘   └─────────┘
                                        ▲
                                        │
                                   First visible
                                   improvement
```

**Key constraint:** PR 3 is the first PR with a player-visible improvement. PRs 1-2 are
invisible infrastructure. Per `Console_Tab_Migration_Plan.md` §6, each sprint must include
at least one player-visible deliverable — so PRs 1+2+3 should ship in the same sprint.

---

## 9) Validation Protocol

### Per-PR validation

Every PR must include:

1. **Static checks:**
   - `python3 scripts/dev/sqflint_compat_scan.py --strict <changed files>`
   - `git diff --check`
   - `scripts/dev/check_console_conflicts.sh`

2. **Visual parity evidence:**
   - Screenshot of each impacted tab (before/after if layout changes)
   - Must cover: default view, empty state, selected item, role variants

3. **Behavioral parity evidence:**
   - Exercise all button actions on impacted tabs
   - Confirm hotkeys work on AIR tab
   - Confirm confirmation flow on AIR destructive actions

4. **Test log update:**
   - Append entry to `tests/TEST-LOG.md` with date, commit, scenario, result

### Deferred validation (dedicated server required)

- JIP snapshot correctness for VM-sourced tabs
- Late-client recovery for in-flight events
- Reconnect/respawn ownership edge cases
- Persistence durability across restarts

---

## 10) Relationship to Existing Documents

| Document | Relationship |
|----------|-------------|
| `AIR_TOWER_Vision_Architecture_Plan.md` | **Superseded** for scope; UX rules §2.1 are adopted console-wide in this plan §1.1 |
| `AIR_TOWER_Phase0_Audit.md` | **Preserved** as reference; file inventory remains accurate |
| `AIR_TOWER_UI_Snapshot_Contract_v1.md` | **Preserved** unchanged; AIR snapshot tuple format is not modified |
| `AIR_TOWER_Button_Behavior_Matrix.md` | **Preserved** unchanged; button behavior contracts are not modified |
| `Console_VM_v1.md` | **Extended** in this plan §4.3; new sections added, existing sections unchanged |
| `Console_Tab_Migration_Plan.md` | **Complemented** — this plan provides the concrete implementation sequence; that plan provides the rollout/rollback policy |
| `Console_Golden_Behavior_Matrix.md` | **Preserved** unchanged; SITREP/OPS/closeout contracts are not touched |
| `Farabad_Tablet_2011_Style.md` | **Preserved** unchanged; visual style rules still apply |

---

## 11) Exit Criteria (Plan Complete)

The console refactor is complete when:

1. All 9 tabs read from Console VM (no direct `missionNamespace` reads in painters)
2. All tabs use shared helpers for rows, detail cards, empty states, and buttons
3. Shell layout engine positions all regions from tab declarations (no per-tab special cases in refresh)
4. AIR map renders in Region C without overlapping Region D
5. All 5 AIR status chips are visible and labeled at 1080p
6. No dead/ambiguous buttons on any tab
7. Static IDC collision check passes
8. Visual regression checklist signed off for all 9 tabs
9. Test log is current with entries for all 6 PRs

---

## Appendix A: Console File Heat Map

Files sorted by expected change frequency during this refactor:

| File | PRs touching | Risk |
|------|:------------:|:----:|
| `fn_uiConsoleRefresh.sqf` (449 LOC) | PR 1, 3 | 🔴 High |
| `fn_uiConsoleApplyLayout.sqf` (183 LOC) | PR 1 | 🔴 High |
| `fn_uiConsoleAirPaint.sqf` (1,105 LOC) | PR 3 | 🟡 Medium |
| `config/CfgDialogs.hpp` (1,673 LOC) | PR 1 | 🟡 Medium |
| `fn_consoleVmBuild.sqf` (246 LOC) | PR 2 | 🟢 Low |
| `fn_uiConsoleDashboardPaint.sqf` (581 LOC) | PR 4 | 🟢 Low |
| `fn_uiConsoleOpsPaint.sqf` (576 LOC) | PR 4 | 🟢 Low |
| `fn_uiConsoleCommandPaint.sqf` (491 LOC) | PR 4 | 🟢 Low |
| `fn_uiConsoleIntelPaint.sqf` (1,814 LOC) | PR 5 | 🟢 Low |
| New shared helpers (7 files) | PR 2 | 🟢 Low (new) |

---

## Appendix B: Glossary

| Term | Definition |
|------|-----------|
| **Region** | A declared visual slot in the console layout (A–E) |
| **Layout declaration** | A per-tab config array specifying which regions are active |
| **Painter** | A tab-specific function that fills regions with content |
| **Console VM** | Server-built normalized payload (`ARC_consoleVM_payload`) |
| **Status chip** | A small R/A/G indicator with text label (e.g., "RWY: OPEN") |
| **Decision band** | A narrow high-priority strip shown when action is needed |
| **Visual panel** | Region C: an optional map, chart, or image area |
| **Detail pane** | Region D: shows selected item details |
| **Main board** | Region B: the primary content area (list, structured text, or frames) |

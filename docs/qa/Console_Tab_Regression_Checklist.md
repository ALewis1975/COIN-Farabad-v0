# Console Tab Regression Checklist

**Purpose:** per-tab visual/behavioral regression checklist for the Farabad
Console (Refactor Plan PR 6 deliverable). Run on the dedicated rig (or hosted
MP with at least one client) after any console shell, painter, or Console VM
change. Record results in `tests/TEST-LOG.md` with `PASS`/`FAIL`/`BLOCKED`.

**Tab inventory (10):** DASH, COMMS, BOARDS (TOC-gated), INTEL, OPS, AIR,
HANDOFF, CMD, HQ, S1.

## How to use

For each impacted tab, exercise every row of its table in each applicable role
variant. "Empty state" means the data section's source is empty (fresh mission
or reset). "Selected item" means a main-board row is selected before checking
the detail pane.

Role variants:
- **CMD/TOC** — queue approver (BN CO / S2 / S3 token)
- **Operator** — squad leader / non-approver with console access
- **OMNI** — testing token (sees all)

Layout variants:
- **FULL** — default fallback layout
- **DOCK_RIGHT** — compact right-docked layout
- **TABLET_FRAME** — opt-in rugged tablet frame layout (`ARC_console_layoutMode = "TABLET_FRAME"`)

## Shell (all tabs)

| # | Check | Expected |
|---|-------|----------|
| S1 | Tab bar contents per role | BOARDS appears only for queue approvers; all other tabs per role gating |
| S2 | Region C (visual panel, IDC 78140) | Hidden with height 0 on all tabs except AIR |
| S3 | Action row (78021–78024) | No dead/cryptic disabled buttons; READ-ONLY label where unauthorized |
| S4 | Status strip (78060–78063) | All 4 indicators visible at 1080p |
| S5 | Tab switch round-trip (visit all 10, return to first) | No layout drift, no control bleed-through from prior tab |
| S6 | TABLET_FRAME opt-in | `pics\Farabad_Tablet.paa` frame visible only when layout mode is `TABLET_FRAME` |
| S7 | TABLET_FRAME viewport | Tabs, panes, status strip, Region C, and action row sit inside the tablet screen rectangle |
| S8 | TABLET_FRAME rollback | Switching back to `FULL` hides the frame and restores full-screen positions |
| S9 | TABLET_FRAME tuning vars | `ARC_console_tabletFrameAspect`, `ARC_console_tabletFrameScale`, and `ARC_console_tabletScreenRect` adjust frame/screen placement without script errors |

## DASH

| # | Check | Expected |
|---|-------|----------|
| D1 | Default view | Incident, orders, queue, sustainment sections populated from Console VM |
| D2 | Empty state | Explicit empty messages, no blank sections |
| D3 | VM unavailable (fresh JIP before first broadcast) | Direct-read fallback renders identically |

## COMMS

| # | Check | Expected |
|---|-------|----------|
| C1 | Command nets / PRC-152 / short-range plans render | From VM comms section |
| C2 | CASEVAC block | Active CASEVAC + cooldown from VM medical section |

## BOARDS (TOC-gated)

| # | Check | Expected |
|---|-------|----------|
| B1 | Incident/queue/orders blocks | Match CMD tab values (same VM sections) |
| B2 | Last SITREP | Found even when older than the VM 5-entry log_tail (direct ops-log read) |
| B3 | Staleness badge | "DATA STALE" line appears when ops section age exceeds TTL (pause broadcast to test) |
| B4 | Empty state | Explicit (none) markers for queue/orders/SITREP |

## INTEL

| # | Check | Expected |
|---|-------|----------|
| I1 | Intel feed (last 25) | Renders from VM intelFeed section; identical to pre-migration |
| I2 | FEED detail selection | Entry detail resolves by id |
| I3 | S2 estimate + OPFOR entries | SIGHTING/THREAT/ISR filter works |
| I4 | FIELD REQUESTS rows (JTAC/SHADOW/TNP) | Role-gated rows present; selection closes dialog then runs client fn |
| I5 | Empty feed | Explicit empty message |

## OPS

| # | Check | Expected |
|---|-------|----------|
| O1 | Orders/queue/backlog frames | From VM ops section |
| O2 | Order actions (accept/deny) | Work identically; server-validated |

## AIR (descoped from VM — rev-checked direct reads, plan §12.3)

| # | Check | Expected |
|---|-------|----------|
| A1 | 3-second rule | Runway state, inbound/outbound counts visible immediately |
| A2 | 5 status chips at 1080p | All visible and labeled |
| A3 | Map in Region C | No overlap with detail pane |
| A4 | Recent events | Callsigns resolved, not raw FLT-xxxx |
| A5 | Hotkeys (H, R, E, D, M, Enter, Esc) | Work identically |
| A6 | Freshness line | FRESH/STALE/DEGRADED renders from snapshot contract |
| A7 | TABLET_FRAME AIR map | Map remains inside the tablet screen and does not cover AIR details or action buttons |

## HANDOFF

| # | Check | Expected |
|---|-------|----------|
| H1 | RTB (INTEL/EPW) state lines | From VM handoff section orders; identical to pre-migration |
| H2 | TOC focus redirection | TOC staff see active-incident group, not own group |
| H3 | Arrived detection | Server arrivedAt primary; proximity fallback works |
| H4 | Staleness badge | "DATA STALE" appears when handoff section age exceeds TTL |
| H5 | Buttons | Debrief enabled when intel RTB accepted; EPW requires accepted + arrived |

## CMD

| # | Check | Expected |
|---|-------|----------|
| M1 | Incident/follow-on/queue fields | From VM incident/followOn sections |
| M2 | Approve/deny/closeout actions | Work identically |

## HQ

| # | Check | Expected |
|---|-------|----------|
| Q1 | ADMIN_SCORE detail | Latest score + rating from VM stateSummary (mission_score); fallback when VM empty |
| Q2 | Publisher freshness list | Ages render for all listed ARC_pub_*UpdatedAt vars |
| Q3 | Admin actions | Role-gated; destructive actions confirm |

## S1 (descoped from VM — rev-checked direct reads, plan §12.3)

| # | Check | Expected |
|---|-------|----------|
| P1 | Roster categories + strength totals | From ARC_pub_s1_registry |
| P2 | Rev-check | No repaint when registry timestamp unchanged |
| P3 | Empty registry | "Waiting for personnel snapshot broadcast." hint |

## JIP / dedicated-only checks (BLOCKED in sandbox; operator run required)

| # | Check | Expected |
|---|-------|----------|
| J1 | JIP client opens console before first VM broadcast | Fallback reads render; no script errors |
| J2 | JIP client after broadcast | VM-sourced tabs match a connected client |
| J3 | Staleness badges with genuinely stale data | Badge appears/disappears across broadcast resume |
| J4 | Reconnect/respawn | Console re-init (keybinds/EHs) re-registers per-mission token |
| J5 | JIP in TABLET_FRAME | Frame and inner screen layout apply locally without new server state or RemoteExec traffic |

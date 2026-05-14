# Air/Tower Runtime QA Checklist

**Purpose:** Hands-on playtest verification guide for the Air/Tower (AIRFIELD\_OPS / ATC) subsystem.
These checks require a real Arma 3 session (local MP or dedicated server) and cannot be automated
in the static-analysis sandbox.

**When to use:** After any change to `functions/ambiance/fn_airbase*.sqf`,
`functions/core/fn_publicBroadcastState.sqf`, `functions/ui/fn_uiConsoleAir*.sqf`,
or `config/CfgRemoteExec.hpp` that touches Air/Tower paths.

**Tester prerequisites:**
- Arma 3 dedicated server (or hosted MP session) available.
- At least one additional client to test JIP behaviour.
- Console access (AIRFIELD\_OPS tab) on a unit authorised for tower control.
- RPT log viewer open and accessible during the session.

---

## Checklist format

Each scenario below lists:
- **Setup** — conditions to arrange before checking.
- **Action** — what to do.
- **Expected** — what correct behaviour looks like.
- **RPT / state markers** — log events or variables to look for on the server.

Mark each line `[ ]` → `[x]` (pass) or `[!]` (fail with notes) during your session.

---

## Scenario 1 — No traffic baseline

**Setup:** Fresh mission start; no queued flights, no arrivals.

| # | Check | Expected | RPT marker |
|---|-------|----------|------------|
| 1.1 | Open AIRFIELD\_OPS → default scan view | ARRIVALS: "No arrivals inbound"; RUNWAY: OPEN; DEPARTURES: empty or no entries | — |
| 1.2 | `ARC_pub_airbaseUiSnapshot` broadcast | `freshnessState` = FRESH; `runway.state` = OPEN; `arrivals` and `departures` arrays empty | `airbase_v1_lastTickAt` timestamp recent |
| 1.3 | No console script errors in RPT | No `undefined variable`, no `Expression not found`, no `getOrDefault` errors | RPT clean |

---

## Scenario 2 — Multiple departures queued

**Setup:** Queue at least three departures via normal game flow.

| # | Check | Expected | RPT marker |
|---|-------|----------|------------|
| 2.1 | DEPARTURES board shows all queued flights in order | Callsigns visible; status QUEUED; count matches queue depth | `airbase_v1_queue` array length |
| 2.2 | First departure transitions RUNWAY to RESERVED then OCCUPIED | Runway chip changes: OPEN → RESERVED → OCCUPIED | `AIRBASE RUNWAY: OPEN -> RESERVED`, `OPEN -> OCCUPIED` in OPS log |
| 2.3 | Remaining queued flights stay QUEUED while first is in progress | No queue jump without prioritize action | — |
| 2.4 | On departure completion, RUNWAY returns to OPEN and next flight begins | Runway chip returns to OPEN; next flight starts dispatch | `AIRBASE RUNWAY: OCCUPIED -> OPEN` |

---

## Scenario 3 — Hold and release departures

**Setup:** At least two departures queued, no active runway execution.

| # | Check | Expected | RPT marker |
|---|-------|----------|------------|
| 3.1 | Operator selects HOLD DEPARTURES action | Runway chip or status area shows HOLD active; queued flights remain but do not dispatch | `AIRBASE_HOLD_SET` event |
| 3.2 | New departure queued while hold active | Flight appears in DEPARTURES with QUEUED status; does not dispatch | — |
| 3.3 | Operator selects RELEASE DEPARTURES | Hold clears; dispatch resumes normally | `AIRBASE_HOLD_CLEARED` event |
| 3.4 | Auth-denied user attempts HOLD | Server rejects; client receives hint; RPT logs AIRBASE\_HOLD\_AUTH\_DENIED | `AIRBASE_HOLD_AUTH_DENIED` in OPS log |

---

## Scenario 4 — Cancel queued departure

**Setup:** Two or more departures queued.

| # | Check | Expected | RPT marker |
|---|-------|----------|------------|
| 4.1 | Operator selects a queued flight and cancels it | Flight disappears from DEPARTURES board | `AIRBASE_QUEUE_CANCEL` event |
| 4.2 | Remaining queued flights are unaffected | Other flights remain at their queue positions | `airbase_v1_queue` count decremented by one |
| 4.3 | Cancelling the active runway flight is blocked | Cancel denied; hint sent to caller | `AIRBASE_CANCEL_ACTIVE_BLOCKED` in OPS log |
| 4.4 | Record status updated to CANCELLED | Flight record shows CANCELLED in recent events / debug view | — |

---

## Scenario 5 — Prioritize departure

**Setup:** Three or more departures queued (A, B, C in order); select C to prioritize.

| # | Check | Expected | RPT marker |
|---|-------|----------|------------|
| 5.1 | After prioritize, selected flight moves to head of queue | Flight C now first; A and B follow | `AIRBASE_PRIORITY_SET` event |
| 5.2 | No duplicate entries in queue | Queue length unchanged; only one entry per flight ID | `airbase_v1_queue` count unchanged |
| 5.3 | Record status updated to PRIORITIZED | Flight record metadata shows prioritizedBy |  — |
| 5.4 | Next dispatch uses the prioritized flight | Correct callsign occupies runway first | — |

---

## Scenario 6 — Arrival inbound while departures queued

**Setup:** At least one departure queued; spawn or trigger an inbound arrival.

| # | Check | Expected | RPT marker |
|---|-------|----------|------------|
| 6.1 | Arrival appears in ARRIVALS section | Callsign, phase (INBOUND / APPROACH), and distance/age visible | `airbase_v1_arrivals` state |
| 6.2 | Runway conflict is avoided | Arrival and departure do not simultaneously occupy the runway | RPT: no simultaneous OCCUPIED for two different FIDs |
| 6.3 | Priority logic respected | If departure is dispatching, arrival waits for runway clear; if arrival is landing, queued departure waits | — |
| 6.4 | After landing completes, runway returns to OPEN | RUNWAY chip returns to OPEN; next departure can proceed | `AIRBASE RUNWAY: OCCUPIED -> OPEN` |

---

## Scenario 7 — Emergency/priority arrival

**Setup:** Queue at least one departure; trigger or mark an arrival as emergency.

| # | Check | Expected | RPT marker |
|---|-------|----------|------------|
| 7.1 | Emergency arrival appears in decision queue / CLEARANCES | Status chip indicates EMERGENCY; decision action visible in AIRFIELD\_OPS | `clearanceEmergencyCount > 0` |
| 7.2 | Tower approves emergency clearance | Arrival proceeds; dispatching departure is held if appropriate per mission design | `AIRBASE_CLEARANCE_DECISION` event |
| 7.3 | Emergency marker visible on map pane | Arrival marker has distinct visual indicator on CT\_MAP (78137) | — |

---

## Scenario 8 — Runway occupied/reserved/open transitions

**Setup:** Vary conditions (normal departure, hold, sweep, orphan scenario if possible).

| # | Check | Expected | RPT marker |
|---|-------|----------|------------|
| 8.1 | Manual admin reset clears runway state | After `airbaseAdminResetControlState`, runway returns to OPEN | `AIRBASE_CONTROL_RESET` event |
| 8.2 | Sweep recovers stale OCCUPIED lock | If `execActive = false` while runway state is OCCUPIED, next tick or action clears it | `AIRBASE RUNWAY: OCCUPIED -> OPEN (cleanup ORPHANED_EXEC)` |
| 8.3 | Sweep recovers expired RESERVED lock | If `runwayUntil` has elapsed, sweep clears RESERVED | `cleanup TIMEOUT` in OPS log |
| 8.4 | No permanent OCCUPIED state after 5-minute idle | State machine self-heals without operator intervention | — |

---

## Scenario 9 — Failed RETURN-arrival recovery

**Setup:** Trigger a RETURN arrival (an asset returning from a prior sortie) and cause it to fail
(e.g., destroy the aircraft in flight or script-force a failure condition in test).

| # | Check | Expected | RPT marker |
|---|-------|----------|------------|
| 9.1 | Asset does not remain stuck in `RETURN_QUEUED` | Asset transitions to COOLDOWN with `availableAt` set | `AIRBASE_RETURN_FAILURE_RECOVERED` event |
| 9.2 | `activeFlight` cleared on asset | Asset's `activeFlight` field returns to empty string | — |
| 9.3 | Asset becomes available again after cooldown | After cooldown expires, asset re-enters pool for future sorties | `availableAt < serverTime` |
| 9.4 | No duplicate or orphaned queue entry | Queue does not retain a ghost entry for the failed RETURN flight | — |

---

## Scenario 10 — JIP / late client snapshot freshness

**Setup:** Running mission with some Air/Tower state (at least one queued departure or arrival).
Have a second client join while the mission is running.

| # | Check | Expected | RPT marker |
|---|-------|----------|------------|
| 10.1 | Late client receives `ARC_pub_airbaseUiSnapshot` | AIRFIELD\_OPS shows current state immediately after join (no blank/empty state) | `ARC_pub_airbaseUiSnapshot` JIP variable received |
| 10.2 | Snapshot `freshnessState` is FRESH or DEGRADED (not STALE) on join | Freshness indicator reflects time since last tick, not a stale epoch | `updatedAt` timestamp in snapshot |
| 10.3 | Arrivals / Departures match server state | Late client's board matches the AIRFIELD\_OPS view on an earlier-joined client | Side-by-side comparison |
| 10.4 | `rev` counter is non-zero on late join | Confirms snapshot has been updated at least once since mission start | `ARC_pub_airbaseUiSnapshotRev` variable |

---

## Scenario 11 — Malformed / missing position tuple safety

**Setup:** If possible, suppress position data for one arrival or departure by temporarily setting
its position to `[0, 0]` or removing from queue externally. (Can be simulated via server-side
`diag_log` inspection and variable manipulation in the debug console.)

| # | Check | Expected | RPT marker |
|---|-------|----------|------------|
| 11.1 | Map pane (CT\_MAP 78137) does not produce script errors when position is `[0, 0]` | RPT shows no `undefined variable` or array-index errors from `fn_uiConsoleAirMapPaint.sqf` | RPT clean |
| 11.2 | Marker falls back to airbase center when position tuple is short | Marker appears at airbase center, not at `[0, 0]` world origin | Visual check on map |
| 11.3 | AIRFIELD\_OPS traffic board still renders | Board does not blank; only map marker position is affected | — |

---

## Scenario 12 — AIRFIELD\_OPS visual overlap audit

**Setup:** Enable layout audit mode before opening the console.
Execute the following in the Arma 3 debug console on the server or client machine
(shift-click the execute button to run server-side, or use the in-game debug console):
```sqf
ARC_console_layout_audit = true;
```
Then open the Farabad Console and navigate to the AIR / AIRFIELD\_OPS tab.

| # | Check | Expected | RPT marker |
|---|-------|----------|------------|
| 12.1 | No overlap detected between status chip strip (78130) and traffic board (78011) | Audit log shows no overlap for the chips/list pair | RPT: no `[ARC][AUDIT] OVERLAP` for IDCs 78130/78011 |
| 12.2 | No overlap between decision band (78136) and traffic board (78011) | — | RPT: no `[ARC][AUDIT] OVERLAP` for IDCs 78136/78011 |
| 12.3 | No overlap between map pane (78137) and selected-detail card (78016) | — | RPT: no `[ARC][AUDIT] OVERLAP` for IDCs 78137/78016 |
| 12.4 | No overlap between map pane (78137) and traffic board (78011) | — | RPT: no `[ARC][AUDIT] OVERLAP` for IDCs 78137/78011 |
| 12.5 | Three-second scan: default view shows ARRIVALS / RUNWAY / DEPARTURES without needing to scroll | Visual check; all three sections visible without scrolling on 1920×1080 | Screenshot |

---

## Pre-existing known issues (do not regress)

The following failures are **pre-existing and unrelated** to Air/Tower queue logic.
Document them here for awareness; do not fail a PR because of these:

- `check_console_conflicts.sh`: Reports duplicate IDCs `78201`, `78202`, `78211`.
  These are pre-existing conflicts unrelated to Air/Tower queue or snapshot code.

---

## Dedicated server / JIP deferred checks

The following cannot be verified in local hosted MP and require a true dedicated server:

- Persistence of `airbase_v1_*` state across server restarts (persistence durability).
- JIP snapshot recovery if the server has been running for more than 30 minutes.
- Reconnect/respawn ownership edge cases where a player disconnects mid-RPC.
- Late-client recovery for in-flight executions (`execActive = true` at join time).

---

## References

- Static contract checks: `tests/static/airbase_queue_lifecycle_contract_checks.sh`
- RemoteExec contract check: `scripts/dev/check_remoteexec_contract.sh`
- Existing planning-mode checks: `tests/static/airbase_planning_mode_checks.sh`
- Hardening plan: `docs/security/RemoteExec_Hardening_Plan.md`
- Endpoint audit matrix: `docs/security/RemoteExec_Endpoint_Audit_Matrix.md`
- sqflint compat guide: `docs/qa/SQFLINT_COMPAT_GUIDE.md`

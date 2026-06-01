# Command Cycle & Base-Gate Dedicated Runtime QA Checklist

**Roadmap:** Step 6 — Lane A (Stabilize & harden), items **A1** and **A3**.

**Purpose:** Hands-on playtest verification that the command cycle
(task → SITREP → follow-on) and the base gates / ATC clearance flow work on a
**real dedicated server**. These checks require a live Arma 3 dedicated host and
cannot be automated in the static-analysis sandbox.

> The companion static gate for Lane A **A2** is
> `tests/static/rpc_owner_capture_conformance_checks.sh` (enforces explicit RPC
> owner-capture across every `ARC_fnc_rpcValidateSender` handler). Run it before
> a runtime session so authority code is known-conformant going in.

**Related code / subsystems**
- Command cycle: `functions/command/*`, `functions/core/fn_toc*`,
  `functions/core/fn_rpcValidateSender.sqf`.
- Base gates / ATC: `functions/world/fn_worldGateBarrierInit.sqf`,
  `functions/ambiance/fn_airbase*.sqf`.

**Tester prerequisites**
- Arma 3 **dedicated** server (not hosted/listen) available.
- At least one extra client to exercise JIP and role-denial paths.
- One unit on an authorised command role (TOC approver / OMNI) and one on an
  unauthorised role, to confirm allow-vs-deny.
- RPT log viewer open on the server during the session.

**How to mark results**
Mark each line `[ ]` → `[x]` (pass) or `[!]` (fail, with notes). Record the
server RPT path, build stamp (`ARC_buildStamp`), and commit SHA, then append a
summary line to `tests/TEST-LOG.md`.

---

## Global pass condition

> **No `*_SECURITY_DENIED` and no `MISSING_REMOTE_CONTEXT` appear in the server
> RPT for any action taken by a correctly-authorised operator.**

Keep a running `grep` on the RPT during the session:

```
SECURITY_DENIED | MISSING_REMOTE_CONTEXT | OWNER_MISMATCH | NULL_OBJECT
```

Any of these against a *valid* role/action is a **FAIL**.

---

## A1 — Command cycle on a dedicated server

### Scenario 1 — Incident generation → acceptance

**Setup:** Fresh dedicated start; operator on an authorised TOC role.

| # | Action | Expected | RPT / state marker |
|---|--------|----------|--------------------|
| 1.1 | Operator generates / pulls the next incident | Incident created and published; appears in field + TOC consoles | `ARC_fnc_tocRequestNextIncident` accepted; no `TOC_NEXT_INCIDENT_SECURITY_DENIED` |
| 1.2 | Operator accepts the incident as a task | Task assigned; active task visible | `ARC_fnc_tocRequestAcceptIncident` accepted; no `TOC_ACCEPT_INCIDENT_SECURITY_DENIED` |
| 1.3 | Assigned unit confirms/accepts the order | Order acknowledged on the unit | `ARC_fnc_intelOrderAccept` accepted; no `TOC_ORDER_ACCEPT_SECURITY_DENIED` |

### Scenario 2 — SITREP → follow-on order

| # | Action | Expected | RPT / state marker |
|---|--------|----------|--------------------|
| 2.1 | Field unit submits a SITREP | SITREP received and accepted at TOC | `ARC_fnc_tocReceiveSitrep` accepted; no `TOC_SITREP_SECURITY_DENIED` |
| 2.2 | TOC issues a follow-on decision (RTB / Hold / Proceed) | Order delivered to the unit and acknowledged | `ARC_fnc_tocRequestCloseoutAndOrder` accepted; no `TOC_CLOSEOUT_SECURITY_DENIED` |
| 2.3 | Unit acknowledges the follow-on order | Acknowledgement reflected in command state | Order ack logged; no denial |
| 2.4 | Incident closes | Incident transitions to closed; removed from active lists | `ARC_fnc_tocRequestCloseIncident` accepted; no `TOC_CLOSE_INCIDENT_SECURITY_DENIED` |

### Scenario 3 — Authority allow/deny matrix

| # | Action | Expected | RPT / state marker |
|---|--------|----------|--------------------|
| 3.1 | Each spine RPC invoked by an **authorised** role | Succeeds | No `*_SECURITY_DENIED`, no `MISSING_REMOTE_CONTEXT` |
| 3.2 | Same RPCs invoked by an **unauthorised** role | Denied cleanly (no state change) | `*_SECURITY_DENIED` with `reason=ROLE_DENIED` (expected here) |
| 3.3 | Forged caller object (owner mismatch attempt) | Rejected | `reason=OWNER_MISMATCH` (expected here) |

### Scenario 4 — JIP reconstruction

| # | Action | Expected | RPT / state marker |
|---|--------|----------|--------------------|
| 4.1 | Late-joiner connects mid-incident | Client reconstructs the active task/orders from published state | `ARC_pub_state_v2` / `ARC_pub_companyCommand` consumed on the JIP client; consoles populate without manual refresh |
| 4.2 | JIP client opens the command console | Active incident, assignment, and order status match the server | No client script errors; no re-issue of server RPCs to populate |

### Scenario 5 — Persistence (save/load)

| # | Action | Expected | RPT / state marker |
|---|--------|----------|--------------------|
| 5.1 | Save with an active incident + issued order | Save completes | `ARC_fnc_tocRequestSave` accepted; no `TOC_SAVE_SECURITY_DENIED` |
| 5.2 | Reload from save | Active incident, assignment, and order state survive intact | State matches pre-save; no orphaned/duplicate incidents |

### Scenario 6 — Cleanup

| # | Action | Expected | RPT / state marker |
|---|--------|----------|--------------------|
| 6.1 | Close an incident that created world refs (markers/tasks/objects) | All associated world refs are removed | No leftover markers/tasks; no dangling object references in RPT |

---

## A3 — Base gates + ATC clearance parity

### Scenario 7 — World gate auto open/close

**Reference:** `ARC_fnc_worldGateBarrierInit`; default trigger radius
`ARC_worldGateTriggerRadiusM = 18` m.

| # | Action | Expected | RPT / state marker |
|---|--------|----------|--------------------|
| 7.1 | Confirm all configured gates resolve at init | Each Eden-placed barrier (`ARC_barrier_north/main/south`) initialises | `worldGateBarrierInit: N gates initialized` (N matches placed barriers) |
| 7.2 | Drive a BLUFOR vehicle within ~18 m of a gate | Barrier auto-raises after the configured raise delay | `Gate <label>: opened for BLUFOR vehicle.` |
| 7.3 | Move the vehicle clear of the gate | Barrier auto-closes after the lower delay | `Gate <label>: auto-closed (no BLUFOR).` |
| 7.4 | Repeat at each gate | Behaviour identical at every gate | One open/close pair logged per gate |

### Scenario 8 — ATC clearance parity (rotary vs fixed-wing)

| # | Action | Expected | RPT / state marker |
|---|--------|----------|--------------------|
| 8.1 | Request taxi/takeoff clearance with a **fixed-wing** airframe | Clearance request submitted and decided through the airbase flow | `ARC_fnc_airbaseSubmitClearanceRequest` / `ARC_fnc_airbaseRequestClearanceDecision` accepted; no `AIRBASE_CLEARANCE_*_SECURITY_DENIED` |
| 8.2 | Request the same with a **rotary** airframe | Identical clearance flow and outcome as fixed-wing | Same RPC path, same accept behaviour |
| 8.3 | Land both airframe types within the airbase bubble | Landing/approach approval works for both | No denial; consistent decision metadata |

### Scenario 9 — ATC JIP + cleanup

| # | Action | Expected | RPT / state marker |
|---|--------|----------|--------------------|
| 9.1 | Late-joiner during an active clearance | Clearance/queue state reconstructs from `ARC_pub_airbaseUiSnapshot` | `freshnessState = FRESH`; AIRFIELD_OPS populates without manual refresh |
| 9.2 | Aircraft leaves the airbase bubble | Despawn/cleanup occurs; no orphaned clearance entries | Queue entry cleared; no dangling refs in RPT |

---

## Sign-off

| Item | Result | Notes |
|------|--------|-------|
| A1 command cycle (Scenarios 1–6) | | |
| A3 gates + ATC parity (Scenarios 7–9) | | |
| Global pass condition (no denials for valid roles) | | |

On completion, append a `tests/TEST-LOG.md` entry recording the dedicated build
stamp, commit SHA, scenarios exercised, and PASS/FAIL/BLOCKED per section.

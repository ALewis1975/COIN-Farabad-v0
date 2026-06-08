# TASKENG / SITREP / Follow-On Reliability Sweep — 2026-06-08

**Mode:** J — Operations / Config / Data Maintenance  
**Status:** Reliability sweep checklist and evidence contract  
**Scope:** TASKENG, SITREP, TOC actions, follow-on orders, lead promotion, queue/orders state, public snapshots, role gates, rebuild/reset, JIP observer behavior.  
**Runtime behavior changes:** None.

---

## 1) Purpose

This reliability sweep proves the command cycle that defines the mission spine under the new read-model and ecosystem-layer work.

The active reliability plan defines A4 as the TASKENG / SITREP / follow-on-orders proof point. Its acceptance focus is that task acceptance, execution, SITREP, closeout, and follow-on orders complete without orphaned state; unit status, queue, orders, lead pool, and public snapshots stay consistent; TOC role gates remain enforced; and rebuild/reset paths leave no ghost tasks or stale addActions.

This sweep does not add behavior. It defines the runtime evidence required before the mission spine can be treated as validated in hosted MP, dedicated, JIP, reconnect, and restart contexts.

---

## 2) Source-of-truth alignment

| Artifact | Role |
|---|---|
| `docs/planning/Subsystem_Reliability_and_Adaptive_COIN_Plan.md` | Defines A4 acceptance focus and deferred runtime proof. |
| `docs/qa/Pre_Dedicated_Mission_Completion_Audit_2026-04-06.md` | Canonical completion ledger. TASKENG / SITREP / TOC remains runtime-only unverified. |
| `docs/architecture/Layer_Contract_Ledger.md` | Layer ownership for L9 Intel / S2, L10 Operations / S3, L11 Sustainment / S4, and L12 Interface. |
| `docs/architecture/State_Config_Ownership_Overlay.md` | State/config ownership overlay for tasking, orders, lead pool, snapshots, and UI consumers. |
| `docs/architecture/Console_VM_v1.md` | Read-model contract for Console surfaces. |
| `docs/security/RemoteExec_Endpoint_Audit_Matrix.md` | Authority and role gate ledger for request paths. |
| `tests/TEST-LOG.md` | Canonical validation log. |

---

## 3) Systems under sweep

| System | Layer | Reliability question |
|---|---|---|
| Lead pool / lead promotion | L9 Intel / S2 and L10 Operations / S3 | Do leads promote to tasking without duplicate consumption, stale entries, or missing source metadata? |
| TASKENG active task lifecycle | L10 Operations / S3 | Does task create -> offer -> accept -> execute -> complete pending SITREP -> close transition cleanly? |
| SITREP gate / submission | L10 Operations / S3 | Do proximity, role, assignment, and state gates match client and server behavior? |
| Follow-on orders | L10 Operations / S3 | Do RTB/Hold/Proceed/follow-on orders publish, accept, complete, and expire without orphaned state? |
| Queue / orders public state | L3 State / Event / Persistence and L10 Operations / S3 | Are queue, order, lead, and task snapshots consistent for current clients and JIP clients? |
| Unit status / readiness | L7 BLUFOR Footprint | Do unit status and group/task binding remain stable across accept, SITREP, closeout, and reconnect? |
| Console VM / Interface | L12 Interface | Do Console tabs show stale/unknown/denied state instead of false no-data? |
| Role gates / TOC actions | L10 Operations / S3 and L12 Interface | Do privileged actions require TOC/S2/S3/Command tokens and server validation? |
| Rebuild / reset | L3 State / Event / Persistence | Do rebuild/reset paths clear active task, addActions, orders, queues, and helper state without ghosts? |
| JIP / reconnect observer | L3 State / Event / Persistence and L12 Interface | Does a late or reconnecting client reconstruct mission spine state from public snapshots/VM? |

---

## 4) Static review checklist

| # | Check | Expected result | Result |
|---|---|---|---|
| S1 | Lead promotion paths use server-owned state. | No client-authoritative lead consumption or task creation. | `PENDING` |
| S2 | Active task lifecycle has one authoritative owner per state key. | State Ownership Ledger matches current writers. | `PENDING` |
| S3 | SITREP gate logic is centralized or parity-backed. | Client/server gates do not drift. | `PENDING` |
| S4 | Follow-on order issue/accept/complete paths use validated server handlers. | UI actions only request; server mutates state. | `PENDING` |
| S5 | Queue/order/lead public snapshots remain bounded and presentation-oriented. | No unbounded mirror of internal state. | `PENDING` |
| S6 | Console VM consumers can tolerate stale or missing state. | No false empty state when snapshot is stale. | `PENDING` |
| S7 | Rebuild/reset clears active task, helper addActions, queue/order state, and task markers. | No ghost task or stale addAction path remains. | `PENDING` |
| S8 | RemoteExec surfaces changed by recent work are unchanged or fully audited. | No new privileged RPC surface introduced by this sweep. | `PENDING` |

---

## 5) Hosted MP runtime checklist

| # | Scenario | Steps | Expected result | Result |
|---|---|---|---|---|
| H1 | Lead to task path | Generate or select a lead; promote/consume it into the tasking path. | Lead is consumed once; task carries source metadata; no duplicate active task. | `BLOCKED_RUNTIME` |
| H2 | Task offer and acceptance | TOC offers task; valid player/group accepts. | Active task state, public snapshots, helpers, and assigned group agree. | `BLOCKED_RUNTIME` |
| H3 | Invalid acceptance | Unauthorized or wrong group attempts acceptance. | Server denies; UI shows denied/blocked state; no authoritative mutation. | `BLOCKED_RUNTIME` |
| H4 | Task execution state | Execute active task until objective completion trigger. | Task moves to complete-pending-SITREP or equivalent close-ready state. | `BLOCKED_RUNTIME` |
| H5 | SITREP gate and submit | Submit SITREP from valid role/location/state and from invalid combinations. | Valid submission accepted; invalid submissions denied with no state drift. | `BLOCKED_RUNTIME` |
| H6 | Closeout and follow-on | TOC closes incident and issues RTB/Hold/Proceed/follow-on order. | Order publishes; task closes; follow-on state is visible and bounded. | `BLOCKED_RUNTIME` |
| H7 | Order acceptance and completion | Assigned group accepts and completes follow-on order. | Order state updates; no stale order remains in public/VM surfaces. | `BLOCKED_RUNTIME` |
| H8 | Reset/rebuild during idle | Run rebuild/reset with no active task. | Clean state, no errors, no stale markers/actions. | `BLOCKED_RUNTIME` |
| H9 | Reset/rebuild during active task | Run rebuild/reset while active task/order exists. | Active state clears or rebuilds deterministically; no ghost task/addAction remains. | `BLOCKED_RUNTIME` |
| H10 | Console VM parity | Inspect tasking, orders, queue, lead, and follow-on views. | Console shows fresh/stale/unknown states accurately; no false no-data state. | `BLOCKED_RUNTIME` |

---

## 6) Dedicated / JIP / reconnect runtime checklist

| # | Scenario | Steps | Expected result | Result |
|---|---|---|---|---|
| D1 | Dedicated fresh start | Start full mod-stack dedicated session. | TASKENG, queue, orders, leads, Console VM, and public snapshots initialize cleanly. | `BLOCKED_RUNTIME` |
| D2 | JIP before task acceptance | Join after task is offered but before acceptance. | Late client sees offered task/queue state and correct action availability. | `BLOCKED_RUNTIME` |
| D3 | JIP after task acceptance | Join after group accepts active task. | Late client reconstructs active task, accepted group, helper/action state, and console state. | `BLOCKED_RUNTIME` |
| D4 | JIP after SITREP pending | Join while task is complete-pending-SITREP. | Late client sees SITREP requirements and valid/invalid action state. | `BLOCKED_RUNTIME` |
| D5 | JIP after follow-on order | Join after follow-on order emission. | Late client sees order, target, group binding, and acceptance state. | `BLOCKED_RUNTIME` |
| D6 | Reconnect during active task | Disconnect/reconnect assigned player during active task. | Reconnected client does not mutate authority and receives fresh-enough state. | `BLOCKED_RUNTIME` |
| D7 | Reconnect during order state | Disconnect/reconnect during follow-on order state. | Reconnected client recovers order visibility and action state without duplicate acceptance. | `BLOCKED_RUNTIME` |
| D8 | Restart after active task | Save/restart while task active. | Active task either rehydrates correctly or is cleaned by documented reset path. | `BLOCKED_RUNTIME` |
| D9 | Restart after closed task/order | Save/restart after closeout/follow-on. | No orphaned tasks, orders, leads, markers, helpers, or addActions remain. | `BLOCKED_RUNTIME` |

---

## 7) Evidence to collect

| Evidence | Required |
|---|---|
| RPT excerpts for lead creation/promotion/consumption | Yes |
| RPT excerpts for task offer, acceptance, execution, and closeout | Yes |
| RPT excerpts for SITREP gate accept/deny paths | Yes |
| RPT excerpts for follow-on order issue/accept/complete paths | Yes |
| Public snapshot dump before and after task acceptance | Yes |
| Console VM payload excerpt before/after SITREP and follow-on | Yes |
| Queue/order/lead pool public state before and after closeout | Yes |
| Rebuild/reset RPT excerpts and state dump | Yes |
| JIP observer notes for each dedicated/JIP scenario | Yes |
| `tests/TEST-LOG.md` PASS / FAIL / BLOCKED_RUNTIME entry | Yes |

---

## 8) Pass / fail rules

### PASS

All hosted MP and dedicated/JIP checks complete with no unresolved state ownership, role gate, snapshot, JIP recovery, reset/rebuild, or orphaned-state failure.

### FAIL

Any check demonstrates:

- Client-authoritative task, SITREP, order, or lead mutation.
- Duplicate active task, duplicate lead consumption, or duplicate order acceptance.
- Follow-on order visible to wrong role/group or accepted by unauthorized client.
- JIP client reconstructs false task/order state or cannot recover public state.
- Reset/rebuild leaves ghost task, stale marker, stale helper action, stale order, or stale queue state.
- Dedicated restart creates orphaned active task/order/lead/thread state.

### BLOCKED_RUNTIME

Use `BLOCKED_RUNTIME` when Arma hosted MP, full mod stack, dedicated server, JIP observer, reconnect, restart, or required scenario setup is unavailable.

---

## 9) Current result

**Result:** `BLOCKED_RUNTIME`

Reason: This PR defines the reliability sweep and evidence contract. Actual hosted MP, dedicated, JIP, reconnect, respawn, reset/rebuild, and persistence validation must be executed in Arma and recorded in `tests/TEST-LOG.md`.

---

## 10) Follow-up tasks

| ID | Follow-up | Mode |
|---|---|---|
| A4-FU-01 | Execute hosted MP lead -> task -> SITREP -> closeout -> follow-on smoke. | J |
| A4-FU-02 | Execute dedicated/JIP active task and follow-on observer checks. | J |
| A4-FU-03 | Execute reconnect/restart checks around active and closed task/order state. | J |
| A4-FU-04 | Convert any confirmed mission-spine defect into bounded Mode A bug-fix PR. | A |
| A4-FU-05 | Do not claim mission spine validation until A4 hosted/dedicated/JIP rows pass with evidence. | Governance |

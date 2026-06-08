# CIVSUB / Threat / IED Reliability Sweep — 2026-06-08

**Mode:** J — Operations / Config / Data Maintenance  
**Status:** Reliability sweep checklist and evidence contract  
**Scope:** CIVSUB, Threat, IED, VBIED, suicide-bomber scaffold, threat economy, district posture coupling, evidence/disposal flow, JIP observer behavior.  
**Runtime behavior changes:** None.

---

## 1) Purpose

This reliability sweep proves the current CIVSUB / Threat / IED coupling before additional adaptive COIN behavior is implemented.

The active reliability plan defines the A3 goal as proving population, influence, threat records, and IED lifecycle coupling. This sweep converts that goal into executable evidence requirements.

This sweep does not add new behavior. It defines what must be observed, what evidence must be collected, and what blocks dedicated/JIP readiness claims until runtime proof exists.

---

## 2) Source-of-truth alignment

| Artifact | Role |
|---|---|
| `docs/planning/Subsystem_Reliability_and_Adaptive_COIN_Plan.md` | Defines A3 acceptance focus and deferred runtime proof. |
| `docs/qa/Pre_Dedicated_Mission_Completion_Audit_2026-04-06.md` | Canonical completion ledger. CIVSUB and Threat / IED / VBIED remain runtime-only unverified. |
| `docs/projectFiles/Farabad_CIVSUBv1_Development_Baseline (1).md` | Locked CIVSUB v1 intent. |
| `docs/projectFiles/Farabad_THREAT_v0_IED_P1_Baseline_regen.md` | Locked Threat v0 + IED Phase 1 implementation baseline. |
| `docs/architecture/Layer_Contract_Ledger.md` | Layer ownership for L4 Civilian / Population and L8 Threat Synthesis. |
| `docs/architecture/State_Ownership_Ledger.md` | State family ownership ledger. |
| `docs/architecture/Configuration_Ownership_Ledger.md` | Config family ownership ledger. |
| `tests/TEST-LOG.md` | Canonical validation log. |

---

## 3) Systems under sweep

| System | Layer | Reliability question |
|---|---|---|
| CIVSUB district posture | L4 Civilian / Population | Do deltas update district posture through server-owned state and publish usable snapshots? |
| CIVSUB physical civilian sampling | L4 Civilian / Population | Does physical sampling work under the intended mod stack without persistence depending on live spawned civilians? |
| CIVSUB identity/contact path | L4 Civilian / Population | Do touched civilians retain identity state and interaction outcomes? |
| Threat records | L8 Threat Synthesis | Do records remain stable and avoid client-side inference? |
| Threat economy | L8 Threat Synthesis | Do allow/deny outcomes expose budget, cooldown, escalation, and district-posture reasons? |
| IED lifecycle | L8 Threat Synthesis | Does suspicious object lifecycle produce discovery, evidence, disposition, neutralization, and cleanup evidence? |
| VBIED / driven VBIED scaffold | L8 Threat Synthesis | Does scaffolded behavior remain bounded and lifecycle-visible where enabled? |
| Suicide-bomber scaffold | L8 Threat Synthesis | Does scaffolded behavior remain gated, visible, and cleanup-safe where enabled? |
| Protected-zone gates | L1 World Registry / L8 Threat Synthesis | Do physical hostile manifestations deny protected-zone violations? |
| JIP observer | L3 State / Event / Persistence / L12 Interface | Does a late client reconstruct public threat/intel/evidence state without hidden assumptions? |

---

## 4) Static review checklist

| # | Check | Expected result | Result |
|---|---|---|---|
| S1 | CIVSUB delta producers route through server-owned functions. | No client-authoritative district mutation found. | `PENDING` |
| S2 | CIVSUB district snapshots remain bounded and public-consumer safe. | UI/Console consumers do not infer hidden state. | `PENDING` |
| S3 | Threat records remain stable public records. | No client-only shape inference required. | `PENDING` |
| S4 | Threat economy snapshot exposes allow/deny reason surface. | Budget/cooldown/escalation/district posture visible enough for operators. | `PENDING` |
| S5 | IED evidence/disposition paths remain server-mediated. | No client-authoritative evidence or disposition state. | `PENDING` |
| S6 | Protected-zone checks exist before attack or IED manifestation. | No direct manifestation path bypasses exclusions. | `PENDING` |
| S7 | Runtime Boundary snapshot is not consumed for behavior yet. | Runtime policy remains diagnostic in this sweep. | `PENDING` |
| S8 | RemoteExec changes are absent. | No new RPC surface introduced. | `PENDING` |

---

## 5) Hosted MP runtime checklist

| # | Scenario | Steps | Expected result | Result |
|---|---|---|---|---|
| H1 | CIVSUB district activation | Enter active district and let CIVSUB tick/sampler run. | District snapshot updates; no RPT spam; physical civilians remain bounded. | `BLOCKED_RUNTIME` |
| H2 | CIVSUB contact interaction | Interact with civilian through available contact/papers/question path. | Interaction is server-mediated; identity/contact result is visible where intended. | `BLOCKED_RUNTIME` |
| H3 | CIVSUB delta to posture | Trigger or simulate lawful aid/detention/harm outcome. | District delta is applied through server-owned state. | `BLOCKED_RUNTIME` |
| H4 | Threat scheduler with multiple district postures | Run scheduler with at least two different district postures. | Allow/deny outcomes differ by posture, budget, cooldown, and escalation as expected. | `BLOCKED_RUNTIME` |
| H5 | Threat record visibility | Generate or activate a threat-linked lead/task. | Threat record appears in public/debug surfaces without client inference. | `BLOCKED_RUNTIME` |
| H6 | IED suspicious object flow | Activate IED scenario, discover object, collect/log evidence, dispose/neutralize. | Discovery/evidence/disposition/cleanup events are logged and visible. | `BLOCKED_RUNTIME` |
| H7 | Protected-zone denial | Attempt hostile manifestation near protected zone or airbase exclusion. | Event denies or relocates safely; reason is logged. | `BLOCKED_RUNTIME` |
| H8 | Cleanup after resolution | Resolve threat and leave area. | World objects/groups are cleaned or converted to history-only records. | `BLOCKED_RUNTIME` |

---

## 6) Dedicated / JIP runtime checklist

| # | Scenario | Steps | Expected result | Result |
|---|---|---|---|---|
| D1 | Dedicated fresh start | Start full mod-stack dedicated session. | CIVSUB, Threat, IED initial state publishes cleanly with no critical RPT errors. | `BLOCKED_RUNTIME` |
| D2 | JIP during active CIVSUB district | Join after CIVSUB district is active. | Late client sees current public district/console state or clear stale state. | `BLOCKED_RUNTIME` |
| D3 | JIP during active threat record | Join after threat record exists. | Late client sees public threat/intel/evidence state without hidden inference. | `BLOCKED_RUNTIME` |
| D4 | JIP observer during IED evidence/disposal flow | Join while evidence/disposition state exists. | Late client reconstructs evidence/disposition/public threat state correctly. | `BLOCKED_RUNTIME` |
| D5 | Reconnect during active threat/IED event | Disconnect/reconnect during active lifecycle. | Reconnected client does not mutate authority and receives fresh-enough state. | `BLOCKED_RUNTIME` |
| D6 | Restart after closed threat event | Save/restart after closed threat/evidence flow. | No orphaned records, objects, tasks, or evidence references. | `BLOCKED_RUNTIME` |

---

## 7) Evidence to collect

| Evidence | Required |
|---|---|
| RPT excerpts for CIVSUB init/tick/sampler/contact | Yes |
| RPT excerpts for threat scheduler allow/deny decisions | Yes |
| RPT excerpts for IED discovery/evidence/disposition/cleanup | Yes |
| Threat economy snapshot before and after event | Yes |
| CIVSUB district snapshot before and after delta | Yes |
| Screenshot or text copy of Console/Diary threat/intel visibility | Yes |
| JIP observer notes | Yes |
| `tests/TEST-LOG.md` PASS / FAIL / BLOCKED entry | Yes |

---

## 8) Pass / fail rules

### PASS

All required hosted and dedicated/JIP checks complete with no unresolved state ownership, replication, cleanup, or protected-zone failure.

### FAIL

Any check demonstrates:

- Client-authoritative mutation of district, threat, evidence, or disposition state.
- Threat/IED manifestation bypasses protected-zone checks.
- Threat records require client inference.
- JIP client reconstructs false state or cannot recover public state.
- Cleanup leaves persistent orphaned world entities or stale records.

### BLOCKED_RUNTIME

Use `BLOCKED_RUNTIME` when Arma runtime, full mod stack, dedicated rig, JIP observer, or required scenario setup is unavailable.

---

## 9) Current result

**Result:** `BLOCKED_RUNTIME`

Reason: This PR defines the reliability sweep and evidence contract. Actual hosted MP, dedicated, JIP, reconnect, respawn, and full mod-stack validation must be executed in Arma and recorded in `tests/TEST-LOG.md`.

---

## 10) Follow-up tasks

| ID | Follow-up | Mode |
|---|---|---|
| A3-FU-01 | Execute hosted MP CIVSUB / Threat / IED smoke checklist. | J |
| A3-FU-02 | Execute dedicated/JIP observer flow for active threat/evidence state. | J |
| A3-FU-03 | Convert any confirmed defect into bounded Mode A bug-fix PR. | A |
| A3-FU-04 | Do not begin adaptive threat behavior until failures are closed or scoped. | Governance |

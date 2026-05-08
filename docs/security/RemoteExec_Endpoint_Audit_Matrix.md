# RemoteExec Endpoint Audit Matrix

**Version:** 1.3
**Date:** 2026-05-08
**Status:** Live audit ledger — populated as Phase 1 of `docs/architecture/Architecture_Plan_2026-05-08.md` proceeds.
**Mode:** F — Documentation-Only Changes
**Companion:** `docs/security/RemoteExec_Hardening_Plan.md` (policy + endpoint inventory)

---

## 1) Purpose

`RemoteExec_Hardening_Plan.md` defines the policy, target allowlist, and required checks for every RPC endpoint. This file is the **live ledger** that records the **current verified status** of each endpoint against those requirements.

Architecture Plan §2.3 specifies the required checks per endpoint:

- **S0** — server guard (`if (!isServer) exitWith {};`)
- **S1** — sender / object binding (`ARC_fnc_rpcValidateSender` or equivalent owner-match)
- **S2** — parameter type / shape validation
- **S3** — role authorization (where the endpoint is privileged)
- **S4** — world / state invariant checks (object alive, distance, current incident/order state, etc.)
- **S5** — idempotency / rate-limit + structured `[ARC][SEC]` logging

A non-applicable check is recorded as `n/a`. An unverified check is recorded as `?`. A failing or missing check is recorded as `❌` and must be linked to a remediation task.

---

## 2) Status legend

| Symbol | Meaning |
|---|---|
| ✅ | Verified present and correct on current head. |
| ⚠️ | Present but with caveat or partial coverage; see notes. |
| ❌ | Missing or known incorrect; remediation required. |
| ? | Not yet audited. |
| n/a | Not applicable for this endpoint. |

**JIP** column: `0` (default deny) or `1` (allowed). Any `1` requires explicit justification.

**Last verified** column: short SHA or ISO date of the audit pass that recorded the status. Empty when never audited.

---

## 3) Client → Server endpoint ledger (target = 2)

> Initial values are seeded from `docs/security/RemoteExec_Hardening_Plan.md` §3 (required checks per endpoint). Audit status starts at `?` for any endpoint not previously verified by a dated PR. Update this ledger via Mode I (Security Hardening) PRs.

### 3.1 CIVSUB endpoints

Audited 2026-05-08 against current head. CIVSUB endpoints share an inline owner-match pattern (`remoteExecutedOwner` vs `owner _actor`) rather than calling `ARC_fnc_rpcValidateSender`, with structured `[CIVSUB][SEC]` logging on rejection. See §6.1 for findings.

| Endpoint | S0 | S1 | S2 | S3 | S4 | S5 | JIP | Last verified | Notes |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|---|---|
| `ARC_fnc_civsubContactReqAction` | ✅ | ✅ | ✅ | n/a | ✅ | ⚠️ | 0 | 2026-05-08 | 6m proximity gate; per-action dispatch validates state; no rate-limit. |
| `ARC_fnc_civsubContactReqSnapshot` | ✅ | ✅ | ✅ | n/a | ✅ | ⚠️ | 0 | 2026-05-08 | Read-only snapshot; no rate-limit. |
| `ARC_fnc_civsubInteractCheckPapers` | ✅ | ✅ | ✅ | n/a | ✅ | ⚠️ | 0 | 2026-05-08 | Compliance precondition (uncon/cuffed/surrender); no rate-limit. |
| `ARC_fnc_civsubInteractDetain` | ✅ | ✅ | ✅ | n/a | ✅ | ⚠️ | 0 | 2026-05-08 | Requires civ districtId; no rate-limit. |
| `ARC_fnc_civsubInteractEndSession` | ✅ | ✅ | ✅ | n/a | ✅ | ⚠️ | 0 | 2026-05-08 | Stop-owner UID match; **no `civsub_v1_enabled` gate** (F-CIV-1). |
| `ARC_fnc_civsubInteractHandoffSheriff` | ✅ | ✅ | ✅ | n/a | ✅ | ⚠️ | 0 | 2026-05-08 | 25m sheriff-holding gate; cuffs-removed gate; no rate-limit. |
| `ARC_fnc_civsubInteractOrderStop` | ✅ | ✅ | ✅ | n/a | ✅ | ⚠️ | 0 | 2026-05-08 | UID populated; **no `civsub_v1_enabled` gate** (F-CIV-1). |
| `ARC_fnc_civsubInteractRelease` | ✅ | ✅ | ✅ | n/a | ✅ | ⚠️ | 0 | 2026-05-08 | Requires civ districtId + civUid; no rate-limit. |
| `ARC_fnc_civsubInteractShowPapers` | ✅ | ✅ | ✅ | n/a | ✅ | ⚠️ | 0 | 2026-05-08 | Probabilistic cooperation gate; no rate-limit. |
| `ARC_fnc_civsubRunMdtByNetId` | ✅ | ✅ | ✅ | ❌ | ⚠️ | ⚠️ | 0 | 2026-05-08 | **TOC role gate missing** (F-CIV-2). Delegates to checkPapers without role check. |

### 3.2 Dev / admin endpoints

Audited 2026-05-08 against current head. Most use `ARC_fnc_rpcValidateSender` + `OMNI || canApproveQueue` role gate; two endpoints (`devToggleDebugMode`, `uiCoverageAuditServer`) are missing privileged gates. See §6.2 for findings.

| Endpoint | S0 | S1 | S2 | S3 | S4 | S5 | JIP | Last verified | Notes |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|---|---|
| `ARC_fnc_devCompileAuditServer` | ✅ | ✅ | ✅ | ✅ | n/a | ✅ | 0 | 2026-05-08 | 15s debounce; OMNI/approver gate via `rpcValidateSender`. |
| `ARC_fnc_devDiagnosticsSnapshot` | ✅ | ✅ | ✅ | ✅ | n/a | ⚠️ | 0 | 2026-05-08 | Read-only; OMNI/approver gate; no rate-limit. |
| `ARC_fnc_devToggleDebugMode` | ✅ | ❌ | ✅ | ❌ | n/a | ⚠️ | 0 | 2026-05-08 | **No sender validation, no role gate** (F-DEV-1). Toggles seven global debug flags + log level via `publicVariable true`. Privileged. |
| `ARC_fnc_uiConsoleQAAuditServer` | ✅ | ✅ | ✅ | ✅ | n/a | ⚠️ | 0 | 2026-05-08 | Read-only; OMNI/approver gate; no rate-limit. |
| `ARC_fnc_uiCoverageAuditServer` | ✅ | ⚠️ | n/a | ❌ | n/a | ⚠️ | 0 | 2026-05-08 | **No sender validation enforcement, no role gate** (F-DEV-2). Logs remote owner only. Writes `ARC_uiCoverageMap` (`publicVariable true`). Static content, but allowlisted from clients. |

### 3.3 Objective / IED / VBIED endpoints

Audited 2026-05-08 against current head (Wave 3 / batch 2). Two objective endpoints (`execObjectiveComplete`, `iedCollectEvidence`) implement the inline `remoteExecutedOwner` vs `owner _caller` pattern with structured `[ARC][SEC]` rejection logging. The two server-detonate endpoints log the remote-owner but do **not** validate or reject — they rely on incident-state idempotency, not sender authority. See §6.3 for findings.

| Endpoint | S0 | S1 | S2 | S3 | S4 | S5 | JIP | Last verified | Notes |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|---|---|
| `ARC_fnc_execObjectiveComplete` | ✅ | ✅ | ✅ | n/a | ✅ | ⚠️ | 0 | 2026-05-08 | Sender-owner match; `isPlayer _caller` gate; active-task / objective-match invariants; no rate-limit. |
| `ARC_fnc_iedCollectEvidence` | ✅ | ✅ | ✅ | n/a | ✅ | ⚠️ | 0 | 2026-05-08 | Sender-owner match (when `_collector` provided); netId resolves and not-already-collected invariants; no rate-limit. |
| `ARC_fnc_iedServerDetonate` | ✅ | ❌ | ✅ | ❌ | ✅ | ⚠️ | 0 | 2026-05-08 | **No sender validation, no EOD role gate** (F-IED-1). State-guarded against double-fire (`activeIedDetonationHandled`). Logs remote-owner only. |
| `ARC_fnc_vbiedServerDetonate` | ✅ | ❌ | ✅ | ❌ | ✅ | ⚠️ | 0 | 2026-05-08 | **No sender validation, no EOD role gate** (F-IED-2). State-guarded by `activeVbiedDetonated` / `activeVbiedSafe`. Logs remote-owner only. |

### 3.4 Intel / order / TOC endpoints

| Endpoint | S0 | S1 | S2 | S3 | S4 | S5 | JIP | Last verified | Notes |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|---|---|
| `ARC_fnc_intelOrderAccept` | ? | ? | ? | n/a | ? | ? | 0 | | |
| `ARC_fnc_intelOrderCompleteRtbEpw` | ? | ? | ? | n/a | ? | ? | 0 | | |
| `ARC_fnc_intelOrderCompleteRtbIntel` | ? | ? | ? | n/a | ? | ? | 0 | | |
| `ARC_fnc_intelQueueDecide` | ? | ? | ? | ? | ? | ? | 0 | | TOC approver role. |
| `ARC_fnc_intelQueueSubmit` | ? | ? | ? | n/a | ? | ? | 0 | | |
| `ARC_fnc_intelTocIssueOrder` | ? | ? | ? | ? | ? | ? | 0 | | TOC role required. |
| `ARC_fnc_publicBroadcastState` | ? | ? | ? | ? | n/a | ? | 0 | | Admin re-broadcast. |
| `ARC_fnc_tocReceiveSitrep` | ? | ? | ? | n/a | ? | ? | 0 | | |
| `ARC_fnc_tocRequestAcceptIncident` | ? | ? | ? | n/a | ? | ? | 0 | | |
| `ARC_fnc_tocRequestCloseIncident` | ? | ? | ? | ? | ? | ? | 0 | | TOC role. |
| `ARC_fnc_tocRequestCloseoutAndOrder` | ? | ? | ? | ? | ? | ? | 0 | | TOC role. |
| `ARC_fnc_tocRequestForceIncident` | ? | ? | ? | ? | ? | ? | 0 | | Admin only. |
| `ARC_fnc_tocRequestLogIntel` | ? | ? | ? | n/a | ? | ? | 0 | | |
| `ARC_fnc_tocRequestNextIncident` | ? | ? | ? | n/a | ? | ? | 0 | | |
| `ARC_fnc_tocRequestRebuildActive` | ? | ? | ? | ? | ? | ? | 0 | | Admin only. |
| `ARC_fnc_tocRequestRefreshIntel` | ? | ? | ? | ? | ? | ? | 0 | | |
| `ARC_fnc_tocRequestResetAll` | ? | ? | ? | ? | n/a | ? | 0 | | Admin only. |
| `ARC_fnc_tocRequestSave` | ? | ? | ? | ? | n/a | ? | 0 | | Admin only. |
| `ARC_fnc_tocRequestCivsubReset` | ? | ? | ? | ? | n/a | ? | 0 | | Admin only. |
| `ARC_fnc_tocRequestCivsubSave` | ? | ? | ? | ? | n/a | ? | 0 | | Admin only. |

### 3.5 Airbase / TOWER endpoints

Audited 2026-05-08 against current head (Wave 3 / batch 3). Prior S0–S3 verification from Phase 8 remains valid; this pass closes S4/S5 status for all 10 Airbase/TOWER client→server endpoints.

| Endpoint | S0 | S1 | S2 | S3 | S4 | S5 | JIP | Last verified | Notes |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|---|---|
| `ARC_fnc_airbaseSubmitClearanceRequest` | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | 0 | 2026-05-08 | Rich world/state invariants (caller↔aircraft owner/distance/seat + route validation). No explicit caller debounce/rate-limit. |
| `ARC_fnc_airbaseRequestClearanceDecision` | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | 0 | 2026-05-08 | Pending-state + route/runway-lock invariants. No explicit caller debounce/rate-limit. |
| `ARC_fnc_airbaseRequestPrioritizeFlight` | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | 0 | 2026-05-08 | Queue-membership invariant enforced. No explicit caller debounce/rate-limit. |
| `ARC_fnc_airbaseCancelClearanceRequest` | ✅ | ✅ | ✅ | n/a | ✅ | ⚠️ | 0 | 2026-05-08 | State + requester/override invariants enforced. No explicit caller debounce/rate-limit. |
| `ARC_fnc_airbaseRequestCancelQueuedFlight` | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | 0 | 2026-05-08 | Queue/record execution guards + return-asset restore invariants. No explicit caller debounce/rate-limit. |
| `ARC_fnc_airbaseMarkClearanceEmergency` | ✅ | ✅ | ✅ | n/a | ✅ | ⚠️ | 0 | 2026-05-08 | Pending-state + requester/override invariants enforced. No explicit caller debounce/rate-limit. |
| `ARC_fnc_airbaseRequestSetLaneStaffing` | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | 0 | 2026-05-08 | Lane/value invariants + staffing state consistency enforced. No explicit caller debounce/rate-limit. |
| `ARC_fnc_airbaseRequestHoldDepartures` | ✅ | ✅ | ✅ | ✅ | n/a | ⚠️ | 0 | 2026-05-08 | Privileged state flip with structured denial logging; no debounce/rate-limit. |
| `ARC_fnc_airbaseRequestReleaseDepartures` | ✅ | ✅ | ✅ | ✅ | n/a | ⚠️ | 0 | 2026-05-08 | Privileged state flip with structured denial logging; no debounce/rate-limit. |
| `ARC_fnc_tocRequestAirbaseResetControlState` | ✅ | ✅ | ✅ | ✅ | n/a | ⚠️ | 0 | 2026-05-08 | Strong S1/S3 and security intel logging; no explicit debounce/rate-limit on reset trigger. |

### 3.6 CASREQ / Logistics / Medical / CASEVAC endpoints

Audited 2026-05-08 against current head (Wave 3 / batch 3). CASREQ handlers are mostly aligned on S0–S4; two non-CASREQ endpoints (`execSpawnConvoy`, `medicalCasevacRequest`) remain allowlisted client→server surfaces without sender binding.

| Endpoint | S0 | S1 | S2 | S3 | S4 | S5 | JIP | Last verified | Notes |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|---|---|
| `ARC_fnc_casreqOpen` | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | 0 | 2026-05-08 | Sender validation + role gate + subsystem/world guards. No per-caller cooldown. |
| `ARC_fnc_casreqDecide` | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | 0 | 2026-05-08 | Role-gated decision path with OPEN-state invariant. No per-caller cooldown. |
| `ARC_fnc_casreqExecute` | ✅ | ✅ | ✅ | n/a | ✅ | ⚠️ | 0 | 2026-05-08 | APPROVED→EXECUTING invariant; sender-bound. No explicit role gate and no per-caller cooldown. |
| `ARC_fnc_casreqClose` | ✅ | ✅ | ✅ | n/a | ✅ | ⚠️ | 0 | 2026-05-08 | Result/state/index invariants present; sender-bound. No explicit role gate and no per-caller cooldown. |
| `ARC_fnc_execSpawnConvoy` | ⚠️ | ❌ | ✅ | ❌ | ⚠️ | ⚠️ | 0 | 2026-05-08 | Non-server path relays to server, but server path has no sender validation/role gate (F-LOG-1). |
| `ARC_fnc_medicalCasevacRequest` | ✅ | ❌ | ✅ | ❌ | ✅ | ✅ | 0 | 2026-05-08 | World-state + cooldown guard is present, but no sender binding/role gate despite allowlisted client→server exposure (F-MED-1). |

---

## 4) Server → Client endpoint ledger

Server→client endpoints are not subject to S1–S4 in the same way (the server is the authority). Audit focus is **JIP intent correctness** and idempotency of client-side handlers.

| Endpoint | JIP | Idempotent? | Object-keyed? | Last verified | Notes |
|---|:---:|:---:|:---:|---|---|
| `ARC_fnc_airbaseDiaryUpdate` | 0 | ? | n/a | | Live update; no JIP replay needed. |
| `ARC_fnc_briefingHardResetClient` | 0 | ? | n/a | | Reset pulse. |
| `ARC_fnc_civsubCivAddAceActions` | 1 | ? | ✅ | | Object-keyed (per-civilian). |
| `ARC_fnc_civsubCivAddContactActions` | 1 | ? | ✅ | | Object-keyed (per-civilian). |
| `ARC_fnc_civsubClientMessage` | 0 | n/a | n/a | | Ephemeral. |
| `ARC_fnc_civsubClientShowIdCard` | 0 | n/a | n/a | | Ephemeral. |
| `ARC_fnc_civsubContactClientReceiveResult` | 0 | n/a | n/a | | Request/response. |
| `ARC_fnc_civsubContactClientReceiveSnapshot` | 0 | n/a | n/a | | Request/response. |
| `ARC_fnc_clientAddObjectiveAction` | 1 | ? | ✅ | | Object-bound add-action. |
| `ARC_fnc_clientHint` | 0 | n/a | n/a | | Ephemeral. |
| `ARC_fnc_clientPurgeArcTasks` | 0 | ? | n/a | | Reset pulse. |
| `ARC_fnc_clientSetCurrentTask` | 0 | ? | n/a | | Live assignment. |
| `ARC_fnc_clientToast` | 0 | n/a | n/a | | Ephemeral. |
| `ARC_fnc_iedClientAddEvidenceAction` | 1 | ? | ✅ | | Object-bound add-action. |
| `ARC_fnc_iedClientEnableEvidenceLogistics` | 1 | ? | ✅ | | Carry/drag flags. |
| `ARC_fnc_intelClientNotify` | 0 | n/a | n/a | | Ephemeral. |
| `ARC_fnc_tocInitPlayer` | 0 | ? | n/a | | Should use join hook, not JIP replay. |
| `ARC_fnc_uiConsoleCompileAuditClientReceive` | 0 | n/a | n/a | | Request/response. |
| `ARC_fnc_uiConsoleQAAuditClientReceive` | 0 | n/a | n/a | | Request/response. |
| `ARC_fnc_devDiagnosticsClientReceive` | 0 | n/a | n/a | | Request/response. |

---

## 5) Command-class allowlist tracking

Non-`ARC_fnc_*` entries in `CfgRemoteExec.Commands`. Each entry should have a justification and, where feasible, a migration plan to a named `ARC_fnc_*` wrapper.

| Command | Currently allowed? | Justification | Migration target |
|---|:---:|---|---|
| `BIS_fnc_holdActionAdd` | ? | Object-bound hold actions. | Optional wrapper. |
| `BIS_fnc_holdActionRemove` | ? | Pair with above. | Optional wrapper. |
| `disableAI` | ? | Civilian/AI behavior shaping. | Wrap in `ARC_fnc_*` if reused. |
| `enableAudioFeature` | ? | Audio control. | Wrap if reused. |
| `forceWalk` | ? | Civilian/AI behavior shaping. | Wrap if reused. |
| `limitSpeed` | ? | Convoy / AI movement. | Wrap if reused. |
| `playMoveNow` | ? | Animations. | Wrap if reused. |
| `setPhysicsCollisionFlag` | ? | Vehicle physics. | Wrap if reused. |
| `setPilotLight` | ? | Vehicle lighting. | Wrap if reused. |
| `setUnitTrait` | ? | Unit traits. | Wrap if reused. |
| `switchMove` | ? | Animations. | Wrap if reused. |
| `systemChat` | ? | UI feedback. | Replace with `ARC_fnc_clientHint` / `ARC_fnc_clientToast` where possible. |
| `call` | ❌ (target state) | Dynamic execution; high risk. | Remove if currently allowed; replace every site with named wrapper. |

---

## 6) Audit pass procedure

Per pass:

1. Pick a section (3.1 – 3.6, 4, 5).
2. For each endpoint, open the implementing function and confirm the corresponding check.
3. Record `✅ / ⚠️ / ❌ / n/a` plus the audit date or short SHA in **Last verified**.
4. For any `❌` or `⚠️`, open a Mode I PR with the remediation; reference this matrix in the PR description.
5. Update `tests/TEST-LOG.md` with the pass result (PASS / FAIL / BLOCKED) and link.

---

## 6) Findings — open remediation items

These findings were recorded by the 2026-05-08 audit passes (Wave 1 + Wave 3 batches). Each must be resolved by a follow-on Mode I PR with tightly scoped changes.

### 6.1 CIVSUB findings

| ID | Endpoint(s) | Check | Severity | Description | Remediation |
|---|---|:---:|:---:|---|---|
| F-CIV-1 | `ARC_fnc_civsubInteractEndSession`, `ARC_fnc_civsubInteractOrderStop` | S4 | P2 | Both endpoints lack the `civsub_v1_enabled` mission-toggle gate that every other CIVSUB endpoint enforces. Side effects are bounded (movement freeze / restore on a CIVSUB-managed civilian) but execution should not proceed when the subsystem is disabled. | Add `if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};` after the S0 guard. |
| F-CIV-2 | `ARC_fnc_civsubRunMdtByNetId` | S3 | P1 | Matrix scaffold notes "TOC role gate required" but the implementation has **no role check** — any authenticated player can run the MDT crime DB pipeline against any civilian by netId. Delegates to `civsubInteractCheckPapers` with `requireCompliance=false`. | Add a TOC/S2 role gate (e.g. `[_actor] call ARC_fnc_rolesCanApproveQueue` or an MDT-specific role check) before delegating. |
| F-CIV-3 | All CIVSUB client→server endpoints | S5 | P2 | Inline `remoteExecutedOwner`/`owner _actor` validation pattern is correct but is duplicated in nine functions instead of routing through `ARC_fnc_rpcValidateSender`. Drift risk over time. | Migrate to `ARC_fnc_rpcValidateSender` in a single Mode I PR; preserve `[CIVSUB][SEC]` log prefix via a thin wrapper or pass-through `_event` codes. |
| F-CIV-4 | All CIVSUB client→server endpoints | S5 | P2 | No per-actor rate-limit / idempotency on dialog-action and snapshot endpoints. A misbehaving client can flood the server. | Add a per-owner cooldown (≥250ms for snapshot; ≥1s for state-mutating actions) keyed on `getPlayerUID _actor`, with rejection logged once per cooldown window. |

### 6.2 Dev / admin findings

| ID | Endpoint | Check | Severity | Description | Remediation |
|---|---|:---:|:---:|---|---|
| F-DEV-1 | `ARC_fnc_devToggleDebugMode` | S1, S3 | P1 | Globally toggles seven debug flags and `FARABAD_log_minLevel` via `publicVariable true` with no sender validation and no role check. Any client on the allowlist can flip global debug state. | Add `ARC_fnc_rpcValidateSender` call and the same `OMNI \|\| canApproveQueue` gate used by sibling dev/admin endpoints; reject with `[ARC][SEC] DEBUG_TOGGLE_DENIED` log. |
| F-DEV-2 | `ARC_fnc_uiCoverageAuditServer` | S1, S3 | P2 | Logs `remoteExecutedOwner` only — does not validate or reject. No role gate. Writes `ARC_uiCoverageMap` with `publicVariable true`. Content is static, but the side effect is global. | Add sender validation + admin role gate; or remove the endpoint from `CfgRemoteExec` allowlist and call it server-side only. |
| F-DEV-3 | `ARC_fnc_devDiagnosticsSnapshot`, `ARC_fnc_uiConsoleQAAuditServer` | S5 | P3 | Read-only audit endpoints have no debounce. Approver-gated, so risk is low; consider matching the 15s debounce already used by `devCompileAuditServer` for consistency. | Add 15s debounce keyed on requester UID. |

### 6.3 Objective / IED / VBIED findings

| ID | Endpoint(s) | Check | Severity | Description | Remediation |
|---|---|:---:|:---:|---|---|
| F-IED-1 | `ARC_fnc_iedServerDetonate` | S1, S3 | P1 | Function logs `remoteExecutedOwner` but does not validate or reject; there is no EOD role gate. The endpoint deletes the IED prop, deletes the trigger, creates a `Bo_Mk82` explosion at the active objective position, and marks `activeIedTriggerEnabled=false`. State guard (`activeIedDetonationHandled`) prevents double-fire but does not constrain who initiates the first fire. Trigger collision in normal play makes this low-impact in steady state, but the RPC is callable from any allowlisted client. | Add `ARC_fnc_rpcValidateSender` (or inline owner-match) + reject when caller is not the proximity-trigger source. Confirm only the proximity trigger / EOD pathway can invoke this. Add `[ARC][SEC] IED_SERVER_DETONATE_DENIED` log on rejection. Consider removing from `CfgRemoteExec` allowlist if the trigger is server-spawned (no remote caller required). |
| F-IED-2 | `ARC_fnc_vbiedServerDetonate` | S1, S3 | P1 | Same shape as F-IED-1: remote-owner logged but not validated; no role gate. Same idempotency guards (`activeVbiedDetonated`, `activeVbiedSafe`). | Same remediation as F-IED-1. If the only legitimate caller is the in-world VBIED proximity trigger, prefer removing from `CfgRemoteExec` allowlist over adding a role check. |
| F-IED-3 | `ARC_fnc_execObjectiveComplete`, `ARC_fnc_iedCollectEvidence` | S5 | P2 | Sender-validated and state-validated, but no per-actor rate-limit. A misbehaving client can replay the call rapidly until idempotency kicks in. | Add a per-owner cooldown (≥1s) keyed on `getPlayerUID _caller` / `_collector`; rejection logged once per cooldown window. |

### 6.4 Airbase / CASREQ / Logistics / Medical findings

| ID | Endpoint(s) | Check | Severity | Description | Remediation |
|---|---|:---:|:---:|---|---|
| F-AIR-1 | `ARC_fnc_airbaseSubmitClearanceRequest`, `ARC_fnc_airbaseRequestClearanceDecision`, `ARC_fnc_airbaseRequestPrioritizeFlight`, `ARC_fnc_airbaseCancelClearanceRequest`, `ARC_fnc_airbaseRequestCancelQueuedFlight`, `ARC_fnc_airbaseMarkClearanceEmergency`, `ARC_fnc_airbaseRequestSetLaneStaffing`, `ARC_fnc_airbaseRequestHoldDepartures`, `ARC_fnc_airbaseRequestReleaseDepartures`, `ARC_fnc_tocRequestAirbaseResetControlState` | S5 | P2 | All 10 Airbase/TOWER client→server endpoints now verify S4, but none applies per-caller cooldown/debounce. Repeated spam calls can still consume server cycles and log bandwidth. | Add a shared per-owner/per-endpoint cooldown helper (0.25–1.0s by action class) and emit structured denial logs once per cooldown window. |
| F-CAS-1 | `ARC_fnc_casreqExecute`, `ARC_fnc_casreqClose` | S3 | P2 | Both endpoints are sender-validated but lack explicit role/ownership authorization. Any authenticated client with a valid CASREQ ID can transition lifecycle state. | Gate execute/close to requester UID, assigned pilot role, or TOC approver/OMNI; reject and log unauthorized transitions with `[ARC][SEC]` event codes. |
| F-LOG-1 | `ARC_fnc_execSpawnConvoy` | S1, S3 | P1 | Endpoint is allowlisted client→server but server path does not validate sender identity and has no role gate. Non-server calls are relayed to server asynchronously, allowing any client to request convoy spawn attempts. | Add `ARC_fnc_rpcValidateSender` + privileged role/invariant gate (or remove from client allowlist if this should be server-internal only). Keep relay path non-authoritative. |
| F-MED-1 | `ARC_fnc_medicalCasevacRequest` | S1, S3 | P1 | Endpoint is allowlisted client→server yet has no sender validation or authorization gate; clients can request CASEVAC lead creation directly by passing `west`. Cooldown reduces spam but does not enforce caller legitimacy. | Prefer removing the endpoint from `CfgRemoteExec` allowlist and invoking server-side from trusted medical handlers only; if kept allowlisted, add sender validation + role/invariant gate. |

Each finding above is the seed for a Mode I PR. Open issues / PRs must reference the finding ID (F-CIV-#, F-DEV-#, F-IED-#, F-AIR-#, F-CAS-#, F-LOG-#, F-MED-#) and update this section to `RESOLVED` with the merge SHA when remediation lands.

---

## 7) Out-of-scope for this ledger

- New endpoint additions (covered by `RemoteExec_Hardening_Plan.md` §2 + `CfgRemoteExec.hpp` review).
- Allowlist mode changes (`mode` / `jip` defaults) — those are policy changes belonging in the hardening plan.
- Client-local function refactors that do not change the RPC surface.

---

## Change log

### v1.3 — 2026-05-08
- Wave 3 / batch 3 audit pass completed:
  - §3.5 Airbase/TOWER endpoints re-verified for S4/S5 (all 10 rows moved from `?` to explicit statuses).
  - New §3.6 added for CASREQ + Logistics/Medical/CASEVAC endpoints (`casreqOpen/Decide/Execute/Close`, `execSpawnConvoy`, `medicalCasevacRequest`).
- Added §6.4 findings for this batch: F-AIR-1, F-CAS-1, F-LOG-1, F-MED-1.
- Truth-status: branch-local. Findings derived from current cloned working branch; not yet `origin/main`-confirmed per `Farabad_Source_of_Truth_and_Workflow_Spec.md`.

### v1.2 — 2026-05-08
- Wave 3 / batch 2 audit pass: §3.3 (Objective / IED / VBIED) populated with verified S0–S5 status against current head.
- Added §6.3 (Objective / IED / VBIED findings) capturing three open remediation items (F-IED-1..3). F-IED-1 / F-IED-2 are P1 Mode I follow-ons; F-IED-3 is a P2 rate-limit gap shared with `execObjectiveComplete` and `iedCollectEvidence`.
- Truth-status: branch-local. Findings derived from current cloned working branch; not yet `origin/main`-confirmed per `Farabad_Source_of_Truth_and_Workflow_Spec.md`.

### v1.1 — 2026-05-08
- Wave 1 / batch 1 audit pass: CIVSUB endpoints (§3.1) and dev/admin endpoints (§3.2) populated with verified S0–S5 status.
- Added §6 (findings ledger) capturing seven open remediation items (F-CIV-1..4, F-DEV-1..3). Each item becomes a follow-on Mode I PR.
- Out-of-scope sections renumbered to §7; this change log moved under §8.

### v1.0 — 2026-05-08
- Initial scaffold derived from `RemoteExec_Hardening_Plan.md`. All client→server entries seeded with `?` except AIR/TOWER (verified 2026-04-07). Server→client entries seeded from §1.2 of the hardening plan with JIP intent preserved.

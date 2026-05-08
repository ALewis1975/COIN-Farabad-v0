# RemoteExec Endpoint Audit Matrix

**Version:** 1.0 (initial scaffold)
**Date:** 2026-05-08
**Status:** Live audit ledger — populated as Phase 1 of `docs/architecture/Architecture_Plan_2026-05-08.md` proceeds.
**Mode:** F — Documentation-Only Changes (this scaffold)
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

| Endpoint | S0 | S1 | S2 | S3 | S4 | S5 | JIP | Last verified | Notes |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|---|---|
| `ARC_fnc_civsubContactReqAction` | ? | ? | ? | n/a | ? | ? | 0 | | |
| `ARC_fnc_civsubContactReqSnapshot` | ? | ? | ? | n/a | ? | ? | 0 | | |
| `ARC_fnc_civsubInteractCheckPapers` | ? | ? | ? | n/a | ? | ? | 0 | | |
| `ARC_fnc_civsubInteractDetain` | ? | ? | ? | n/a | ? | ? | 0 | | |
| `ARC_fnc_civsubInteractEndSession` | ? | ? | ? | n/a | ? | ? | 0 | | |
| `ARC_fnc_civsubInteractHandoffSheriff` | ? | ? | ? | n/a | ? | ? | 0 | | |
| `ARC_fnc_civsubInteractOrderStop` | ? | ? | ? | n/a | ? | ? | 0 | | |
| `ARC_fnc_civsubInteractRelease` | ? | ? | ? | n/a | ? | ? | 0 | | |
| `ARC_fnc_civsubInteractShowPapers` | ? | ? | ? | n/a | ? | ? | 0 | | |
| `ARC_fnc_civsubRunMdtByNetId` | ? | ? | ? | ? | ? | ? | 0 | | TOC role gate required. |

### 3.2 Dev / admin endpoints

| Endpoint | S0 | S1 | S2 | S3 | S4 | S5 | JIP | Last verified | Notes |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|---|---|
| `ARC_fnc_devCompileAuditServer` | ? | ? | ? | ? | n/a | ? | 0 | | Admin only. |
| `ARC_fnc_devDiagnosticsSnapshot` | ? | ? | ? | ? | n/a | ? | 0 | | Admin only. |
| `ARC_fnc_devToggleDebugMode` | ? | ? | ? | ? | n/a | ? | 0 | | Admin only. |
| `ARC_fnc_uiConsoleQAAuditServer` | ? | ? | ? | ? | n/a | ? | 0 | | Admin only. |
| `ARC_fnc_uiCoverageAuditServer` | ? | ? | ? | ? | n/a | ? | 0 | | Admin only. |

### 3.3 Objective / IED / VBIED endpoints

| Endpoint | S0 | S1 | S2 | S3 | S4 | S5 | JIP | Last verified | Notes |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|---|---|
| `ARC_fnc_execObjectiveComplete` | ? | ? | ? | n/a | ? | ? | 0 | | |
| `ARC_fnc_iedCollectEvidence` | ? | ? | ? | n/a | ? | ? | 0 | | |
| `ARC_fnc_iedServerDetonate` | ? | ? | ? | ? | ? | ? | 0 | | EOD authority required. |
| `ARC_fnc_vbiedServerDetonate` | ? | ? | ? | ? | ? | ? | 0 | | EOD authority required. |

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

Status verified by Phase 8 hardening pass (see `docs/security/RemoteExec_Hardening_Plan.md` §6). Re-verify on each AIR/TOWER PR.

| Endpoint | S0 | S1 | S2 | S3 | S4 | S5 | JIP | Last verified | Notes |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|---|---|
| `ARC_fnc_airbaseSubmitClearanceRequest` | ✅ | ✅ | ✅ | ✅ | ? | ? | 0 | 2026-04-07 | S4/S5 not formally re-verified in this ledger. |
| `ARC_fnc_airbaseRequestClearanceDecision` | ✅ | ✅ | ✅ | ✅ | ? | ? | 0 | 2026-04-07 | |
| `ARC_fnc_airbaseRequestPrioritizeFlight` | ✅ | ✅ | ✅ | ✅ | ? | ? | 0 | 2026-04-07 | |
| `ARC_fnc_airbaseCancelClearanceRequest` | ✅ | ✅ | ✅ | n/a | ? | ? | 0 | 2026-04-07 | Self-cancel. |
| `ARC_fnc_airbaseRequestCancelQueuedFlight` | ✅ | ✅ | ✅ | ✅ | ? | ? | 0 | 2026-04-07 | Tower authority. |
| `ARC_fnc_airbaseMarkClearanceEmergency` | ✅ | ✅ | ✅ | n/a | ? | ? | 0 | 2026-04-07 | |
| `ARC_fnc_airbaseRequestSetLaneStaffing` | ✅ | ✅ | ✅ | ✅ | ? | ? | 0 | 2026-04-07 | |
| `ARC_fnc_airbaseRequestHoldDepartures` | ✅ | ✅ | ✅ | ✅ | n/a | ? | 0 | 2026-04-07 | |
| `ARC_fnc_airbaseRequestReleaseDepartures` | ✅ | ✅ | ✅ | ✅ | n/a | ? | 0 | 2026-04-07 | |
| `ARC_fnc_tocRequestAirbaseResetControlState` | ✅ | ✅ | ✅ | ✅ | n/a | ? | 0 | 2026-04-07 | Admin reset. |

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

1. Pick a section (3.1 – 3.5, 4, 5).
2. For each endpoint, open the implementing function and confirm the corresponding check.
3. Record `✅ / ⚠️ / ❌ / n/a` plus the audit date or short SHA in **Last verified**.
4. For any `❌` or `⚠️`, open a Mode I PR with the remediation; reference this matrix in the PR description.
5. Update `tests/TEST-LOG.md` with the pass result (PASS / FAIL / BLOCKED) and link.

---

## 7) Out-of-scope for this ledger

- New endpoint additions (covered by `RemoteExec_Hardening_Plan.md` §2 + `CfgRemoteExec.hpp` review).
- Allowlist mode changes (`mode` / `jip` defaults) — those are policy changes belonging in the hardening plan.
- Client-local function refactors that do not change the RPC surface.

---

## Change log

### v1.0 — 2026-05-08
- Initial scaffold derived from `RemoteExec_Hardening_Plan.md`. All client→server entries seeded with `?` except AIR/TOWER (verified 2026-04-07). Server→client entries seeded from §1.2 of the hardening plan with JIP intent preserved.

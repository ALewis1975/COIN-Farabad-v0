# RemoteExec Hardening Plan

## Purpose
This document inventories current RemoteExec usage and defines a hardening plan for `CfgRemoteExec`, sender validation, and JIP behavior.

---

## 1) Full RPC endpoint inventory

### 1.1 Client → Server (`target = 2`) ARC RPC endpoints

These are the highest-risk endpoints because any connected client can attempt to invoke them.

| Endpoint | Typical caller(s) | Notes |
|---|---|---|
| `ARC_fnc_civsubContactReqAction` | CIVSUB contact dialog | Player action request (question/check-id/background/detain/release/etc.). |
| `ARC_fnc_civsubContactReqSnapshot` | CIVSUB contact dialog open/load | Pulls server snapshot for selected civilian. |
| `ARC_fnc_civsubInteractCheckPapers` | ACE interaction | Server-validated paperwork check flow. |
| `ARC_fnc_civsubInteractDetain` | ACE interaction | Server-side detain state mutation. |
| `ARC_fnc_civsubInteractEndSession` | Contact dialog unload | Session close + cleanup. |
| `ARC_fnc_civsubInteractHandoffSheriff` | ACE interaction | Custody handoff state mutation. |
| `ARC_fnc_civsubInteractOrderStop` | Contact actions | Movement/control command for civ. |
| `ARC_fnc_civsubInteractRelease` | ACE interaction | Release detainee flow. |
| `ARC_fnc_civsubInteractShowPapers` | ACE interaction | Identity presentation request. |
| `ARC_fnc_civsubRunMdtByNetId` | TOC UI action | Lookup workflow by target netId. |
| `ARC_fnc_devCompileAuditServer` | HQ UI dev tool | Dev/admin server audit execution. |
| `ARC_fnc_execObjectiveComplete` | Objective/IED interactions | Completes objective stages on server. |
| `ARC_fnc_iedCollectEvidence` | Evidence action | Collect evidence item by netId. |
| `ARC_fnc_iedServerDetonate` | IED disposition action | Server detonation of IED. |
| `ARC_fnc_intelOrderAccept` | TOC/field UI | Accept active order. |
| `ARC_fnc_intelOrderCompleteRtbEpw` | Field UI / station action | Completes EPW RTB order. |
| `ARC_fnc_intelOrderCompleteRtbIntel` | Field UI / station action | Completes intel debrief RTB order. |
| `ARC_fnc_intelQueueDecide` | TOC queue manager | Approve/reject queued requests. |
| `ARC_fnc_intelQueueSubmit` | Field lead/follow-on UI | Submits queue request payloads. |
| `ARC_fnc_intelTocIssueOrder` | TOC issue order prompt | Issues order from TOC to unit. |
| `ARC_fnc_publicBroadcastState` | HQ UI | Re-broadcast public state snapshot. |
| `ARC_fnc_tocReceiveSitrep` | SITREP submit UI | Primary SITREP ingress endpoint. |
| `ARC_fnc_tocRequestAcceptIncident` | TOC/field UI | Accept current incident tasking. |
| `ARC_fnc_tocRequestCivsubReset` | HQ UI | Admin reset CIVSUB state. |
| `ARC_fnc_tocRequestCivsubSave` | HQ UI | Admin save CIVSUB state. |
| `ARC_fnc_tocRequestCloseIncident` | TOC/HQ UI | Close incident with result code. |
| `ARC_fnc_tocRequestCloseoutAndOrder` | Closeout dialog | Combined closeout + follow-on request. |
| `ARC_fnc_tocRequestForceIncident` | HQ UI | Force-spawn specific incident. |
| `ARC_fnc_tocRequestLogIntel` | Intel logging UI | Manual intel log ingestion. |
| `ARC_fnc_tocRequestNextIncident` | TOC UI | Request next incident from queue. |
| `ARC_fnc_tocRequestRebuildActive` | HQ UI | Rebuild active incident state. |
| `ARC_fnc_tocRequestRefreshIntel` | Intel/TOC UI | Refresh intel feed/state. |
| `ARC_fnc_tocRequestResetAll` | HQ UI | Full admin reset. |
| `ARC_fnc_tocRequestSave` | HQ UI | Save operation trigger. |
| `ARC_fnc_uiConsoleQAAuditServer` | HQ UI QA tool | Server-side QA audit runner. |
| `ARC_fnc_uiCoverageAuditServer` | HQ UI QA tool | Coverage/audit scan runner. |
| `ARC_fnc_vbiedServerDetonate` | VBIED disposition action | Server detonation of VBIED. |

### 1.2 Server → Client ARC RPC endpoints

| Endpoint | Delivery type | JIP intent today |
|---|---|---|
| `ARC_fnc_airbaseDiaryUpdate` | Broadcast/targeted UI text | Non-JIP (live update). |
| `ARC_fnc_briefingHardResetClient` | Broadcast | Non-JIP reset pulse. |
| `ARC_fnc_civsubCivAddAceActions` | Object-bound broadcast | JIP via object key (`_unit`). |
| `ARC_fnc_civsubCivAddContactActions` | Object-bound broadcast | JIP via object key (`_unit`). |
| `ARC_fnc_civsubClientMessage` | Targeted client | Non-JIP ephemeral. |
| `ARC_fnc_civsubClientShowIdCard` | Targeted client | Non-JIP ephemeral. |
| `ARC_fnc_civsubContactClientReceiveResult` | Targeted client | Non-JIP request/response. |
| `ARC_fnc_civsubContactClientReceiveSnapshot` | Targeted client | Non-JIP request/response. |
| `ARC_fnc_clientAddObjectiveAction` | Broadcast | JIP=true (late joiners need action). |
| `ARC_fnc_clientHint` | Targeted client | Non-JIP ephemeral hint. |
| `ARC_fnc_clientPurgeArcTasks` | Broadcast | Non-JIP reset pulse. |
| `ARC_fnc_clientSetCurrentTask` | Broadcast/targeted | Non-JIP live assignment. |
| `ARC_fnc_clientToast` | Broadcast/targeted | Non-JIP ephemeral toast. |
| `ARC_fnc_iedClientAddEvidenceAction` | Broadcast | JIP=true (late joiners need action). |
| `ARC_fnc_iedClientEnableEvidenceLogistics` | Broadcast | JIP=true (late joiners need carry/drag flags). |
| `ARC_fnc_intelClientNotify` | Targeted | Non-JIP ephemeral notify. |
| `ARC_fnc_tocInitPlayer` | Broadcast from bootstrap | Non-JIP (player init should use join hook). |
| `ARC_fnc_uiConsoleCompileAuditClientReceive` | Targeted | Non-JIP request/response. |
| `ARC_fnc_uiConsoleQAAuditClientReceive` | Targeted | Non-JIP request/response. |

### 1.3 Non-ARC / engine command remoteExec targets in repository

These are also part of the executable RemoteExec surface and must be explicitly considered in `CfgRemoteExec`:

- `BIS_fnc_holdActionAdd`
- `BIS_fnc_holdActionRemove`
- `call` (high risk; should be removed or heavily constrained)
- `disableAI`
- `enableAudioFeature`
- `forceWalk`
- `limitSpeed`
- `playMoveNow`
- `setPhysicsCollisionFlag`
- `setPilotLight`
- `setUnitTrait`
- `switchMove`
- `systemChat`

---

## 2) Proposed `CfgRemoteExec` allowlist entries

### 2.1 Policy baseline

```sqf
class CfgRemoteExec
{
    class Functions
    {
        mode = 1;   // whitelist only
        jip = 0;    // deny JIP by default unless explicitly enabled

        // ... explicit ARC_fnc_* entries below
    };

    class Commands
    {
        mode = 1;   // whitelist only
        jip = 0;

        // ... explicit command/function command entries below
    };
};
```

### 2.2 Functions allowlist (recommended)

1. **Allow (JIP=0)** all client→server RPC endpoints listed in **1.1**.
2. **Allow (JIP=0)** targeted/ephemeral server→client endpoints in **1.2**.
3. **Allow (JIP=1)** only persistent late-join critical endpoints:
   - `ARC_fnc_clientAddObjectiveAction`
   - `ARC_fnc_iedClientAddEvidenceAction`
   - `ARC_fnc_iedClientEnableEvidenceLogistics`
   - `ARC_fnc_civsubCivAddContactActions` (object-keyed)
   - `ARC_fnc_civsubCivAddAceActions` (object-keyed)
4. **Do not allow** arbitrary utility/dev function execution on clients by default.

### 2.3 Commands allowlist (recommended)

Allow only the specific non-ARC targets currently required by mission/editor logic:

- `BIS_fnc_holdActionAdd` (JIP as needed by object-bound hold actions)
- `BIS_fnc_holdActionRemove`
- `disableAI`
- `enableAudioFeature`
- `forceWalk`
- `limitSpeed`
- `playMoveNow`
- `setPhysicsCollisionFlag`
- `setPilotLight`
- `setUnitTrait`
- `switchMove`
- `systemChat`

**Explicitly disallow** `call` if at all possible (replace with named function wrapper). Dynamic `remoteExec ["call", ...]` materially increases exploitability.

---

## 3) Required sender validation checks per endpoint

For each client→server endpoint in **1.1**, enforce (or keep enforcing) the following minimum checks.

### Legend
- **S0**: `if (!isServer) exitWith {};`
- **S1**: Sender-object bind (`ARC_fnc_rpcValidateSender` or exact equivalent owner match check).
- **S2**: Type/shape validation of all params (including enum/value whitelists).
- **S3**: Authorization check (TOC/HQ/approver role gates where applicable).
- **S4**: World-state/locality invariants (distance, object alive, netId resolves, current incident/order state).
- **S5**: Rate-limit/idempotency + structured security logging.

| Endpoint | Required checks |
|---|---|
| `ARC_fnc_civsubContactReqAction` | S0, S1, S2, S4, S5 |
| `ARC_fnc_civsubContactReqSnapshot` | S0, S1, S2, S4, S5 |
| `ARC_fnc_civsubInteractCheckPapers` | S0, S1, S2, S4, S5 |
| `ARC_fnc_civsubInteractDetain` | S0, S1, S2, S4, S5 |
| `ARC_fnc_civsubInteractEndSession` | S0, S1, S2, S4, S5 |
| `ARC_fnc_civsubInteractHandoffSheriff` | S0, S1, S2, S4, S5 |
| `ARC_fnc_civsubInteractOrderStop` | S0, S1, S2, S4, S5 |
| `ARC_fnc_civsubInteractRelease` | S0, S1, S2, S4, S5 |
| `ARC_fnc_civsubInteractShowPapers` | S0, S1, S2, S4, S5 |
| `ARC_fnc_civsubRunMdtByNetId` | S0, S1, S2, S3, S4, S5 |
| `ARC_fnc_devCompileAuditServer` | S0, S1, S2, S3, S5 |
| `ARC_fnc_execObjectiveComplete` | S0, S1, S2, S4, S5 |
| `ARC_fnc_iedCollectEvidence` | S0, S1, S2, S4, S5 |
| `ARC_fnc_iedServerDetonate` | S0, S1, S2, S3, S4, S5 |
| `ARC_fnc_intelOrderAccept` | S0, S1, S2, S4, S5 |
| `ARC_fnc_intelOrderCompleteRtbEpw` | S0, S1, S2, S4, S5 |
| `ARC_fnc_intelOrderCompleteRtbIntel` | S0, S1, S2, S4, S5 |
| `ARC_fnc_intelQueueDecide` | S0, S1, S2, S3, S4, S5 |
| `ARC_fnc_intelQueueSubmit` | S0, S1, S2, S4, S5 |
| `ARC_fnc_intelTocIssueOrder` | S0, S1, S2, S3, S4, S5 |
| `ARC_fnc_publicBroadcastState` | S0, S1, S2, S3, S5 |
| `ARC_fnc_tocReceiveSitrep` | S0, S1, S2, S4, S5 |
| `ARC_fnc_tocRequestAcceptIncident` | S0, S1, S2, S4, S5 |
| `ARC_fnc_tocRequestCivsubReset` | S0, S1, S2, S3, S5 |
| `ARC_fnc_tocRequestCivsubSave` | S0, S1, S2, S3, S5 |
| `ARC_fnc_tocRequestCloseIncident` | S0, S1, S2, S3, S4, S5 |
| `ARC_fnc_tocRequestCloseoutAndOrder` | S0, S1, S2, S3, S4, S5 |
| `ARC_fnc_tocRequestForceIncident` | S0, S1, S2, S3, S4, S5 |
| `ARC_fnc_tocRequestLogIntel` | S0, S1, S2, S4, S5 |
| `ARC_fnc_tocRequestNextIncident` | S0, S1, S2, S4, S5 |
| `ARC_fnc_tocRequestRebuildActive` | S0, S1, S2, S3, S4, S5 |
| `ARC_fnc_tocRequestRefreshIntel` | S0, S1, S2, S3, S4, S5 |
| `ARC_fnc_tocRequestResetAll` | S0, S1, S2, S3, S5 |
| `ARC_fnc_tocRequestSave` | S0, S1, S2, S3, S5 |
| `ARC_fnc_uiConsoleQAAuditServer` | S0, S1, S2, S3, S5 |
| `ARC_fnc_uiCoverageAuditServer` | S0, S1, S2, S3, S5 |
| `ARC_fnc_vbiedServerDetonate` | S0, S1, S2, S3, S4, S5 |

Implementation note: standardize all S1 gates to `ARC_fnc_rpcValidateSender` for consistency, then layer endpoint-specific checks.

---

## 4) JIP behavior expectations and risks

### 4.1 Expected JIP behavior

1. **Only persistent state reconstruction RPCs should use JIP.**
   - Objective actions, evidence actions, and civ interaction action attachments are valid JIP candidates.
2. **Ephemeral UX signals should not use JIP.**
   - Toasts/hints/one-shot result notifications should remain non-JIP.
3. **Client init should be deterministic without relying on JIP replay of transient events.**
   - Prefer explicit init/snapshot pull + server authoritative state publication.

### 4.2 Key JIP risks

- **Replay drift:** JIP queue can replay stale actions if object lifecycle changed (deleted/replaced objects).
- **State skew:** Non-idempotent client handlers can double-apply during reconnect/JIP.
- **Privilege leakage:** If admin/debug RPCs are JIP-enabled accidentally, later joiners may receive unintended effects.
- **Bandwidth growth:** Excessive JIP-enabled broadcast RPCs increase join-time load.

### 4.3 Mitigations

- Keep JIP allowlist minimal and object-keyed where possible.
- Ensure all JIP handlers are idempotent (safe reapply).
- Add object existence/type guards before client-side action registration.
- Add regression tests for: fresh join, reconnect, and join-after-reset cases.

---

## 5) Rollout sequence (recommended)

1. Add `CfgRemoteExec` whitelist with explicit `Functions` + `Commands` entries.
2. Enable only required JIP entries from section 2.2.
3. Normalize sender validation (S1) across all section 1.1 endpoints.
4. Add denied-call telemetry counters and review logs in multiplayer test sessions.
5. Run dedicated server smoke tests with at least one JIP client.

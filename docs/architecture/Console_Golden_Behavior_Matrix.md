# Console Golden Behavior Matrix

This matrix defines the **golden (must-hold) behavior** for Console SITREP eligibility, OPS secondary control behavior, and closeout/ACK gating in the current branch.

---

## 1) SITREP eligibility by incident type and phase

### Behavior matrix

| Incident type | Phase / state | SITREP allowed? | Rule source |
|---|---|---:|---|
| `IED` | Accepted + not yet close-ready | ✅ Yes | Server allows IED exception to close-ready requirement. |
| `IED` | Accepted + close-ready | ✅ Yes | Normal close-ready path also applies. |
| Non-`IED` | Accepted + not yet close-ready | ❌ No | Server rejects SITREP until close-ready. |
| Non-`IED` | Accepted + close-ready | ✅ Yes | Required path for closure SITREP. |
| Any | Not accepted | ❌ No | Active incident must be accepted first. |
| Any | SITREP already sent | ❌ No | One SITREP per incident. |
| Any | Unauthorized role | ❌ No | Role gate enforced on server and client helper. |
| Any | Outside SITREP proximity anchors | ❌ No | Proximity check required against incident/objective/convoy anchors. |

### Acceptance statements + verification commands

1. **Pass condition:** IED is explicitly exempt from close-ready gating during SITREP submit.  
   **Fail condition:** No explicit IED exception exists in server SITREP gate.  
   **Verify:**
   ```bash
   rg -n "if \(!_updateOnly && \{ !_closeReady \} && \{ _tU isNotEqualTo \"IED\" \}\) exitWith" functions/core/fn_tocReceiveSitrep.sqf
   ```

2. **Pass condition:** Non-IED SITREP is rejected when not close-ready.  
   **Fail condition:** Rejection path/message is absent.  
   **Verify:**
   ```bash
   rg -n "SITREP rejected: incident still in progress" functions/core/fn_tocReceiveSitrep.sqf
   ```

3. **Pass condition:** Incident must be accepted before SITREP submission.  
   **Fail condition:** No accepted-state guard exists.  
   **Verify:**
   ```bash
   rg -n "activeIncidentAccepted|if \(!_accepted\) exitWith" functions/core/fn_tocReceiveSitrep.sqf
   ```

4. **Pass condition:** Duplicate SITREPs are blocked (one per incident).  
   **Fail condition:** No `activeIncidentSitrepSent` guard exists.  
   **Verify:**
   ```bash
   rg -n "One SITREP per incident|activeIncidentSitrepSent|if \(_alreadySent\) exitWith" functions/core/fn_tocReceiveSitrep.sqf
   ```

5. **Pass condition:** Role authorization is required for SITREP.  
   **Fail condition:** No role check in server SITREP handler.  
   **Verify:**
   ```bash
   rg -n "rolesIsAuthorized|Rejecting SITREP from unauthorized role" functions/core/fn_tocReceiveSitrep.sqf
   ```

6. **Pass condition:** Proximity to SITREP anchors is required.  
   **Fail condition:** No distance/anchor rejection path exists.  
   **Verify:**
   ```bash
   rg -n "Proximity enforcement|SITREP rejected: you must be within|distance2D" functions/core/fn_tocReceiveSitrep.sqf
   ```

---

## 2) OPS tab secondary-control text/state rules

### Behavior matrix

| Context in OPS tab | Secondary button label | Secondary enabled | Click behavior |
|---|---|---:|---|
| Default / non-IED | `FOLLOW-ON (SITREP)` | ❌ Disabled | Click path routes to follow-on action, which toasts that follow-on is collected in SITREP flow. |
| `IED` + SITREP not sent | `EOD DISPO` | ✅ Enabled for authorized role | Opens EOD disposition request action. |
| `IED` + SITREP already sent | `FOLLOW-ON (SITREP)` | ❌ Disabled | Follow-on is informational-only via SITREP flow; no standalone path. |
| No selection | `FOLLOW-ON (SITREP)` | ❌ Disabled | Details pane explains follow-on is captured inside SITREP flow. |

### Acceptance statements + verification commands

1. **Pass condition:** OPS secondary defaults to `FOLLOW-ON (SITREP)` and disabled.  
   **Fail condition:** Different default label/state in OPS painter.  
   **Verify:**
   ```bash
   rg -n "_followOnViaSitrepLabel|_secondaryLabel = _followOnViaSitrepLabel|_secondaryEnabled = false" functions/ui/fn_uiConsoleOpsPaint.sqf
   ```

2. **Pass condition:** IED + unsent SITREP switches secondary to `EOD DISPO` and enables for authorized users.  
   **Fail condition:** No IED override for label/state.  
   **Verify:**
   ```bash
   rg -n "if \(_typU isEqualTo \"IED\"\) then|_secondaryLabel = \"EOD DISPO\"|_secondaryEnabled = _isAuth" functions/ui/fn_uiConsoleOpsPaint.sqf
   ```

3. **Pass condition:** OPS click-secondary dispatches EOD action only for IED + unsent SITREP, otherwise follow-on action.  
   **Fail condition:** Dispatch condition differs from IED/unsent split.  
   **Verify:**
   ```bash
   rg -n "case \"OPS\"|ARC_fnc_uiConsoleActionRequestEodDispo|ARC_fnc_uiConsoleActionRequestFollowOn|_typ|_sit" functions/ui/fn_uiConsoleClickSecondary.sqf
   ```

4. **Pass condition:** Standalone follow-on action is intentionally blocked and replaced by SITREP-flow guidance toast.  
   **Fail condition:** Follow-on still performs legacy prompt/request path.  
   **Verify:**
   ```bash
   rg -n "UI11\+ workflow change|if \(true\) exitWith|Follow-on requests are now collected as part of the SITREP submission flow" functions/ui/fn_uiConsoleActionRequestFollowOn.sqf
   ```

---

## 3) Closeout gating and ACK expectations

### Behavior matrix

| Stage | Required condition | Outcome |
|---|---|---|
| TOC closeout request entry | Active incident already has SITREP (`activeIncidentSitrepSent=true`) | Without SITREP, closeout is denied. |
| Immediate path (`ARC_policy_noAutoOrdersOnCloseout=true`) | SITREP present + TOC authorized | Incident closes immediately; follow-on package queued to TOC queue; no order ACK gate. |
| Staged path (`ARC_policy_noAutoOrdersOnCloseout=false`) | SITREP present + TOC authorized + order issued/reused | Sets `activeIncidentClosePending*`; incident remains open awaiting unit order acceptance. |
| Unit ACK on staged path | Accepted order matches pending group/order wildcard rules | Acceptance triggers `ARC_fnc_incidentClose` with pending result. |
| Unit ACK mismatch on staged path | Accepted order does not match pending group/order | No close trigger fires. |

### Acceptance statements + verification commands

1. **Pass condition:** Closeout is denied when SITREP has not been received.  
   **Fail condition:** No SITREP precondition before closeout path.  
   **Verify:**
   ```bash
   rg -n "Require SITREP for the active incident|Closeout denied: SITREP not received yet" functions/core/fn_tocRequestCloseoutAndOrder.sqf
   ```

2. **Pass condition:** Immediate close branch exists and explicitly bypasses order acceptance gating.  
   **Fail condition:** Immediate branch absent or still staged.  
   **Verify:**
   ```bash
   rg -n "BRANCH=IMMEDIATE|close now|no order acceptance gate|Follow-on package queued" functions/core/fn_tocRequestCloseoutAndOrder.sqf
   ```

3. **Pass condition:** Staged close branch arms `activeIncidentClosePending*` and declares wait-for-acceptance semantics.  
   **Fail condition:** Pending flags or acceptance wait language absent.  
   **Verify:**
   ```bash
   rg -n "activeIncidentClosePending|Awaiting unit acceptance|BRANCH=STAGED" functions/core/fn_tocRequestCloseoutAndOrder.sqf
   ```

4. **Pass condition:** Order acceptance contains closeout-pending hook and closes incident only on group/order match.  
   **Fail condition:** Acceptance always closes or never checks pending metadata.  
   **Verify:**
   ```bash
   rg -n "Closeout pending hook|_matchGroup|_matchOrder|ARC_fnc_incidentClose" functions/command/fn_intelOrderAccept.sqf
   ```

5. **Pass condition:** Order acceptance persists ACK metadata (`acceptedAt`, `acceptedBy`, `acceptedByUID`) before closeout hook.  
   **Fail condition:** ACK metadata not written.  
   **Verify:**
   ```bash
   rg -n "acceptedAt|acceptedBy|acceptedByUID|_ord set \[2, \"ACCEPTED\"\]" functions/command/fn_intelOrderAccept.sqf
   ```

---

## Operational note

This document is intentionally executable as a regression checklist: every acceptance statement has a directly runnable `rg` command to validate source-level conformance.

# EPIC 2 — TOC/Admin RPC Validation Consistency (Audit Update)

## Scope
- functions/core/fn_tocRequestRefreshIntel.sqf
- functions/core/fn_tocRequestSave.sqf
- functions/core/fn_tocRequestResetAll.sqf
- functions/core/fn_tocRequestShowLeads.sqf
- functions/core/fn_tocRequestCivsubSave.sqf
- functions/core/fn_tocRequestCivsubReset.sqf

## Consistency updates applied
1. Added lazy compile guard for `ARC_fnc_rpcValidateSender` in all scoped handlers.
2. Added/normalized optional explicit caller param (`_caller` / `_requester`) in all scoped handlers.
3. Normalized remote caller resolution flow:
   - prefer explicit caller object
   - fallback map from `remoteExecutedOwner` when owner ID is valid
4. Added shared sender validation gate calls with explicit security event codes:
   - `TOC_REFRESH_INTEL_SECURITY_DENIED`
   - `TOC_SAVE_SECURITY_DENIED`
   - `TOC_RESET_ALL_SECURITY_DENIED`
   - `TOC_SHOW_LEADS_SECURITY_DENIED`
   - `TOC_CIVSUB_SAVE_SECURITY_DENIED`
   - `TOC_CIVSUB_RESET_SECURITY_DENIED`
5. Preserved existing role authorization behavior and aligned admin tools to approver/OMNI gating on remote path.

## Expected behavior
- Dedicated/remote path: request is rejected if network sender and caller object do not match.
- Privileged/admin tools (`save/reset/show leads/civsub save/civsub reset`) require authorized TOC/OMNI permissions when invoked remotely.
- Local/server path remains operational for controlled server-side tooling.

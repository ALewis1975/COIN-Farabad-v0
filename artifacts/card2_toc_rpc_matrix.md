# EPIC 2 — TOC/Admin RPC Validation Consistency

## Scope
- functions/core/fn_tocRequestRefreshIntel.sqf
- functions/core/fn_tocRequestSave.sqf
- functions/core/fn_tocRequestResetAll.sqf

## Consistency updates applied
1. Added lazy compile guard for `ARC_fnc_rpcValidateSender` in all 3 handlers.
2. Added optional explicit caller param (`_caller`) to all 3 handlers.
3. Normalized remote caller resolution flow:
   - prefer explicit caller
   - fallback map from `remoteExecutedOwner` when remote owner > 0
4. Added shared sender validation gate per handler with explicit security event codes:
   - `TOC_REFRESH_INTEL_SECURITY_DENIED`
   - `TOC_SAVE_SECURITY_DENIED`
   - `TOC_RESET_ALL_SECURITY_DENIED`
5. Kept existing role authorization gates intact after sender validation.

## Expected behavior
- Dedicated/remote path: request is rejected if network sender and caller object do not match.
- Local/server path: existing admin role checks still gate privileged actions.

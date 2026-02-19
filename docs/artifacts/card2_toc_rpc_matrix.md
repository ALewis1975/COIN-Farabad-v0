# EPIC 2 — TOC/Admin RPC Validation Consistency (Audit Update)

## Scope
- functions/core/fn_tocRequestRefreshIntel.sqf
- functions/core/fn_tocRequestSave.sqf
- functions/core/fn_tocRequestResetAll.sqf
- functions/core/fn_tocRequestShowLeads.sqf
- functions/core/fn_tocRequestCivsubSave.sqf
- functions/core/fn_tocRequestCivsubReset.sqf

## Server RPC inventory slice (CfgFunctions + handlers)
- `ARC_fnc_tocRequestAirbaseResetControlState` → `functions/core/fn_tocRequestAirbaseResetControlState.sqf`
- `ARC_fnc_tocRequestCloseoutAndOrder` → `functions/core/fn_tocRequestCloseoutAndOrder.sqf`
- `ARC_fnc_tocRequestCivsubSave` → `functions/core/fn_tocRequestCivsubSave.sqf`
- `ARC_fnc_tocRequestCivsubReset` → `functions/core/fn_tocRequestCivsubReset.sqf`

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


## Standard server RPC validation sequence
1. **Param/type checks**
   - Parse with typed `params` defaults.
   - Normalize/fallback values for compatibility, but log denials for malformed remote input.
2. **Caller identity + role checks**
   - Resolve caller from explicit object first, then `remoteExecutedOwner` fallback.
   - Enforce `ARC_fnc_rpcValidateSender` for remote paths and run role gates (`rolesCanApproveQueue` / `OMNI`) before mutation.
3. **Domain invariants**
   - Verify subsystem toggles and runtime prerequisites (example: `civsub_v1_enabled`, active SITREP/context).
4. **Early return + structured denial log**
   - On each denial, emit `ARC_fnc_intelLog` with `event`, `rpc`, `reason`, owner, and caller metadata, then return `false`.

### Outlier handlers hardened first (AIR/CMD/CIVSUB)
- `ARC_fnc_tocRequestAirbaseResetControlState` (AIR)
- `ARC_fnc_tocRequestCloseoutAndOrder` (CMD)
- `ARC_fnc_tocRequestCivsubSave` (CIVSUB)
- `ARC_fnc_tocRequestCivsubReset` (CIVSUB)

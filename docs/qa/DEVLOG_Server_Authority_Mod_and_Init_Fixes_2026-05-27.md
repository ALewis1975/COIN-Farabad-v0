# Server Authority, Mod, and Init Fixes: Civilians, Task & Airbase Systems

## Scope and audit boundary

- Audited mission-owned SQF/config files in this repository for authority/init issues:
  - `initServer.sqf`
  - `functions/core/fn_bootstrapServer.sqf`
  - `functions/core/fn_taskCreateIncident.sqf`
  - `functions/ambiance/fn_airbasePostInit.sqf`
  - `functions/ambiance/fn_airbaseInit.sqf`
  - `functions/civsub/fn_civsubCivSamplerTick.sqf`
  - `functions/civsub/fn_civsubCivCleanupTick.sqf`
  - `functions/civsub/fn_civsubCivSpawnInDistrict.sqf`
  - `functions/civsub/fn_civsubCivDespawnUnit.sqf`
- Audited mission dependency declaration source in `mission.sqm` (`addons[]` + `AddonsMetaData`).
- Did **not** modify any 3rd-party mod files (outside mission repo control).

## What was fixed in-repo

1. **Server authority hardening (civilian/task/airbase):**
   - Added/strengthened explicit guard-path logging for non-server execution attempts.
   - Ensured civilian spawn failure bookkeeping writes mission state only on server.
   - Added server guard to `ARC_fnc_taskCreateIncident` to prevent non-server task mutation.

2. **Civilian spawn/despawn debug visibility:**
   - Added `diag_log` lifecycle breadcrumbs for:
     - successful CIVSUB spawn
     - successful CIVSUB despawn
     - sampler/cleanup guard failures
     - spawn guard/failure paths

3. **Task/Airbase init trigger visibility:**
   - Added structured `diag_log` start/post logs in bootstrap/init trigger points:
     - task rehydrate + exec-init bootstrap status
     - airbase init trigger in `initServer.sqf`
     - airbase post-init start/guard/post status
     - airbase init start/guard/post status

## Config/script error findings from provided server RPT

The reported `Missing ';'` config parse errors are in external mod content, not mission files:

- `Expansion_Mod_Police\vehicles\config.cpp` line 3270
- `Expansion_Mod_Police\fatigues\config.cpp` lines 121, 139

These must be fixed in the mod package/version on the server/client modset.

## Server admin required actions (out-of-repo)

1. **Fix/replace external mod with config parse errors**
   - Update or remove the broken `Expansion_Mod_Police` build producing missing-semicolon parse errors.

2. **Resolve missing addon dependencies from server modline**
   - RPT shows repeated `Skipped loading of addon ... as required addon ... is not present`.
   - Typical missing families in this RPT include CUP load-order packs, ACRE, Vietnam/SOG load-order, WS/LXWS load-order, GM, CSLA, Aegis, SPE/SPEX, and other ACE compat targets.
   - Align server startup modline with the mission-required mod stack and keep compat packs only when their parent mods are loaded.

3. **Mission dependency declaration source of truth**
   - Keep `mission.sqm` `addons[]` entries satisfiable by server+client load order.
   - If optional compat mods are intentionally omitted, remove corresponding compat packs from launch parameters to reduce RPT noise and startup skips.

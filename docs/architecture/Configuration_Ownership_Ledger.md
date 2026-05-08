# Configuration Ownership Ledger

**Version:** 1.0
**Date:** 2026-05-08
**Status:** Active. Wave 7-T1 deliverable of `docs/architecture/Architecture_Plan_2026-05-08.md` (R5 mitigation).
**Mode:** F — Documentation-Only Changes
**Companions:**
- `initServer.sqf` (current home for most operator-visible variables).
- `data/ARC_ConfigData.sqf` (preferred home for tuning constants and class pools).
- `functions/core/fn_operatorToggleAuditStartup.sqf` + `ARC_operatorToggleAuditCatalog` (curated posture-toggle audit).

---

## 1) Purpose

Architecture Plan §3 requires every operator-visible variable in `initServer.sqf` to be classified into one of four classes, each with a documented target home. This ledger is that classification.

Without this ledger, `initServer.sqf` continues to absorb everything (subsystem flags, tuning constants, class pools, debug overrides, runtime caches), which is the R5 risk in Architecture Plan §1.3.

Hard rule (Architecture Plan §3): when adding a new operator toggle, also add a startup-audit entry in `ARC_operatorToggleAuditCatalog` so RPT operators can confirm it took effect. **No silent toggles.**

---

## 2) Classification scheme

Per Architecture Plan §3:

| Class | Examples | Target home |
|---|---|---|
| **Posture toggle** | `ARC_safeModeEnabled`, `ARC_profile_devMode`, `civsub_v1_enabled`, `civsub_v1_civs_enabled`, `airbase_v1_ambiance_enabled` | `initServer.sqf` (kept; surfaced through `ARC_operatorToggleAuditCatalog`). |
| **Subsystem tuning constant** | radius / cooldown / cap / interval values | `data/ARC_ConfigData.sqf` (preferred) or subsystem-owned `*Init` function. |
| **Class pool / classname registry** | IED / VBIED / civ / patrol pools | `data/ARC_ConfigData.sqf` or subsystem `*Init` builders. |
| **Runtime-derived state** | `ARC_pub_*`, derived caches (`ARC_bridgeMarkers`, etc.) | Computed by core / subsystem init at bootstrap; not authored as a constant in `initServer.sqf`. |

A variable that fits more than one class is classified by its **operator-facing intent**: if operators flip it on/off to change posture, it's a toggle; if operators tweak a number to tune behavior, it's a tuning constant; otherwise it's a pool or runtime cache.

---

## 3) Section-by-section ledger

`initServer.sqf` is structured into commented section banners. This ledger uses the same banners as the unit of work; `Lines` are approximate at the v1.0 audit pass and should be re-anchored when relocations land.

### 3.1 Build + patch stamps (lines ~11–17)

| Variable | Class | Target home | Notes |
|---|---|---|---|
| `ARC_buildStamp` | Runtime-derived state | Stay in `initServer.sqf` | RPT breadcrumb; updated per build. Not a tuning value. |

### 3.2 Core dev posture / debug toggles (lines ~19–80)

| Variable | Class | Target home | Notes |
|---|---|---|---|
| `ARC_profile_devMode` | Posture toggle | `initServer.sqf` | In audit catalog as profile gate. Already idempotent (`isNil` guard). |
| `ARC_safeModeEnabled` | Posture toggle | `initServer.sqf` | In audit catalog as `SafeMode`. |
| `ARC_debugLogEnabled`, `ARC_debugLogToChat` | Posture toggle (debug) | `initServer.sqf` | Server-authoritative debug flags; explicitly listed in `_arcDeclaredServerToggles` hygiene array. |
| `ARC_devDebugInspectorEnabled`, `ARC_debugInspectorEnabled` | Posture toggle (debug) | `initServer.sqf` | Inspector diary gate. |
| `FARABAD_log_enabled`, `FARABAD_log_minLevel`, `FARABAD_log_toRPT`, `FARABAD_log_toExtension` | Posture toggle (logger) | `initServer.sqf` | Logger rollout posture. The `FARABAD_` prefix is intentional and pre-existing: the logger is a separate, mod-independent subsystem (see `docs/qa/FARABAD_Logger_Dual_Write_Runbook.md`) whose namespace must remain stable for downstream consumers. Renaming to `ARC_log_*` is **out of scope** for this Mode F PR. Add to `ARC_operatorToggleAuditCatalog` (W7-T3). |

### 3.3 Core dev posture — scaffolding (lines ~84–99)

| Variable | Class | Target home | Notes |
|---|---|---|---|
| `ARC_objectiveScaffoldEnabled`, `ARC_objectiveMeetUseAI` | Posture toggle | `initServer.sqf` | Annotated as "future feature; currently not consumed". Audit-catalog candidates if/when consumed. |
| `ARC_patrolSpawnContactsEnabled` | Posture toggle | `initServer.sqf` | In audit catalog as `MIG`. |

### 3.4 Console VM feature flags (lines ~102–110)

| Variable | Class | Target home | Notes |
|---|---|---|---|
| `ARC_console_ops_v2`, `ARC_console_dashboard_v2` | Posture toggle | `initServer.sqf` | Wave 5 / Phase 3 console migration gates. Add to audit catalog under a `Console` group (W7-T3). |

### 3.5 UI / in-world actions (lines ~112–127)

| Variable | Class | Target home | Notes |
|---|---|---|---|
| `ARC_rtbInWorldActionsEnabled`, `ARC_sitrepInWorldActionsEnabled` | Posture toggle | `initServer.sqf` | In audit catalog as `UI/actions`. |
| `ARC_intelPropSpawnRadiusM` | Tuning constant | `data/ARC_ConfigData.sqf` | Currently surfaced in audit catalog as a `number`, but it is a tuning value, not a posture flip. Acceptable to keep in catalog for operator visibility; relocation is optional (W7-T2 will decide). |
| `ARC_allowIncidentDuringAcceptedRtb` | Posture toggle | `initServer.sqf` | In audit catalog as `MIG`. |

### 3.6 World simulation tuning (lines ~130–169)

| Variable | Class | Target home | Notes |
|---|---|---|---|
| `ARC_worldIndex_weights`, `ARC_worldIndex_tierThresholds` | Tuning constant | `data/ARC_ConfigData.sqf` | Pure tuning numbers; not operator-facing posture. **Relocate (W7-T2).** |
| `ARC_threatVirtualActivationRadiusM*`, `ARC_threatVirtualSpawnRadiusM*`, `ARC_threatVirtualDespawnRadiusM*`, `ARC_threatVirtualDespawnDelayS`, `ARC_threatVirtualRepositionS`, `ARC_threatVirtualPoolTickS`, `ARC_threatVirtualPatrolRadiusM`, `ARC_threatVirtualPatrolWaypointN` | Tuning constant | `data/ARC_ConfigData.sqf` | Twelve threat-pool tuning constants. **Relocate as a single block (W7-T2).** |

### 3.7 OPFOR class pool (lines ~171–191)

| Variable | Class | Target home | Notes |
|---|---|---|---|
| `ARC_opforPatrolUnitClasses` | Class pool | `data/ARC_ConfigData.sqf` | 13-classname pool for 3CB MEI/MEE. **Relocate (W7-T2)** alongside existing `ARC_convoyCarPool` etc. |

### 3.8 CIVSUB v1 (lines ~194–284)

| Variable | Class | Target home | Notes |
|---|---|---|---|
| `civsub_v1_enabled`, `civsub_v1_civs_enabled`, `civsub_v1_persist`, `civsub_v1_scheduler_enabled`, `civsub_v1_rumor_enabled`, `civsub_v1_debug`, `civsub_v1_showPapers_forceCoop`, `civsub_v1_editorTestCivs_pin`, `civsub_v1_civ_classPool_forceRebuild` | Posture toggle | `initServer.sqf` | Subsystem on/off + dev posture. Most are already in audit catalog; verify all coverage in W7-T3. |
| `civsub_v1_seed`, `civsub_v1_tick_s`, `civsub_v1_version`, `civsub_v1_civ_tick_s`, `civsub_v1_civ_cap_*`, `civsub_v1_civ_minSeparation_m`, `civsub_v1_spawn_cache_locRadius_m`, `civsub_v1_civ_preferredFaction`, `civsub_v1_scheduler_s` | Tuning constant | `data/ARC_ConfigData.sqf` or `functions/civsub/fn_civsubInit.sqf` | Pure tuning values. **Relocate (W7-T2).** Subsystem-init is acceptable since they are CIVSUB-only. |
| `civsub_v1_civ_classPool`, `civsub_v1_civ_classPool_cached`, `civsub_v1_civ_classPool_cached_key`, `civsub_v1_editorTestCivs` | Class pool | `data/ARC_ConfigData.sqf` | Civilian classname pools and cached derivatives. **Relocate (W7-T2).** |
| `civsub_v1_civ_cap_overrides` | Class pool / tuning | `data/ARC_ConfigData.sqf` | Per-district override map. |

### 3.9 Airbase v1 + tower posture (lines ~260–284)

| Variable | Class | Target home | Notes |
|---|---|---|---|
| `airbase_v1_tower_allowBnCmd`, `airbase_v1_tower_authDebug` | Posture toggle | `initServer.sqf` | In audit catalog as `Airbase`. |
| `airbase_v1_tower_bnCommandTokens`, `airbase_v1_pilotGroupTokens`, `airbase_v1_tower_ccicTokens`, `airbase_v1_tower_lcTokens` | Class pool (token registry) | `data/ARC_ConfigData.sqf` | Token vocabularies; pure data. **Relocate (W7-T2).** |

### 3.10 CIVTRAF (lines ~286–430)

| Variable | Class | Target home | Notes |
|---|---|---|---|
| `civsub_v1_traffic_enabled`, `civsub_v1_traffic_allow_moving`, `civsub_v1_traffic_deleteWrecks`, `civsub_v1_traffic_debug` | Posture toggle | `initServer.sqf` | `civsub_v1_traffic_enabled` is in audit catalog (under `CIVSUB` and `SafeMode`). The other three should be added (W7-T3). |
| `civsub_v1_traffic_tick_s`, `civsub_v1_traffic_spawn_budget_*`, `civsub_v1_traffic_activeDistrictsMax`, `civsub_v1_traffic_cap_*`, `civsub_v1_traffic_minSeparation_m`, `civsub_v1_traffic_spawnRadius_m`, `civsub_v1_traffic_playerMinDistance_m`, `civsub_v1_traffic_roadside_offset_m`, `civsub_v1_traffic_fallback_*`, `civsub_v1_traffic_preferWeight`, `civsub_v1_traffic_cleanupRadius_m`, `civsub_v1_traffic_cleanupMinDelay_s`, `civsub_v1_traffic_prob_moving`, `civsub_v1_traffic_moving_*` | Tuning constant | `data/ARC_ConfigData.sqf` or `functions/civsub/fn_civsubTrafficInit.sqf` | ~25 traffic tuning numbers. **Relocate (W7-T2)** to `civsubTrafficInit` (already partly seeded there). |
| `civsub_v1_traffic_vehiclePool_prefer`, `civsub_v1_traffic_vehiclePool_fallback`, `civsub_v1_traffic_driverClass` | Class pool | `data/ARC_ConfigData.sqf` | Vehicle / driver classname pools. **Relocate (W7-T2).** |
| `civsub_v1_traffic_spawnAnchors`, `civsub_v1_traffic_exclusions` | Runtime-derived state | `functions/civsub/fn_civsubTrafficInit.sqf` | `spawnAnchors` is `createHashMap` (runtime cache); `exclusions` is built from marker references. Already partly built in `civsubTrafficInit`; collapse so `initServer.sqf` does not pre-seed. |
| `civsub_v1_traffic_dbg_*` (counters), `civsub_v1_traffic_lastMovingSpawnFail` | Runtime-derived state (debug counters) | `functions/civsub/fn_civsubTrafficInit.sqf` | Initialised to 0 / "" at bootstrap; should be reset by traffic init, not pre-seeded in `initServer.sqf`. |
| `ARC_airbase_dynamic_radius_m` | Tuning constant | `data/ARC_ConfigData.sqf` | Drives traffic exclusion radius. Cross-subsystem; safe to keep server-authoritative. |

### 3.11 CIVLOC — location NPCs (lines ~433–469)

| Variable | Class | Target home | Notes |
|---|---|---|---|
| `civsub_v1_locnpc_enabled` | Posture toggle | `initServer.sqf` | Add to audit catalog (W7-T3). |
| `civsub_v1_locnpc_tick_s`, `civsub_v1_locnpc_bubbleRadius_m*`, `civsub_v1_locnpc_cap_global`, `civsub_v1_locnpc_cluster_m` | Tuning constant | `functions/civsub/fn_civsubLocNpcInit.sqf` (subsystem-owned init) | LocNPC-only tuning. **Relocate (W7-T2).** |

### 3.12 IED + detection posture (lines ~470–504)

| Variable | Class | Target home | Notes |
|---|---|---|---|
| `ARC_iedPhase1_siteSelectionEnabled`, `ARC_iedPassiveDetectEnabled`, `ARC_iedScanActionEnabled`, `ARC_iedCompleteActionEnabled`, `ARC_iedSiteAvoidAirbase`, `ARC_iedEvidenceCarryEnabled`, `ARC_iedEvidenceDragEnabled`, `ARC_eodsEnhancementsEnabled` | Posture toggle | `initServer.sqf` | First three are in audit catalog; the rest should be added (W7-T3). |
| `ARC_iedPassiveDetectRadiusM`, `ARC_iedProxRadiusM`, `ARC_iedSiteSearchRadiusM`, `ARC_iedSiteMinSeparationM`, `ARC_iedSitePickTries`, `ARC_iedPhase1_recordsCap`, `ARC_iedEvidenceRoadSearchRadiusM`, `ARC_iedEvidenceCargoSize`, `ARC_eodDispoApprovalTTLsec`, `ARC_eodDisposalRadiusM`, `ARC_eodRtbEvidenceMode` | Tuning constant | `data/ARC_ConfigData.sqf` | IED tuning block. **Relocate (W7-T2).** |
| `ARC_eodDisposalMarkerName` | Tuning constant (string) | `data/ARC_ConfigData.sqf` | Marker name reference. |

### 3.13 VBIED (lines ~505–602)

| Variable | Class | Target home | Notes |
|---|---|---|---|
| `ARC_vbiedPhase3_enabled`, `ARC_vbiedDefuseActionEnabled` | Posture toggle | `initServer.sqf` | In audit catalog as `VBIED`. |
| `ARC_vbiedDefuseWindowSeconds`, `ARC_vbiedCooldownSeconds`, `ARC_vbiedProxRadiusM`, plus other VBIED tuning numbers | Tuning constant | `data/ARC_ConfigData.sqf` | **Relocate (W7-T2).** Already in audit catalog as `number` rows; that membership is operator-visibility, not a relocation block. |

### 3.14 EOD disposal site logistics (lines ~603–613)

| Variable | Class | Target home | Notes |
|---|---|---|---|
| Tuning numbers and marker names in this block | Tuning constant | `data/ARC_ConfigData.sqf` | **Relocate (W7-T2).** |

### 3.15 Local / friendly forces on scene (lines ~614–635)

| Variable | Class | Target home | Notes |
|---|---|---|---|
| `ARC_localSupportEnabled`, `ARC_localSupportPersistInAO`, `ARC_localSupportReuseExisting`, `ARC_localSupportDynamicSimEnabled` | Posture toggle | `initServer.sqf` | Add to audit catalog (W7-T3). |
| `ARC_localSupportEligibleTypes`, `ARC_localSupportGarrisonCount_*`, `ARC_localSupportPatrolCount_*` | Tuning constant / class pool | `data/ARC_ConfigData.sqf` | **Relocate (W7-T2).** |

### 3.16 Task UX + markers (lines ~636–653)

| Variable | Class | Target home | Notes |
|---|---|---|---|
| Marker / UX tuning entries | Tuning constant | `data/ARC_ConfigData.sqf` | **Relocate (W7-T2).** |

### 3.17 Static task compositions (lines ~654–660)

| Variable | Class | Target home | Notes |
|---|---|---|---|
| `ARC_checkpointStaticCompsEnabled` | Posture toggle | `initServer.sqf` | Add to audit catalog (W7-T3). |
| Composition references | Class pool | `data/ARC_ConfigData.sqf` or `data/compositions/*` | **Relocate (W7-T2).** |

### 3.18 Cache scaffolding (lines ~661–743)

| Variable | Class | Target home | Notes |
|---|---|---|---|
| `ARC_cacheScaffoldEnabled` | Posture toggle | `initServer.sqf` | Add to audit catalog (W7-T3). |
| `ARC_cacheContainerCount` | Tuning constant | `data/ARC_ConfigData.sqf` | **Relocate (W7-T2).** |
| `ARC_cacheContainerClassPool` | Class pool | `data/ARC_ConfigData.sqf` | **Relocate (W7-T2).** |

### 3.19 Convoy features (lines ~744–1016)

This is the largest single block in `initServer.sqf` (~270 lines).

| Variable | Class | Target home | Notes |
|---|---|---|---|
| Convoy posture flags (e.g. `ARC_convoyEnforceCrewSide*`, `ARC_convoyVipPassengersEnabled`, `ARC_convoyBridgeAssistEnabled`, `ARC_convoyBridgeAssistFollowersEnabled`) | Posture toggle | `initServer.sqf` | Add to audit catalog under a `Convoy` group (W7-T3). |
| `ARC_convoyPool_*` (Ammo, CAV, Fuel, Government, HQ, MP, Medical, PrivateContractors, PrivateSecurity, Repair, Security, Transport), `ARC_convoyAllowedCrewFactions`, `ARC_convoyAllowedCrewSides`, `ARC_convoyAllowedVehicleFactions`, `ARC_convoyAllowedVehicleSides`, `ARC_convoyBundleClassMatrix`, `ARC_convoyRoleMatrixPoolKeys` | Class pool | `data/ARC_ConfigData.sqf` | Twelve convoy classname pools + matrices. **Relocate (W7-T2).** Existing `ARC_convoyCarPool` is already in `ARC_ConfigData.sqf`; add these alongside. |
| All `ARC_convoy*Sec`, `ARC_convoy*M`, `ARC_convoyVipGuardCount`, follower/bridge tuning numbers | Tuning constant | `data/ARC_ConfigData.sqf` | ~30 convoy tuning numbers. **Relocate (W7-T2).** |

### 3.20 Profile-driven debug overrides (lines ~1017–1033)

| Variable | Class | Target home | Notes |
|---|---|---|---|
| Variables overridden in this block | Posture toggle | `initServer.sqf` | This block is the canonical location for dev-profile-driven posture flips. Keep here. Document in W7-T2 PR that this block does not relocate. |

### 3.21 Operator startup audit catalog (lines ~1034–1134)

| Variable | Class | Target home | Notes |
|---|---|---|---|
| `ARC_operatorToggleAuditCatalog` | Runtime-derived state (curated metadata) | `initServer.sqf` | The catalog itself stays here so it can be edited alongside the toggles it audits. W7-T3 extends it to cover every posture toggle classified above. |
| `ARC_dynamic_tod_allowAirbaseNight`, `ARC_dynamic_tod_allowCivilNight`, `ARC_dynamic_tod_allowOpsNight`, `ARC_dynamic_tod_allowThreatNight` | Posture toggle | `initServer.sqf` | TOD posture flags. Add to audit catalog under a `TOD` group (W7-T3). |
| `ARC_worldTime*` and `ARC_worldTimeEvents_*` | Posture toggle / tuning constant | `initServer.sqf` for posture, `data/ARC_ConfigData.sqf` for intervals | Posture flags already in audit catalog as `WorldTime`. |
| `ARC_routeRecon*` (`MinLengthM`, `EndOffsetM`, `EndRadiusM`, `RoadSnapM`) | Tuning constant | `data/ARC_ConfigData.sqf` | **Relocate (W7-T2).** |

### 3.22 Post-override startup scripts + bootstrap (lines ~1049–1225)

| Variable | Class | Target home | Notes |
|---|---|---|---|
| Anything written after the catalog block | Runtime-derived state | Function call sites (not authored as constants) | These are bootstrap statements and assertions, not configuration. Keep here. |

---

## 4) Summary statistics (current head)

Approximate counts at the v1.0 audit pass (re-anchor when relocations land):

| Class | Count | Action |
|---|---:|---|
| Posture toggle (operator-flippable on/off) | ~55 | **Stay in `initServer.sqf`**; ensure every entry is reflected in `ARC_operatorToggleAuditCatalog` (W7-T3). |
| Subsystem tuning constant | ~110 | **Relocate to `data/ARC_ConfigData.sqf` or subsystem `*Init`** (W7-T2). |
| Class pool / classname registry | ~25 | **Relocate to `data/ARC_ConfigData.sqf`** alongside existing pools (W7-T2). |
| Runtime-derived state (caches, counters, catalog) | ~20 | Move authoring to subsystem `*Init` paths; do not pre-seed in `initServer.sqf`. |
| Build / patch / metadata | ~5 | Stay in `initServer.sqf`. |
| **Total distinct keys in `initServer.sqf`** | **242** at audit time | |

After Wave 7-T2 / Wave 7-T3 land, `initServer.sqf` should retain only the posture-toggle, build-metadata, and dev-profile-override blocks (Architecture Plan §3 phase exit gate).

---

## 5) Open findings

| ID | Status | Description | Recommendation |
|---|:---:|---|---|
| C-OWN-1 | Open (W7-T2) | `civsub_v1_traffic_*` tuning constants are split between `initServer.sqf:291..430` and `functions/civsub/fn_civsubTrafficInit.sqf:23..93`. Two seed paths for the same logical group. | Consolidate into `civsubTrafficInit` (preferred — subsystem-owned). |
| C-OWN-2 | Open (W7-T3) | Audit catalog (`ARC_operatorToggleAuditCatalog`) covers ~30 toggles; this ledger classifies ~55 posture toggles. The delta needs to enter the catalog. | W7-T3 expands the catalog to cover all 55 toggles (groups: `Console`, `Convoy`, `LocalSupport`, `Cache`, `LocNPC`, `TOD`, plus extensions to existing groups). |
| C-OWN-3 | Open (W7-T2) | `ARC_intelPropSpawnRadiusM` is currently surfaced in the audit catalog as a `number`. Tuning values in the catalog are acceptable for operator visibility but blur the toggle/tuning boundary. | Keep in catalog (operator-visible) but relocate the **default** to `data/ARC_ConfigData.sqf`. The catalog row stays. Same pattern applies to other `number`-typed catalog rows. |
| C-OWN-4 | Open (W7-T2) | Eight CIVSUB and twelve airbase tuning constants are currently written with the replicated `true` flag from `initServer.sqf` even though clients only read them as constants. The replicated-flag is correct (clients do read them); the home is the question. | Relocation does not change the replicated-flag — `data/ARC_ConfigData.sqf` already uses `setVariable [..., true]`. |

---

## 6) Update policy

This ledger MUST be updated when any of the following changes:

- A new operator-visible variable is added to `initServer.sqf` (or any of its class peers).
- A variable is relocated from `initServer.sqf` to `data/ARC_ConfigData.sqf` or a subsystem `*Init`.
- The `ARC_operatorToggleAuditCatalog` is expanded with a new group or row.

Process:

1. Open the same Mode F (this ledger) or Mode C (relocation) PR that introduces the change.
2. Update the relevant §3 row(s) and the §4 totals.
3. Bump §7 change log.

---

## 7) Change log

### v1.0 — 2026-05-08
- Initial issuance. Classifies every operator-visible variable currently in `initServer.sqf` (current head, 242 distinct keys, ~1225 lines) per Architecture Plan §3 four-class scheme.
- Identifies relocation targets for ~110 tuning constants and ~25 class pools (Wave 7-T2 work).
- Identifies ~25 posture toggles missing from `ARC_operatorToggleAuditCatalog` (Wave 7-T3 work).
- Truth-status: branch-local. Classification derived from current cloned working branch; not yet `origin/main`-confirmed per `Farabad_Source_of_Truth_and_Workflow_Spec.md`.
- Acceptance criterion (Wave 7-T1): every variable has a class (posture toggle / tuning constant / class pool / runtime-derived) and a target home file.

if (!isServer) exitWith {};

/*
    COIN Farabad - initServer.sqf
    Server-side configuration overrides.

    RULE: Keep all missionNamespace overrides ABOVE ARC_fnc_bootstrapServer so the
    exec/init pipeline reads intended settings on first run.
*/

// ============================================================================
// BUILD + PATCH STAMPS (RPT breadcrumbs)
// ============================================================================

// Update this stamp to match the mission folder you’re running.
missionNamespace setVariable ["ARC_buildStamp", "COIN_Farabad_v0.Farabad-20260217-0001", true];
diag_log format ["[ARC][BUILD] %1", missionNamespace getVariable ["ARC_buildStamp","UNKNOWN"]];

// Debug toggles (server authoritative)
missionNamespace setVariable ["ARC_debugLogEnabled", false, true];
missionNamespace setVariable ["ARC_debugLogToChat", false, true];

// Optional dev gate for inspector diary (set true explicitly in dev environments)
if (isNil { missionNamespace getVariable "ARC_devDebugInspectorEnabled" }) then {
    missionNamespace setVariable ["ARC_devDebugInspectorEnabled", false, true];
};

missionNamespace setVariable [
    "ARC_debugInspectorEnabled",
    missionNamespace getVariable ["ARC_devDebugInspectorEnabled", false],
    true
];

// FARABAD logger rollout defaults (set only when not preconfigured)
if (isNil { missionNamespace getVariable "FARABAD_log_enabled" }) then {
    missionNamespace setVariable ["FARABAD_log_enabled", true, true];
};

if (isNil { missionNamespace getVariable "FARABAD_log_minLevel" }) then {
    missionNamespace setVariable ["FARABAD_log_minLevel", "INFO", true];
};

// RPT sink is the baseline/fallback for all environments.
if (isNil { missionNamespace getVariable "FARABAD_log_toRPT" }) then {
    missionNamespace setVariable ["FARABAD_log_toRPT", true, true];
};

// Extension sink is optional and may be enabled when an extension is available.
if (isNil { missionNamespace getVariable "FARABAD_log_toExtension" }) then {
    missionNamespace setVariable ["FARABAD_log_toExtension", false, true];
};


// Optional patch breadcrumbs (keep these accurate; they’re your fastest sanity check)
diag_log "FARABAD_MIG_S0_hotfix04_convoy_startup_breadcrumbs loaded";

// ============================================================================
// CORE DEV POSTURE (scaffolding + debug)
// ============================================================================

// Migration harness ("rebuild without restart")
// Keep these toggles server-authoritative. Default posture is safe/off until a migration step is verified.
missionNamespace setVariable ["ARC_mig_enabled", true, true];
missionNamespace setVariable ["ARC_mig_uiSnapshotOnly", false, true];
missionNamespace setVariable ["ARC_mig_useRequestRouter", false, true];
missionNamespace setVariable ["ARC_mig_disableLegacyActions", false, true];

// Scaffold core objectives first (object-first posture)
missionNamespace setVariable ["ARC_objectiveScaffoldEnabled", true, true];

// Debug inspector diary is controlled by ARC_devDebugInspectorEnabled (see debug toggles above)

// Meetings: enable the liaison NPC so the meeting marker can track them
missionNamespace setVariable ["ARC_objectiveMeetUseAI", true, true];

// Hold off on hostile contact AI while object systems and markers stabilize
missionNamespace setVariable ["ARC_patrolSpawnContactsEnabled", false, true];


// ============================================================================
// UI / IN-WORLD ACTIONS
// ============================================================================

// RTB in-world actions (Intel/EPW): disable addActions + ACE interact
missionNamespace setVariable ["ARC_rtbInWorldActionsEnabled", false, true];

// SITREP in-world action (dismounted): disable addAction
missionNamespace setVariable ["ARC_sitrepInWorldActionsEnabled", false, true];

// Intel props spawn radius (meters)
missionNamespace setVariable ["ARC_intelPropSpawnRadiusM", 10, true];

// Incident-generation policy (test posture): when false, TOC generation is blocked
// while the last tasked group still has pending order acceptance or accepted RTB.
missionNamespace setVariable ["ARC_allowIncidentDuringAcceptedRtb", false, true];


// ============================================================================
// CIVSUB v1 (district influence + identity + physical civ sampling)
// ============================================================================

// Master enable
missionNamespace setVariable ["civsub_v1_enabled", true, true];

// Persistence + timing
missionNamespace setVariable ["civsub_v1_persist", true, true];
missionNamespace setVariable ["civsub_v1_seed", 11011, true];
missionNamespace setVariable ["civsub_v1_tick_s", 60, true];
missionNamespace setVariable ["civsub_v1_version", 1, true];

// Player interaction posture
missionNamespace setVariable ["civsub_v1_showPapers_forceCoop", true, true];

// Physical civilians (sampler)
missionNamespace setVariable ["civsub_v1_civs_enabled", true, true];
missionNamespace setVariable ["civsub_v1_civ_tick_s", 20, true];

// Optional editor-placed CIVSUB test civilians (3DEN variable names)
// Accepted entry forms:
//   "civsub_test_01"
//   ["civsub_test_01", "D14"]
//   ["civsub_test_01", "D14", true]
missionNamespace setVariable ["civsub_v1_editorTestCivs", ["civsub_test_01"], true];
missionNamespace setVariable ["civsub_v1_editorTestCivs_pin", true, true];

missionNamespace setVariable ["civsub_v1_civ_cap_activeDistrictsMax", 1, true];
missionNamespace setVariable ["civsub_v1_civ_cap_global", 24, true];
missionNamespace setVariable ["civsub_v1_civ_cap_perDistrict", 16, true];
missionNamespace setVariable ["civsub_v1_civ_cap_overrides", [["D14",2]], true]; // e.g., keep specific districts low
missionNamespace setVariable ["civsub_v1_civ_minSeparation_m", 25, true];

// Spawn cache (town/LOC anchor radius)
missionNamespace setVariable ["civsub_v1_spawn_cache_locRadius_m", 250, true];

// Class pool selection (3CB Takistan Civ)
missionNamespace setVariable ["civsub_v1_civ_preferredFaction", "UK3CB_TKC_C", true];

// TROUBLESHOOTING: force rebuild + clear caches (use when chasing “wrong civ types”)
missionNamespace setVariable ["civsub_v1_civ_classPool_forceRebuild", true, true];
missionNamespace setVariable ["civsub_v1_civ_classPool_cached", [], true];
missionNamespace setVariable ["civsub_v1_civ_classPool_cached_key", "", true];

// Optional: hard-set deterministic 3CB Takistan Civ class pool
missionNamespace setVariable ["civsub_v1_civ_classPool", [
    "UK3CB_TKC_C_CIV",
    "UK3CB_TKC_C_SPOT",
    "UK3CB_TKC_C_WORKER"
], true];

// Scheduler (rumors / ambient emissions, etc.)
missionNamespace setVariable ["civsub_v1_scheduler_enabled", true, true];
missionNamespace setVariable ["civsub_v1_scheduler_s", 120, true];        // baseline cadence (set to 30 for rapid testing)
missionNamespace setVariable ["civsub_v1_rumor_enabled", true, true];     // set false to disable rumors
missionNamespace setVariable ["civsub_v1_debug", true, true];            // enables scheduler/diag logs (if present)

// AIRBASE tower authorization test posture (BN Command group access enabled for validation drills)
missionNamespace setVariable ["airbase_v1_tower_allowBnCmd", true, true];
missionNamespace setVariable ["airbase_v1_tower_bnCommandTokens", ["BNCMD", "BN COMMAND", "BNHQ", "BN HQ", "BN CO", "BNCO", "BN CDR", "BNCDR", "BN CMDR", "BATTALION CO", "BATTALION CDR", "REDFALCON 6", "REDFALCON6", "RED FALCON 6", "RED-FALCON-6", "FALCON 6", "FALCON6", "FALCON-6"], true];
missionNamespace setVariable ["airbase_v1_tower_authDebug", false, true];
missionNamespace setVariable ["airbase_v1_pilotGroupTokens", ["EFS", "HAWG", "VIPER", "PILOT"], true];


// ============================================================================
// CIVTRAF (ambient civilian traffic) — mostly parked, minimal moving
// ============================================================================

// Master enable
missionNamespace setVariable ["civsub_v1_traffic_enabled", true, true];

// Cadence and budgets (no burst spawns)
missionNamespace setVariable ["civsub_v1_traffic_tick_s", 2, true];                       // 1–2s recommended
missionNamespace setVariable ["civsub_v1_traffic_spawn_budget_globalPerTick", 1, true];
missionNamespace setVariable ["civsub_v1_traffic_spawn_budget_perDistrictPerTick", 1, true];

// Active district limiter (traffic only)
missionNamespace setVariable ["civsub_v1_traffic_activeDistrictsMax", 3, true];

// Caps
missionNamespace setVariable ["civsub_v1_traffic_cap_global", 18, true];
missionNamespace setVariable ["civsub_v1_traffic_cap_perDistrict", 10, true];

// Placement / separation
missionNamespace setVariable ["civsub_v1_traffic_minSeparation_m", 35, true];
missionNamespace setVariable ["civsub_v1_traffic_spawnRadius_m", 250, true];
missionNamespace setVariable ["civsub_v1_traffic_playerMinDistance_m", 90, true];
missionNamespace setVariable ["civsub_v1_traffic_roadside_offset_m", 4, true];            // shoulder offset baseline
missionNamespace setVariable ["civsub_v1_traffic_fallback_roadsideMin_m", 8, true];      // fallback: nearest-road shoulder band min
missionNamespace setVariable ["civsub_v1_traffic_fallback_roadsideMax_m", 20, true];     // fallback: nearest-road shoulder band max
missionNamespace setVariable ["civsub_v1_traffic_fallback_buildingMin_m", 4, true];      // fallback: nearest settlement/building min
missionNamespace setVariable ["civsub_v1_traffic_fallback_buildingMax_m", 45, true];     // fallback: nearest settlement/building max
missionNamespace setVariable ["civsub_v1_traffic_fallback_waterEdgeReject_m", 12, true]; // reject fallback positions near water edges/banks

// Optional district traffic spawn anchors (districtId -> [x,y,z]); keep empty to use district centroids.
missionNamespace setVariable ["civsub_v1_traffic_spawnAnchors", createHashMapFromArray [], true];
missionNamespace setVariable ["civsub_v1_traffic_preferWeight", 0.90, true];              // bias toward 3CB

// Cleanup posture
missionNamespace setVariable ["civsub_v1_traffic_cleanupRadius_m", 500, true];
missionNamespace setVariable ["civsub_v1_traffic_cleanupMinDelay_s", 60, true];
missionNamespace setVariable ["civsub_v1_traffic_deleteWrecks", true, true];

// Exclusions: keep traffic out of the airbase bubble
missionNamespace setVariable ["civsub_v1_traffic_exclusions", [["mkr_airbaseCenter", 1600]], true];

// Diagnostics (temporary)
missionNamespace setVariable ["civsub_v1_traffic_debug", false, true];

// Vehicle pool (prefer spawnable 3CB Takistan civ vehicles; fallback to vanilla)
missionNamespace setVariable ["civsub_v1_traffic_vehiclePool_prefer", [
    "UK3CB_TKC_C_Datsun_Civ_Closed",
    "UK3CB_TKC_C_Datsun_Civ_Open",
    "UK3CB_TKC_C_Hilux_Civ_Closed",
    "UK3CB_TKC_C_Hilux_Civ_Open",
    "UK3CB_TKC_C_Hatchback",
    "UK3CB_TKC_C_Lada",
    "UK3CB_TKC_C_Lada_Taxi",
    "UK3CB_TKC_C_Skoda",
    "UK3CB_TKC_C_S1203",
    "UK3CB_TKC_C_Sedan",
    "UK3CB_TKC_C_SUV",
    "UK3CB_TKC_C_Gaz24",
    "UK3CB_TKC_C_Golf",
    "UK3CB_TKC_C_Pickup",
    "UK3CB_TKC_C_UAZ_Closed",
    "UK3CB_TKC_C_UAZ_Open"
], true];

missionNamespace setVariable ["civsub_v1_traffic_vehiclePool_fallback", [
    "C_Offroad_01_F",
    "C_SUV_01_F",
    "C_Van_01_transport_F",
    "C_Hatchback_01_F"
], true];

// Minimal moving (enabled with conservative cap/probability)
missionNamespace setVariable ["civsub_v1_traffic_allow_moving", true, true];
missionNamespace setVariable ["civsub_v1_traffic_cap_moving_global", 2, true];
missionNamespace setVariable ["civsub_v1_traffic_prob_moving", 0.10, true];
missionNamespace setVariable ["civsub_v1_traffic_moving_spawnMaxDistrictAttempts", 3, true];
missionNamespace setVariable ["civsub_v1_traffic_moving_maxSpeed", 35, true];
missionNamespace setVariable ["civsub_v1_traffic_driverClass", "C_man_1", true];

// Moving spawn diagnostics (cumulative counters)
missionNamespace setVariable ["civsub_v1_traffic_dbg_moving_spawnAttempts", 0, true];
missionNamespace setVariable ["civsub_v1_traffic_dbg_moving_spawnFail_noRoadsidePos", 0, true];
missionNamespace setVariable ["civsub_v1_traffic_dbg_moving_spawnFail_playerTooNear", 0, true];
missionNamespace setVariable ["civsub_v1_traffic_dbg_moving_spawnFail_createFail", 0, true];
missionNamespace setVariable ["civsub_v1_traffic_lastMovingSpawnFail", "", true];


// ============================================================================
// IED (Phase 1) + detection posture
// ============================================================================

missionNamespace setVariable ["ARC_iedPhase1_siteSelectionEnabled", true, true];
missionNamespace setVariable ["ARC_iedPhase1_recordsCap", 24, true];

missionNamespace setVariable ["ARC_iedSiteAvoidAirbase", true, true];
missionNamespace setVariable ["ARC_iedSiteMinSeparationM", 120, true];
missionNamespace setVariable ["ARC_iedSitePickTries", 48, true];
missionNamespace setVariable ["ARC_iedSiteSearchRadiusM", 350, true];

missionNamespace setVariable ["ARC_iedProxRadiusM", 7, true];

// ACE-first detection UX
missionNamespace setVariable ["ARC_iedScanActionEnabled", false, true];      // legacy scan action (default off)
missionNamespace setVariable ["ARC_iedPassiveDetectEnabled", true, true];   // passive detector discovery (default on)
missionNamespace setVariable ["ARC_iedPassiveDetectRadiusM", 12, true];

// Interaction controls
missionNamespace setVariable ["ARC_iedCompleteActionEnabled", false, true]; // legacy/debug only; keep off

// Evidence placement and logistics
missionNamespace setVariable ["ARC_iedEvidenceRoadSearchRadiusM", 45, true];
missionNamespace setVariable ["ARC_iedEvidenceCargoSize", 1, true];
missionNamespace setVariable ["ARC_iedEvidenceCarryEnabled", true, true];
missionNamespace setVariable ["ARC_iedEvidenceDragEnabled", true, true];

// EOD disposition approvals
missionNamespace setVariable ["ARC_eodDispoApprovalTTLsec", 900, true];

// Optional EODS v2 enhancements
missionNamespace setVariable ["ARC_eodsEnhancementsEnabled", false, true];


// ============================================================================
// VBIED (v1 general controls + scaffolding) + suspicious lead circles
// ============================================================================

// VBIED general controls
missionNamespace setVariable ["ARC_vbiedPhase3_enabled", true, true];
missionNamespace setVariable ["ARC_vbiedCooldownSeconds", 1800, true];
missionNamespace setVariable ["ARC_vbiedExplosionClass", "Bo_Mk82", true];
missionNamespace setVariable ["ARC_vbiedProxRadiusM", 12, true];
missionNamespace setVariable ["ARC_vbiedSiteAvoidAirbase", true, true];
missionNamespace setVariable ["ARC_vbiedTelegraphIntelLog", true, true];

// VBIED scaffolding (object-first)
missionNamespace setVariable ["ARC_vbiedScaffoldEnabled", true, true];

// VBIED defuse window (Phase 3.1)
missionNamespace setVariable ["ARC_vbiedDefuseActionEnabled", true, true];
missionNamespace setVariable ["ARC_vbiedDefuseWindowSeconds", 300, true];
missionNamespace setVariable ["ARC_vbiedDefuseWorkDistanceM", 2, true];
missionNamespace setVariable ["ARC_vbiedOuterRadiusM", 10, true];
missionNamespace setVariable ["ARC_vbiedRushSpeedKmh", 20, true];

// Suspicious lead circles (approximate only; no exact marker)
missionNamespace setVariable ["ARC_suspiciousLeadCirclesEnabled", true, true];
missionNamespace setVariable ["ARC_suspiciousLeadCircleCenterJitterM", 120, true];
missionNamespace setVariable ["ARC_suspiciousLeadCircleRadiusM_activity", 450, true];
missionNamespace setVariable ["ARC_suspiciousLeadCircleRadiusM_person", 250, true];
missionNamespace setVariable ["ARC_suspiciousLeadCircleRadiusM_vehicle", 350, true];
missionNamespace setVariable ["ARC_suspiciousLeadCircleTtlSec", 75*60, true];

// VBIED vehicle class pool (also used elsewhere; keep authoritative here)
missionNamespace setVariable ["ARC_vbiedVehicleClassPool", [
    "UK3CB_TKC_C_Datsun_Civ_Closed",
    "UK3CB_TKC_C_Datsun_Civ_Open",
    "UK3CB_TKC_C_Hatchback",
    "UK3CB_TKC_C_Hilux_Civ_Closed",
    "UK3CB_TKC_C_Hilux_Civ_Open",
    "UK3CB_TKC_C_Kamaz_Covered",
    "UK3CB_TKC_C_Kamaz_Fuel",
    "UK3CB_TKC_C_Kamaz_Open",
    "UK3CB_TKC_C_Kamaz_Repair",
    "UK3CB_TKC_C_Lada",
    "UK3CB_TKC_C_Lada_Taxi",
    "UK3CB_TKC_C_LR_Closed",
    "UK3CB_TKC_C_LR_Open",
    "UK3CB_TKC_C_Pickup",
    "UK3CB_TKC_C_V3S_Reammo",
    "UK3CB_TKC_C_V3S_Refuel",
    "UK3CB_TKC_C_V3S_Recovery",
    "UK3CB_TKC_C_V3S_Repair",
    "UK3CB_TKC_C_V3S_Closed",
    "UK3CB_TKC_C_V3S_Open",
    "UK3CB_TKC_C_Sedan",
    "UK3CB_TKC_C_Skoda",
    "UK3CB_TKC_C_S1203",
    "UK3CB_TKC_C_S1203_Amb",
    "UK3CB_TKC_C_SUV",
    "UK3CB_TKC_C_SUV_Armoured",
    "UK3CB_TKC_C_Tractor",
    "UK3CB_TKC_C_Tractor_Old",
    "UK3CB_TKC_C_TT650",
    "UK3CB_TKC_C_UAZ_Closed",
    "UK3CB_TKC_C_UAZ_Open",
    "UK3CB_TKC_C_Ural",
    "UK3CB_TKC_C_Ural_Fuel",
    "UK3CB_TKC_C_Ural_Open",
    "UK3CB_TKC_C_Ural_Ammo",
    "UK3CB_TKC_C_Ural_Empty",
    "UK3CB_TKC_C_Ural_Recovery",
    "UK3CB_TKC_C_Ural_Repair",
    "UK3CB_TKC_C_Gaz24",
    "UK3CB_TKC_C_Golf",
    "UK3CB_TKC_C_YAVA"
], true];


// ============================================================================
// EOD disposal site logistics (evidence RTB + VBIED tow/disposal)
// ============================================================================

missionNamespace setVariable ["ARC_eodDisposalMarkerName", "mkr_eod_disposal", true];
missionNamespace setVariable ["ARC_eodDisposalRadiusM", 12, true];

// Evidence transport mode: "ACE_CARGO" or "VIRTUAL_ITEM"
missionNamespace setVariable ["ARC_eodRtbEvidenceMode", "ACE_CARGO", true];


// ============================================================================
// LOCAL / FRIENDLY FORCES ON SCENE (TNP / TNA)
// ============================================================================

missionNamespace setVariable ["ARC_localSupportEnabled", true, true];
missionNamespace setVariable ["ARC_localSupportReuseExisting", true, true];
missionNamespace setVariable ["ARC_localSupportEligibleTypes", ["CIVIL","CHECKPOINT","DEFEND"], true];

// Light default presence (tune later as needed)
missionNamespace setVariable ["ARC_localSupportGarrisonCount_CHECKPOINT", 5, true];
missionNamespace setVariable ["ARC_localSupportGarrisonCount_CIVIL", 5, true];
missionNamespace setVariable ["ARC_localSupportGarrisonCount_DEFEND", 5, true];

missionNamespace setVariable ["ARC_localSupportPatrolCount_CHECKPOINT", 4, true];
missionNamespace setVariable ["ARC_localSupportPatrolCount_CIVIL", 4, true];
missionNamespace setVariable ["ARC_localSupportPatrolCount_DEFEND", 4, true];

// Persistence + performance posture
missionNamespace setVariable ["ARC_localSupportPersistInAO", true, true];
missionNamespace setVariable ["ARC_localSupportDynamicSimEnabled", true, true];


// ============================================================================
// TASK UX + MARKERS
// ============================================================================

// Meeting / liaison marker
missionNamespace setVariable ["ARC_taskMarkerMeetActorEnabled", true, true];

// IED / suspicious-object tasks: show approximate search area (not exact object)
missionNamespace setVariable ["ARC_taskMarkerSuspiciousAreaEnabled", true, true];
missionNamespace setVariable ["ARC_taskObjSearchJitterM_IED", 60, true];
missionNamespace setVariable ["ARC_taskObjSearchRadiusM_IED", 100, true];

// HUD / toast scaling
missionNamespace setVariable ["ARC_taskDescTextScale", 0.75, true];
missionNamespace setVariable ["ARC_taskHudScale", 0.85, true];
missionNamespace setVariable ["ARC_uiToastScale", 0.85, true];


// ============================================================================
// STATIC TASK COMPOSITIONS
// ============================================================================

missionNamespace setVariable ["ARC_checkpointStaticCompsEnabled", true, true];


// ============================================================================
// CACHE SCAFFOLDING (containers + counts)
// ============================================================================

missionNamespace setVariable ["ARC_cacheScaffoldEnabled", true, true];
missionNamespace setVariable ["ARC_cacheContainerCount", 4, true];
missionNamespace setVariable ["ARC_cacheContainerClassPool", [
    "VirtualReammoBox_camonet_F",
    "Box_FIA_Ammo_F",
    "Box_FIA_Support_F",
    "Box_FIA_Wps_F",
    "Barrel4",
    "Barrels",
    "Suitcase",
    "Fort_Crate_wood",
    "AmmoCrate_NoInteractive_",
    "CUP_bedna_ammo2X",
    "CUP_ammobednaX",
    "AmmoCrates_NoInteractive_Large",
    "AmmoCrates_NoInteractive_Small",
    "Misc_Backpackheap",
    "Misc_Backpackheap_EP1",
    "CUP_hromada_beden_dekorativniX",
    "Land_PaperBox_closed_F",
    "Land_PaperBox_open_full_F",
    "Land_DataTerminal_01_F",
    "Land_MetalCase_01_large_F",
    "Land_MetalCase_01_medium_F",
    "Land_MetalCase_01_small_F",
    "Land_AmmoboxOld_F",
    "Land_PlasticCase_01_large_F",
    "Land_PlasticCase_01_large_black_F",
    "Land_PlasticCase_01_large_black_CBRN_F",
    "Land_PlasticCase_01_medium_F",
    "Land_PlasticCase_01_medium_black_F",
    "Land_PlasticCase_01_medium_black_CBRN_F",
    "Land_PlasticCase_01_small_F",
    "Land_PlasticCase_01_small_black_F",
    "Land_PlasticCase_01_small_black_CBRN_F",
    "Land_Suitcase_F",
    "Box_C_UAV_06_F",
    "Land_WoodenCrate_01_F",
    "WoodenCrate_01_Container",
    "Land_WoodenCrate_01_stack_x3_F",
    "WoodenCrate_01_stack_x3_Container",
    "Land_WoodenCrate_01_stack_x5_F",
    "WoodenCrate_01_stack_x5_Container",
    "ACE_Box_82mm_Mo_Combo",
    "ACE_Box_82mm_Mo_HE",
    "ACE_Box_82mm_Mo_Illum",
    "ACE_Box_82mm_Mo_Smoke",
    "ACE_Box_Ammo",
    "ACE_Box_Chemlights",
    "ACE_medicalSupplyCrate_advanced",
    "ACE_medicalSupplyCrate",
    "ACE_Box_Misc",
    "ACE_fastropingSupplyCrate",
    "ACRE_RadioSupplyCrate",
    "Box_cTab_items",
    "VirtualReammoBox_small_F",
    "UK3CB_Cocaine_Bricks",
    "UK3CB_Cocaine_Pallet_Wrapped_ARMEX",
    "UK3CB_Cocaine_Pallet_Wrapped_Black",
    "UK3CB_Cocaine_Pallet_Wrapped_Blue",
    "UK3CB_Cocaine_Pallet_Wrapped_Green",
    "UK3CB_Cocaine_Pallet_Wrapped",
    "UK3CB_Cocaine_Pallet_Wrapped_IDAP_01",
    "UK3CB_Cocaine_Pallet_Wrapped_IDAP_02",
    "UK3CB_Cocaine_Pallet_Wrapped_LARKIN",
    "UK3CB_Cocaine_Pallet_Wrapped_QUON",
    "UK3CB_Cocaine_Pallet_Wrapped_VRANA",
    "Box_IED_Exp_F",
    "VirtualReammoBox_F",
    "Boxloader_Ammo_Arsenal",
    "Boxloader_Ammo_West",
    "Boxloader_BigPallet_Repair",
    "Boxloader_VehicleAmmo_West",
    "Boxloader_SmallPallet_Ammo",
    "CargoNet_01_barrels_F",
    "CargoNet_01_box_F"
], true];


// ============================================================================
// CONVOY FEATURES (do not modify spawn logic here)
// ============================================================================

// VIP escort passengers
missionNamespace setVariable ["ARC_convoyVipPassengersEnabled", true, true];
missionNamespace setVariable ["ARC_convoyVipGuardCount", 4, true];

// Authoritative mission-level convoy pools (exact classnames by group key).
missionNamespace setVariable ["ARC_convoyPool_HQ", [
    "rhsusf_m1151_usarmy_d",
    "rhsusf_m1151_mk19crows_usarmy_d",
    "rhsusf_m1151_m2crows_usarmy_d",
    "rhsusf_m1152_sicps_usarmy_d",
    "rhsusf_m1152_usarmy_d",
    "rhsusf_m1165_usarmy_d",
    "rhsusf_m1240a1_usarmy_d",
    "rhsusf_m1240a1_mk19crows_usarmy_d",
    "rhsusf_m1240a1_m2crows_usarmy_d",
    "rhsusf_m998_d_2dr_fulltop",
    "rhsusf_m998_d_2dr_halftop",
    "rhsusf_m998_d_2dr",
    "rhsusf_m998_d_4dr_fulltop",
    "rhsusf_m998_d_4dr_halftop",
    "rhsusf_m998_d_4dr"
], true];
missionNamespace setVariable ["ARC_convoyPool_MP", [
    "rhsusf_M1117_D",
    "rhsusf_m1151_usarmy_d",
    "rhsusf_m1151_mk19_v1_usarmy_d",
    "rhsusf_m1151_m2_v1_usarmy_d"
], true];
missionNamespace setVariable ["ARC_convoyPool_CAV", [
    "rhsusf_m1151_mk19_v2_usarmy_d",
    "rhsusf_m1151_m2_v2_usarmy_d",
    "rhsusf_m1045_d"
], true];
missionNamespace setVariable ["ARC_convoyPool_Security", [
    "rhsusf_m1151_mk19_v2_usarmy_d",
    "rhsusf_m1151_m2_v2_usarmy_d",
    "rhsusf_m1151_mk19_v1_usarmy_d",
    "rhsusf_m1151_m2_v1_usarmy_d",
    "rhsusf_m1240a1_m2_uik_usarmy_d",
    "rhsusf_m1240a1_mk19_usarmy_d",
    "rhsusf_m1240a1_m2_usarmy_d",
    "rhsusf_m966_d"
], true];
missionNamespace setVariable ["ARC_convoyPool_Transport", [
    "rhsusf_M1078A1P2_B_D_fmtv_usarmy",
    "rhsusf_M1078A1P2_B_D_flatbed_fmtv_usarmy",
    "rhsusf_M1078A1P2_B_D_CP_fmtv_usarmy",
    "rhsusf_M1083A1P2_B_D_fmtv_usarmy",
    "rhsusf_M1083A1P2_B_D_flatbed_fmtv_usarmy",
    "rhsusf_M1084A1P2_B_D_fmtv_usarmy",
    "rhsusf_M977A4_usarmy_d",
    "B_Truck_01_mover_F",
    "B_Truck_01_cargo_F",
    "B_Truck_01_box_F",
    "B_Truck_01_flatbed_F",
    "B_Truck_01_transport_F",
    "B_Truck_01_covered_F"
], true];
missionNamespace setVariable ["ARC_convoyPool_Medical", [
    "B_Truck_01_medical_F",
    "rhsusf_M1232_usarmy_d",
    "rhsusf_M1085A1P2_B_D_Medical_fmtv_usarmy"
], true];
missionNamespace setVariable ["ARC_convoyPool_Ammo", [
    "rhsusf_M977A4_AMMO_BKIT_usarmy_d",
    "rhsusf_m1152_rsv_usarmy_d",
    "B_Truck_01_ammo_F"
], true];
missionNamespace setVariable ["ARC_convoyPool_Repair", [
    "rhsusf_M977A4_REPAIR_BKIT_usarmy_d",
    "B_Truck_01_Repair_F"
], true];
missionNamespace setVariable ["ARC_convoyPool_Fuel", [
    "rhsusf_M978A4_BKIT_usarmy_d",
    "B_Truck_01_fuel_F"
], true];
missionNamespace setVariable ["ARC_convoyPool_Government", [
    "UK3CB_TKC_B_SUV",
    "UK3CB_TKC_B_SUV_Armoured",
    "UK3CB_TKA_B_SUV_Armoured",
    "d3s_tundra_19_COP",
    "d3s_escalade_20_FSB",
    "d3s_escalade_16_cop"
], true];
missionNamespace setVariable ["ARC_convoyPool_PrivateSecurity", [
    "EM_Police_Raptor_UM",
    "EM_Police_Explorer_UM",
    "UK3CB_TKA_B_SUV_Armed"
], true];
missionNamespace setVariable ["ARC_convoyPool_PrivateContractors", [
    "d3s_scania_16_30reef",
    "d3s_scania_16_30",
    "d3s_scania_16_t75",
    "d3s_scania_16_t50",
    "d3s_scania_16_t14",
    "d3s_scania_16_t22",
    "d3s_peterbilt_579_tank",
    "d3s_peterbilt_579_dump",
    "d3s_peterbilt_579_dryvan",
    "d3s_peterbilt_579",
    "d3s_SRmh_9500",
    "d3s_SRmh_9500_fuel",
    "d3s_SRmh_9500_cov",
    "d3s_SRlonghorn_4520",
    "d3s_SRlonghorn_4520_fuel",
    "d3s_SRlonghorn_4520_cov",
    "d3s_scania_16",
    "d3s_escalade_16",
    "d3s_raptor_17_3_BIG",
    "d3s_h1_06_A",
    "d3s_h1_06",
    "d3s_h2_02",
    "d3s_h2_02_Black",
    "d3s_cherokee_18_LTD",
    "d3s_cherokee_18",
    "d3s_hiluxarctic_14",
    "d3s_200_16_EX",
    "d3s_200_VX_16",
    "d3s_200_16",
    "d3s_tundra_19",
    "d3s_tundra_19_P"
], true];

// Convoy role matrix pools (explicit mission-level overrides).
// Precedence note: fn_execSpawnConvoy resolves role pools first, then _bundleOrLegacy
// substitutes ARC_convoyBundleClassMatrix when a bundle ID matches. These role lists are
// therefore fallback coverage when no bundle-specific class list is found.
missionNamespace setVariable ["ARC_convoyRoleMatrixPoolKeys", [
    ["lead", ["ARC_convoyPool_CAV", "ARC_convoyPool_Security", "ARC_convoyPool_HQ"]],
    ["escort", ["ARC_convoyPool_MP", "ARC_convoyPool_CAV", "ARC_convoyPool_Security", "ARC_convoyPool_PrivateSecurity", "ARC_convoyPool_Government", "ARC_convoyPool_PrivateContractors"]],
    ["logistics", ["ARC_convoyPool_Transport", "ARC_convoyPool_Medical", "ARC_convoyPool_Ammo", "ARC_convoyPool_Repair", "ARC_convoyPool_Fuel", "ARC_convoyPool_HQ", "ARC_convoyPool_MP", "ARC_convoyPool_Government", "ARC_convoyPool_PrivateSecurity", "ARC_convoyPool_PrivateContractors"]]
], true];
// Authoritative convoy bundle matrix overrides (exact classnames by bundle ID).
// LOGI_* and ESCORT_* bundles intentionally provide narrower curated class lists that
// override broader ARC_convoyPool_* role pools whenever bundle resolution succeeds.
missionNamespace setVariable ["ARC_convoyBundleClassMatrix", [
    ["LOGI_HEADQUARTERS", [
        "rhsusf_m1085a1p2_b_d_fmtv_usarmy"
    ]],
    ["LOGI_MPS", [
        "UK3CB_TKP_B_Hilux_Open",
        "UK3CB_TKP_B_Hilux_Closed",
        "UK3CB_TKP_B_Offroad",
        "UK3CB_TKP_B_Offroad_M2"
    ]],
    ["LOGI_1_73_CAV", [
        "rhsusf_M1232_M2_usarmy_d",
        "rhsusf_M1232_MK19_usarmy_d"
    ]],
    ["LOGI_TRANSPORT", [
        "rhsusf_m1083a1p2_d_fmtv_usarmy",
        "rhsusf_m1083a1p2_d_open_fmtv_usarmy",
        "rhsusf_m977a4_usarmy_d"
    ]],
    ["LOGI_MEDICAL", [
        "rhsusf_m997_ambulance_usarmy_d"
    ]],
    ["LOGI_AMMO", [
        "rhsusf_m977a4_ammo_usarmy_d",
        "rhsusf_m1078a1p2_d_flatbed_fmtv_usarmy"
    ]],
    ["LOGI_REPAIR", [
        "rhsusf_m984a4_usarmy_d",
        "rhsusf_m977a4_repair_bkit_usarmy_d"
    ]],
    ["LOGI_FUEL", [
        "rhsusf_m978a4_usarmy_d",
        "rhsusf_M978A4_BKIT_usarmy_d"
    ]],
    ["LOGI_GOVERNMENT", [
        "UK3CB_TKC_B_SUV",
        "UK3CB_TKC_B_SUV_Armoured"
    ]],
    ["LOGI_PRIVATE_SECURITY", [
        "UK3CB_ION_B_Desert_SUV_Armed",
        "UK3CB_ION_B_Desert_SUV_Armoured"
    ]],
    ["LOGI_CONTRACTOR_SECURITY", [
        "d3s_scania_16_30reef",
        "d3s_scania_16_30",
        "d3s_scania_16_t75",
        "d3s_scania_16_t50",
        "d3s_scania_16_t14",
        "d3s_scania_16_t22",
        "d3s_peterbilt_579_tank",
        "d3s_peterbilt_579_dump",
        "d3s_peterbilt_579_dryvan",
        "d3s_peterbilt_579",
        "d3s_SRmh_9500",
        "d3s_SRmh_9500_fuel",
        "d3s_SRmh_9500_cov",
        "d3s_SRlonghorn_4520",
        "d3s_SRlonghorn_4520_fuel",
        "d3s_SRlonghorn_4520_cov",
        "d3s_scania_16",
        "d3s_escalade_16",
        "d3s_raptor_17_3_BIG",
        "d3s_h1_06_A",
        "d3s_h1_06",
        "d3s_h2_02",
        "d3s_h2_02_Black",
        "d3s_cherokee_18_LTD",
        "d3s_cherokee_18",
        "d3s_hiluxarctic_14",
        "d3s_200_16_EX",
        "d3s_200_VX_16",
        "d3s_200_16",
        "d3s_tundra_19",
        "d3s_tundra_19_P"
    ]],
    ["ESCORT_STANDARD", [
        "rhsusf_M1232_M2_usarmy_d",
        "rhsusf_M1232_MK19_usarmy_d",
        "UK3CB_TKP_B_Hilux_Open",
        "UK3CB_TKP_B_Offroad_M2"
    ]],
    ["ESCORT_VIP", [
        "UK3CB_ION_B_Desert_SUV",
        "UK3CB_ION_B_Desert_SUV_Armed",
        "UK3CB_ION_B_Desert_SUV_Armoured"
    ]],
    ["CONVOY_GENERIC", [
        "rhsusf_M1232_M2_usarmy_d",
        "rhsusf_m1083a1p2_d_fmtv_usarmy"
    ]]
], true];

// Side/faction policy for allowed convoy classes (crew defaults preserve WEST join safety; vehicle side is open for contractor/government bundles).
missionNamespace setVariable ["ARC_convoyAllowedVehicleSides", [], true];
missionNamespace setVariable ["ARC_convoyAllowedCrewSides", [1], true];
missionNamespace setVariable ["ARC_convoyAllowedVehicleFactions", [], true];
missionNamespace setVariable ["ARC_convoyAllowedCrewFactions", [], true];
missionNamespace setVariable ["ARC_convoyEnforceCrewSideWest", true, true];
missionNamespace setVariable ["ARC_convoyEnforceCrewSide", missionNamespace getVariable ["ARC_convoyEnforceCrewSideWest", true], true]; // deprecated legacy mirror

// Bridge handling (assist + stuck recovery)
missionNamespace setVariable ["ARC_convoyBridgeAssistEnabled", true, true];
missionNamespace setVariable ["ARC_convoyBridgeAssistBypassSec", 14, true];
missionNamespace setVariable ["ARC_convoyBridgeStuckSec", 22, true];

// Bridge buffered zones + commit points
missionNamespace setVariable ["ARC_convoyBridgeBufferM", 22, true];
missionNamespace setVariable ["ARC_convoyBridgeAssistOutsideM", 18, true];
missionNamespace setVariable ["ARC_convoyBridgeAssistRoadSnapM", 10, true];

// Tail vehicle bridge assist (prevents convoy splitting)
missionNamespace setVariable ["ARC_convoyBridgeAssistFollowersEnabled", true, true];
missionNamespace setVariable ["ARC_convoyBridgeAssistFollowerBypassSec", 10, true];
missionNamespace setVariable ["ARC_convoyBridgeAssistFollowerTtlSec", 90, true];
missionNamespace setVariable ["ARC_convoyBridgeFollowerRecoveryCooldownSec", 28, true];
missionNamespace setVariable ["ARC_convoyBridgeFollowerGapTriggerMinM", 160, true];
missionNamespace setVariable ["ARC_convoyBridgeFollowerDoMoveReissueSec", 3.5, true];
missionNamespace setVariable ["ARC_convoyBridgeAssistPointRadiusM", 16, true];

// General follower rejoin tightening (all disruptions, not bridge-only)
missionNamespace setVariable ["ARC_convoyFollowerRecoveryCooldownSec", 50, true];
missionNamespace setVariable ["ARC_convoyFollowerGapTriggerMinM", 180, true];
missionNamespace setVariable ["ARC_convoyFollowerDoMoveReissueSec", 5, true];
missionNamespace setVariable ["ARC_convoyFollowerRejoinOrderTtlSec", 50, true];
missionNamespace setVariable ["ARC_convoyFollowerRejoinPointRadiusM", 26, true];

// Route recon parameters
missionNamespace setVariable ["ARC_routeReconStartOffsetM", 450, true];
missionNamespace setVariable ["ARC_routeReconEndOffsetM", 650, true];
missionNamespace setVariable ["ARC_routeReconMinLengthM", 700, true];
missionNamespace setVariable ["ARC_routeReconRoadSnapM", 140, true];
missionNamespace setVariable ["ARC_routeReconStartRadiusM", 75, true];
missionNamespace setVariable ["ARC_routeReconEndRadiusM", 75, true];


// ============================================================================
// POST-OVERRIDE SERVER STARTUP SCRIPTS (keep above bootstrap call if they depend on vars)
// ============================================================================

// Faction units spawn with guardpost.sqf
private _targetFactions = ["rhs_faction_usaf", "rhs_faction_usarmy_d"];
private _unitsNeedingGuardPost = allUnits select { (faction _x) in _targetFactions };
{ [_x] spawn ARC_fnc_guardPost; } forEach _unitsNeedingGuardPost;


// ============================================================================
// BOOTSTRAP (must remain last)
// ============================================================================


// ---------------------------------------------------------------------------
// Police Extended lightbar startup (centralized; replaces per-object init)
// ---------------------------------------------------------------------------
[] execVM "scripts\ARC_lightbarStartupServer.sqf";

diag_log format [
    "[ARC][DEBUG] Effective toggles | ARC_debugLogEnabled=%1 | ARC_debugLogToChat=%2 | ARC_debugInspectorEnabled=%3",
    missionNamespace getVariable ["ARC_debugLogEnabled", false],
    missionNamespace getVariable ["ARC_debugLogToChat", false],
    missionNamespace getVariable ["ARC_debugInspectorEnabled", false]
];

// World time controls (force reset to mission-editor baseline date/time + multiplier)
missionNamespace setVariable ["ARC_worldTime_enabled", true, true];
missionNamespace setVariable ["ARC_worldTime_forceDate", true, true];
missionNamespace setVariable ["ARC_worldTime_startDate", +date, true];
missionNamespace setVariable ["ARC_worldTime_forceMultiplier", true, true];
missionNamespace setVariable ["ARC_worldTime_timeMultiplier", 6, true];
missionNamespace setVariable ["ARC_worldTime_broadcastIntervalSec", 30, true];

[] call ARC_fnc_bootstrapServer;

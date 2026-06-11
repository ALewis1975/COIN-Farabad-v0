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

// Profile switch (live-safe defaults; dev profile explicitly opts into debug posture)
if (isNil { missionNamespace getVariable "ARC_profile_devMode" }) then {
    missionNamespace setVariable ["ARC_profile_devMode", false, true];
};

private _arcProfileDevMode = missionNamespace getVariable ["ARC_profile_devMode", false];
diag_log format ["[ARC][PROFILE] ARC_profile_devMode=%1", _arcProfileDevMode];

// Safe mode (operator kill-switch): keep command/control alive while pausing nonessential runtime spawners.
if (isNil { missionNamespace getVariable "ARC_safeModeEnabled" }) then {
    missionNamespace setVariable ["ARC_safeModeEnabled", false, true];
};

private _arcSafeModeEnabled = missionNamespace getVariable ["ARC_safeModeEnabled", false];
if (!(_arcSafeModeEnabled isEqualType true) && !(_arcSafeModeEnabled isEqualType false)) then {
    _arcSafeModeEnabled = false;
    missionNamespace setVariable ["ARC_safeModeEnabled", false, true];
};

if (_arcSafeModeEnabled) then {
    diag_log "[ARC][SAFE MODE] ==================================================";
    diag_log "[ARC][SAFE MODE] SAFE MODE ACTIVE: nonessential subsystem spawning is paused.";
    diag_log "[ARC][SAFE MODE] Essentials remain online: state publish, TOC console, SITREP workflow.";
    diag_log "[ARC][SAFE MODE] Operator procedure: observe stability, then disable ARC_safeModeEnabled and re-enable traffic -> IED/VBIED -> ambiance in stages.";
    diag_log "[ARC][SAFE MODE] ==================================================";
};

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

// Scaffold core objectives first (object-first posture)
// declared for future feature; currently not consumed
missionNamespace setVariable ["ARC_objectiveScaffoldEnabled", true, false];

// Debug inspector diary is controlled by ARC_devDebugInspectorEnabled (see debug toggles above)

// Meetings: enable the liaison NPC so the meeting marker can track them
// declared for future feature; currently not consumed
missionNamespace setVariable ["ARC_objectiveMeetUseAI", true, false];

// Hostile contact AI enabled; object systems and markers are stable
missionNamespace setVariable ["ARC_patrolSpawnContactsEnabled", true, true];


// ============================================================================
// CONSOLE VM — migration feature flags removed (Refactor Plan §12.2 / PR 4)
// DASH/OPS/CMD/COMMS read ARC_consoleVM_payload via ARC_fnc_consoleVmAdapterV1
// unconditionally, with direct missionNamespace reads as fallback only.
// ============================================================================
private _arcConsoleHQTokensDefault = [
    "BNCMD", "BN COMMAND", "BNHQ", "BN HQ", "BN CO", "BNCO",
    "BN CDR", "BNCDR", "BN CMDR", "BATTALION CO", "BATTALION CDR",
    "REDFALCON 6", "REDFALCON6", "RED FALCON 6", "FALCON 6", "FALCON6"
];
missionNamespace setVariable ["ARC_consoleHQTokensDefault", _arcConsoleHQTokensDefault, true];
missionNamespace setVariable ["ARC_consoleHQTokens", _arcConsoleHQTokensDefault, true];

// ============================================================================
// UI / IN-WORLD ACTIONS
// ============================================================================

// Vanilla addActions are the required in-world interaction surface.
missionNamespace setVariable ["ARC_vanillaAddActionsEnabled", true, true];

// RTB in-world actions legacy umbrella: kept as a fallback for older callers.
missionNamespace setVariable ["ARC_rtbInWorldActionsEnabled", true, true];
// Separate in-world interaction toggles keep Mobile Ops vehicle actions opt-in
// while fixed TOC, RTB, CIVSUB, objective, evidence, SITREP, scan, and recruit
// addActions are enabled by default.
missionNamespace setVariable ["ARC_tocAddActionsEnabled", true, true];
missionNamespace setVariable ["ARC_mobileTocAddActionsEnabled", false, true];
missionNamespace setVariable ["ARC_rtbAddActionsEnabled", true, true];
missionNamespace setVariable ["ARC_civsubContactAddActionsEnabled", true, true];
missionNamespace setVariable ["ARC_objectiveAddActionsEnabled", true, true];
missionNamespace setVariable ["ARC_iedEvidenceAddActionsEnabled", true, true];
missionNamespace setVariable ["ARC_recruitAddActionsEnabled", true, true];

// SITREP in-world action (dismounted): vanilla addAction enabled by default.
missionNamespace setVariable ["ARC_sitrepInWorldActionsEnabled", true, false];

// RAVEN JTAC → CASREQ 9-line prefill field action: enabled by default.
missionNamespace setVariable ["ARC_casreqJtacPrefillEnabled", true, true];

// SHADOW ISR → lead bridge field action: enabled by default.
missionNamespace setVariable ["ARC_isrShadowLeadBridgeEnabled", true, true];

// TNP partnered ops → lead request field action: enabled by default.
missionNamespace setVariable ["ARC_opsTnpPartneredRequestEnabled", true, true];

// Complex/chain IED modules (un-deferred): tier-gated reachability.
//   ARC_iedChainEnabled          secondary chain devices linked to the primary
//                                IED (execution.chain_count > 0; tier >= 2).
//   ARC_iedComplexAttackEnabled  staged secondary ambush group activated on
//                                detonation (execution.complexity >= 3; tier >= 3).
missionNamespace setVariable ["ARC_iedChainEnabled", true, true];
missionNamespace setVariable ["ARC_iedComplexAttackEnabled", true, true];

// -------------------------------------------------------------------------
// Spawn-pattern matrix (issue #633) — staged rollout toggles.
//   ARC_spawnPatternsEnabled         master gate for the data-driven spawn
//                                     pattern matrix + audit diagnostics.
//   ARC_incidentOverlaySpawnsEnabled  transient Incident/Lead overlay spawning.
//   ARC_sitePurposeExpansionEnabled   expanded SitePop site-purpose baselines.
// All default ON after live-run validation (2026-06-11). For rollback, set any
// toggle to false BEFORE initServer.sqf runs (seeds are isNil-guarded).
// Off state restores the previous type-driven incidents and three-site SitePop.
if (isNil { missionNamespace getVariable "ARC_spawnPatternsEnabled" }) then {
    missionNamespace setVariable ["ARC_spawnPatternsEnabled", true, true];
};
if (isNil { missionNamespace getVariable "ARC_incidentOverlaySpawnsEnabled" }) then {
    missionNamespace setVariable ["ARC_incidentOverlaySpawnsEnabled", true, true];
};
if (isNil { missionNamespace getVariable "ARC_sitePurposeExpansionEnabled" }) then {
    missionNamespace setVariable ["ARC_sitePurposeExpansionEnabled", true, true];
};
// Transient overlay spawning caps (issue #633 step 4/8 — bounded performance).
//   ARC_overlayMaxAiPerIncident        total overlay AI allowed per incident.
//   ARC_overlayMaxHostilesPerIncident  hostile (east) overlay AI cap; keeps
//                                       overlay OPFOR within the physical OPFOR
//                                       budget rather than stacking on the
//                                       virtual pool (ARC_fnc_threatVirtualPoolTick).
//   ARC_overlayMaxObjectsPerIncident   total overlay props/vehicles per incident.
// These are consumed only when ARC_incidentOverlaySpawnsEnabled is on.
// NOTE: ARC_sitePurposeExpansionEnabled is consumed by data/farabad_site_templates.sqf
// (loaded by ARC_fnc_sitePopInit). When on (default), it appends purpose-specific
// SitePop baselines for the high-value named AO locations on top of the three
// original sites; when off the mission keeps the original three-site behaviour.
if (isNil { missionNamespace getVariable "ARC_overlayMaxAiPerIncident" }) then {
    missionNamespace setVariable ["ARC_overlayMaxAiPerIncident", 14, true];
};
if (isNil { missionNamespace getVariable "ARC_overlayMaxHostilesPerIncident" }) then {
    missionNamespace setVariable ["ARC_overlayMaxHostilesPerIncident", 6, true];
};
if (isNil { missionNamespace getVariable "ARC_overlayMaxObjectsPerIncident" }) then {
    missionNamespace setVariable ["ARC_overlayMaxObjectsPerIncident", 12, true];
};
// Opt-in diagnostics: when the master gate is on, log a one-shot summary audit
// of the spawn-pattern matrix so coverage/warnings are visible in the RPT.
// Non-verbose by default (toggles now ship on, so this runs every start);
// operators can run [true] call ARC_fnc_worldSpawnPatternAudit for per-row detail.
if (missionNamespace getVariable ["ARC_spawnPatternsEnabled", false]) then {
    [] spawn {
        private _t0 = diag_tickTime;
        waitUntil { !isNil "ARC_fnc_worldSpawnPatternAudit" || { (diag_tickTime - _t0) > 30 } };
        if (isNil "ARC_fnc_worldSpawnPatternAudit") exitWith { diag_log "[ARC][SPAWNPAT][WARN] initServer: ARC_fnc_worldSpawnPatternAudit not available after 30s; skipping audit."; };
        [false] call ARC_fnc_worldSpawnPatternAudit;
    };
};

// Simple AI recruitment from the named Eden object "recruitment_01".
// Clients render one "Recruit AI" action; the server validates sender identity,
// registered recruitment object, public infantry class, side/faction match, and
// the per-player recruited-AI cap. Existing Object Init opt-in remains supported
// for Huron cargo containers:
//   if (isServer) then { this setVariable ["ARC_isRecruitContainer", true, true]; };
missionNamespace setVariable ["ARC_recruitContainerEnabled", true, true];
missionNamespace setVariable ["ARC_recruitContainerClasses", ["B_Slingload_01_Cargo_F"], true];
missionNamespace setVariable ["ARC_recruitContainerNames", ["recruitment_01"], true];
missionNamespace setVariable ["ARC_recruitContainerNetIds", [], true];
missionNamespace setVariable ["ARC_recruitGroupMaxUnits", 12, true];
// Recruit "Recruit AI" addAction interaction range (meters) and faction gate.
// Range default matches the historical hardcoded addAction radius; the faction
// gate defaults to true to preserve the existing same-faction enforcement.
missionNamespace setVariable ["ARC_recruitActionRangeM", 50, true];
missionNamespace setVariable ["ARC_recruitRequireSameFaction", true, true];

[] spawn {
    if (!isServer) exitWith {};
    uiSleep 1;

    private _attempt = 0;
    while { _attempt < 12 } do
    {
        if (!isNil "ARC_fnc_recruitServerPublishContainers") then
        {
            [] call ARC_fnc_recruitServerPublishContainers;
        };
        _attempt = _attempt + 1;
        uiSleep 5;
    };
};

// Intel props spawn radius (meters)
missionNamespace setVariable ["ARC_intelPropSpawnRadiusM", 10, true];

// Incident-generation policy (test posture): when false, TOC generation is blocked
// while the last tasked group still has pending order acceptance or accepted RTB.
missionNamespace setVariable ["ARC_allowIncidentDuringAcceptedRtb", false, true];


// ============================================================================
// WORLD SIMULATION — objective index + virtual pool tuning
// ============================================================================

// Strategic objective index scoring weights (density, junction, site, proximity).
// All four weights should sum to 1.0 for a balanced score; adjust to shift emphasis.
missionNamespace setVariable ["ARC_worldIndex_weights", [0.25, 0.25, 0.30, 0.20], true];

// Tier thresholds: locations with score >= HIGH threshold are "HIGH"; >= MED = "MED"; else "LOW".
// Incident seeding multipliers: HIGH x1.4, MED x1.1, LOW x0.8.
missionNamespace setVariable ["ARC_worldIndex_tierThresholds", [0.65, 0.35], true];

// Virtual OpFor pool: activation/spawn/despawn radii (metres) split by player platform type.
// Ground players (infantry, ground vehicles): use the _ground values.
// Air players (helicopters, fixed-wing): use the _air values — greater range improves
// aerial ambiance and ensures pilots see world activity at realistic distances.
//
// Radius relationships (intentional):
//   Activation > Spawn > Despawn margin:
//   Activation radius is ~10 % larger than spawn radius so groups enter ACTIVE
//   (alert) state slightly before they physically spawn, preventing pop-in at
//   the boundary.  Despawn radius is slightly larger than spawn radius so groups
//   do not immediately despawn when a player backs off the spawn edge.
//   The spawn radii (2,000 m ground / 5,000 m air) are the "spawn distances"
//   referenced in playtest notes — activation/despawn are derived buffers.
missionNamespace setVariable ["ARC_threatVirtualActivationRadiusM_ground", 2200, true]; // DORMANT -> ACTIVE (ground player nearby)
missionNamespace setVariable ["ARC_threatVirtualActivationRadiusM_air",    5500, true]; // DORMANT -> ACTIVE (air player nearby)
missionNamespace setVariable ["ARC_threatVirtualSpawnRadiusM_ground",      2000, true]; // ACTIVE  -> PHYSICAL — ground player spawn distance
missionNamespace setVariable ["ARC_threatVirtualSpawnRadiusM_air",         5000, true]; // ACTIVE  -> PHYSICAL — air player spawn distance
missionNamespace setVariable ["ARC_threatVirtualDespawnRadiusM_ground",    2400, true]; // PHYSICAL -> start despawn countdown (ground)
missionNamespace setVariable ["ARC_threatVirtualDespawnRadiusM_air",       6000, true]; // PHYSICAL -> start despawn countdown (air)
// Legacy single-value fallbacks (= ground defaults; kept for compatibility with external callers).
missionNamespace setVariable ["ARC_threatVirtualActivationRadiusM", 2200, true];
missionNamespace setVariable ["ARC_threatVirtualSpawnRadiusM",      2000, true];
missionNamespace setVariable ["ARC_threatVirtualDespawnRadiusM",    2400, true];
missionNamespace setVariable ["ARC_threatVirtualMinSpawnDistM",     300,  true]; // ACTIVE -> PHYSICAL — minimum standoff from the nearest player; spawns inside this bubble are pushed outward (or deferred) so OPFOR never materialise on top of holders
missionNamespace setVariable ["ARC_threatVirtualDespawnDelayS",     90,   true]; // seconds beyond despawn radius before group is deleted
missionNamespace setVariable ["ARC_threatVirtualRepositionS",       600,  true]; // drift interval for DORMANT groups (seconds)
missionNamespace setVariable ["ARC_threatVirtualPoolTickS",         60,   true]; // pool tick cadence (seconds)
missionNamespace setVariable ["ARC_threatVirtualPatrolRadiusM",    200,  true]; // physical group patrol radius when spawned (metres)
missionNamespace setVariable ["ARC_threatVirtualPatrolWaypointN",  5,    true]; // waypoint count for physical group patrol task
missionNamespace setVariable ["ARC_threatVirtualPoolMaxGroups",    96,   true]; // hard cap on seeded virtual OPFOR groups across all locations
missionNamespace setVariable ["ARC_threatVirtualPhysicalMaxGroups", 8,   true]; // hard cap on simultaneous physical virtual-OPFOR groups
missionNamespace setVariable ["ARC_threatVirtualPhysicalMaxGroups_FarabadCity", 4, true]; // tighter simultaneous cap inside Farabad City
missionNamespace setVariable ["ARC_threatVirtualSpawnBudgetPerTick", 2,  true]; // max virtual-OPFOR groups allowed to materialize per pool tick
missionNamespace setVariable ["ARC_threatProtectedSpawnMarkers", [["mkr_airbaseCenter", 1600]], true]; // marker-radius hostile no-spawn bubbles
missionNamespace setVariable ["ARC_sitePopActiveSitesCap",          6,   true]; // max simultaneous active SitePop sites

// OPFOR unit class pool — 3CB Middle Eastern Insurgents (MEI) + Extremists (MEE), OPFOR side.
// Use _O_ (East/OPFOR) variants so faction side in CfgVehicles matches createGroup east.
// MEI_O classnames confirmed from community mission sources; MEE_O follows same pattern.
// Classes absent from CfgVehicles produce null on createUnit and are handled gracefully.
missionNamespace setVariable ["ARC_opforPatrolUnitClasses", [
    // 3CB Middle Eastern Insurgents — OPFOR (faction: UK3CB_MEI_O)
    "UK3CB_MEI_O_RIF_2",       // Rifleman (AK variant 2)
    "UK3CB_MEI_O_RIF_3",       // Rifleman (AK variant 3)
    "UK3CB_MEI_O_RIF_4",       // Rifleman (AK variant 4)
    "UK3CB_MEI_O_RIF_7",       // Rifleman (AK variant 7)
    "UK3CB_MEI_O_GL",          // Grenadier (AK + underbarrel GL)
    "UK3CB_MEI_O_AR_01",       // Auto-Rifleman (PKM/RPD)
    "UK3CB_MEI_O_AT",          // Anti-Tank (RPG-7)
    "UK3CB_MEI_O_MD",          // Combat Medic
    // 3CB Middle Eastern Extremists — OPFOR (faction: UK3CB_MEE_O) — hardline cells
    "UK3CB_MEE_O_RIF_1",       // Rifleman (AK variant 1)
    "UK3CB_MEE_O_RIF_2",       // Rifleman (AK variant 2)
    "UK3CB_MEE_O_GL",          // Grenadier
    "UK3CB_MEE_O_AR",          // Auto-Rifleman
    "UK3CB_MEE_O_MD"           // Medic
], true];


// ============================================================================
// IDLE GATE (empty-server simulation pause)
// ============================================================================

// When no interfaced human players are connected (headless clients excluded),
// ARC_fnc_idleGateActive pauses idle-gated background ticks: ambient lead/rumor
// generation, medical + sustainment ambient decay, and ambient spawn ticks
// (civ sampler, civ traffic, location NPCs, airbase ground traffic, sitepop).
missionNamespace setVariable ["ARC_idleGateEnabled", true, true];
// Grace period (s) of empty server before the gate engages. Kept above the
// sitepop despawn grace windows so proximity cleanup finishes before pausing.
missionNamespace setVariable ["ARC_idleGateGraceS", 300, true];


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
missionNamespace setVariable ["civsub_v1_civ_tick_s", 30, true];   // sampler cadence (s); 30 balances CPU vs. town-population latency (was 20). See docs/perf/Tick_Cadence_Review.md

// Optional editor-placed CIVSUB test civilians (3DEN variable names)
// Accepted entry forms:
//   "civsub_test_01"
//   ["civsub_test_01", "D14"]
//   ["civsub_test_01", "D14", true]
missionNamespace setVariable ["civsub_v1_editorTestCivs", ["civsub_test_01"], true];
missionNamespace setVariable ["civsub_v1_editorTestCivs_pin", true, true];

missionNamespace setVariable ["civsub_v1_civ_cap_activeDistrictsMax", 3, true];
missionNamespace setVariable ["civsub_v1_civ_cap_global", 36, true];
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

// Explicit civilian class pool: 3CB Takistan (TKC) + Middle Eastern (MEC) civilians.
// This overrides the dynamic faction-scan in fn_civsubCivBuildClassPool.
// MEC classes are silently ignored at createUnit time if not present in the modset.
missionNamespace setVariable ["civsub_v1_civ_classPool", [
    // 3CB Takistan Civilians (faction: UK3CB_TKC_C)
    "UK3CB_TKC_C_CIV",
    "UK3CB_TKC_C_SPOT",
    "UK3CB_TKC_C_WORKER",
    "UK3CB_TKC_C_DOC",
    // 3CB Middle Eastern Civilians (faction: UK3CB_MEC_C)
    "UK3CB_MEC_C_CIV",
    "UK3CB_MEC_C_WORKER"
], true];

// Scheduler (rumors / ambient emissions, etc.)
missionNamespace setVariable ["civsub_v1_scheduler_enabled", true, true];
missionNamespace setVariable ["civsub_v1_scheduler_s", 240, true];        // baseline cadence; self-scaling via fn_civsubProbHourToTick so events/hr unchanged (was 120; set to 30 for rapid testing). See docs/perf/Tick_Cadence_Review.md
missionNamespace setVariable ["civsub_v1_rumor_enabled", true, true];     // set false to disable rumors
missionNamespace setVariable ["civsub_v1_debug", false, true];           // enables scheduler/diag logs (if present)

// AIRBASE tower authorization test posture (BN Command group access enabled for validation drills)
missionNamespace setVariable ["airbase_v1_tower_allowBnCmd", true, true];
missionNamespace setVariable ["airbase_v1_tower_bnCommandTokens", ["BNCMD", "BN COMMAND", "BNHQ", "BN HQ", "BN CO", "BNCO", "BN CDR", "BNCDR", "BN CMDR", "BATTALION CO", "BATTALION CDR", "REDFALCON 6", "REDFALCON6", "RED FALCON 6", "RED-FALCON-6", "FALCON 6", "FALCON6", "FALCON-6"], true];
missionNamespace setVariable ["airbase_v1_tower_authDebug", false, true];
missionNamespace setVariable ["airbase_v1_pilotGroupTokens", ["EFS", "HAWG", "VIPER", "PILOT"], true];
// CCIC tokens: match "Watch Supervisor / Controller-in-Charge (WS/WIC) @332 EOSS | FARABAD TOWER"
// Normalized hay for WS/CIC: "332 EOSS | FARABAD TOWER WATCH SUPERVISOR CONTROLLER IN CHARGE (WS WIC) @332 EOSS | FARABAD TOWER"
missionNamespace setVariable ["airbase_v1_tower_ccicTokens", [
    "FARABAD TOWER WSCIC",
    "FARABAD TOWER WS CCIC",
    "FARABAD TOWER WS-CIC",
    "FARABAD TOWER W/S CCIC",
    "FARABAD-TOWER-WS-CCIC",
    "FARABAD TOWER WS.CCIC",
    "FARABAD TOWER WATCH SUPERVISOR"
], true];
// LC tokens: match "Lead Controller (LC)" with group "332 EOSS | FARABAD TOWER"
// Normalized hay for LC: "332 EOSS | FARABAD TOWER LEAD CONTROLLER (LC)"
missionNamespace setVariable ["airbase_v1_tower_lcTokens", [
    "FARABAD TOWER LC",
    "FARABAD TOWER WS LC",
    "FARABAD-TOWER-LC",
    "FARABAD TOWER W/S LC",
    "FARABAD TOWER LEAD CONTROLLER"
], true];


// ============================================================================
// CIVTRAF (ambient civilian traffic) — mostly parked, minimal moving
// ============================================================================

// Master enable
missionNamespace setVariable ["civsub_v1_traffic_enabled", true, true];

// Cadence and budgets (no burst spawns)
missionNamespace setVariable ["civsub_v1_traffic_tick_s", 5, true];                       // 5s recommended; 2s was too aggressive for the 498-line tick function
missionNamespace setVariable ["civsub_v1_traffic_spawn_budget_globalPerTick", 1, true];
missionNamespace setVariable ["civsub_v1_traffic_spawn_budget_perDistrictPerTick", 1, true];

// Active district limiter (traffic only)
missionNamespace setVariable ["civsub_v1_traffic_activeDistrictsMax", 3, true];

// Caps
missionNamespace setVariable ["civsub_v1_traffic_cap_global", 28, true];
missionNamespace setVariable ["civsub_v1_traffic_cap_perDistrict", 10, true];

// Shared airbase dynamic boundary radius (single source of truth for airbase cleanup + civ exclusion)
missionNamespace setVariable ["ARC_airbase_dynamic_radius_m", 1600, true];

// Placement / separation
// spawnRadius_m: search radius around the player-centroid spawn center.
// playerMinDistance_m: hard minimum distance from any player — set to just beyond
//   the 1 km view distance so vehicles never pop into existence within player sight.
// spawnRadius_m must significantly exceed playerMinDistance_m to leave a viable
// spawn ring (e.g. 1400 m radius with 1050 m exclusion → ~350 m wide ring beyond view).
missionNamespace setVariable ["civsub_v1_traffic_minSeparation_m", 35, true];
missionNamespace setVariable ["civsub_v1_traffic_spawnRadius_m", 1400, true];
missionNamespace setVariable ["civsub_v1_traffic_playerMinDistance_m", 1050, true];
// convoyMinDistance_m: hard minimum distance from any active convoy vehicle (tagged
//   ARC_isConvoyVeh and tracked in ARC_activeConvoyNetIds). Mirrors playerMinDistance
//   so traffic does not pop into existence inside or just ahead of a moving convoy
//   even when no human is nearby (e.g. AI-led convoy elements).
missionNamespace setVariable ["civsub_v1_traffic_convoyMinDistance_m", 1050, true];
missionNamespace setVariable ["civsub_v1_traffic_roadside_offset_m", 4, true];            // shoulder offset baseline
missionNamespace setVariable ["civsub_v1_traffic_fallback_roadsideMin_m", 8, true];      // fallback: nearest-road shoulder band min
missionNamespace setVariable ["civsub_v1_traffic_fallback_roadsideMax_m", 20, true];     // fallback: nearest-road shoulder band max
missionNamespace setVariable ["civsub_v1_traffic_fallback_buildingMin_m", 4, true];      // fallback: nearest settlement/building min
missionNamespace setVariable ["civsub_v1_traffic_fallback_buildingMax_m", 45, true];     // fallback: nearest settlement/building max
missionNamespace setVariable ["civsub_v1_traffic_fallback_waterEdgeReject_m", 12, true]; // reject fallback positions near water edges/banks

// Optional district traffic spawn anchors (districtId -> [x,y,z]); keep empty to use district centroids.
missionNamespace setVariable ["civsub_v1_traffic_spawnAnchors", createHashMap, true];
missionNamespace setVariable ["civsub_v1_traffic_preferWeight", 0.90, true];              // bias toward 3CB

// Cleanup posture
// cleanupRadius_m must exceed spawnRadius_m so vehicles at the far edge of the
// spawn ring are not immediately considered out-of-bubble and cleaned up.
missionNamespace setVariable ["civsub_v1_traffic_cleanupRadius_m", 1500, true];
missionNamespace setVariable ["civsub_v1_traffic_cleanupMinDelay_s", 60, true];
missionNamespace setVariable ["civsub_v1_traffic_deleteWrecks", true, true];

// Exclusions: keep traffic out of the airbase bubble
missionNamespace setVariable ["civsub_v1_traffic_exclusions", [["mkr_airbaseCenter", missionNamespace getVariable ["ARC_airbase_dynamic_radius_m", 1600]]], true];

// Diagnostics (temporary)
missionNamespace setVariable ["civsub_v1_traffic_debug", false, true];

// Vehicle pool (prefer spawnable 3CB Takistan civ vehicles and D3S civilian pack; fallback to vanilla)
missionNamespace setVariable ["civsub_v1_traffic_vehiclePool_prefer", [
    "UK3CB_TKC_C_Datsun_Civ_Closed",
    "UK3CB_TKC_C_Datsun_Civ_Open",
    "UK3CB_TKC_C_Gaz24",
    "UK3CB_TKC_C_Golf",
    "UK3CB_TKC_C_Hatchback",
    "UK3CB_TKC_C_Hilux_Civ_Closed",
    "UK3CB_TKC_C_Hilux_Civ_Open",
    "UK3CB_TKC_C_Ikarus",
    "UK3CB_TKC_C_Kamaz_Covered",
    "UK3CB_TKC_C_Kamaz_Fuel",
    "UK3CB_TKC_C_Kamaz_Open",
    "UK3CB_TKC_C_Kamaz_Repair",
    "UK3CB_TKC_C_Lada",
    "UK3CB_TKC_C_Lada_Taxi",
    "UK3CB_TKC_C_LR_Closed",
    "UK3CB_TKC_C_LR_Open",
    "UK3CB_TKC_C_Pickup",
    "UK3CB_TKC_C_S1203",
    "UK3CB_TKC_C_S1203_Amb",
    "UK3CB_TKC_C_Sedan",
    "UK3CB_TKC_C_Skoda",
    "UK3CB_TKC_C_SUV",
    "UK3CB_TKC_C_SUV_Armoured",
    "UK3CB_TKC_C_TT650",
    "UK3CB_TKC_C_Tractor",
    "UK3CB_TKC_C_Tractor_Old",
    "UK3CB_TKC_C_UAZ_Closed",
    "UK3CB_TKC_C_UAZ_Open",
    "UK3CB_TKC_C_Ural",
    "UK3CB_TKC_C_Ural_Ammo",
    "UK3CB_TKC_C_Ural_Empty",
    "UK3CB_TKC_C_Ural_Fuel",
    "UK3CB_TKC_C_Ural_Open",
    "UK3CB_TKC_C_Ural_Recovery",
    "UK3CB_TKC_C_Ural_Repair",
    "UK3CB_TKC_C_V3S_Closed",
    "UK3CB_TKC_C_V3S_Open",
    "UK3CB_TKC_C_V3S_Reammo",
    "UK3CB_TKC_C_V3S_Recovery",
    "UK3CB_TKC_C_V3S_Refuel",
    "UK3CB_TKC_C_V3S_Repair",
    "UK3CB_TKC_C_YAVA",
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
    "d3s_h2_02_Black"
], true];

missionNamespace setVariable ["civsub_v1_traffic_vehiclePool_fallback", [
    "C_Offroad_01_F",
    "C_SUV_01_F",
    "C_Van_01_transport_F",
    "C_Hatchback_01_F"
], true];

// Moving traffic (visible ambient flow)
missionNamespace setVariable ["civsub_v1_traffic_allow_moving", true, true];
missionNamespace setVariable ["civsub_v1_traffic_cap_moving_global", 6, true];
missionNamespace setVariable ["civsub_v1_traffic_prob_moving", 0.40, true];
missionNamespace setVariable ["civsub_v1_traffic_moving_spawnMaxDistrictAttempts", 3, true];
missionNamespace setVariable ["civsub_v1_traffic_moving_maxSpeed", 35, true];
// Lateral lane offset (m) for moving spawns: shifts the spawn + first move
// target to the RIGHT of the travel direction so vehicles spawn inside the
// correct carriageway/lane instead of on the road centreline (median), where
// divided-highway barrier props sit. Clamped to 0-8 m; the picker steps the
// offset down toward the centreline until the candidate is still on the paved
// road, so narrow single-carriageway roads keep a small/zero offset.
missionNamespace setVariable ["civsub_v1_traffic_moving_laneOffset_m", 3, true];
// Moving waypoint distances: min clamps to 1000-3000m; search clamps to min+100..4000m.
// The 100m gap prevents near-duplicate road picks; 4000m upper bound preserves district locality.
// Search radius must exceed minimum distance so the road-distance filter can produce candidates.
missionNamespace setVariable ["civsub_v1_traffic_moving_waypointMinDistance_m", 1000, true];
missionNamespace setVariable ["civsub_v1_traffic_moving_waypointSearchRadius_m", 1800, true];
// Moving route candidate cap clamps to 4-40 road objects per vehicle route refresh.
missionNamespace setVariable ["civsub_v1_traffic_moving_waypointCandidateLimit", 15, true];
// Moving route refresh: retry clamps to 10-120s; base clamps to 30-600s; jitter clamps to 0-300s.
missionNamespace setVariable ["civsub_v1_traffic_moving_waypointRetryDelay_s", 30, true];
missionNamespace setVariable ["civsub_v1_traffic_moving_waypointRefreshBase_s", 90, true];
missionNamespace setVariable ["civsub_v1_traffic_moving_waypointRefreshJitter_s", 60, true];
missionNamespace setVariable ["civsub_v1_traffic_driverClass", "C_man_1", true];

// Moving spawn diagnostics (cumulative counters)
missionNamespace setVariable ["civsub_v1_traffic_dbg_moving_spawnAttempts", 0, true];
missionNamespace setVariable ["civsub_v1_traffic_dbg_moving_spawnFail_noRoadsidePos", 0, true];
missionNamespace setVariable ["civsub_v1_traffic_dbg_moving_spawnFail_playerTooNear", 0, true];
missionNamespace setVariable ["civsub_v1_traffic_dbg_moving_spawnFail_createFail", 0, true];
missionNamespace setVariable ["civsub_v1_traffic_lastMovingSpawnFail", "", true];


// ============================================================================
// CIVLOC — location-appropriate ambient NPCs (workers, patients, etc.)
// ============================================================================

missionNamespace setVariable ["civsub_v1_locnpc_enabled", true, true];
missionNamespace setVariable ["civsub_v1_locnpc_tick_s",   10, true];           // tick cadence (s); 10 recommended

// Bubble: spawn NPCs at sites within this distance of any player.
// Air players (helicopter/fixed-wing) use the larger radius so pilots see world activity.
missionNamespace setVariable ["civsub_v1_locnpc_bubbleRadius_m_ground", 2000, true];
missionNamespace setVariable ["civsub_v1_locnpc_bubbleRadius_m_air",    5000, true];
// Legacy single-value fallback (= ground default).
missionNamespace setVariable ["civsub_v1_locnpc_bubbleRadius_m", 2000, true];

// Global NPC cap across all sites
missionNamespace setVariable ["civsub_v1_locnpc_cap_global",      32, true];

// Site-position clustering radius (m) — positions closer than this become one site
missionNamespace setVariable ["civsub_v1_locnpc_cluster_m",       80, true];

// Cleanup: despawn NPCs when players have been further than this for cleanupMinDelay_s
missionNamespace setVariable ["civsub_v1_locnpc_cleanupRadius_m",    2400, true];
missionNamespace setVariable ["civsub_v1_locnpc_cleanupMinDelay_s",  120, true];

// NPC class pools (prefer 3CB Takistan; fallback to vanilla if mods absent)
missionNamespace setVariable ["civsub_v1_locnpc_classPool_worker", [
    "UK3CB_TKC_C_WORKER",
    "C_man_1"
], true];
missionNamespace setVariable ["civsub_v1_locnpc_classPool_civ", [
    "UK3CB_TKC_C_CIV",
    "C_man_polo_1_F"
], true];

missionNamespace setVariable ["civsub_v1_locnpc_debug", false, true];


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

// Vanilla-first detection UX
missionNamespace setVariable ["ARC_iedScanActionEnabled", true, true];       // scan addAction (default on)
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

// VBIED Driven + Suicide Bomber (locked v1 pacing knobs — authoritative defaults)
// Spawn-path enable flags (escalation-tier gates still apply inside the ticks).
missionNamespace setVariable ["ARC_vbiedDrivenEnabled", true, true];
missionNamespace setVariable ["ARC_suicideBomberEnabled", true, true];
// Telegraph floor for driven VBIED: 0 forces a minimum urgent warning lead
// before the spawn-delay window elapses (fairness rule, non-negotiable).
missionNamespace setVariable ["ARC_vbiedDrivenIntelLevel", 0, true];
// District risk cooldown applied on VBIED DETONATED (lead-emission penalty path).
missionNamespace setVariable ["ARC_vbiedDetonationCooldownS", 3600, true];

// VBIED scaffolding (object-first)
missionNamespace setVariable ["ARC_vbiedScaffoldEnabled", true, true];
missionNamespace setVariable ["airbase_v1_ambiance_enabled", true, true];
missionNamespace setVariable ["airbase_v1_runtime_enabled", true, true];
// Ambient ground vehicle traffic (ORBAT-aligned whitelist; see fn_airbaseGroundTrafficInit)
missionNamespace setVariable ["airbase_v1_gnd_traffic_enabled", true, true];
missionNamespace setVariable ["airbase_v1_gnd_cleanupRadius_m", missionNamespace getVariable ["ARC_airbase_dynamic_radius_m", 1600], true];
missionNamespace setVariable ["ARC_dynamic_tod_allowCivilNight", true, true];
missionNamespace setVariable ["ARC_dynamic_tod_allowAirbaseNight", false, true];
missionNamespace setVariable ["ARC_dynamic_tod_allowThreatNight", true, true];
missionNamespace setVariable ["ARC_dynamic_tod_allowOpsNight", true, true];
// Dynamic ORBAT population for the 8 empty Eden layers (see fn_airbaseOrbatPopulate)
missionNamespace setVariable ["airbase_v1_orbat_populate_enabled", true, true];

if (_arcSafeModeEnabled) then {
    missionNamespace setVariable ["civsub_v1_traffic_enabled", false, true];
    missionNamespace setVariable ["ARC_iedPhase1_siteSelectionEnabled", false, true];
    missionNamespace setVariable ["ARC_vbiedPhase3_enabled", false, true];
    missionNamespace setVariable ["ARC_vbiedScaffoldEnabled", false, true];
    missionNamespace setVariable ["ARC_vbiedDrivenEnabled", false, true];
    missionNamespace setVariable ["ARC_suicideBomberEnabled", false, true];
    missionNamespace setVariable ["airbase_v1_ambiance_enabled", false, true];
    missionNamespace setVariable ["airbase_v1_runtime_enabled", false, true];
    missionNamespace setVariable ["airbase_v1_gnd_traffic_enabled", false, true];
    missionNamespace setVariable ["airbase_v1_orbat_populate_enabled", false, true];
};

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

// Lead routing (single-track model): origin discrimination is automatic, but the
// optional auto-enqueue policy routes high-confidence FIELD-origin leads straight
// into the TOC Queue (backlog) at creation. Disabled by default to preserve the
// deliberate S2/TOC review cycle; ARC_leadAutoEnqueueMinStrength gates which leads
// qualify when the policy is enabled.
missionNamespace setVariable ["ARC_leadAutoEnqueueField", false, true];
missionNamespace setVariable ["ARC_leadAutoEnqueueMinStrength", 0.7, true];

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
    "TFAR_NATO_Radio_Crate",
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
// CASEVAC CASUALTY POOL
// ============================================================================
// BLUFOR casualty classes used to stand up a downed wounded unit at CASEVAC
// incidents (QRF incidents carrying the "CASEVAC" lead tag). Classes are
// validated with isClass at spawn time; fn_execInitActive falls back to proven
// 3CB Takistani Army BLUFOR classes and finally vanilla "B_Soldier_F".
missionNamespace setVariable ["ARC_casevacCasualtyClassPool", [
    "UK3CB_TKA_B_AR",
    "UK3CB_TKA_B_TL",
    "UK3CB_TKA_B_OFF",
    "B_Soldier_F"
], true];


// ============================================================================
// CONVOY FEATURES (do not modify spawn logic here)
// ============================================================================

// Server-owned convoy pools/tunables (non-replicated startup config).
[] call ARC_fnc_convoyStartupConfig;

// ============================================================================
// PROFILE-DRIVEN DEBUG OVERRIDES (single block)
// ============================================================================

if (_arcProfileDevMode) then {
    missionNamespace setVariable ["ARC_debugLogEnabled", true, true];
    missionNamespace setVariable ["ARC_debugLogToChat", true, true];
    missionNamespace setVariable ["ARC_devDebugInspectorEnabled", true, true];
    missionNamespace setVariable ["ARC_debugInspectorEnabled", true, true];
    missionNamespace setVariable ["civsub_v1_debug", true, true];
    missionNamespace setVariable ["civsub_v1_traffic_debug", true, true];
    missionNamespace setVariable ["airbase_v1_tower_authDebug", true, true];

    diag_log "[ARC][PROFILE] Dev profile active: debug overrides enabled.";
};


// ============================================================================
// POST-OVERRIDE SERVER STARTUP SCRIPTS (keep above bootstrap call if they depend on vars)
// ============================================================================

// Faction units spawn with guardpost.sqf
private _targetFactions = ["rhs_faction_usaf", "rhs_faction_usarmy_d"];
private _unitsNeedingGuardPost = [];
{
    if ((faction _x) in _targetFactions) then {
        _unitsNeedingGuardPost pushBack _x;
    };
} forEach allUnits;
{ [_x] spawn ARC_fnc_guardPost; } forEach _unitsNeedingGuardPost;


// ============================================================================
// BOOTSTRAP (must remain last)
// ============================================================================


// ---------------------------------------------------------------------------
// Police Extended lightbar startup (centralized; replaces per-object init)
// ---------------------------------------------------------------------------
[] execVM "scripts\ARC_lightbarStartupServer.sqf";

diag_log format [
    "[ARC][CONFIG] Effective toggles | ARC_debugLogEnabled=%1 | ARC_debugLogToChat=%2 | ARC_debugInspectorEnabled=%3",
    missionNamespace getVariable ["ARC_debugLogEnabled", false],
    missionNamespace getVariable ["ARC_debugLogToChat", false],
    missionNamespace getVariable ["ARC_debugInspectorEnabled", false]
];

// World time controls (force reset to mission-editor baseline date/time + multiplier)
missionNamespace setVariable ["ARC_worldTime_enabled", true, true];
missionNamespace setVariable ["ARC_worldTime_forceDate", true, true];
missionNamespace setVariable ["ARC_worldTime_startDate", +date, true];
missionNamespace setVariable ["ARC_worldTime_forceMultiplier", false, true];
missionNamespace setVariable ["ARC_worldTime_timeMultiplier", 6, true];
missionNamespace setVariable ["ARC_worldTime_broadcastIntervalSec", 30, true];

// World time events (Central Asian prayer/market/cultural schedule)
missionNamespace setVariable ["ARC_worldTimeEvents_enabled", true, true];
missionNamespace setVariable ["ARC_worldTimeEvents_broadcastIntervalSec", 30, true];

// Operator startup audit catalog (curated, operator-facing controls only)
missionNamespace setVariable ["ARC_operatorToggleAuditCatalog", [
    ["MIG", [
        ["ARC_allowIncidentDuringAcceptedRtb", "bool"],
        ["ARC_patrolSpawnContactsEnabled", "bool"]
    ]],
    ["CIVSUB", [
        ["civsub_v1_enabled", "bool"],
        ["civsub_v1_civs_enabled", "bool"],
        ["civsub_v1_tick_s", "number"],
        ["civsub_v1_scheduler_enabled", "bool"],
        ["civsub_v1_scheduler_s", "number"],
        ["civsub_v1_traffic_enabled", "bool"],
        ["civsub_v1_traffic_cap_global", "number"],
        ["civsub_v1_traffic_cap_perDistrict", "number"]
    ]],
    ["IED", [
        ["ARC_iedPhase1_siteSelectionEnabled", "bool"],
        ["ARC_iedPassiveDetectEnabled", "bool"],
        ["ARC_iedPassiveDetectRadiusM", "number"],
        ["ARC_iedProxRadiusM", "number"],
        ["ARC_eodDispoApprovalTTLsec", "number"]
    ]],
    ["VBIED", [
        ["ARC_vbiedPhase3_enabled", "bool"],
        ["ARC_vbiedDefuseActionEnabled", "bool"],
        ["ARC_vbiedDefuseWindowSeconds", "number"],
        ["ARC_vbiedCooldownSeconds", "number"],
        ["ARC_vbiedProxRadiusM", "number"],
        ["ARC_vbiedDrivenEnabled", "bool"],
        ["ARC_suicideBomberEnabled", "bool"],
        ["ARC_vbiedDrivenIntelLevel", "number"],
        ["ARC_vbiedDetonationCooldownS", "number"]
    ]],
    ["Airbase", [
        ["airbase_v1_tower_allowBnCmd", "bool"],
        ["airbase_v1_tower_authDebug", "bool"],
        ["airbase_v1_ambiance_enabled", "bool"],
        ["airbase_v1_runtime_enabled", "bool"]
    ]],
    ["SafeMode", [
        ["ARC_safeModeEnabled", "bool"],
        ["civsub_v1_traffic_enabled", "bool"],
        ["ARC_iedPhase1_siteSelectionEnabled", "bool"],
        ["ARC_vbiedPhase3_enabled", "bool"],
        ["airbase_v1_ambiance_enabled", "bool"],
        ["airbase_v1_runtime_enabled", "bool"]
    ]],
    ["WorldTime", [
        ["ARC_worldTime_enabled", "bool"],
        ["ARC_worldTime_forceDate", "bool"],
        ["ARC_worldTime_forceMultiplier", "bool"],
        ["ARC_worldTime_timeMultiplier", "number"],
        ["ARC_worldTime_broadcastIntervalSec", "number"]
    ]],
    ["UI/actions", [
        ["ARC_vanillaAddActionsEnabled", "bool"],
        ["ARC_rtbInWorldActionsEnabled", "bool"],
        ["ARC_tocAddActionsEnabled", "bool"],
        ["ARC_mobileTocAddActionsEnabled", "bool"],
        ["ARC_rtbAddActionsEnabled", "bool"],
        ["ARC_civsubContactAddActionsEnabled", "bool"],
        ["ARC_objectiveAddActionsEnabled", "bool"],
        ["ARC_iedEvidenceAddActionsEnabled", "bool"],
        ["ARC_recruitAddActionsEnabled", "bool"],
        ["ARC_sitrepInWorldActionsEnabled", "bool"],
        ["ARC_recruitContainerEnabled", "bool"],
        ["ARC_recruitContainerNetIds", "array"],
        ["ARC_recruitContainerNames", "array"],
        ["ARC_recruitActionRangeM", "number"],
        ["ARC_recruitGroupMaxUnits", "number"],
        ["ARC_recruitRequireSameFaction", "bool"],
        ["ARC_intelPropSpawnRadiusM", "number"]
    ]]
], true];

// Runtime config hygiene: warn when toggles declared here are not mapped to a known consumer.
private _arcDeclaredServerToggles = [
    "ARC_debugLogEnabled",
    "ARC_debugLogToChat",
    "ARC_devDebugInspectorEnabled",
    "ARC_debugInspectorEnabled",
    "ARC_objectiveScaffoldEnabled",
    "ARC_objectiveMeetUseAI",
    "ARC_patrolSpawnContactsEnabled",
    "ARC_vanillaAddActionsEnabled",
    "ARC_rtbInWorldActionsEnabled",
    "ARC_tocAddActionsEnabled",
    "ARC_mobileTocAddActionsEnabled",
    "ARC_rtbAddActionsEnabled",
    "ARC_civsubContactAddActionsEnabled",
    "ARC_objectiveAddActionsEnabled",
    "ARC_iedEvidenceAddActionsEnabled",
    "ARC_recruitAddActionsEnabled",
    "ARC_sitrepInWorldActionsEnabled",
    "ARC_recruitContainerEnabled",
    "ARC_recruitContainerClasses",
    "ARC_recruitContainerNetIds",
    "ARC_recruitContainerNames",
    "ARC_recruitActionRangeM",
    "ARC_recruitGroupMaxUnits",
    "ARC_recruitRequireSameFaction",
    "ARC_recruitCompanyCommandGroupIds",
    "ARC_recruitCommandRoleTokens",
    "ARC_recruitUnitWhitelist",
    "ARC_allowIncidentDuringAcceptedRtb",
    "ARC_safeModeEnabled",
    "ARC_worldTime_enabled",
    "ARC_worldTime_forceDate",
    "ARC_worldTime_startDate",
    "ARC_worldTime_forceMultiplier",
    "ARC_worldTime_timeMultiplier",
    "ARC_worldTime_broadcastIntervalSec",
    "ARC_worldTimeEvents_enabled",
    "ARC_worldTimeEvents_broadcastIntervalSec",
    "airbase_v1_runtime_enabled"
];

private _arcKnownToggleConsumers = [
    ["ARC_debugLogEnabled", "functions/core/fn_debugLog.sqf"],
    ["ARC_debugLogToChat", "functions/core/fn_debugLog.sqf"],
    ["ARC_devDebugInspectorEnabled", "initServer.sqf -> ARC_debugInspectorEnabled mirror"],
    ["ARC_debugInspectorEnabled", "functions/core/fn_tocInitPlayer.sqf"],
    ["ARC_objectiveScaffoldEnabled", "initServer.sqf (declared for future feature; not yet consumed)"],
    ["ARC_objectiveMeetUseAI", "initServer.sqf (declared for future feature; not yet consumed)"],
    ["ARC_patrolSpawnContactsEnabled", "functions/ops/fn_opsPatrolOnActivate.sqf"],
    ["ARC_vanillaAddActionsEnabled", "global default inherited by vanilla addAction clients"],
    ["ARC_rtbInWorldActionsEnabled", "legacy fallback for split RTB/TOC action toggles"],
    ["ARC_tocAddActionsEnabled", "functions/core/fn_tocInitPlayer.sqf"],
    ["ARC_mobileTocAddActionsEnabled", "functions/core/fn_tocInitPlayer.sqf (remote_ops_vehicle only)"],
    ["ARC_rtbAddActionsEnabled", "functions/intel/fn_intelInitClient.sqf"],
    ["ARC_civsubContactAddActionsEnabled", "functions/civsub/fn_civsubCivAddContactActions.sqf"],
    ["ARC_objectiveAddActionsEnabled", "functions/core/fn_clientAddObjectiveAction.sqf"],
    ["ARC_iedEvidenceAddActionsEnabled", "functions/ied/fn_iedClientAddEvidenceAction.sqf"],
    ["ARC_recruitAddActionsEnabled", "functions/logistics/fn_recruitClientAddActions.sqf"],
    ["ARC_sitrepInWorldActionsEnabled", "functions/core/fn_tocInitPlayer.sqf"],
    ["ARC_recruitContainerEnabled", "functions/logistics/fn_recruitClientInit.sqf + functions/logistics/fn_recruitSpawnRequest.sqf"],
    ["ARC_recruitContainerClasses", "functions/logistics/fn_recruitClientInit.sqf + functions/logistics/fn_recruitSpawnRequest.sqf"],
    ["ARC_recruitContainerNetIds", "functions/logistics/fn_recruitServerPublishContainers.sqf + functions/logistics/fn_recruitClientInit.sqf"],
    ["ARC_recruitContainerNames", "functions/logistics/fn_recruitServerPublishContainers.sqf (Eden variable-name opt-in)"],
    ["ARC_recruitActionRangeM", "functions/logistics/fn_recruitClientAddActions.sqf"],
    ["ARC_recruitGroupMaxUnits", "functions/logistics/fn_recruitSpawnRequest.sqf"],
    ["ARC_recruitRequireSameFaction", "declared default; fn_recruitSpawnRequest.sqf enforces same-faction unconditionally (see tests/static/recruitment_container_contract_checks.sh)"],
    ["ARC_recruitCompanyCommandGroupIds", "functions/core/fn_rolesCanRecruitAI.sqf"],
    ["ARC_recruitCommandRoleTokens", "functions/core/fn_rolesCanRecruitAI.sqf"],
    ["ARC_recruitUnitWhitelist", "functions/logistics/fn_recruitClientAddActions.sqf + functions/logistics/fn_recruitSpawnRequest.sqf"],
    ["ARC_allowIncidentDuringAcceptedRtb", "functions/core/fn_tocRequestNextIncident.sqf"],
    ["ARC_safeModeEnabled", "initServer.sqf + functions/core/fn_bootstrapServer.sqf + functions/core/fn_incidentCreate.sqf"],
    ["ARC_worldTime_enabled", "functions/core/fn_bootstrapServer.sqf"],
    ["ARC_worldTime_forceDate", "functions/core/fn_bootstrapServer.sqf"],
    ["ARC_worldTime_startDate", "functions/core/fn_bootstrapServer.sqf"],
    ["ARC_worldTime_forceMultiplier", "functions/core/fn_bootstrapServer.sqf"],
    ["ARC_worldTime_timeMultiplier", "functions/core/fn_bootstrapServer.sqf"],
    ["ARC_worldTime_broadcastIntervalSec", "functions/core/fn_bootstrapServer.sqf"],
    ["ARC_worldTimeEvents_enabled", "scripts/worldtime/worldtime_events_server.sqf"],
    ["ARC_worldTimeEvents_broadcastIntervalSec", "scripts/worldtime/worldtime_events_server.sqf"],
    ["airbase_v1_runtime_enabled", "functions/ambiance/fn_airbaseRuntimeEnabled.sqf"]
];

private _arcKnownToggleConsumerIndex = createHashMap;
private _arcHashGetOrDefault = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
{
    if (_x isEqualType [] && { (count _x) > 0 }) then
    {
        private _key = _x select 0;
        if (_key isEqualType "") then {
            _arcKnownToggleConsumerIndex set [_key, true];
        };
    };
} forEach _arcKnownToggleConsumers;

{
    private _toggle = _x;
    if (!([_arcKnownToggleConsumerIndex, _toggle, false] call _arcHashGetOrDefault)) then {
        diag_log format ["[ARC][CONFIG][WARN] Toggle '%1' is declared in initServer.sqf but missing from the known-consumer registry.", _toggle];
    };
} forEach _arcDeclaredServerToggles;

// Explicit server bootstrap ownership for AIRBASE scheduler startup.
diag_log "[ARC][AIRBASE][INIT] trigger start (initServer -> airbasePostInit)";
private _airbasePostInitOk = [] call ARC_fnc_airbasePostInit;
diag_log format ["[ARC][AIRBASE][INIT] trigger post result=%1", _airbasePostInitOk];

[] call ARC_fnc_bootstrapServer;

// ---------------------------------------------------------------------------
// World time events (Central Asian prayer/market schedule).
// Starts AFTER bootstrapServer because it waits for ARC_serverReady internally.
// ---------------------------------------------------------------------------
[] execVM "scripts\worldtime\worldtime_events_server.sqf";

// ---------------------------------------------------------------------------
// Government stats aggregate loop (low-frequency, same cadence as worldtime).
// Publishes ARC_govStats for client UI (Government Status / S2 sub-panels).
// ---------------------------------------------------------------------------
[] call ARC_fnc_govStatsScheduler;

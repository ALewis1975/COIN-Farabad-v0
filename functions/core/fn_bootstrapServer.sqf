/*
    Server bootstrap:
      - register world reference markers/zones
      - load persistent state
      - rehydrate active task if needed
      - publish public state snapshots (for TOC screens + briefing)
      - start incident loop
*/

if (!isServer) exitWith {};

// Build stamp (authoritative source is initServer.sqf)
private _buildStamp = missionNamespace getVariable ["ARC_buildStamp", "UNKNOWN"];
diag_log format ["[ARC][BUILD] %1", _buildStamp];

// Load editable classname pools/tunables (single source-of-truth).
// Safe: this file only sets values that are currently nil.
call compile preprocessFileLineNumbers "data\ARC_ConfigData.sqf";


enableDynamicSimulationSystem true;

// ---------------------------------------------------------------------------
// Mobile Ops vehicle: publish a stable reference and trigger client action rebinding
// when AI/locality swaps tend to wipe addActions.
// ---------------------------------------------------------------------------
[] spawn
{
    uiSleep 1;

    private _mob = missionNamespace getVariable ["remote_ops_vehicle", objNull];
    if (isNull _mob) exitWith { diag_log "[ARC][MOBILE OPS] remote_ops_vehicle not found; skipping EH install."; };

    missionNamespace setVariable ["ARC_mobileOpsVehicleNetId", netId _mob, true];

    if (isNil { missionNamespace getVariable "ARC_mobileOpsExpectedActionCount" }) then
    {
        // Keep in sync with the number of [MOBILE OPS]/[MOBILE QUEUE]/[MOBILE ORDER] actions in fn_tocInitPlayer.sqf
        missionNamespace setVariable ["ARC_mobileOpsExpectedActionCount", 17, true];
    };

    if (!(_mob getVariable ["ARC_mobileOps_ehInstalled", false])) then
    {
        _mob setVariable ["ARC_mobileOps_ehInstalled", true, true];

        _mob addEventHandler ["Local", {
            params ["_entity", "_isLocal"];
            missionNamespace setVariable ["ARC_mobileOpsVehicleNetId", netId _entity, true];
            [] remoteExecCall ["ARC_fnc_tocInitPlayer", 0];
        }];

        _mob addEventHandler ["GetIn", { [] remoteExecCall ["ARC_fnc_tocInitPlayer", 0]; }];
        _mob addEventHandler ["GetOut", { [] remoteExecCall ["ARC_fnc_tocInitPlayer", 0]; }];
    };
};


// --- Mission-tunable defaults (safe: only set when not already defined) ------
// Field SITREP proximity (meters). Server is authoritative; clients use this for UI gating.
if (isNil { missionNamespace getVariable "ARC_sitrepProximityM" }) then { missionNamespace setVariable ["ARC_sitrepProximityM", 50, true]; };
if (isNil { missionNamespace getVariable "ARC_convoySpacingPreLinkupM" }) then { missionNamespace setVariable ["ARC_convoySpacingPreLinkupM", 25]; };
if (isNil { missionNamespace getVariable "ARC_convoySpacingPostLinkupM" }) then { missionNamespace setVariable ["ARC_convoySpacingPostLinkupM", 50]; };
if (isNil { missionNamespace getVariable "ARC_convoySpacingM" }) then { missionNamespace setVariable ["ARC_convoySpacingM", 50]; }; // post-linkup spacing (active route)
if (isNil { missionNamespace getVariable "ARC_convoyDepartDelaySec" }) then { missionNamespace setVariable ["ARC_convoyDepartDelaySec", 120]; };
if (isNil { missionNamespace getVariable "ARC_convoyDetectRadiusM" }) then { missionNamespace setVariable ["ARC_convoyDetectRadiusM", 50]; };
if (isNil { missionNamespace getVariable "ARC_convoyForceFollowRoad" }) then { missionNamespace setVariable ["ARC_convoyForceFollowRoad", true]; };

// IEDSUB Phase 4: default approval TTL for EOD disposition requests (seconds)
if (isNil { missionNamespace getVariable "ARC_eodDispoApprovalTTLsec" }) then { missionNamespace setVariable ["ARC_eodDispoApprovalTTLsec", 900]; };

// Route recon segment length constraints (meters).
if (isNil { missionNamespace getVariable "ARC_routeReconMinLengthM" }) then { missionNamespace setVariable ["ARC_routeReconMinLengthM", 1000]; };
if (isNil { missionNamespace getVariable "ARC_routeReconMaxLengthM" }) then { missionNamespace setVariable ["ARC_routeReconMaxLengthM", 4000]; };

// Suspicious vehicle pools: if no dedicated VOI pool is provided, reuse the VBIED pool.
if (isNil { missionNamespace getVariable "ARC_voiVehicleClassPool" }) then
{
    private _vb = missionNamespace getVariable ["ARC_vbiedVehicleClassPool", []];
    if (!(_vb isEqualType [])) then { _vb = []; };
    missionNamespace setVariable ["ARC_voiVehicleClassPool", _vb];
};

// IED physical prop pool: vanilla IED objects + best-effort ACE/EODs classes (when present).
if (isNil { missionNamespace getVariable "ARC_iedObjectClassPool" }) then
{
    private _pool = [];

    // EODS v2 enhancements are optional. Default OFF to avoid mod-side regressions.
    // When OFF, we will not include EODS classnames in the random IED object pool.
    if (isNil { missionNamespace getVariable "ARC_eodsEnhancementsEnabled" }) then
    {
        missionNamespace setVariable ["ARC_eodsEnhancementsEnabled", false, true];
    };
    private _eodsOk = missionNamespace getVariable ["ARC_eodsEnhancementsEnabled", false];
    if (!(_eodsOk isEqualType true)) then { _eodsOk = false; };

    // Vanilla IED objects (always available in Arma 3).
    {
        if (isClass (configFile >> "CfgVehicles" >> _x)) then { _pool pushBackUnique _x; };
    } forEach ["IEDUrbanSmall_F", "IEDUrbanBig_F", "IEDLandSmall_F", "IEDLandBig_F"];

    // Scan config for mod-added IED props (best-effort). This avoids hardcoding uncertain classnames.
    private _cfg = configFile >> "CfgVehicles";
    for "_i" from 0 to ((count _cfg) - 1) do
    {
        private _c = _cfg select _i;
        if (!isClass _c) then { continue; };

        private _name = configName _c;
        private _n = toLower _name;

        if ((_n find "ied") < 0) then { continue; };

        // Filter common false-positives:
        //  - carried/carry helper classes
        //  - vehicles/modules/logics that should never spawn as a "suspicious object"
        if ((_n find "carried") >= 0 || { (_n find "carry") >= 0 }) then { continue; };
        if (_name isKindOf "AllVehicles" || { _name isKindOf "CAManBase" } || { _name isKindOf "Logic" } || { _name isKindOf "Module_F" }) then { continue; };
        if !(_name isKindOf "Thing") then { continue; };

        // Exclude ACE helper/module classes that should never be spawned as world objects.
        if ((_n find "ace_module") >= 0 || { (_n find "moduleexplosive") >= 0 }) then { continue; };
        if ((_n find "ace_explosives_place") >= 0 || { (_n find "_place_") >= 0 }) then { continue; };

        // Prefer ACE-compatible IED things. Only include EODS classes when explicitly enabled.
        if ((_n find "ace") >= 0) then { _pool pushBackUnique _name; continue; };
        if (_eodsOk && { (_n find "eods") >= 0 }) then { _pool pushBackUnique _name; continue; };
    };

    if (_pool isEqualTo []) then
    {
        // Ultra-safe fallback (should never be empty if vanilla content is present).
        _pool = ["IEDUrbanSmall_F", "IEDLandSmall_F"] select { isClass (configFile >> "CfgVehicles" >> _x) };
    };

    missionNamespace setVariable ["ARC_iedObjectClassPool", _pool, true];
    diag_log format ["[ARC][IED] IED object pool initialized (n=%1): %2", count _pool, _pool];
};

// IED detonation handling / assessment
if (isNil { missionNamespace getVariable "ARC_iedDetonationDetectRadiusM" }) then { missionNamespace setVariable ["ARC_iedDetonationDetectRadiusM", 120]; }; // explosion pos -> objective anchor gate
if (isNil { missionNamespace getVariable "ARC_iedDetonationAssessRadiusM" }) then { missionNamespace setVariable ["ARC_iedDetonationAssessRadiusM", 120]; }; // casualty scan radius
if (isNil { missionNamespace getVariable "ARC_iedCivSnapshotRadiusM" }) then { missionNamespace setVariable ["ARC_iedCivSnapshotRadiusM", 200]; }; // civilians tracked pre-detonation
if (isNil { missionNamespace getVariable "ARC_iedCivSnapshotIntervalSec" }) then { missionNamespace setVariable ["ARC_iedCivSnapshotIntervalSec", 10]; };

// IED Phase 1 (site selection + proximity trigger)
if (isNil { missionNamespace getVariable "ARC_iedPhase1_siteSelectionEnabled" }) then { missionNamespace setVariable ["ARC_iedPhase1_siteSelectionEnabled", true]; };
if (isNil { missionNamespace getVariable "ARC_iedSiteSearchRadiusM" }) then { missionNamespace setVariable ["ARC_iedSiteSearchRadiusM", 350]; };
if (isNil { missionNamespace getVariable "ARC_iedSiteAvoidAirbase" }) then { missionNamespace setVariable ["ARC_iedSiteAvoidAirbase", true]; };
if (isNil { missionNamespace getVariable "ARC_iedSitePickTries" }) then { missionNamespace setVariable ["ARC_iedSitePickTries", 48]; };
if (isNil { missionNamespace getVariable "ARC_iedSiteMinSeparationM" }) then { missionNamespace setVariable ["ARC_iedSiteMinSeparationM", 120]; };
if (isNil { missionNamespace getVariable "ARC_iedProxRadiusM" }) then { missionNamespace setVariable ["ARC_iedProxRadiusM", 7]; };
if (isNil { missionNamespace getVariable "ARC_iedPhase1_recordsCap" }) then { missionNamespace setVariable ["ARC_iedPhase1_recordsCap", 24]; };

// IED discovery UX controls
// - Keep "Scan" disabled by default; ACE tools + passive detection become the primary discovery method.
if (isNil { missionNamespace getVariable "ARC_iedScanActionEnabled" }) then { missionNamespace setVariable ["ARC_iedScanActionEnabled", false, true]; };
if (isNil { missionNamespace getVariable "ARC_iedPassiveDetectEnabled" }) then { missionNamespace setVariable ["ARC_iedPassiveDetectEnabled", true, true]; };
if (isNil { missionNamespace getVariable "ARC_iedPassiveDetectRadiusM" }) then { missionNamespace setVariable ["ARC_iedPassiveDetectRadiusM", 12, true]; };


// IED Phase 2 (evidence / follow-on lead)
if (isNil { missionNamespace getVariable "ARC_iedEvidenceClass" }) then { missionNamespace setVariable ["ARC_iedEvidenceClass", "Land_File1_F"]; };
if (isNil { missionNamespace getVariable "ARC_iedEvidenceSpawnRadiusM" }) then { missionNamespace setVariable ["ARC_iedEvidenceSpawnRadiusM", 6]; };
if (isNil { missionNamespace getVariable "ARC_iedEvidenceFollowOnLeadChance" }) then { missionNamespace setVariable ["ARC_iedEvidenceFollowOnLeadChance", 0.55]; };


// IED Phase 3 (VBIED v1)
if (isNil { missionNamespace getVariable "ARC_vbiedPhase3_enabled" }) then { missionNamespace setVariable ["ARC_vbiedPhase3_enabled", true]; };
if (isNil { missionNamespace getVariable "ARC_vbiedCooldownSeconds" }) then { missionNamespace setVariable ["ARC_vbiedCooldownSeconds", 1800]; }; // 30m
if (isNil { missionNamespace getVariable "ARC_vbiedProxRadiusM" }) then { missionNamespace setVariable ["ARC_vbiedProxRadiusM", 12]; };
if (isNil { missionNamespace getVariable "ARC_vbiedTelegraphIntelLog" }) then { missionNamespace setVariable ["ARC_vbiedTelegraphIntelLog", true]; };
if (isNil { missionNamespace getVariable "ARC_vbiedExplosionClass" }) then { missionNamespace setVariable ["ARC_vbiedExplosionClass", "Bo_Mk82"]; };
if (isNil { missionNamespace getVariable "ARC_vbiedPhase3_recordsCap" }) then { missionNamespace setVariable ["ARC_vbiedPhase3_recordsCap", 12]; };

// VBIED site selection (vehicle-class aware)
if (isNil { missionNamespace getVariable "ARC_vbiedSiteAvoidAirbase" }) then { missionNamespace setVariable ["ARC_vbiedSiteAvoidAirbase", true]; };
if (isNil { missionNamespace getVariable "ARC_vbiedSitePickTries" }) then { missionNamespace setVariable ["ARC_vbiedSitePickTries", 36]; };
if (isNil { missionNamespace getVariable "ARC_vbiedSiteSlopeMax" }) then { missionNamespace setVariable ["ARC_vbiedSiteSlopeMax", 0.22]; };


// Cleanup tuning (smaller radii avoid "base keeps everything alive forever")
if (isNil { missionNamespace getVariable "ARC_cleanupRadiusConvoyM" }) then { missionNamespace setVariable ["ARC_cleanupRadiusConvoyM", 300]; };
if (isNil { missionNamespace getVariable "ARC_cleanupRadiusRouteSupportM" }) then { missionNamespace setVariable ["ARC_cleanupRadiusRouteSupportM", 450]; };

// Route security should not be permanent by default (can be overridden per mission)
if (isNil { missionNamespace getVariable "ARC_routeSupportPersistInAO" }) then { missionNamespace setVariable ["ARC_routeSupportPersistInAO", false]; };

// Recon/observation tasks: allow stand-off observation
if (isNil { missionNamespace getVariable "ARC_reconObservationRadiusM" }) then { missionNamespace setVariable ["ARC_reconObservationRadiusM", 500]; };

// Intel prop pool for raids/safehouses. Keeps objectives from feeling like "all briefcases".
if (isNil { missionNamespace getVariable "ARC_intelPropClassPool" }) then
{
    private _pool = [];
    {
        if (isClass (configFile >> "CfgVehicles" >> _x)) then { _pool pushBackUnique _x; };
    } forEach [
        "Land_Laptop_F",
        "Land_SatellitePhone_F",
        "Land_MobilePhone_smart_F",
        "Land_Map_F",
        "Land_File1_F",
        "Land_File2_F",
        "Land_FilePhotos_F",
        "Land_File_research_F"
    ];

    if (_pool isEqualTo []) then { _pool = ["Land_File1_F"]; };
    missionNamespace setVariable ["ARC_intelPropClassPool", _pool];
};

if (isNil { missionNamespace getVariable "ARC_convoyBridgeSpeedKph" }) then { missionNamespace setVariable ["ARC_convoyBridgeSpeedKph", 18]; };
if (isNil { missionNamespace getVariable "ARC_convoyBridgeSpacingM" }) then { missionNamespace setVariable ["ARC_convoyBridgeSpacingM", 35]; };
if (isNil { missionNamespace getVariable "ARC_convoyBridgeMarkerPrefix" }) then { missionNamespace setVariable ["ARC_convoyBridgeMarkerPrefix", "arc_bridge_"]; };

// Cache mission-maker authored bridge areas (arc_bridge_* markers) for convoy bridge handling.
private _bridgePrefix = toLower (missionNamespace getVariable ["ARC_convoyBridgeMarkerPrefix", "arc_bridge_"]);
private _bridgeMarkers = allMapMarkers select
{
    private _n = toLower _x;
    (_n find _bridgePrefix) == 0 && { (toUpper (markerShape _x)) != "ICON" }
};
missionNamespace setVariable ["ARC_bridgeMarkers", _bridgeMarkers];
diag_log format ["[ARC][BRIDGE] Loaded %1 bridge markers (prefix %2): %3", count _bridgeMarkers, _bridgePrefix, _bridgeMarkers];



// Simple sequential convoy spawn (avoids collisions on busy pads).
// IMPORTANT: Large convoys need time to clear the spawn marker before the next vehicle appears.
// Default is intentionally conservative; mission makers can override higher if needed.
if (isNil { missionNamespace getVariable "ARC_convoySpawnIntervalSec" }) then { missionNamespace setVariable ["ARC_convoySpawnIntervalSec", 10]; };
if (isNil { missionNamespace getVariable "ARC_convoySpawnPadClearRadiusM" }) then { missionNamespace setVariable ["ARC_convoySpawnPadClearRadiusM", 25]; };

// Spawn pad kick: a small shove so vehicles actually leave the pad (avoids infinite pad-block waits).
if (isNil { missionNamespace getVariable "ARC_convoySpawnPadKickEnabled" }) then { missionNamespace setVariable ["ARC_convoySpawnPadKickEnabled", true]; };
if (isNil { missionNamespace getVariable "ARC_convoySpawnPadKickTimeoutSec" }) then { missionNamespace setVariable ["ARC_convoySpawnPadKickTimeoutSec", 8]; };

// Spawn staging: prevents "overtake racing" while vehicles are still assembling on the spawn pad.
if (isNil { missionNamespace getVariable "ARC_convoySpawnStagingEnabled" }) then { missionNamespace setVariable ["ARC_convoySpawnStagingEnabled", true]; };
if (isNil { missionNamespace getVariable "ARC_convoySpawnStageSpeedKph" }) then { missionNamespace setVariable ["ARC_convoySpawnStageSpeedKph", 12]; };
// If < 0, execSpawnConvoy auto-computes spacing from pad-clear radius and desired convoy spacing.
if (isNil { missionNamespace getVariable "ARC_convoySpawnStageSpacingM" }) then { missionNamespace setVariable ["ARC_convoySpawnStageSpacingM", -1]; };
if (isNil { missionNamespace getVariable "ARC_convoySpawnStageMaxDistM" }) then { missionNamespace setVariable ["ARC_convoySpawnStageMaxDistM", 350]; };
if (isNil { missionNamespace getVariable "ARC_convoySpawnStageRoadSnapM" }) then { missionNamespace setVariable ["ARC_convoySpawnStageRoadSnapM", 80]; };

// Convoy speed + crew perception tuning (AI driving stability + better escort behavior)
if (isNil { missionNamespace getVariable "ARC_convoySpeedKph" }) then { missionNamespace setVariable ["ARC_convoySpeedKph", 35]; };
if (isNil { missionNamespace getVariable "ARC_convoySpeedKph_logistics" }) then { missionNamespace setVariable ["ARC_convoySpeedKph_logistics", 30]; };
if (isNil { missionNamespace getVariable "ARC_convoySpeedKph_escort" }) then { missionNamespace setVariable ["ARC_convoySpeedKph_escort", 40]; };
if (isNil { missionNamespace getVariable "ARC_convoySpeedKphMax" }) then { missionNamespace setVariable ["ARC_convoySpeedKphMax", 45]; };

if (isNil { missionNamespace getVariable "ARC_convoyDriverSpotDistance" }) then { missionNamespace setVariable ["ARC_convoyDriverSpotDistance", 1]; };
if (isNil { missionNamespace getVariable "ARC_convoyDriverSpotTime" }) then { missionNamespace setVariable ["ARC_convoyDriverSpotTime", 1]; };

// Reset behavior: reroll strategic levers on ResetAll (testing convenience)
if (isNil { missionNamespace getVariable "ARC_resetRerollEnvironment" }) then { missionNamespace setVariable ["ARC_resetRerollEnvironment", true]; };

// Edge-start convoy behavior (spawn at map edge, move to link-up, then wait for escort)
if (isNil { missionNamespace getVariable "ARC_convoyUseEdgeStartsChance" }) then { missionNamespace setVariable ["ARC_convoyUseEdgeStartsChance", 0.45]; };
if (isNil { missionNamespace getVariable "ARC_convoyEdgeSpawnInsetM" }) then { missionNamespace setVariable ["ARC_convoyEdgeSpawnInsetM", 60]; };
// Road snap radius for convoy spawn and edge link-up generation.
if (isNil { missionNamespace getVariable "ARC_convoyRoadSnapM" }) then { missionNamespace setVariable ["ARC_convoyRoadSnapM", 120]; };
// Edge-start link-up distance (meters). Keep it long enough to feel inbound, but not so long that escorts lag behind.
if (isNil { missionNamespace getVariable "ARC_convoyLinkupDistM" }) then { missionNamespace setVariable ["ARC_convoyLinkupDistM", 650]; };
if (isNil { missionNamespace getVariable "ARC_convoyLinkupTowardAirbaseM" }) then { missionNamespace setVariable ["ARC_convoyLinkupTowardAirbaseM", 500]; };
if (isNil { missionNamespace getVariable "ARC_convoyLinkupMinEdgeInsetM" }) then { missionNamespace setVariable ["ARC_convoyLinkupMinEdgeInsetM", 200]; };
// Stronger turn penalty helps keep link-up points on the same inbound road (reduces "parallel road" outcomes).
if (isNil { missionNamespace getVariable "ARC_convoyLinkupTurnPenaltyMperDeg" }) then { missionNamespace setVariable ["ARC_convoyLinkupTurnPenaltyMperDeg", 4.0]; };

// Convoy scaling (vehicle count, cohesion, route helpers)
if (isNil { missionNamespace getVariable "ARC_convoyMaxVehicles" }) then { missionNamespace setVariable ["ARC_convoyMaxVehicles", 10]; };
if (isNil { missionNamespace getVariable "ARC_convoySpacingLargeM" }) then { missionNamespace setVariable ["ARC_convoySpacingLargeM", 50]; };
if (isNil { missionNamespace getVariable "ARC_convoySpacingHugeM" }) then { missionNamespace setVariable ["ARC_convoySpacingHugeM", 75]; };

// Cohesion controller (slows the convoy when a vehicle falls back)
if (isNil { missionNamespace getVariable "ARC_convoyCatchupEnabled" }) then { missionNamespace setVariable ["ARC_convoyCatchupEnabled", true]; };
if (isNil { missionNamespace getVariable "ARC_convoyCatchupGapSlowFactor" }) then { missionNamespace setVariable ["ARC_convoyCatchupGapSlowFactor", 2.2]; };
if (isNil { missionNamespace getVariable "ARC_convoyCatchupGapHoldFactor" }) then { missionNamespace setVariable ["ARC_convoyCatchupGapHoldFactor", 3.4]; };
if (isNil { missionNamespace getVariable "ARC_convoyCatchupMinSpeedKph" }) then { missionNamespace setVariable ["ARC_convoyCatchupMinSpeedKph", 10]; };
if (isNil { missionNamespace getVariable "ARC_convoyCatchupHoldSpeedKph" }) then { missionNamespace setVariable ["ARC_convoyCatchupHoldSpeedKph", 8]; };

// Arrival completion: require most of the convoy to be at the destination before the incident closes.
if (isNil { missionNamespace getVariable "ARC_convoyArrivalFraction" }) then { missionNamespace setVariable ["ARC_convoyArrivalFraction", 0.75]; };
if (isNil { missionNamespace getVariable "ARC_convoyArrivalMinVehicles" }) then { missionNamespace setVariable ["ARC_convoyArrivalMinVehicles", 2]; };

// Route helpers
if (isNil { missionNamespace getVariable "ARC_convoyRouteMarkersEnabled" }) then { missionNamespace setVariable ["ARC_convoyRouteMarkersEnabled", true]; };
if (isNil { missionNamespace getVariable "ARC_convoyRouteMarkerCount" }) then { missionNamespace setVariable ["ARC_convoyRouteMarkerCount", 10]; };
if (isNil { missionNamespace getVariable "ARC_convoyRouteMarkerAlpha" }) then { missionNamespace setVariable ["ARC_convoyRouteMarkerAlpha", 0.35]; };
if (isNil { missionNamespace getVariable "ARC_convoyWaypointMin" }) then { missionNamespace setVariable ["ARC_convoyWaypointMin", 8]; };
if (isNil { missionNamespace getVariable "ARC_convoyWaypointMax" }) then { missionNamespace setVariable ["ARC_convoyWaypointMax", 12]; };
if (isNil { missionNamespace getVariable "ARC_convoyWaypointIntervalM" }) then { missionNamespace setVariable ["ARC_convoyWaypointIntervalM", 450]; };

// Deadline model for convoys: factor to approximate road distance vs straight-line distance.
if (isNil { missionNamespace getVariable "ARC_convoyETAFactor" }) then { missionNamespace setVariable ["ARC_convoyETAFactor", 1.35]; };

// Recovery behavior: allow off-road bypass only when far from destination (prevents TOC shortcut issues).
if (isNil { missionNamespace getVariable "ARC_convoyAllowOffroadRecovery" }) then { missionNamespace setVariable ["ARC_convoyAllowOffroadRecovery", true]; };
if (isNil { missionNamespace getVariable "ARC_convoyOffroadRecoveryMinDistToDestM" }) then { missionNamespace setVariable ["ARC_convoyOffroadRecoveryMinDistToDestM", 1200]; };

// Role-specific RHS vehicle pools (filtered by isClass at spawn time)
if (isNil { missionNamespace getVariable "ARC_rhsConvoyCargoPool_general" }) then
{
    missionNamespace setVariable ["ARC_rhsConvoyCargoPool_general", [
        "rhsusf_m1083a1p2_d_fmtv_usarmy",
        "rhsusf_m1083a1p2_d_open_fmtv_usarmy",
        "rhsusf_m977a4_usarmy_d"
    ]];
};

if (isNil { missionNamespace getVariable "ARC_rhsConvoyCargoPool_fuel" }) then
{
    missionNamespace setVariable ["ARC_rhsConvoyCargoPool_fuel", [
        "rhsusf_m978a4_usarmy_d",
        "rhsusf_m978a4_bkit_usarmy_d"
    ]];
};

if (isNil { missionNamespace getVariable "ARC_rhsConvoyCargoPool_ammo" }) then
{
    missionNamespace setVariable ["ARC_rhsConvoyCargoPool_ammo", [
        "rhsusf_m977a4_ammo_usarmy_d",
        "rhsusf_m1078a1p2_d_flatbed_fmtv_usarmy"
    ]];
};

if (isNil { missionNamespace getVariable "ARC_rhsConvoyCargoPool_med" }) then
{
    missionNamespace setVariable ["ARC_rhsConvoyCargoPool_med", [
        "rhsusf_m997_ambulance_usarmy_d"
    ]];
};

if (isNil { missionNamespace getVariable "ARC_rhsConvoyCargoPool_hq" }) then
{
    // Command/shelter-ish vehicles (best-effort; filtered by isClass at runtime).
    missionNamespace setVariable ["ARC_rhsConvoyCargoPool_hq", [
        "rhsusf_m1085a1p2_b_d_fmtv_usarmy"
    ]];
};

if (isNil { missionNamespace getVariable "ARC_rhsConvoyCargoPool_maint" }) then
{
    missionNamespace setVariable ["ARC_rhsConvoyCargoPool_maint", [
        "rhsusf_m984a4_usarmy_d",
        "rhsusf_m977a4_repair_bkit_usarmy_d"
    ]];
};

// --- Convoy vehicle pools (default) ------------------------------------------
// These can be overridden by missionNamespace variables before/after bootstrap.
// NOTE: At spawn time, vehicle class validity and side are still filtered with isClass/side checks.

// Lead security element (US Army, desert)
if (isNil { missionNamespace getVariable "ARC_convoyVehiclesLead" }) then
{
    missionNamespace setVariable ["ARC_convoyVehiclesLead", [
        "rhsusf_M1232_M2_usarmy_d",
        "rhsusf_M1232_MK19_usarmy_d"
    ]];
};

// Generic escort pool (US Army, desert). Escort convoys may additionally inject SUV/Police vehicles.
if (isNil { missionNamespace getVariable "ARC_convoyVehiclesEscort" }) then
{
    missionNamespace setVariable ["ARC_convoyVehiclesEscort", [
        "rhsusf_M1232_M2_usarmy_d",
        "rhsusf_M1232_MK19_usarmy_d"
    ]];
};

// Generic logistics pool (US Army, desert). LOGISTICS convoys will also pull from the role-specific pools.
if (isNil { missionNamespace getVariable "ARC_convoyVehiclesLogistics" }) then
{
    missionNamespace setVariable ["ARC_convoyVehiclesLogistics", [
        "rhsusf_m1083a1p2_d_fmtv_usarmy",
        "rhsusf_m1083a1p2_d_open_fmtv_usarmy",
        "rhsusf_m977a4_usarmy_d",
        "rhsusf_m978a4_usarmy_d",
        "rhsusf_m997_ambulance_usarmy_d"
    ]];
};

if (isNil { missionNamespace getVariable "ARC_debugConvoyLinkup" }) then { missionNamespace setVariable ["ARC_debugConvoyLinkup", false]; };
// Larger snap radius reduces last-segment offroad shortcuts near airbase/FOBs where objectives may sit off the road grid.
if (isNil { missionNamespace getVariable "ARC_convoyDestSnapM" }) then { missionNamespace setVariable ["ARC_convoyDestSnapM", 250]; };
if (isNil { missionNamespace getVariable "ARC_convoyBypassWindowSec" }) then { missionNamespace setVariable ["ARC_convoyBypassWindowSec", 18]; };

// Spawned group naming (editor-style group IDs)
if (isNil { missionNamespace getVariable "ARC_unitBnReg" }) then { missionNamespace setVariable ["ARC_unitBnReg", "2-325"]; };
if (isNil { missionNamespace getVariable "ARC_unitType" }) then { missionNamespace setVariable ["ARC_unitType", "AIR"]; };
if (isNil { missionNamespace getVariable "ARC_unitCallsign" }) then { missionNamespace setVariable ["ARC_unitCallsign", "REDFALCON"]; };
if (isNil { missionNamespace getVariable "ARC_unitCompanyLetters" }) then { missionNamespace setVariable ["ARC_unitCompanyLetters", ["A","B","C","D"]]; };
if (isNil { missionNamespace getVariable "ARC_unitMaxPlatoons" }) then { missionNamespace setVariable ["ARC_unitMaxPlatoons", 4]; };
if (isNil { missionNamespace getVariable "ARC_unitMaxSquads" }) then { missionNamespace setVariable ["ARC_unitMaxSquads", 4]; };

// Convoy ORBAT (82nd-themed, logistics/support + higher-echelon escort elements)
// Profile format: [bnReg, unitType, callsign, companyDesignators, maxPlatoons, maxSquads]
if (isNil { missionNamespace getVariable "ARC_orbatConvoyProfiles_logistics" }) then
{
    missionNamespace setVariable ["ARC_orbatConvoyProfiles_logistics", [
        // Sustainment / distribution style
        ["82", "SUST", "LONGHAUL", ["HHC","A","B","C"], 3, 4],
        ["407", "BSB",  "PROVIDER", ["HHC","A","B","C"], 3, 4],
        ["307", "BSB",  "LIFELINE", ["HHC","A","B"],     3, 4],
        ["82", "TRANS", "ROADRUNNER", ["A","B","C"],     3, 4],
        ["82", "MAINT", "FIXIT",     ["HHC","A"],         2, 4],
        ["82", "MED",   "ANGEL",     ["HHC","A"],         2, 4]
    ]];
};

if (isNil { missionNamespace getVariable "ARC_orbatConvoyProfiles_escort" }) then
{
    missionNamespace setVariable ["ARC_orbatConvoyProfiles_escort", [
        // Higher echelon / security flavored escort tasking
        ["82DIV", "DIV", "ALLAMERICAN", ["HHC"],             4, 4],
        ["82",    "MP",  "LAWDAWG",     ["A","B"],         3, 4],
        ["82",    "ENG", "SAPPER",      ["A","B"],         3, 4],
        ["82",    "SIG", "PATCHCORD",   ["HHC","A"],       2, 4],
        // Occasionally pull escorts from a combat unit
        ["2-325", "AIR", "REDFALCON",   ["A","B","C","D"], 4, 4]
    ]];
};

// Debug: show hidden convoy spawn markers (default false)
if (isNil { missionNamespace getVariable "ARC_debugShowConvoySpawnMarker" }) then { missionNamespace setVariable ["ARC_debugShowConvoySpawnMarker", false]; };

// Reset behavior: suppress auto incident creation briefly after ResetAll
if (isNil { missionNamespace getVariable "ARC_resetAutoIncidentHoldSec" }) then { missionNamespace setVariable ["ARC_resetAutoIncidentHoldSec", 300]; };

// Build world reference layer first (so incidents can safely use ARC_loc_* markers)
[] call ARC_fnc_worldInit;

// Load persistent COIN state
[] call ARC_fnc_stateLoad;

// Threat v0 + IED P1 (server-only)
[] call ARC_fnc_threatInit;

// CIVSUB v1 (district influence + identity plumbing)
if (missionNamespace getVariable ["civsub_v1_enabled", false]) then
{
    [] call ARC_fnc_civsubInitServer;
};

// Mirror persisted SITREP gating state into missionNamespace for clients
missionNamespace setVariable ["ARC_activeIncidentSitrepSent", ["activeIncidentSitrepSent", false] call ARC_fnc_stateGet, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepFrom", ["activeIncidentSitrepFrom", ""] call ARC_fnc_stateGet, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepSummary", ["activeIncidentSitrepSummary", ""] call ARC_fnc_stateGet, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepDetails", ["activeIncidentSitrepDetails", ""] call ARC_fnc_stateGet, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepAnnexCivsub", ["activeIncidentSitrepAnnexCivsub", ""] call ARC_fnc_stateGet, true];


// Recreate parent "case" tasks for any persisted threads (tasks don't persist across restarts).
[] call ARC_fnc_threadRehydrateParents;

// If state says we had an active incident but tasks were wiped by a restart,
// recreate the task now.
[] call ARC_fnc_taskRehydrateActive;

// Ensure the active incident has an execution plan (objective + timers).
[] call ARC_fnc_execInitActive;

// ---------------------------------------------------------------------------
// Global IED detonation catcher (disabled)
//
// NOTE:
//   addMissionEventHandler does NOT support an "Explosion" mission event type.
//   "Explosion" is an OBJECT/UNIT event handler (addEventHandler) and will throw
//   a load-time error if used as a mission EH.
//
// Current approach:
//   - IED/VBIED objectives install object-level Explosion/Killed handlers in
//     ARC_fnc_execInitActive.
//   - If we later need a true mission-wide catcher, implement it via projectile
//     tracking, ACE events, or a monitored objective-anchor radius loop.
// ---------------------------------------------------------------------------

// Public convoy anchors (for client-side SITREP proximity gating)
missionNamespace setVariable ["ARC_activeConvoyNetIds", ["activeConvoyNetIds", []] call ARC_fnc_stateGet, true];

// Intel layer init (TOC queue, orders, metrics sampling)
[] call ARC_fnc_intelInit;

// Publish initial snapshots for clients (JIP-safe)
[] call ARC_fnc_publicBroadcastState;
[] call ARC_fnc_intelBroadcast;
[] call ARC_fnc_iedDispoBroadcast;
[] call ARC_fnc_leadBroadcast;
[] call ARC_fnc_threadBroadcast;

// UI coverage audit (publishes ARC_uiCoverageMap)
[] call ARC_fnc_uiCoverageAuditServer;


// Phase 6 closeout: best-effort save on mission end / shutdown.
if (isNil { missionNamespace getVariable 'ARC_missionEndSaveEH' }) then
{
    private _eh = addMissionEventHandler ["Ended", {
        if (isServer) then
        {
            if (missionNamespace getVariable ["civsub_v1_enabled", false]) then
            {
                if (!isNil "ARC_fnc_civsubPersistSave") then { [] call ARC_fnc_civsubPersistSave; };
            };
            [] call ARC_fnc_stateSave;
        };
    }];
    missionNamespace setVariable ['ARC_missionEndSaveEH', _eh];
};

// Start the incident loop
[] call ARC_fnc_incidentLoop;

// Start the execution loop (checks end states / objective completion)
[] call ARC_fnc_execLoop;

// Start incident watchdog (stall detector / close-ready suggestions)
if (!isNil "ARC_fnc_incidentWatchdogLoop") then { [] call ARC_fnc_incidentWatchdogLoop; };

// Publish server readiness flag for clients (initPlayerLocal gate)

// ---------------------------------------------------------------------------
// WORLD TIME v1 (Phase 3)
// - Conservative defaults: does NOT force date or timeMultiplier unless toggles are set.
// - Server-owned snapshot broadcast for UI/systems: ARC_worldTimeSnap, ARC_worldTime_dayPhase
// - No external scripts; no CfgFunctions edits.
// ---------------------------------------------------------------------------
if (isServer) then
{
    private _wtEnabled = missionNamespace getVariable ["ARC_worldTime_enabled", true];
    if (_wtEnabled) then
    {
        if !(missionNamespace getVariable ["ARC_worldTime_running", false]) then
        {
            missionNamespace setVariable ["ARC_worldTime_running", true];

            private _interval = missionNamespace getVariable ["ARC_worldTime_broadcastIntervalSec", 45];

            private _thr = missionNamespace getVariable ["ARC_worldTime_phaseThresholds", [5.5, 9.0, 17.0, 20.5]];
            if !(_thr isEqualType [] && {count _thr == 4}) then { _thr = [5.5, 9.0, 17.0, 20.5]; };

            private _forceDate = missionNamespace getVariable ["ARC_worldTime_forceDate", false];
            private _startDate = missionNamespace getVariable ["ARC_worldTime_startDate", [2011,7,1,6,0]];
            if !(_startDate isEqualType [] && {count _startDate >= 5}) then { _startDate = [2011,7,1,6,0]; };

            private _forceMult = missionNamespace getVariable ["ARC_worldTime_forceMultiplier", false];
            private _mult = missionNamespace getVariable ["ARC_worldTime_timeMultiplier", 4];

            if (_forceDate) then { setDate _startDate; };
            if (_forceMult) then { setTimeMultiplier _mult; };

            // Publish once immediately, then on a low-frequency loop.
            private _publishOnce = {
                params ["_thr"];
                private _d = date;
                private _dt = daytime;

                private _tNightEnd = _thr # 0;
                private _tMorningEnd = _thr # 1;
                private _tWorkEnd = _thr # 2;
                private _tEveningEnd = _thr # 3;

                private _phase = "NIGHT";
                if (_dt < _tNightEnd) then { _phase = "NIGHT"; }
                else
                {
                    if (_dt < _tMorningEnd) then { _phase = "MORNING"; }
                    else
                    {
                        if (_dt < _tWorkEnd) then { _phase = "WORK"; }
                        else
                        {
                            if (_dt < _tEveningEnd) then { _phase = "EVENING"; }
                            else { _phase = "NIGHT"; };
                        };
                    };
                };

                private _snap = [_d, _dt, _phase, timeMultiplier, serverTime];
                missionNamespace setVariable ["ARC_worldTimeSnap", _snap, true];
                missionNamespace setVariable ["ARC_worldTime_dayPhase", _phase, true];
            };

            [_thr] call _publishOnce;
            diag_log format [
                "[ARC][WORLD TIME] started (interval=%1s forceDate=%2 forceMult=%3) snap=%4",
                _interval, _forceDate, _forceMult, (missionNamespace getVariable ["ARC_worldTimeSnap", []])
            ];

            private _h = [_interval, _thr] spawn {
                params ["_interval", "_thr"];
                while { missionNamespace getVariable ["ARC_worldTime_running", false] } do
                {
                    // Inline publish (avoid external dependencies and scoping issues)
                    private _d = date;
                    private _dt = daytime;

                    private _tNightEnd = _thr # 0;
                    private _tMorningEnd = _thr # 1;
                    private _tWorkEnd = _thr # 2;
                    private _tEveningEnd = _thr # 3;

                    private _phase = "NIGHT";
                    if (_dt < _tNightEnd) then { _phase = "NIGHT"; }
                    else
                    {
                        if (_dt < _tMorningEnd) then { _phase = "MORNING"; }
                        else
                        {
                            if (_dt < _tWorkEnd) then { _phase = "WORK"; }
                            else
                            {
                                if (_dt < _tEveningEnd) then { _phase = "EVENING"; }
                                else { _phase = "NIGHT"; };
                            };
                        };
                    };

                    private _snap = [_d, _dt, _phase, timeMultiplier, serverTime];
                    missionNamespace setVariable ["ARC_worldTimeSnap", _snap, true];
                    missionNamespace setVariable ["ARC_worldTime_dayPhase", _phase, true];

                    sleep _interval;
                };
            };
            missionNamespace setVariable ["ARC_worldTime_loopHandle", _h];
        };
    };
};
// ---------------------------------------------------------------------------

missionNamespace setVariable ["ARC_serverReady", true, true];
diag_log "[ARC][CORE] ARC_serverReady = true";

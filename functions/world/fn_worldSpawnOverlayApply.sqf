/*
    ARC_fnc_worldSpawnOverlayApply

    Server: spawn the transient task overlay (AI + objects) resolved by
    ARC_fnc_worldSpawnPatternResolve for an active Incident / Lead / civic
    mission (issue #633 step 4/7/8).

    Bounded + cleanup-owned by design:
      - Skips entirely in safe mode (ARC_safeModeEnabled) and when the overlay
        toggle (ARC_incidentOverlaySpawnsEnabled) is off.
      - Clamps total AI to ARC_overlayMaxAiPerIncident and hostile (east) AI to
        ARC_overlayMaxHostilesPerIncident so overlay OPFOR shares the physical
        OPFOR budget rather than stacking on top of the virtual pool.
      - Clamps objects to ARC_overlayMaxObjectsPerIncident.
      - Placement uses bounded radial offsets around the anchor (no unbounded
        nearestObjects / buildingPos scans). The only nearestObjects call is the
        small parked-vehicle collision guard, run once at init (not in a tick).
      - De-dup guard: when a SitePop site is already active near the anchor,
        ambient civilian roles SitePop already provides are suppressed so the
        overlay does not double-spawn the same functional role.
      - Every spawned unit/group/object is tagged ARC_overlaySpawn and returned
        as a NetId list so ARC_fnc_execCleanupActive can despawn it on close.

    Class pools are resolved per role via ARC_fnc_worldSpawnRoleResolve (units)
    and a curated vanilla object map (objects), both filtered against
    CfgVehicles so absent classes are skipped without RPT spam.

    Params:
        0: ARRAY  — merged overlay def (return of ARC_fnc_worldSpawnPatternResolve):
                    [["overlay",ROLES],["objects",OBJS],["placement",STR],...]
        1: ARRAY  — anchor world position [x,y,z] (ATL).
        2: NUMBER — task AO radius (meters); placement offsets are derived from it.
        3: STRING — taskId (for tagging/logging).

    Returns: ARRAY — NetId strings of every spawned unit and object (possibly empty).
*/

if (!isServer) exitWith {[]};

params [
    ["_def",    [], [[]]],
    ["_anchor", [], [[]]],
    ["_radius", 80, [0]],
    ["_taskId", "", [""]]
];

if ((count _def) == 0) exitWith {[]};
if (!(_anchor isEqualType []) || { (count _anchor) < 2 }) exitWith {[]};

// Hard gates: toggle + safe mode.
private _enabled = missionNamespace getVariable ["ARC_incidentOverlaySpawnsEnabled", false];
if (!(_enabled isEqualType true) || { !_enabled }) exitWith {[]};
private _safe = missionNamespace getVariable ["ARC_safeModeEnabled", false];
if (_safe isEqualType true && { _safe }) exitWith {
    diag_log "[ARC][SPAWNPAT][INFO] ARC_fnc_worldSpawnOverlayApply: safe mode active — overlay spawn skipped.";
    []
};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _pairsToMap = {
    params ["_pairs"];
    private _m = createHashMap;
    if (!(_pairs isEqualType [])) exitWith { _m };
    { if (_x isEqualType [] && { (count _x) >= 2 }) then { _m set [_x select 0, _x select 1]; }; } forEach _pairs;
    _m
};

private _m       = [_def] call _pairsToMap;
private _roles   = [_m, "overlay", []] call _hg;
private _objects = [_m, "objects", []] call _hg;
private _source  = [_m, "source", ""] call _hg;
if (!(_roles isEqualType [])) then { _roles = []; };
if (!(_objects isEqualType [])) then { _objects = []; };

private _p3 = +_anchor;
if ((count _p3) < 3) then { _p3 pushBack 0; };
private _r = _radius;
if (!(_r isEqualType 0) || { _r <= 0 }) then { _r = 80; };
_r = (_r max 20) min 400;

// --- Caps -----------------------------------------------------------------
private _maxAi = missionNamespace getVariable ["ARC_overlayMaxAiPerIncident", 14];
if (!(_maxAi isEqualType 0) || { _maxAi < 0 }) then { _maxAi = 14; };
private _maxHostiles = missionNamespace getVariable ["ARC_overlayMaxHostilesPerIncident", 6];
if (!(_maxHostiles isEqualType 0) || { _maxHostiles < 0 }) then { _maxHostiles = 6; };
private _maxObjects = missionNamespace getVariable ["ARC_overlayMaxObjectsPerIncident", 12];
if (!(_maxObjects isEqualType 0) || { _maxObjects < 0 }) then { _maxObjects = 12; };

// --- De-dup guard: is a SitePop site already active near the anchor? ------
private _sitePopActiveNear = false;
private _spActive = missionNamespace getVariable ["ARC_sitePopActive", createHashMap];
if (_spActive isEqualType createHashMap && { (count _spActive) > 0 }) then {
    private _named = missionNamespace getVariable ["ARC_worldNamedLocations", []];
    if (_named isEqualType []) then {
        {
            private _siteId = _x;
            { // find the matching named location centre
                if (_x isEqualType [] && { (_x param [0,""]) isEqualTo _siteId }) then {
                    private _lp = _x param [2, []];
                    if (_lp isEqualType [] && { (count _lp) >= 2 }) then {
                        if ((_p3 distance2D _lp) <= (_r + 150)) exitWith { _sitePopActiveNear = true; };
                    };
                };
            } forEach _named;
        } forEach ([_spActive] call (compile "params ['_m']; keys _m"));
    };
};
private _ambientRoles = ["resident","pedestrian","vendor","shopper","worshipper","guest","crowd","roadside_civ"];

// --- Object tag -> curated vanilla class pool -----------------------------
// Vanilla classes are always present; filtered through cfgClassExists anyway.
private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";
private _objMap = [[
    ["civ_car",         ["C_Hatchback_01_F","C_Offroad_01_F","C_SUV_01_F","C_Hatchback_01_sport_F"]],
    ["civ_truck",       ["C_Van_01_box_F","C_Truck_02_covered_F","C_Van_01_transport_F"]],
    ["pickup",          ["C_Offroad_01_F","C_Offroad_01_repair_F"]],
    ["official_car",    ["C_SUV_01_F","C_Offroad_luxe_F"]],
    ["cargo_truck",     ["C_Truck_02_covered_F","C_Truck_02_transport_F"]],
    ["fuel_truck",      ["C_Truck_02_fuel_F","C_Van_01_fuel_F"]],
    ["utility_truck",   ["C_Truck_02_box_F","C_Van_01_box_F"]],
    ["ambulance",       ["C_Van_01_box_F","C_Offroad_01_F"]],
    ["voi_vehicle",     ["C_Hatchback_01_F","C_Offroad_01_F","C_SUV_01_F"]],
    ["vbied_vehicle",   ["C_Van_01_box_F","C_Hatchback_01_F","C_Offroad_01_F"]],
    ["aid_table",       ["Land_CampingTable_F","Land_TableDesk_F"]],
    ["aid_crate",       ["Land_CratesPlastic_F","B_supplyCrate_F"]],
    ["supply_crate",    ["B_supplyCrate_F","Land_CratesWooden_F"]],
    ["water_container", ["Land_WaterTank_01_F","Land_BarrelWater_F"]],
    ["cargo_clutter",   ["Land_CargoBox_V1_F","Land_Pallet_vertical_F"]],
    ["work_clutter",    ["Land_ToolTrolley_02_F","Land_Pallet_vertical_F"]],
    ["hazard_clutter",  ["Land_BarrelTrash_F","Land_MetalBarrel_F"]],
    ["market_stall",    ["Land_Market_stalls_01_F","Land_CampingTable_F"]],
    ["barrier",         ["Land_BagFence_Long_F","Land_Cargo_Patrol_V1_F"]],
    ["generator",       ["Land_PortableGenerator_01_F","Land_Generator_F"]],
    ["repair_crate",    ["Land_ToolTrolley_01_F","Land_CratesWooden_F"]],
    ["cache",           ["Land_CratesWooden_F","Box_NATO_AmmoVeh_F","Land_Pallet_MilBags_F"]],
    ["ied_object",      ["Land_Suitcase_F","Land_Sacks_goods_F","Land_GarbageBags_F"]]
]] call _hmCreate;

// --- Placement: bounded radial offset by strategy -------------------------
private _placePos = {
    params ["_place"];
    private _band = switch (toLower _place) do {
        case "gate_lane":      { [6, 0.35] };
        case "roadside":       { [8, 0.45] };
        case "courtyard":      { [4, 0.40] };
        case "indoor":         { [3, 0.30] };
        case "perimeter":      { [(_r * 0.6) max 12, 0.30] };
        case "route_segment":  { [10, 0.55] };
        case "open":           { [5, 0.50] };
        default                { [5, 0.45] };
    };
    private _minD = _band select 0;
    private _span = (_r * (_band select 1)) max 8;
    private _ang  = random 360;
    private _dist = _minD + random _span;
    private _pp   = [(_p3 select 0) + (sin _ang) * _dist, (_p3 select 1) + (cos _ang) * _dist, 0];
    if (surfaceIsWater _pp) then {
        _ang = random 360; _dist = _minD + random (_span min 20);
        _pp = [(_p3 select 0) + (sin _ang) * _dist, (_p3 select 1) + (cos _ang) * _dist, 0];
    };
    _pp
};

private _todPolicy = [] call ARC_fnc_dynamicTodGetPolicy;
private _todPhase = [_todPolicy, "phase", "DAY"] call _hg;
if (!(_todPhase isEqualType "")) then { _todPhase = "DAY"; };
private _todProfile = [_todPolicy, "profile", "STANDARD"] call _hg;
if (!(_todProfile isEqualType "")) then { _todProfile = "STANDARD"; };

private _netIds = [];
private _aiSpawned = 0;
private _hostileSpawned = 0;
private _objSpawned = 0;

private _resolveSide = {
    params ["_sideStr"];
    switch (toLower _sideStr) do {
        case "west":  { west };
        case "east":  { east };
        case "indep": { independent };
        case "civ":   { civilian };
        default       { civilian };
    };
};

// --- Spawn AI roles -------------------------------------------------------
{
    if (!(_x isEqualType []) || { (count _x) < 5 }) then { continue; };
    _x params [
        ["_roleTag", "unit", [""]],
        ["_sideStr", "civ",  [""]],
        ["_countRange", [1,1], [[]]],
        ["_behavior", "wander", [""]],
        ["_placement", "open", [""]]
    ];

    // De-dup: skip SitePop-provided ambient roles when a site is active nearby.
    if (_sitePopActiveNear && { (toLower _roleTag) in _ambientRoles }) then { continue; };

    if (_aiSpawned >= _maxAi) then { continue; };

    private _isHostile = (toLower _sideStr) isEqualTo "east";
    if (_isHostile && { _hostileSpawned >= _maxHostiles }) then { continue; };

    private _classes = [_sideStr, _roleTag] call ARC_fnc_worldSpawnRoleResolve;
    if ((count _classes) == 0) then { continue; };

    private _mn = 1; private _mx = 1;
    if (_countRange isEqualType [] && { (count _countRange) >= 2 } && { (_countRange select 0) isEqualType 0 }) then {
        _mn = (_countRange select 0) max 0;
        _mx = (_countRange select 1) max _mn;
    };
    if (_mx <= 0) then { continue; };
    private _count = _mn + floor (random (_mx - _mn + 1));
    if (_count <= 0) then { continue; };

    // Apply caps to the drawn count.
    _count = _count min (_maxAi - _aiSpawned);
    if (_isHostile) then { _count = _count min (_maxHostiles - _hostileSpawned); };
    if (_count <= 0) then { continue; };

    private _side = [_sideStr] call _resolveSide;
    private _grp = createGroup [_side, true];
    _grp setVariable ["ARC_overlaySpawn", true, true];
    _grp setVariable ["ARC_overlayTaskId", _taskId, true];
    if (!(_side isEqualTo civilian)) then { _grp allowFleeing 0; };
    if (_isHostile) then {
        _grp setBehaviour "AWARE";
        _grp setCombatMode "YELLOW";
    } else {
        _grp setBehaviour "SAFE";
        _grp setCombatMode "WHITE";
    };

    for "_i" from 1 to _count do {
        private _sp = [_placement] call _placePos;
        _sp resize 3;
        private _cls = selectRandom _classes;
        private _u = _grp createUnit [_cls, _sp, [], 0, "NONE"];
        if (isNull _u) then { continue; };
        _u setPosATL _sp;
        _u setVariable ["ARC_overlaySpawn", true, true];
        _u setVariable ["ARC_overlayTaskId", _taskId, true];
        _u setVariable ["ARC_overlayRole", _roleTag, true];
        _u setVariable ["ARC_dynamic_tod_phase_spawn", _todPhase, false];
        _u setVariable ["ARC_dynamic_tod_profile_spawn", _todProfile, false];
        if ((toLower _sideStr) isEqualTo "civ") then {
            removeAllWeapons _u;
            removeAllItems _u;
        };
        _u enableDynamicSimulation true;
        _netIds pushBack (netId _u);
        _aiSpawned = _aiSpawned + 1;
        if (_isHostile) then { _hostileSpawned = _hostileSpawned + 1; };
    };

    // Ambient behaviour for non-hostile groups (reuse SitePop ambiance helper).
    if (!_isHostile && { !isNil "ARC_fnc_sitePopApplyAmbiance" }) then {
        [_grp, _behavior, _p3, _r, ""] call ARC_fnc_sitePopApplyAmbiance;
    };
} forEach _roles;

// --- Spawn objects --------------------------------------------------------
{
    if (!(_x isEqualType []) || { (count _x) < 3 }) then { continue; };
    _x params [
        ["_objTag", "", [""]],
        ["_countRange", [1,1], [[]]],
        ["_placement", "open", [""]]
    ];
    if (_objSpawned >= _maxObjects) then { continue; };

    private _pool = [_objMap, toLower _objTag, []] call _hg;
    private _valid = _pool select { [_x] call ARC_fnc_cfgClassExists };
    if ((count _valid) == 0) then {
        private _warned = missionNamespace getVariable ["ARC_overlayObjWarned", []];
        if (!(_warned isEqualType [])) then { _warned = []; };
        if (!(_objTag in _warned)) then {
            _warned pushBack _objTag;
            missionNamespace setVariable ["ARC_overlayObjWarned", _warned];
            diag_log format ["[ARC][SPAWNPAT][WARN] ARC_fnc_worldSpawnOverlayApply: object tag '%1' has no valid class in the live preset; skipped.", _objTag];
        };
        continue;
    };

    private _mn = 1; private _mx = 1;
    if (_countRange isEqualType [] && { (count _countRange) >= 2 } && { (_countRange select 0) isEqualType 0 }) then {
        _mn = (_countRange select 0) max 0;
        _mx = (_countRange select 1) max _mn;
    };
    if (_mx <= 0) then { continue; };
    private _count = _mn + floor (random (_mx - _mn + 1));
    _count = _count min (_maxObjects - _objSpawned);
    if (_count <= 0) then { continue; };

    private _isVehicleTag = ((toLower _objTag) find "car" >= 0) || { (toLower _objTag) find "truck" >= 0 } || { (toLower _objTag) find "vehicle" >= 0 } || { (toLower _objTag) find "pickup" >= 0 } || { (toLower _objTag) find "ambulance" >= 0 };

    for "_i" from 1 to _count do {
        private _sp = [_placement] call _placePos;
        _sp resize 3;
        // Collision guard for vehicles (bounded, one-time at init).
        if (_isVehicleTag && { (count (nearestObjects [_sp, ["LandVehicle"], 6])) > 0 }) then { continue; };
        private _cls = selectRandom _valid;
        private _o = createVehicle [_cls, _sp, [], 0, "CAN_COLLIDE"];
        if (isNull _o) then { continue; };
        _o setPosATL _sp;
        if (_isVehicleTag) then { _o lock true; };
        _o setVariable ["ARC_overlaySpawn", true, true];
        _o setVariable ["ARC_overlayTaskId", _taskId, true];
        _o enableDynamicSimulation true;
        _netIds pushBack (netId _o);
        _objSpawned = _objSpawned + 1;
    };
} forEach _objects;

diag_log format ["[ARC][SPAWNPAT][INFO] ARC_fnc_worldSpawnOverlayApply: task=%1 source=%2 ai=%3 (hostiles=%4) objects=%5 dedup=%6.",
    _taskId, _source, _aiSpawned, _hostileSpawned, _objSpawned, _sitePopActiveNear];

_netIds

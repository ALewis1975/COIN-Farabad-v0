/*
    ARC_fnc_opsSpawnRouteSupport

    Server: Spawn friendly route-support elements along a route (to an objective or along a convoy route).

    Design intent:
      - Provide already-present friendly/security activity (Thunder MSR security, SHERIFF MPs,
        and host-nation police) without creating a separate escort group that follows convoys.
      - Elements occupy intersections along the route and can persist in the AO.

    Params:
        0: STRING - taskId
        1: STRING - incidentType (upper/lower ok)
        2: STRING - incidentMarker (Eden marker id, if available)
        3: STRING - incidentDisplayName
        4: ARRAY  - end position ATL [x,y,z]
        5: NUMBER - suggested AO radius (meters) (optional)
        6: ARRAY  - route points (optional). If provided, points should be ATL/ASL-ish [x,y,z] arrays.

    Returns:
        ARRAY - netId strings for spawned vehicles/units

    Notes:
      - This function is designed to be called on task acceptance (TOC Accept), not on assignment.
      - Persistence mirrors the checkpoint composition approach: objects are not queued for cleanup.
*/

if (!isServer) exitWith {[]};

params [
    ["_taskId", "", [""]],
    ["_typeU", "", [""]],
    ["_marker", "", [""]],
    ["_disp", "", [""]],
    ["_endPosATL", [], [[]]],
    ["_radius", 120, [0]],
    ["_routePts", [], [[]]]
];

if (_taskId isEqualTo "") exitWith {[]};
if (!(_endPosATL isEqualType []) || { (count _endPosATL) < 2 }) exitWith {[]};

private _enabled = missionNamespace getVariable ["ARC_routeSupportEnabled", true];
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {[]};

private _persistInAO = missionNamespace getVariable ["ARC_routeSupportPersistInAO", false];
if (!(_persistInAO isEqualType true) && !(_persistInAO isEqualType false)) then { _persistInAO = true; };

private _dynSim = missionNamespace getVariable ["ARC_routeSupportDynamicSimEnabled", true];
if (!(_dynSim isEqualType true) && !(_dynSim isEqualType false)) then { _dynSim = true; };

// Optional LAMBS behaviors for friendly support units.
// Uses safe isNil guards so the mission still runs when LAMBS isn't loaded.
private _useLambs = missionNamespace getVariable ["ARC_supportUseLAMBS", true];
if (!(_useLambs isEqualType true) && !(_useLambs isEqualType false)) then { _useLambs = true; };

private _type = toUpper _typeU;
private _endPos = +_endPosATL; _endPos resize 3;

private _eligible = missionNamespace getVariable ["ARC_routeSupportEligibleTypes", ["LOGISTICS","ESCORT","IED","RAID","DEFEND","RECON","CHECKPOINT","CIVIL","QRF"]];
if (!(_eligible isEqualType [])) then { _eligible = ["LOGISTICS","ESCORT","IED","RAID","DEFEND","RECON","CHECKPOINT","CIVIL","QRF"]; };
_eligible = _eligible apply { toUpper _x };
if !(_type in _eligible) exitWith {[]};

// Optional: suppress support elements for tasks wholly inside the Airbase.
private _allowAirbaseTasks = missionNamespace getVariable ["ARC_routeSupportAllowAirbaseTasks", false];
if (!(_allowAirbaseTasks isEqualType true) && !(_allowAirbaseTasks isEqualType false)) then { _allowAirbaseTasks = false; };
private _endZoneU = toUpper ([_endPos] call ARC_fnc_worldGetZoneForPos);
if (!_allowAirbaseTasks && { _endZoneU isEqualTo "AIRBASE" } && { !(_type in ["LOGISTICS","ESCORT"]) }) exitWith {[]};

// Runtime-only "do not stack" list (positions where we already placed route support this session).
// Stored as either [x,y,z] (legacy) or [[x,y,z], t] (timestamped). We normalize + prune old entries.
private _sitesRaw = missionNamespace getVariable ["ARC_persistentRouteSupportSites", []];
if (!(_sitesRaw isEqualType [])) then { _sitesRaw = []; };

private _now = serverTime;
private _ttl = missionNamespace getVariable ["ARC_routeSupportSiteTTLsec", -1];
if (!(_ttl isEqualType 0)) then { _ttl = -1; };
if (_ttl < 0) then
{
    // Default: if route support is not persistent, keep sites ~30 min to prevent stacking on fast repeat tasking.
    // If route support is persistent in AO, disable TTL pruning.
    _ttl = if (_persistInAO) then { 0 } else { 1800 };
};
_ttl = (_ttl max 0) min 21600; // cap at 6 hours

private _sites = [];
{
    if (!(_x isEqualType []) || { (count _x) < 2 }) then { continue; };

    // Legacy: position array [x,y,z]
    if ((_x # 0) isEqualType 0) then
    {
        private _p = +_x; _p resize 3;
        _sites pushBack [_p, _now];
        continue;
    };

    // Timestamped: [pos, t]
    if ((_x # 0) isEqualType []) then
    {
        private _p = +(_x # 0); _p resize 3;
        private _t = _x # 1;
        if (!(_t isEqualType 0)) then { _t = _now; };

        if (_ttl <= 0 || { (_now - _t) <= _ttl }) then
        {
            _sites pushBack [_p, _t];
        };
        continue;
    };
} forEach _sitesRaw;

private _maxSites = missionNamespace getVariable ["ARC_routeSupportMaxSites", 3];
if (!(_maxSites isEqualType 0) || { _maxSites < 0 }) then { _maxSites = 3; };
_maxSites = (_maxSites max 0) min 12;

private _spacingM = missionNamespace getVariable ["ARC_routeSupportSiteSpacingM", 1300];
if (!(_spacingM isEqualType 0) || { _spacingM <= 0 }) then { _spacingM = 1300; };
_spacingM = (_spacingM max 450) min 2500;

private _skipStartM = missionNamespace getVariable ["ARC_routeSupportSkipStartM", 600];
if (!(_skipStartM isEqualType 0) || { _skipStartM < 0 }) then { _skipStartM = 600; };
_skipStartM = (_skipStartM max 0) min 2000;

private _skipEndM = missionNamespace getVariable ["ARC_routeSupportSkipEndM", 600];
if (!(_skipEndM isEqualType 0) || { _skipEndM < 0 }) then { _skipEndM = 600; };
_skipEndM = (_skipEndM max 0) min 2000;

private _roadSearchR = missionNamespace getVariable ["ARC_routeSupportRoadSearchRadiusM", 140];
if (!(_roadSearchR isEqualType 0) || { _roadSearchR <= 0 }) then { _roadSearchR = 140; };
_roadSearchR = (_roadSearchR max 60) min 400;

private _dedupeR = missionNamespace getVariable ["ARC_routeSupportDedupeRadiusM", 170];
if (!(_dedupeR isEqualType 0) || { _dedupeR <= 0 }) then { _dedupeR = 170; };
_dedupeR = (_dedupeR max 80) min 450;

// Optional: give route-support group leaders a cTab-compatible device (helps visibility in cTab).
private _giveCtabDevices = missionNamespace getVariable ["ARC_routeSupportGiveCtabDevices", true];
if (!(_giveCtabDevices isEqualType true) && !(_giveCtabDevices isEqualType false)) then { _giveCtabDevices = true; };

// Preferred item class for leader device (defaults to cTab Android).
private _ctabLeaderItem = missionNamespace getVariable ["ARC_routeSupportCtabLeaderItem", "ItemAndroid"];
if (!(_ctabLeaderItem isEqualType "")) then { _ctabLeaderItem = "ItemAndroid"; };

private _fn_assignCtabToLeader = {
    params ["_grp"]; 
    if (!_giveCtabDevices) exitWith {};
    if (isNull _grp) exitWith {};

    private _ldr = leader _grp;
    if (isNull _ldr) exitWith {};
    if (!alive _ldr) exitWith {};

    private _item = "";
    if (isClass (configFile >> "CfgWeapons" >> _ctabLeaderItem)) then { _item = _ctabLeaderItem; };
    if (_item isEqualTo "" && { isClass (configFile >> "CfgWeapons" >> "ItemAndroid") }) then { _item = "ItemAndroid"; };
    if (_item isEqualTo "" && { isClass (configFile >> "CfgWeapons" >> "ItemcTab") }) then { _item = "ItemcTab"; };
    if (_item isEqualTo "") exitWith {};

    if (!(_item in (assignedItems _ldr))) then
    {
        if (!(_item in (items _ldr))) then { _ldr addItem _item; };
        _ldr linkItem _item;
        _ldr assignItem _item;
    };
};



// Vehicle-support tuning
private _vehOffroadM = missionNamespace getVariable ["ARC_routeSupportVehOffroadOffsetM", 16];
if (!(_vehOffroadM isEqualType 0) || { _vehOffroadM < 0 }) then { _vehOffroadM = 16; };
_vehOffroadM = (_vehOffroadM max 8) min 60;

// Foot-support tuning (dismounted route security / local police)
private _footOffroadM = missionNamespace getVariable ["ARC_routeSupportFootOffroadOffsetM", 24];
if (!(_footOffroadM isEqualType 0) || { _footOffroadM < 0 }) then { _footOffroadM = 24; };
_footOffroadM = (_footOffroadM max 10) min 80;

private _vehDismountMin = missionNamespace getVariable ["ARC_routeSupportVehDismountMin", 1];
if (!(_vehDismountMin isEqualType 0) || { _vehDismountMin < 0 }) then { _vehDismountMin = 1; };
_vehDismountMin = (_vehDismountMin max 0) min 6;

private _vehDismountMax = missionNamespace getVariable ["ARC_routeSupportVehDismountMax", 2];
if (!(_vehDismountMax isEqualType 0) || { _vehDismountMax < 0 }) then { _vehDismountMax = 2; };
_vehDismountMax = (_vehDismountMax max _vehDismountMin) min 8;

// Simple unique naming counter for support groups (global via setGroupIdGlobal).
private _fn_nextGroupIdx = {
    private _i = missionNamespace getVariable ["ARC_routeSupportGroupCounter", 0];
    if (!(_i isEqualType 0)) then { _i = 0; };
    _i = _i + 1;
    missionNamespace setVariable ["ARC_routeSupportGroupCounter", _i];
    _i
};

// Find an off-road parking position near the road/intersection so we don't block traffic.
private _fn_findOffroadPos = {
    params ["_basePosATL", "_dirDeg", "_offM"];

    private _base = +_basePosATL; _base resize 3;
    private _off = _offM;
    if (!(_off isEqualType 0) || { _off <= 0 }) then { _off = 16; };

    private _best = [];
    for "_a" from 1 to 10 do
    {
        private _side = if ((random 1) < 0.5) then { 1 } else { -1 };
        private _d = _off + random 10;
        private _cand = _base getPos [_d, (_dirDeg + (90 * _side))];
        _cand resize 3;

        if (surfaceIsWater _cand) then { continue; };
        if (isOnRoad _cand) then { continue; };

        // Keep close enough to still feel like an intersection post.
        private _nr = [_cand, (_off + 25)] call BIS_fnc_nearestRoad;
        if (isNull _nr) then { continue; };

        _best = _cand;
        break;
    };

    if (_best isEqualTo []) then
    {
        // Last resort: shove off the road, even if it isn't perfect.
        _best = _base getPos [_off + 12, _dirDeg + 90];
        _best resize 3;
    };

    _best
};

// Determine a plausible friendly "start" anchor (closest friendly HQ marker to the objective).
private _startMarkers = missionNamespace getVariable ["ARC_routeSupportStartMarkers", [
    "ARC_m_charlie_2_325AIR",
    "ARC_m_base_hq_1",
    "ARC_loc_GreenZone",
    "ARC_loc_military"
]];
if (!(_startMarkers isEqualType [])) then
{
    _startMarkers = ["ARC_m_charlie_2_325AIR","ARC_m_base_hq_1","ARC_loc_GreenZone","ARC_loc_military"];
};

private _startPos = [];
private _bestD = 1e12;
{
    private _m = _x;
    if !(_m isEqualType "") then { continue; };
    if !(_m in allMapMarkers) then { continue; };
    private _p = getMarkerPos _m;
    if (!(_p isEqualType []) || { (count _p) < 2 }) then { continue; };
    private _d = _p distance2D _endPos;
    if (_d < _bestD) then { _bestD = _d; _startPos = _p; };
} forEach _startMarkers;

// If route points were provided, prefer them for sampling.
private _haveRoutePts = (_routePts isEqualType []) && { (count _routePts) >= 2 };

// Sanitize route points.
private _rp = [];
if (_haveRoutePts) then
{
    {
        if (_x isEqualType [] && { (count _x) >= 2 }) then
        {
            private _p = +_x;
            _p resize 3;
            _rp pushBack _p;
        };
    } forEach _routePts;

    _haveRoutePts = (count _rp) >= 2;
};

if (!_haveRoutePts) then
{
    if (_startPos isEqualTo []) exitWith {[]};
    _startPos resize 3;
};

// Early out for very short routes.
private _routeDist = if (_haveRoutePts) then
{
    private _sum = 0;
    for "_i" from 1 to ((count _rp) - 1) do
    {
        _sum = _sum + ((_rp # (_i - 1)) distance2D (_rp # _i));
    };
    _sum
}
else
{
    _startPos distance2D _endPos
};

if (_routeDist < (_skipStartM + _skipEndM + 600)) exitWith {[]};

// Candidate sample points along the route.
private _candidates = [];

if (_haveRoutePts) then
{
    private _total = _routeDist;
    private _nextAt = _skipStartM;
    private _acc = 0;

    for "_i" from 1 to ((count _rp) - 1) do
    {
        private _a = _rp # (_i - 1);
        private _b = _rp # _i;
        private _seg = _a distance2D _b;
        if (_seg <= 0.5) then { continue; };

        while { (_acc + _seg) >= _nextAt && { _nextAt <= (_total - _skipEndM) } && { (count _candidates) < (_maxSites * 2) } } do
        {
            private _t = (_nextAt - _acc) / _seg;
            _t = (_t max 0) min 1;
            private _p = [
                (_a # 0) + ((_b # 0) - (_a # 0)) * _t,
                (_a # 1) + ((_b # 1) - (_a # 1)) * _t,
                (_a # 2) + ((_b # 2) - (_a # 2)) * _t
            ];
            _candidates pushBack _p;
            _nextAt = _nextAt + _spacingM;
        };

        _acc = _acc + _seg;
        if ((count _candidates) >= (_maxSites * 2)) exitWith {};
    };
}
else
{
    private _dir = _startPos getDir _endPos;
    private _avail = (_routeDist - _skipStartM - _skipEndM) max 0;
    private _n = floor (_avail / _spacingM);
    if (_n < 1) then { _n = 1; };
    _n = (_n min (_maxSites * 2)) max 1;

    for "_i" from 1 to _n do
    {
        private _d = _skipStartM + (_i * _spacingM);
        if (_d >= (_routeDist - _skipEndM)) exitWith {};
        _candidates pushBack (_startPos getPos [_d, _dir]);
    };
};

// Helper: pick the best road near a point (prefer intersections).
private _fn_pickRoad = {
    params ["_p", "_r"];
    private _roads = _p nearRoads _r;
    if ((count _roads) <= 0) exitWith { objNull };

    private _best = objNull;
    private _bestConn = -1;
    private _bestD = 1e12;

    {
        private _conn = roadsConnectedTo _x;
        private _nConn = count _conn;
        private _d = _p distance2D _x;

        // Prefer 3+ connections (intersection). If ties, pick nearest.
        if (_nConn > _bestConn || { _nConn == _bestConn && { _d < _bestD } }) then
        {
            _best = _x;
            _bestConn = _nConn;
            _bestD = _d;
        };
    } forEach _roads;

    _best
};

// Helper: determine orientation along road.
private _fn_roadDir = {
    params ["_road"];
    private _dir = random 360;
    if (isNull _road) exitWith { _dir };

    private _conn = roadsConnectedTo _road;
    if ((count _conn) > 0) then
    {
        _dir = _road getDir (_conn # 0);
    };

    _dir
};

// Helper: tag object/unit.
private _fn_tag = {
    params ["_o", "_pkg"];
    if (isNull _o) exitWith {};

    _o setVariable ["ARC_isRouteSupport", true, true];
    _o setVariable ["ARC_routeSupportTaskId", _taskId, true];
    _o setVariable ["ARC_routeSupportIncidentType", _type, true];
    _o setVariable ["ARC_routeSupportPackage", _pkg, true];

    if (_persistInAO) then
    {
        _o setVariable ["ARC_persistInAO", true, true];
    };

    if (_dynSim) then
    {
        _o enableDynamicSimulation true;
    };
};

// Helper: pick from pool.
private _fn_pick = {
    params ["_pool", "_fallback"];
    if (!(_pool isEqualType []) || { (count _pool) <= 0 }) exitWith { _fallback };
    selectRandom _pool
};

// Build default pools (filter by isClass each call; allows modpack changes).
private _poolW = missionNamespace getVariable ["ARC_routeSupportUnitPool_WEST", [
    "rhsusf_army_ocp_rifleman",
    "rhsusf_army_ocp_grenadier",
    "rhsusf_army_ocp_machinegunner",
    "rhsusf_army_ocp_medic",
    "rhsusf_army_ocp_teamleader"
]];
if (!(_poolW isEqualType [])) then
{
    _poolW = ["rhsusf_army_ocp_rifleman","rhsusf_army_ocp_grenadier","rhsusf_army_ocp_machinegunner","rhsusf_army_ocp_medic","rhsusf_army_ocp_teamleader"];
};
_poolW = _poolW select { isClass (configFile >> "CfgVehicles" >> _x) };
if ((count _poolW) <= 0) then { _poolW = ["B_Soldier_F"]; };

private _vehThunder = missionNamespace getVariable ["ARC_routeSupportVehPool_THUNDER", [
    "rhsusf_M1117_D",
    "rhsusf_m1025_d_m2",
    "rhsusf_m1025_d",
    "rhsusf_m966_d"
]];
if (!(_vehThunder isEqualType [])) then { _vehThunder = ["rhsusf_M1117_D","rhsusf_m1025_d_m2","rhsusf_m1025_d","rhsusf_m966_d"]; };
_vehThunder = _vehThunder select { isClass (configFile >> "CfgVehicles" >> _x) };
if ((count _vehThunder) <= 0) then { _vehThunder = ["B_MRAP_01_F"]; };

private _vehSheriff = missionNamespace getVariable ["ARC_routeSupportVehPool_SHERIFF", [
    "rhsusf_m1025_d",
    "rhsusf_M1117_D"
]];
if (!(_vehSheriff isEqualType [])) then { _vehSheriff = ["rhsusf_m1025_d","rhsusf_M1117_D"]; };
_vehSheriff = _vehSheriff select { isClass (configFile >> "CfgVehicles" >> _x) };
if ((count _vehSheriff) <= 0) then { _vehSheriff = ["B_MRAP_01_F"]; };

// TNP pool (best-effort). Prefer 3CB Takistan Police BLUFOR. If unavailable, fall back to BLUFOR generic.
private _tnpFaction = missionNamespace getVariable ["ARC_routeSupportTnpFaction", "UK3CB_TKP_B"];
if (!(_tnpFaction isEqualType "")) then { _tnpFaction = "UK3CB_TKP_B"; };

// Map side -> config side number (CfgVehicles >> side)
private _fn_sideNum = {
    params ["_s"];
    if (_s isEqualTo east) exitWith { 0 };
    if (_s isEqualTo west) exitWith { 1 };
    if (_s isEqualTo independent) exitWith { 2 };
    if (_s isEqualTo civilian) exitWith { 3 };
    1
};

private _tnpCacheKey = format ["ARC_routeSupportTnpUnitClasses_cached_%1", _tnpFaction];
private _poolTnp = missionNamespace getVariable ["ARC_routeSupportUnitPool_TNP", []];
if (!(_poolTnp isEqualType [])) then { _poolTnp = []; };

if ((count _poolTnp) <= 0) then
{
    private _cached = missionNamespace getVariable [_tnpCacheKey, []];
    if (_cached isEqualType [] && { (count _cached) > 0 }) then
    {
        _poolTnp = +_cached;
    }
    else
    {
        private _found = [];
        private _sideNum = [missionNamespace getVariable ["ARC_routeSupportSide_TNP", west]] call _fn_sideNum;
        private _cfg = configFile >> "CfgVehicles";
        {
            if (getNumber (_x >> "scope") != 2) then { continue; };
            if ((getText (_x >> "faction")) != _tnpFaction) then { continue; };
            if (getNumber (_x >> "side") != _sideNum) then { continue; };
            private _cn = configName _x;
            if (_cn isKindOf "Man") then { _found pushBack _cn; };
        } forEach ("true" configClasses _cfg);

        missionNamespace setVariable [_tnpCacheKey, _found];
        _poolTnp = _found;
    };
};

_poolTnp = _poolTnp select { isClass (configFile >> "CfgVehicles" >> _x) };
if ((count _poolTnp) <= 0) then
{
    // BLUFOR fallback (keeps "friendly only" constraint even if 3CB police faction missing)
    private _fb = [
        "B_GEN_Soldier_F",
        "B_GEN_Commander_F",
        "B_Soldier_F",
        "B_Soldier_AR_F",
        "B_Soldier_LAT_F"
    ];
    _fb = _fb select { isClass (configFile >> "CfgVehicles" >> _x) };
    if ((count _fb) <= 0) then { _fb = ["B_Soldier_F"]; };
    _poolTnp = _fb;
};

// Sides (default: BLUFOR)
private _sideTnp = missionNamespace getVariable ["ARC_routeSupportSide_TNP", west];
if (!(_sideTnp isEqualType west) && !(_sideTnp isEqualType east) && !(_sideTnp isEqualType independent) && !(_sideTnp isEqualType civilian)) then
{
    _sideTnp = west;
};

// Decide package type at a site.
private _fn_pickPkg = {
    params ["_sitePos"];

    private _z = toUpper ([_sitePos] call ARC_fnc_worldGetZoneForPos);

    // GreenZone gets more host-nation and MPs.
    if (_z isEqualTo "GREENZONE") exitWith
    {
        if ((random 1) < 0.60) then { "TNP" } else { "SHERIFF" };
    };

    // Near the base, keep it mostly US presence.
    if (_z isEqualTo "AIRBASE") exitWith
    {
        if ((random 1) < 0.70) then { "SHERIFF" } else { "THUNDER" };
    };

    // Default: mostly Thunder, sometimes locals.
    private _r = random 1;
    if (_r < 0.15) exitWith { "TNP" };
    if (_r < 0.35) exitWith { "SHERIFF" };
    "THUNDER"
};

// Spawners
private _fn_spawnVehElement = {
    params ["_pkg", "_vehPool", "_sitePosATL", "_dirDeg"];

    private _idx = call _fn_nextGroupIdx;
    private _nameBase = format ["%1 RS-%2", _pkg, _idx];

    // Park the vehicle off-road so it doesn't obstruct convoys/escorts.
    private _vehPos = [_sitePosATL, _dirDeg, _vehOffroadM] call _fn_findOffroadPos;

    private _vehClass = [_vehPool, "B_MRAP_01_F"] call _fn_pick;
    private _veh = createVehicle [_vehClass, _vehPos, [], 0, "CAN_COLLIDE"];
    _veh setDir _dirDeg;
    _veh setPosATL _vehPos;
    _veh allowDamage false;

    [_veh, _pkg] call _fn_tag;

    // -------------------------------------------------------------------------
    // Crew group (mounted + static)
    // -------------------------------------------------------------------------
    private _grpCrew = createGroup [west, true];
    _grpCrew setVariable ["ARC_isRouteSupport", true, true];
    _grpCrew setVariable ["ARC_routeSupportTaskId", _taskId, true];
    _grpCrew setVariable ["ARC_routeSupportPackage", _pkg, true];
    _grpCrew setVariable ["ARC_routeSupportRole", "CREW", true];
    _grpCrew allowFleeing 0;

    // Start friendly elements calm unless threatened.
    _grpCrew setBehaviour "SAFE";
    _grpCrew setCombatMode "WHITE";

    _grpCrew setGroupIdGlobal [format ["%1 Crew", _nameBase]];

    // Optional: keep LAMBS from re-tasking this group.
    if (_useLambs) then
    {
        _grpCrew setVariable ["lambs_danger_disableGroupAI", true];
    };

    private _uDriver = _grpCrew createUnit [([_poolW, "B_Soldier_F"] call _fn_pick), _vehPos, [], 0, "NONE"];
    private _uGunner = _grpCrew createUnit [([_poolW, "B_Soldier_F"] call _fn_pick), _vehPos, [], 0, "NONE"];

    _uDriver setBehaviour "SAFE";
    _uGunner setBehaviour "SAFE";
    _uDriver setCombatMode "WHITE";
    _uGunner setCombatMode "WHITE";

    [_uDriver, _pkg] call _fn_tag;
    [_uGunner, _pkg] call _fn_tag;

    _uDriver moveInDriver _veh;

    // Gunner seat best-effort; fall back to cargo.
    private _hasG = (count (fullCrew [_veh, "gunner", true])) > 0;
    if (_hasG) then { _uGunner moveInGunner _veh; } else { _uGunner moveInCargo _veh; };

    // Ensure leader carries a cTab-compatible device (helps visibility in cTab).
    [_grpCrew] call _fn_assignCtabToLeader;

    // Freeze: no roaming / no road obstruction.
    _veh engineOn false;
    _veh setFuel (fuel _veh max 0.15);
    _veh setVelocity [0,0,0];

    _uDriver disableAI "PATH";
    _uGunner disableAI "PATH";
    doStop _uDriver;
    doStop _uGunner;

    private _nids = [netId _veh, netId _uDriver, netId _uGunner];

    // -------------------------------------------------------------------------
    // Dismounted security (1-2)
    // -------------------------------------------------------------------------
    private _nSec = _vehDismountMin;
    if (_vehDismountMax > _vehDismountMin) then
    {
        _nSec = _vehDismountMin + floor (random ((_vehDismountMax - _vehDismountMin) + 1));
    };

    if (_nSec > 0) then
    {
        private _grpSec = createGroup [west, true];
        _grpSec setVariable ["ARC_isRouteSupport", true, true];
        _grpSec setVariable ["ARC_routeSupportTaskId", _taskId, true];
        _grpSec setVariable ["ARC_routeSupportPackage", _pkg, true];
        _grpSec setVariable ["ARC_routeSupportRole", "SECURITY", true];
        _grpSec allowFleeing 0;

        _grpSec setBehaviour "SAFE";
        _grpSec setCombatMode "WHITE";

        _grpSec setGroupIdGlobal [format ["%1 Sec", _nameBase]];

        for "_i" from 1 to _nSec do
        {
            private _p = _vehPos getPos [6 + random 4, _dirDeg + 110 + random 140];
            _p resize 3;

            private _u = _grpSec createUnit [([_poolW, "B_Soldier_F"] call _fn_pick), _p, [], 0, "NONE"];
            _u setPosATL _p;

            _u setBehaviour "SAFE";
            _u setCombatMode "WHITE";
            _u setUnitPos "MIDDLE";

            [_u, _pkg] call _fn_tag;

            // Keep them close to the post unless provoked.
            doStop _u;

            _nids pushBack (netId _u);
        };

        // Ensure leader carries a cTab-compatible device (helps visibility in cTab).
        [_grpSec] call _fn_assignCtabToLeader;

        private _holdR = missionNamespace getVariable ["ARC_routeSupportVehDismountHoldRadiusM", 35];
        if (!(_holdR isEqualType 0) || { _holdR <= 0 }) then { _holdR = 35; };
        _holdR = (_holdR max 20) min 120;

        if (_useLambs && { !isNil "lambs_wp_fnc_taskGarrison" }) then
        {
            // Exit condition: firedNear (3) so they can react, but they won't wander otherwise.
            [_grpSec, _sitePosATL, _holdR, [], false, true, 3, false] spawn lambs_wp_fnc_taskGarrison;
        }
        else
        {
            private _wp = _grpSec addWaypoint [_vehPos, 0];
            _wp setWaypointType "HOLD";
            _wp setWaypointBehaviour "SAFE";
            _wp setWaypointCombatMode "WHITE";
            _wp setWaypointSpeed "LIMITED";
        };
    };

    _nids
};

private _fn_spawnFootElement = {
    params ["_pkg", "_side", "_unitPool", "_posATL", ["_dirDeg", 0, [0]]];

    private _idx = call _fn_nextGroupIdx;

    private _grp = createGroup [_side, true];
    _grp setVariable ["ARC_isRouteSupport", true, true];
    _grp setVariable ["ARC_routeSupportTaskId", _taskId, true];
    _grp setVariable ["ARC_routeSupportPackage", _pkg, true];
    _grp setVariable ["ARC_routeSupportRole", "FOOT", true];
    _grp allowFleeing 0;

    // Start friendly locals calm unless threatened.
    _grp setBehaviour "SAFE";
    _grp setCombatMode "WHITE";

    _grp setGroupIdGlobal [format ["%1 RS-%2", _pkg, _idx]];

    private _n = missionNamespace getVariable ["ARC_routeSupportFootCount_TNP", 4];
    if (!(_n isEqualType 0) || { _n <= 0 }) then { _n = 4; };
    _n = (_n max 2) min 10;

    // Shift dismounted elements off-road so convoys don't run them over.
    private _holdPos = +_posATL;
    _holdPos resize 3;
    if (_footOffroadM > 0) then
    {
        _holdPos = [_posATL, _dirDeg, _footOffroadM] call _fn_findOffroadPos;
    };

    private _nids = [];
    for "_i" from 1 to _n do
    {
        private _p = _holdPos getPos [2 + random 6, random 360];
        _p resize 3;

        // Best-effort avoid spawning directly on the road.
        for "_t" from 1 to 6 do
        {
            if (!isOnRoad _p && { !surfaceIsWater _p }) exitWith {};
            _p = _holdPos getPos [4 + random 10, random 360];
            _p resize 3;
        };
        private _cls = [_unitPool, "B_Soldier_F"] call _fn_pick;
        private _u = _grp createUnit [_cls, _p, [], 0, "NONE"];
        _u setPosATL _p;

        [_u, _pkg] call _fn_tag;

        _u setBehaviour "SAFE";
        _u setCombatMode "WHITE";
        _u setUnitPos "MIDDLE";
        doStop _u;

        _nids pushBack (netId _u);
    };

    // Keep them close to the intersection by default (do not wander into the road).
    private _holdR = missionNamespace getVariable ["ARC_routeSupportFootHoldRadiusM", 45];
    if (!(_holdR isEqualType 0) || { _holdR <= 0 }) then { _holdR = 45; };
    _holdR = (_holdR max 20) min 200;

    if (_useLambs && { !isNil "lambs_wp_fnc_taskGarrison" }) then
    {
        [_grp, _holdPos, _holdR, [], false, true, 3, false] spawn lambs_wp_fnc_taskGarrison;
    }
    else
    {
        private _wp = _grp addWaypoint [_holdPos, 0];
        _wp setWaypointType "HOLD";
        _wp setWaypointBehaviour "SAFE";
        _wp setWaypointCombatMode "WHITE";
        _wp setWaypointSpeed "LIMITED";
    };

    // Ensure leader carries a cTab-compatible device (helps visibility in cTab).
    [_grp] call _fn_assignCtabToLeader;

    _nids
};

private _out = [];
private _spawnedSites = 0;

{
    if (_spawnedSites >= _maxSites) exitWith {};

    if (!(_x isEqualType []) || { (count _x) < 2 }) then { continue; };
    private _cand = +_x; _cand resize 3;

    private _road = [_cand, _roadSearchR] call _fn_pickRoad;
    if (isNull _road) then { continue; };

    private _sitePos = getPosATL _road;
    _sitePos resize 3;

    // Skip water/invalid positions
    if (surfaceIsWater _sitePos) then { continue; };

    // Avoid stacking (runtime-only)
    private _dupe = false;
    { if ((_sitePos distance2D (_x # 0)) < _dedupeR) exitWith { _dupe = true; }; } forEach _sites;
    if (_dupe) then { continue; };

    // Avoid placing inside the airbase unless explicitly allowed.
    private _zSite = toUpper ([_sitePos] call ARC_fnc_worldGetZoneForPos);
    if (!_allowAirbaseTasks && { _zSite isEqualTo "AIRBASE" }) then { continue; };

    private _dir = [_road] call _fn_roadDir;

    private _pkg = [_sitePos] call _fn_pickPkg;

    private _spawnNids = [];
    switch (_pkg) do
    {
        case "TNP":
        {
            _spawnNids = ["TNP", _sideTnp, _poolTnp, _sitePos, _dir] call _fn_spawnFootElement;
        };

        case "SHERIFF":
        {
            _spawnNids = ["SHERIFF", _vehSheriff, _sitePos, _dir] call _fn_spawnVehElement;
        };

        default
        {
            _spawnNids = ["THUNDER", _vehThunder, _sitePos, _dir] call _fn_spawnVehElement;
        };
    };

    if (_spawnNids isEqualType [] && { (count _spawnNids) > 0 }) then
    {
        _sites pushBack [_sitePos, _now];
        _out append _spawnNids;
        _spawnedSites = _spawnedSites + 1;

        ["OPS", format ["Route support element (%1) spawned at %2.", _pkg, mapGridPosition _sitePos], _sitePos, [["taskId", _taskId], ["event", "ROUTE_SUPPORT_SPAWNED"], ["pkg", _pkg], ["incidentType", _type]]] call ARC_fnc_intelLog;
    };

} forEach _candidates;

missionNamespace setVariable ["ARC_persistentRouteSupportSites", _sites];

_out

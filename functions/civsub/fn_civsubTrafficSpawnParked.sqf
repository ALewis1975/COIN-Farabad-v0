/*
    ARC_fnc_civsubTrafficSpawnParked

    Spawns one parked civilian vehicle for a district (server-only).

    Params:
      0: districtId (string)
      1: districtState (HashMap)
      2: vehiclePool (array of classnames)
      3: spawnCenter (array [x,y,z], optional)

    Returns: vehicle object or objNull
*/

if (!isServer) exitWith {objNull};

params [
    ["_districtId", "", [""]],
    ["_d", createHashMap, [createHashMap]],
    ["_pool", [], [[]]],
    ["_spawnCenter", [], [[]]]
];

if (_districtId isEqualTo "") exitWith {objNull};
if !(_d isEqualType createHashMap) exitWith {objNull};
if !(_pool isEqualType []) exitWith {objNull};
if ((count _pool) == 0) exitWith {objNull};

private _dbg = missionNamespace getVariable ["civsub_v1_traffic_debug", false];
if (!(_dbg isEqualType true)) then { _dbg = false; };

// Phase 2 helpers (defined in civsubInitServer)
private _posIsRoadish = missionNamespace getVariable ["ARC_civsub_fnc_posIsRoadish", { params ["_p"]; isOnRoad _p }];
private _findOffRoad = missionNamespace getVariable ["ARC_civsub_fnc_findPosOffRoad", { params ["_p"]; _p }];

private _preferW = missionNamespace getVariable ["civsub_v1_traffic_preferWeight", 0.90];
if (!(_preferW isEqualType 0)) then { _preferW = 0.90; };
_preferW = (_preferW max 0) min 1;

// Validated pools (built by ARC_fnc_civsubTrafficBuildVehiclePool). If absent, fall back to provided _pool.
private _poolPrefer = missionNamespace getVariable ["civsub_v1_traffic_vehiclePool_valid_prefer", []];
private _poolFallback = missionNamespace getVariable ["civsub_v1_traffic_vehiclePool_valid_fallback", []];
if (!(_poolPrefer isEqualType [])) then { _poolPrefer = []; };
if (!(_poolFallback isEqualType [])) then { _poolFallback = []; };

private _fnHmGet = {
    params ["_hm", "_key", "_fallback"];
    private _v = _hm get _key;
    if (isNil "_v") exitWith { _fallback };
    _v
};

private _c = [_d, "centroid", [0,0]] call _fnHmGet;
private _r = [_d, "radius_m", 400] call _fnHmGet;
if !(_c isEqualType []) exitWith {objNull};
if ((count _c) < 2) exitWith {objNull};

private _center = [_c select 0, _c select 1, 0];
if (_spawnCenter isEqualType [] && { (count _spawnCenter) >= 2 }) then
{
    _center = [_spawnCenter select 0, _spawnCenter select 1, 0];
};

private _players = allPlayers;

private _spawnR = missionNamespace getVariable ["civsub_v1_traffic_spawnRadius_m", 600];
if (!(_spawnR isEqualType 0)) then { _spawnR = 600; };
// Upper bound raised to 1500 to support out-of-view-distance spawning (1 km+).
_spawnR = (_spawnR max 180) min 1500;
// Use _spawnR directly; the former district-radius cap (min 950) would prevent
// spawning beyond ~400 m even when spawnRadius_m is configured at 1400 m.
private _searchR = _spawnR;

private _minSep = missionNamespace getVariable ["civsub_v1_traffic_minSeparation_m", 35];
if (!(_minSep isEqualType 0)) then { _minSep = 35; };

private _pMin = missionNamespace getVariable ["civsub_v1_traffic_playerMinDistance_m", 60];
if (!(_pMin isEqualType 0)) then { _pMin = 60; };
// Upper bound raised to 1200 to allow out-of-view-distance enforcement (1 km view).
_pMin = (_pMin max 50) min 1200;

private _fallbackRoadMin = missionNamespace getVariable ["civsub_v1_traffic_fallback_roadsideMin_m", 8];
if (!(_fallbackRoadMin isEqualType 0)) then { _fallbackRoadMin = 8; };
_fallbackRoadMin = (_fallbackRoadMin max 4) min 28;

private _fallbackRoadMax = missionNamespace getVariable ["civsub_v1_traffic_fallback_roadsideMax_m", 20];
if (!(_fallbackRoadMax isEqualType 0)) then { _fallbackRoadMax = 20; };
_fallbackRoadMax = (_fallbackRoadMax max (_fallbackRoadMin + 1)) min 60;

private _fallbackBldMin = missionNamespace getVariable ["civsub_v1_traffic_fallback_buildingMin_m", 4];
if (!(_fallbackBldMin isEqualType 0)) then { _fallbackBldMin = 4; };
_fallbackBldMin = (_fallbackBldMin max 0) min 40;

private _fallbackBldMax = missionNamespace getVariable ["civsub_v1_traffic_fallback_buildingMax_m", 45];
if (!(_fallbackBldMax isEqualType 0)) then { _fallbackBldMax = 45; };
_fallbackBldMax = (_fallbackBldMax max (_fallbackBldMin + 1)) min 140;

private _fallbackWaterEdgeReject = missionNamespace getVariable ["civsub_v1_traffic_fallback_waterEdgeReject_m", 12];
if (!(_fallbackWaterEdgeReject isEqualType 0)) then { _fallbackWaterEdgeReject = 12; };
_fallbackWaterEdgeReject = (_fallbackWaterEdgeReject max 4) min 40;

// Failure counters (only logged when debug enabled)
private _fail_noPos = 0;
private _fail_excl = 0;
private _fail_playerNear = 0;
private _fail_createNull = 0;
private _fail_emptyPos = 0;
private _fail_fallbackContext = 0;
private _fail_waterEdge = 0;

private _veh = objNull;
private _attempts = 10;

for "_k" from 1 to _attempts do
{
    private _src = "POOL";
    private _cls = "";
    private _usePrefer = ((count _poolPrefer) > 0) && { (random 1) < _preferW };
    if (_usePrefer) then { _cls = selectRandom _poolPrefer; _src = "PREF"; } else {
        if ((count _poolFallback) > 0) then { _cls = selectRandom _poolFallback; _src = "FALL"; } else { _cls = selectRandom _pool; _src = "POOL"; };
    };
    if (_cls isEqualTo "") then { continue; };


    // 1) Preferred: roadside shoulder
    private _pick = [_center, _searchR, _minSep] call ARC_fnc_civsubTrafficPickRoadsidePos;
    private _pos = [];
    private _roadDir = random 360;
    if ((count _pick) >= 2) then
    {
        _pos = _pick select 0;
        _roadDir = _pick select 1;
    };

    // 2) Fallback: find safe empty position that still feels roadside/settlement-adjacent.
    if ((count _pos) == 0) then
    {
        _fail_noPos = _fail_noPos + 1;
        private _probe = _center getPos [random _searchR, random 360];
        _probe set [2, 0];
        if (surfaceIsWater _probe) then { continue; };

        private _ep = _probe findEmptyPosition [2, 20, _cls];
        if ((count _ep) < 2) then { _fail_emptyPos = _fail_emptyPos + 1; continue; };

        private _candPos = [_ep select 0, _ep select 1, 0];
        if (surfaceIsWater _candPos) then { _fail_waterEdge = _fail_waterEdge + 1; continue; };

        // Reject bank/edge candidates by probing nearby ring points for water transition.
        private _nearWaterEdge = false;
        private _stepDeg = 45;
        for "_a" from 0 to 315 step _stepDeg do
        {
            private _ring = _candPos getPos [_fallbackWaterEdgeReject, _a];
            _ring set [2, 0];
            if (surfaceIsWater _ring) exitWith { _nearWaterEdge = true; };
        };
        if (_nearWaterEdge) then { _fail_waterEdge = _fail_waterEdge + 1; continue; };

        // Fallback must still read as roadside OR settlement-adjacent.
        private _nearRoadsFb = _candPos nearRoads (_fallbackRoadMax + 8);
        private _roadBandOk = false;
        {
            private _rp = getPosATL _x;
            private _dr = _candPos distance2D _rp;
            if (_dr >= _fallbackRoadMin && { _dr <= _fallbackRoadMax }) exitWith { _roadBandOk = true; };
        } forEach _nearRoadsFb;

        private _nearBuildings = nearestObjects [_candPos, ["House", "Building"], _fallbackBldMax, true];
        private _buildingBandOk = false;
        {
            private _db = _candPos distance2D (getPosATL _x);
            if (_db >= _fallbackBldMin && { _db <= _fallbackBldMax }) exitWith { _buildingBandOk = true; };
        } forEach _nearBuildings;

        if (!(_roadBandOk || _buildingBandOk)) then { _fail_fallbackContext = _fail_fallbackContext + 1; continue; };

        _pos = _candPos;
        _roadDir = random 360;
    };

    // Phase 2 hard rule: parked vehicles may NEVER spawn on-road.
    if ([_pos] call _posIsRoadish) then
    {
        private _fixed = [_pos, 2, 24, 16] call _findOffRoad;
        if (_fixed isEqualTo [0,0,0]) then { _fail_noPos = _fail_noPos + 1; continue; };
        _pos = _fixed;
    };

    // Keep parked placements on reasonably flat ground.
    private _nSpawn = surfaceNormal _pos;
    private _slopeSpawn = acos ((_nSpawn vectorDotProduct [0,0,1]) max -1 min 1);
    if (_slopeSpawn > 0.35) then { _fail_noPos = _fail_noPos + 1; continue; }; // ~20 degrees

    // If we spawned near a road (including fallback), align to the nearest road direction.
    // This prevents parked cars from blocking lanes.
    private _nearRoads = _pos nearRoads 60;
    if ((count _nearRoads) > 0) then
    {
        private _nr = _nearRoads select 0;
        if (!isNull _nr) then
        {
            private _conn = roadsConnectedTo _nr;
            if ((count _conn) > 0) then
            {
                private _nr2 = selectRandom _conn;
                if (!isNull _nr2) then { _roadDir = _nr getDir _nr2; };
            };
        };
    };

    // Parked vehicles can face either direction along the road; add slight jitter.
    private _dirFinal = _roadDir + (selectRandom [0,180]) + (random 6 - 3);

    // Player safety distance
    if (_pMin > 0 && { (count _players) > 0 }) then
    {
        private _nearP = false;
        {
            if ((getPosATL _x) distance2D _pos <= _pMin) exitWith { _nearP = true; };
        } forEach _players;
        if (_nearP) then { _fail_playerNear = _fail_playerNear + 1; continue; };
    };

    // Exclusion zones (marker, radius)
    private _ex = missionNamespace getVariable ["civsub_v1_traffic_exclusions", []];
    if (_ex isEqualType []) then
    {
        private _blocked = false;
        {
            private _row = _x;
            if (!(_row isEqualType []) || { (count _row) < 2 }) then { continue; };
            private _m = _row select 0;
            private _rad = _row select 1;
            if !(_m isEqualType "") then { continue; };
            if !(_rad isEqualType 0) then { continue; };
            if (markerPos _m distance2D _pos <= _rad) exitWith { _blocked = true; };
        } forEach _ex;
        if (_blocked) then { _fail_excl = _fail_excl + 1; continue; };
    };

    _veh = createVehicle [_cls, _pos, [], 0, "NONE"];
    if (isNull _veh) then { _fail_createNull = _fail_createNull + 1; continue; };

    _veh setPosATL _pos;
    private _up = surfaceNormal _pos;
    private _fwd = [sin _dirFinal, cos _dirFinal, 0];
    _veh setVectorDirAndUp [_fwd, _up];
    _veh lock 0;

    // Tag for tracking
    _veh setVariable ["ARC_civtraf_role", "PARKED", true];
    _veh setVariable ["ARC_civtraf_districtId", _districtId, true];
    _veh setVariable ["ARC_civtraf_spawnTs", serverTime, true];

    _veh setVariable ["ARC_civtraf_modelSrc", _src, true];
    missionNamespace setVariable ["civsub_v1_traffic_lastSpawnClass", _cls, false];
    missionNamespace setVariable ["civsub_v1_traffic_lastSpawnSrc", _src, false];

    // Cleanup registration (deferred until players leave)
    private _cleanupR = missionNamespace getVariable ["civsub_v1_traffic_cleanupRadius_m", 900];
    if (!(_cleanupR isEqualType 0)) then { _cleanupR = 900; };
    private _minDelay = missionNamespace getVariable ["civsub_v1_traffic_cleanupMinDelay_s", 60];
    if (!(_minDelay isEqualType 0)) then { _minDelay = 60; };

    [[_veh], _pos, _cleanupR, _minDelay, format ["CIVTRAF:PARKED:%1", _districtId]] call ARC_fnc_cleanupRegister;
    break;
};

if (isNull _veh) then
{
    if (_dbg) then
    {
        diag_log format ["[CIVTRAF][SPAWN_FAIL] did=%1 noPos=%2 emptyPos=%3 fbCtx=%4 waterEdge=%5 excl=%6 playerNear=%7 createNull=%8 preferW=%9 preferN=%10 fallN=%11", _districtId, _fail_noPos, _fail_emptyPos, _fail_fallbackContext, _fail_waterEdge, _fail_excl, _fail_playerNear, _fail_createNull, _preferW, count _poolPrefer, count _poolFallback];
    };
};

_veh

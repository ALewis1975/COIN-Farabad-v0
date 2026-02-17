/*
    ARC_fnc_civsubTrafficSpawnParked

    Spawns one parked civilian vehicle for a district (server-only).

    Params:
      0: districtId (string)
      1: districtState (HashMap)
      2: vehiclePool (array of classnames)

    Returns: vehicle object or objNull
*/

if (!isServer) exitWith {objNull};

params [
    ["_districtId", "", [""]],
    ["_d", createHashMap, [createHashMap]],
    ["_pool", [], [[]]]
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

private _c = _d getOrDefault ["centroid", [0,0]];
private _r = _d getOrDefault ["radius_m", 400];
if !(_c isEqualType []) exitWith {objNull};
if ((count _c) < 2) exitWith {objNull};

// Operating center: average of players within the district (or fallback to centroid).
private _center = [_c # 0, _c # 1, 0];
private _players = allPlayers;
if ((count _players) > 0) then
{
    private _sumX = 0;
    private _sumY = 0;
    private _n = 0;
    {
        private _p = getPosATL _x;
        if ((_p distance2D _center) <= (_r + 200)) then
        {
            _sumX = _sumX + (_p # 0);
            _sumY = _sumY + (_p # 1);
            _n = _n + 1;
        };
    } forEach _players;

    if (_n > 0) then
    {
        _center = [_sumX / _n, _sumY / _n, 0];
    };
};

private _spawnR = missionNamespace getVariable ["civsub_v1_traffic_spawnRadius_m", 600];
if (!(_spawnR isEqualType 0)) then { _spawnR = 600; };
_spawnR = (_spawnR max 180) min 900;
// Keep within district, but ensure at least a reasonable local radius.
private _searchR = (_spawnR min ((_r max 250) min 950));

private _minSep = missionNamespace getVariable ["civsub_v1_traffic_minSeparation_m", 35];
if (!(_minSep isEqualType 0)) then { _minSep = 35; };

private _pMin = missionNamespace getVariable ["civsub_v1_traffic_playerMinDistance_m", 120];
if (!(_pMin isEqualType 0)) then { _pMin = 120; };
_pMin = (_pMin max 0) min 400;

// Failure counters (only logged when debug enabled)
private _fail_noPos = 0;
private _fail_excl = 0;
private _fail_playerNear = 0;
private _fail_createNull = 0;
private _fail_emptyPos = 0;

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
        _pos = _pick # 0;
        _roadDir = _pick # 1;
    };

    // 2) Fallback: any safe empty position near the operating center
    if ((count _pos) == 0) then
    {
        _fail_noPos = _fail_noPos + 1;
        private _probe = _center getPos [random _searchR, random 360];
        _probe set [2, 0];
        if (surfaceIsWater _probe) then { continue; };

        private _ep = _probe findEmptyPosition [2, 20, _cls];
        if ((count _ep) < 2) then { _fail_emptyPos = _fail_emptyPos + 1; continue; };
        _pos = [_ep # 0, _ep # 1, 0];
        _roadDir = random 360;
    };

    // Phase 2 hard rule: parked vehicles may NEVER spawn on-road.
    if ([_pos] call _posIsRoadish) then
    {
        private _fixed = [_pos, 2, 24, 16] call _findOffRoad;
        if (_fixed isEqualTo [0,0,0]) then { _fail_noPos = _fail_noPos + 1; continue; };
        _pos = _fixed;
    };

    // If we spawned near a road (including fallback), align to the nearest road direction.
    // This prevents parked cars from blocking lanes.
    private _nearRoads = _pos nearRoads 60;
    if ((count _nearRoads) > 0) then
    {
        private _nr = _nearRoads # 0;
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
            private _m = _row # 0;
            private _rad = _row # 1;
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
        diag_log format ["[CIVTRAF][SPAWN_FAIL] did=%1 noPos=%2 emptyPos=%3 excl=%4 playerNear=%5 createNull=%6 preferW=%7 preferN=%8 fallN=%9", _districtId, _fail_noPos, _fail_emptyPos, _fail_excl, _fail_playerNear, _fail_createNull, _preferW, count _poolPrefer, count _poolFallback];
    };
};

_veh

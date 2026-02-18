/*
    ARC_fnc_civsubTrafficTick

    Runs one CIVTRAF tick:
      - cleanup invalid refs
      - compute desired parked counts per active district
      - spawn parked vehicles within caps (mostly parked)
      - (optional) maintain a tiny number of moving vehicles

    Design goals:
      - deterministic cadence (global budget prevents burst spawns)
      - bias toward preferred (3CB) vehicle models
      - conservative cleanup discipline (uses ARC cleanup system)
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_traffic_enabled", false]) exitWith {false};

private _debug = missionNamespace getVariable ["civsub_v1_traffic_debug", false];
if (!(_debug isEqualType true)) then { _debug = false; };

private _parked = missionNamespace getVariable ["civsub_v1_traffic_list_parked", []];
private _moving = missionNamespace getVariable ["civsub_v1_traffic_list_moving", []];
if !(_parked isEqualType []) then { _parked = []; };
if !(_moving isEqualType []) then { _moving = []; };

private _deleteWrecks = missionNamespace getVariable ["civsub_v1_traffic_deleteWrecks", true];
if (!(_deleteWrecks isEqualType true)) then { _deleteWrecks = true; };

// Prune null/dead; optionally delete wrecks (keeps ambience clean)
private _parked2 = [];
{
    private _v = _x;
    if (isNull _v) then { continue; };
    if (!alive _v) then { if (_deleteWrecks) then { deleteVehicle _v; }; continue; };
    _parked2 pushBack _v;
} forEach _parked;

private _moving2 = [];
{
    private _v = _x;
    if (isNull _v) then { continue; };
    if (!alive _v) then { if (_deleteWrecks) then { deleteVehicle _v; }; continue; };
    _moving2 pushBack _v;
} forEach _moving;

_parked = _parked2;
_moving = _moving2;

// Ensure we have a usable vehicle pool (prefer + fallback validated)
// Rebuild when prefer/fallback lists change.
private _prefer = missionNamespace getVariable ["civsub_v1_traffic_vehiclePool_prefer", []];
private _fallback = missionNamespace getVariable ["civsub_v1_traffic_vehiclePool_fallback", []];
if (!(_prefer isEqualType [])) then { _prefer = []; };
if (!(_fallback isEqualType [])) then { _fallback = []; };

private _key = format ["P:%1|F:%2", str _prefer, str _fallback];
private _keyCached = missionNamespace getVariable ["civsub_v1_traffic_vehiclePool_valid_key", ""];
if (!(_keyCached isEqualType "")) then { _keyCached = ""; };

private _pool = missionNamespace getVariable ["civsub_v1_traffic_vehiclePool_valid", []];
if !(_pool isEqualType []) then { _pool = []; };

if ((count _pool) == 0 || { !(_keyCached isEqualTo _key) }) then
{
    _pool = [] call ARC_fnc_civsubTrafficBuildVehiclePool;
};

private _poolPrefer = missionNamespace getVariable ["civsub_v1_traffic_vehiclePool_valid_prefer", []];
private _poolFallback = missionNamespace getVariable ["civsub_v1_traffic_vehiclePool_valid_fallback", []];
if !(_poolPrefer isEqualType []) then { _poolPrefer = []; };
if !(_poolFallback isEqualType []) then { _poolFallback = []; };

if ((count _pool) == 0) exitWith
{
    missionNamespace setVariable ["civsub_v1_traffic_list_parked", _parked, true];
    missionNamespace setVariable ["civsub_v1_traffic_list_moving", _moving, true];
    if (_debug) then { diag_log "[CIVTRAF][TICK] pool=0 (no spawnable vehicle classes)"; };
    false
};

// Determine active districts (traffic has its own max; does not inherit civ sampler cap)
private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if !(_districts isEqualType createHashMap) exitWith {false};

private _players = [] call ARC_fnc_civsubBubbleGetPlayers;
if ((count _players) == 0) exitWith {false};

private _maxAD = missionNamespace getVariable ["civsub_v1_traffic_activeDistrictsMax", 3];
if (!(_maxAD isEqualType 0)) then { _maxAD = 3; };
if (_maxAD < 1) then { _maxAD = 1; };
private _fallbackDistrictIds = missionNamespace getVariable ["civsub_v1_activeDistrictIds", []];
if !(_fallbackDistrictIds isEqualType []) then { _fallbackDistrictIds = []; };

private _act = [];
private _trafficDistrictSource = "PLAYER_BUBBLE";

// Primary source: districts derived directly from player positions.
private _playerDistrictCounts = []; // [[districtId, count], ...]
{
    if (isNull _x) then { continue; };

    private _did = [getPosATL _x] call ARC_fnc_civsubDistrictsFindByPos;
    if (_did isEqualTo "") then { continue; };

    private _idx = -1;
    for "_i" from 0 to ((count _playerDistrictCounts) - 1) do
    {
        private _row = _playerDistrictCounts select _i;
        if (_row isEqualType [] && { (count _row) >= 2 } && { (_row select 0) isEqualTo _did }) exitWith
        {
            _idx = _i;
        };
    };

    if (_idx < 0) then {
        _playerDistrictCounts pushBack [_did, 1];
    } else {
        private _row = _playerDistrictCounts select _idx;
        private _cnt = _row select 1;
        if !(_cnt isEqualType 0) then { _cnt = 0; };
        _row set [1, _cnt + 1];
        _playerDistrictCounts set [_idx, _row];
    };
} forEach _players;

private _playerDistrictKeys = _playerDistrictCounts apply { _x select 0 };
if ((count _playerDistrictKeys) > 0) then
{
    private _rows = [];
    {
        private _did = _x;
        private _d = [_did] call ARC_fnc_civsubDistrictsGetById;
        if !(_d isEqualType createHashMap) then { continue; };
        if !([_d] call ARC_fnc_civsubIsDistrictActive) then { continue; };

        private _n = 0;
        for "_i" from 0 to ((count _playerDistrictCounts) - 1) do
        {
            private _row = _playerDistrictCounts select _i;
            if (_row isEqualType [] && { (count _row) >= 2 } && { (_row select 0) isEqualTo _did }) exitWith
            {
                _n = _row select 1;
            };
        };
        if !(_n isEqualType 0) then { _n = 0; };
        // Sort by descending player count, then stable district id.
        _rows pushBack [0 - _n, _did, _d];
    } forEach _playerDistrictKeys;

    _rows sort true;
    if ((count _rows) > _maxAD) then { _rows resize _maxAD; };
    _act = _rows;
};

// Fallback: previous centroid-nearest district ordering.
if ((count _act) == 0) then
{
    _trafficDistrictSource = "FALLBACK_CENTROID";

    {
        private _did = _x;
        private _d = [_did] call ARC_fnc_civsubDistrictsGetById;
        if !(_d isEqualType createHashMap) then { continue; };

        if ([_d] call ARC_fnc_civsubIsDistrictActive) then
        {
            // sort key: distance to nearest player (from district centroid)
            private _c = _d get "centroid";
            if (isNil "_c") then { _c = [0,0]; };
            if !(_c isEqualType []) then { _c = [0,0]; };
            if ((count _c) < 2) then { _c = [0,0]; };
            private _min = 1e12;
            {
                private _p = getPosATL _x;
                private _d2 = (_p distance2D [_c select 0, _c select 1, 0]);
                if (_d2 < _min) then { _min = _d2; };
            } forEach _players;

            _act pushBack [_min, _did, _d];
        };
    } forEach _fallbackDistrictIds;

    _act sort true;
    if ((count _act) > _maxAD) then { _act resize _maxAD; };
};

if (_debug) then
{
    private _selected = _act apply { _x select 1 };
    diag_log format ["[CIVTRAF][TICK] activeDistricts=%1 source=%2", _selected, _trafficDistrictSource];
};

private _opCenters = createHashMap;
{
    private _did = _x select 1;
    private _d = _x select 2;
    private _op = [_did, _d] call ARC_fnc_civsubTrafficResolveSpawnCenter;
    _opCenters set [_did, _op];
} forEach _act;
missionNamespace setVariable ["civsub_v1_traffic_opCenters", _opCenters, true];

// Global caps
private _capG = missionNamespace getVariable ["civsub_v1_traffic_cap_global", 18];
if (!(_capG isEqualType 0)) then { _capG = 18; };
if (_capG < 0) then { _capG = 0; };

private _capD = missionNamespace getVariable ["civsub_v1_traffic_cap_perDistrict", 10];
if (!(_capD isEqualType 0)) then { _capD = 10; };
if (_capD < 0) then { _capD = 0; };

private _budgetD = missionNamespace getVariable ["civsub_v1_traffic_spawn_budget_perDistrictPerTick", 1];
if (!(_budgetD isEqualType 0)) then { _budgetD = 1; };
if (_budgetD < 0) then { _budgetD = 0; };

// Spawn budgets are enforced per tick; keep defaults conservative for 1-2s cadence.
// Global budget prevents multi-district burst spawning inside a single tick.
private _budgetG = missionNamespace getVariable ["civsub_v1_traffic_spawn_budget_globalPerTick", 1];
if (!(_budgetG isEqualType 0)) then { _budgetG = 1; };
if (_budgetG < 0) then { _budgetG = 0; };

// Time-of-day multiplier (lightweight heuristic until TOD system exists)
private _tod = dayTime; // 0..24
private _mTod = 1.0;
if (_tod < 5 || { _tod > 21 }) then { _mTod = 0.35; };
if ((_tod >= 7 && { _tod <= 9 }) || (_tod >= 16 && { _tod <= 18 })) then { _mTod = 1.15; };

// Spawn parked vehicles per active district (mostly parked)
{
    if (_budgetG <= 0) exitWith {};
    private _did = _x select 1;
    private _d = _x select 2;

    // Compute S_THREAT (consistent with CIVSUB baseline)
    private _W = _d get "W_EFF_U";
    private _R = _d get "R_EFF_U";
    private _G = _d get "G_EFF_U";
    if (isNil "_W" || { !(_W isEqualType 0) }) then { _W = 45; };
    if (isNil "_R" || { !(_R isEqualType 0) }) then { _R = 55; };
    if (isNil "_G" || { !(_G isEqualType 0) }) then { _G = 35; };

    private _sThreat = ((_R) - (0.35 * _W) - (0.25 * _G));
    _sThreat = (_sThreat max 0) min 100;

    // Threat multiplier: higher threat -> fewer visible vehicles
    private _mThreat = 1.0 - (0.006 * _sThreat);
    _mThreat = (_mThreat max 0.25) min 1.0;

    // Pop multiplier: bigger towns get more traffic (normalized via pop_total)
    private _pop = _d get "pop_total";
    if (isNil "_pop" || { !(_pop isEqualType 0) }) then { _pop = 100; };
    private _mPop = 0.6 + (0.00025 * _pop); // 100 -> 0.625, 2000 -> 1.1
    _mPop = (_mPop max 0.5) min 1.2;

    private _desired = floor ((_capD * _mPop * _mThreat * _mTod) max 0);
    _desired = _desired min _capD;

    // Current parked count for this district
    private _cur = count (_parked select { !isNull _x && { alive _x } && { (_x getVariable ["ARC_civtraf_districtId",""]) isEqualTo _did } });

    private _budget = _budgetD;

    while { _cur < _desired && { (count _parked) < _capG } && { _budget > 0 } && { _budgetG > 0 } } do
    {
        private _op = _opCenters get _did;
        if (isNil "_op" || { !(_op isEqualType []) }) then { _op = []; };
        private _veh = [_did, _d, _pool, _op] call ARC_fnc_civsubTrafficSpawnParked;
        if (isNull _veh) exitWith { _budget = 0; };

        _parked pushBack _veh;
        _cur = _cur + 1;
        _budget = _budget - 1;
        _budgetG = _budgetG - 1;
    };
} forEach _act;

// Moving vehicles (rare; disabled by default in initServer)
private _allowMoving = missionNamespace getVariable ["civsub_v1_traffic_allow_moving", false];
if (_allowMoving) then
{
    private _capMG = missionNamespace getVariable ["civsub_v1_traffic_cap_moving_global", 1];
    if (!(_capMG isEqualType 0)) then { _capMG = 1; };
    if (_capMG < 0) then { _capMG = 0; };

    private _probM = missionNamespace getVariable ["civsub_v1_traffic_prob_moving", 0.10];
    if (!(_probM isEqualType 0)) then { _probM = 0.10; };

    // spawn one moving vehicle at most per tick, with probability
    if ((count _moving) < _capMG && { (count _act) > 0 } && { (random 1) < _probM }) then
    {
        private _row = selectRandom _act;
        private _did = _row select 1;
        private _d = _row select 2;

        private _drvCls = missionNamespace getVariable ["civsub_v1_traffic_driverClass", "C_man_1"];
        if (!(_drvCls isEqualType "")) then { _drvCls = "C_man_1"; };

        private _op = _opCenters get _did;
        if (isNil "_op" || { !(_op isEqualType []) }) then { _op = []; };
        private _pair = [_did, _d, _pool, _drvCls, _op] call ARC_fnc_civsubTrafficSpawnMoving;
        private _veh = _pair select 0;
        if (!isNull _veh) then { _moving pushBack _veh; };
    };

    // maintain moving destinations (simple hop between roads)
    {
        private _veh = _x;
        if (isNull _veh || { !alive _veh }) then { continue; };

        private _next = _veh getVariable ["ARC_civtraf_nextMoveTs", serverTime];
        if (serverTime < _next) then { continue; };

        private _drv = driver _veh;
        if (isNull _drv || { !alive _drv }) then { continue; };

        private _curPos = getPosATL _veh;
        private _roads = _curPos nearRoads 120;
        if ((count _roads) == 0) then
        {
            _veh setVariable ["ARC_civtraf_nextMoveTs", serverTime + 10, true];
            continue;
        };

        private _r = selectRandom _roads;
        private _conn = roadsConnectedTo _r;
        private _destPos = getPosATL _r;
        if ((count _conn) > 0) then
        {
            private _r2 = selectRandom _conn;
            if (!isNull _r2) then { _destPos = getPosATL _r2; };
        };

        _drv doMove _destPos;
        _veh setVariable ["ARC_civtraf_moveTarget", _destPos, true];
        _veh setVariable ["ARC_civtraf_nextMoveTs", serverTime + (10 + random 15), true];
    } forEach _moving;
};

missionNamespace setVariable ["civsub_v1_traffic_list_parked", _parked, true];
missionNamespace setVariable ["civsub_v1_traffic_list_moving", _moving, true];

// Tick counter + periodic diagnostics
private _ti = missionNamespace getVariable ["civsub_v1_traffic_tick_i", 0];
if (!(_ti isEqualType 0)) then { _ti = 0; };
_ti = _ti + 1;
missionNamespace setVariable ["civsub_v1_traffic_tick_i", _ti, false];

if (_debug && { (_ti mod 10) == 0 }) then
{
    private _actIds = _act apply { _x select 1 };
    diag_log format ["[CIVTRAF][TICK] i=%1 active=%2 parked=%3 moving=%4 pool=%5 prefer=%6 fallback=%7 budgetG=%8",
        _ti, _actIds, count _parked, count _moving, count _pool, count _poolPrefer, count _poolFallback, (missionNamespace getVariable ["civsub_v1_traffic_spawn_budget_globalPerTick", 1])
    ];
};

true

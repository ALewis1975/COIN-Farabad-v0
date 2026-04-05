/*
    ARC_fnc_airbaseGroundTrafficTick

    One tick of the airbase ground vehicle traffic system (server-only).
    For each configured spawn zone, counts existing tagged vehicles; spawns one
    if the zone is under its cap and players are present within spawn range.

    Reads (mission namespace):
        airbase_v1_gnd_zones          — array of zone definitions
        airbase_v1_gnd_list           — array of tracked vehicle objects
        airbase_v1_gnd_pool_valid_<c> — validated pool arrays per category
        airbase_v1_gnd_debug          — bool

    Writes:
        airbase_v1_gnd_list           — updated vehicle tracking list
*/

if (!isServer) exitWith { false };
if !(["airbaseGroundTrafficTick"] call ARC_fnc_airbaseRuntimeEnabled) exitWith { false };

private _dbg = missionNamespace getVariable ["airbase_v1_gnd_debug", false];
if (!(_dbg isEqualType true)) then { _dbg = false; };

private _todPolicy = [] call ARC_fnc_dynamicTodRefresh;
private _canSpawnAirbase = _todPolicy getOrDefault ["canSpawnAirbase", true];
if (!(_canSpawnAirbase isEqualType true) && !(_canSpawnAirbase isEqualType false)) then { _canSpawnAirbase = true; };
private _todPhase = _todPolicy getOrDefault ["phase", "DAY"];
if (!(_todPhase isEqualType "")) then { _todPhase = "DAY"; };

// -------------------------------------------------------------------------
// 1) Prune dead / deleted vehicles from the tracking list
// -------------------------------------------------------------------------
private _list = missionNamespace getVariable ["airbase_v1_gnd_list", []];
if (!(_list isEqualType [])) then { _list = []; };

private _pruned = [];
{
    if (alive _x) then { _pruned pushBack _x; };
} forEach _list;
_list = _pruned;
missionNamespace setVariable ["airbase_v1_gnd_list", _list, false];

// -------------------------------------------------------------------------
// 2) Global cap guard
// -------------------------------------------------------------------------
private _capGlobal = missionNamespace getVariable ["airbase_v1_gnd_cap_global", 24];
if (!(_capGlobal isEqualType 0)) then { _capGlobal = 24; };

if ((count _list) >= _capGlobal) exitWith
{
    if (_dbg) then { diag_log "[ARC][ABTRAF][TICK] global cap reached, skipping spawn."; };
    false
};

// -------------------------------------------------------------------------
// 3) Process each zone
// -------------------------------------------------------------------------
private _zones = missionNamespace getVariable ["airbase_v1_gnd_zones", []];
if (!(_zones isEqualType [])) then { _zones = []; };

private _players = allPlayers;
private _playerPresenceRadius = missionNamespace getVariable ["airbase_v1_gnd_playerPresenceRadius_m", 1800];
if (!(_playerPresenceRadius isEqualType 0)) then { _playerPresenceRadius = 1800; };

{
    private _zoneDef = _x;
    // zone format: [zoneId, markerName, spawnRadius, poolCategories, zoneCap]
    if (!(_zoneDef isEqualType [])) then { continue };
    if ((count _zoneDef) < 5) then { continue };

    private _zoneId   = _zoneDef select 0;
    private _mkr      = _zoneDef select 1;
    private _spawnR   = _zoneDef select 2;
    private _cats     = _zoneDef select 3;
    private _zoneCap  = _zoneDef select 4;

    if (!(_zoneId isEqualType "")) then { continue };
    if (!(_mkr isEqualType "")) then { continue };
    if (!(_spawnR isEqualType 0)) then { continue };
    if (!(_cats isEqualType [])) then { continue };
    if (!(_zoneCap isEqualType 0)) then { continue };

    // Verify marker exists
    private _zonePos = getMarkerPos _mkr;
    if (_zonePos isEqualTo [0,0,0]) then
    {
        diag_log format ["[ARC][ABTRAF][TICK] WARN zone=%1 marker=%2 not found, skipping.", _zoneId, _mkr];
        continue
    };

    // Player presence check — only spawn when players are in range
    private _playersNear = false;
    {
        if ((getPos _x) distance2D _zonePos <= _playerPresenceRadius) exitWith { _playersNear = true; };
    } forEach _players;

    if (!_playersNear) then
    {
        if (_dbg) then { diag_log format ["[ARC][ABTRAF][TICK] zone=%1 no players in range, skipping.", _zoneId]; };
        continue
    };

    // Count how many tracked vehicles belong to this zone
    private _zoneCount = 0;
    {
        if ((_x getVariable ["ARC_abtraf_zoneId", ""]) isEqualTo _zoneId) then { _zoneCount = _zoneCount + 1; };
    } forEach _list;

    if (_zoneCount >= _zoneCap) then
    {
        if (_dbg) then { diag_log format ["[ARC][ABTRAF][TICK] zone=%1 at cap (%2/%3), skipping.", _zoneId, _zoneCount, _zoneCap]; };
        continue
    };

    // Build candidate pool from zone categories
    private _pool = [];
    {
        private _cat = _x;
        private _catKey = format ["airbase_v1_gnd_pool_valid_%1", _cat];
        private _catPool = missionNamespace getVariable [_catKey, []];
        if (_catPool isEqualType []) then
        {
            _pool = _pool + (_catPool select { !(_x in _pool) });
        };
    } forEach _cats;

    if ((count _pool) == 0) then
    {
        if (_dbg) then { diag_log format ["[ARC][ABTRAF][TICK] zone=%1 empty pool, skipping.", _zoneId]; };
        continue
    };

    // Pick a classname
    private _cls = selectRandom _pool;

    // Find an empty position near the zone marker, off-road if possible
    private _ep = _zonePos findEmptyPosition [4, _spawnR, _cls];
    if ((count _ep) < 2) then
    {
        if (_dbg) then { diag_log format ["[ARC][ABTRAF][TICK] zone=%1 cls=%2 no empty pos found.", _zoneId, _cls]; };
        continue
    };

    private _pos = [_ep select 0, _ep select 1, 0];

    // Reject water
    if (surfaceIsWater _pos) then
    {
        if (_dbg) then { diag_log format ["[ARC][ABTRAF][TICK] zone=%1 pos is water, skipping.", _zoneId]; };
        continue
    };

    // Slope guard (~20 deg max)
    private _nrm = surfaceNormal _pos;
    private _slope = acos ((_nrm vectorDotProduct [0,0,1]) max -1 min 1);
    if (_slope > 0.35) then
    {
        if (_dbg) then { diag_log format ["[ARC][ABTRAF][TICK] zone=%1 slope %2 too steep, skipping.", _zoneId, _slope]; };
        continue
    };

    // Align to nearest road direction for visual coherence
    private _dir = random 360;
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
                if (!isNull _nr2) then { _dir = _nr getDir _nr2; };
            };
        };
    };
    // Allow facing either direction along road + small jitter
    _dir = _dir + (selectRandom [0, 180]) + (random 6 - 3);

    if (!_canSpawnAirbase) then
    {
        if (_dbg) then { diag_log format ["[ARC][ABTRAF][TOD] spawn suppressed zone=%1 phase=%2", _zoneId, _todPhase]; };
        continue
    };

    // Spawn vehicle (no crew — ambient parked)
    private _veh = createVehicle [_cls, _pos, [], 0, "NONE"];
    if (isNull _veh) then
    {
        diag_log format ["[ARC][ABTRAF][TICK] zone=%1 cls=%2 createVehicle returned null.", _zoneId, _cls];
        continue
    };

    _veh setPosATL _pos;
    private _up = surfaceNormal _pos;
    private _fwd = [sin _dir, cos _dir, 0];
    _veh setVectorDirAndUp [_fwd, _up];
    _veh lock 0;

    // Tag for tracking and cleanup
    _veh setVariable ["ARC_abtraf_zoneId",   _zoneId, false];
    _veh setVariable ["ARC_abtraf_cls",      _cls,    false];
    _veh setVariable ["ARC_abtraf_spawnTs",  serverTime, false];
    _veh setVariable ["ARC_dynamic_tod_phase_spawn", _todPhase, false];
    _veh setVariable ["ARC_dynamic_tod_profile_spawn", _todPolicy getOrDefault ["profile", "STANDARD"], false];

    _list pushBack _veh;

    // Register with ARC cleanup system (despawn when players leave area)
    private _cleanupR = missionNamespace getVariable ["airbase_v1_gnd_cleanupRadius_m", 1600];
    if (!(_cleanupR isEqualType 0)) then { _cleanupR = 1600; };
    private _cleanupDelay = missionNamespace getVariable ["airbase_v1_gnd_cleanupDelay_s", 90];
    if (!(_cleanupDelay isEqualType 0)) then { _cleanupDelay = 90; };

    [[_veh], _pos, _cleanupR, _cleanupDelay, format ["ABTRAF:%1", _zoneId]] call ARC_fnc_cleanupRegister;

    diag_log format ["[ARC][ABTRAF][TICK] spawned zone=%1 cls=%2 pos=%3 count=%4/%5", _zoneId, _cls, _pos, _zoneCount + 1, _zoneCap];

} forEach _zones;

missionNamespace setVariable ["airbase_v1_gnd_list", _list, false];

true

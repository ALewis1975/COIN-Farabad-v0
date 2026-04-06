/*
    ARC_fnc_civsubTrafficSpawnMoving

    Spawns one moving civilian vehicle (rare) for ambience.
    Gated by:
      - civsub_v1_traffic_allow_moving (bool)
      - caps in civsub_v1_traffic_cap_moving_global / perDistrict

    Params:
      0: districtId (string)
      1: districtState (HashMap)
      2: vehiclePool (array)
      3: driverClass (string)

    Returns: [vehicle, driver] or [objNull, objNull]
*/

if (!isServer) exitWith {[objNull, objNull]};

missionNamespace setVariable ["civsub_v1_traffic_lastMovingSpawnFail", "", false];
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _todPolicy = [] call ARC_fnc_dynamicTodGetPolicy;
private _todPhase = [_todPolicy, "phase", "DAY"] call _hg;
if (!(_todPhase isEqualType "")) then { _todPhase = "DAY"; };

params [
    ["_districtId", "", [""]],
    ["_d", createHashMap, [createHashMap]],
    ["_pool", [], [[]]],
    ["_driverCls", "C_man_1", [""]],
    ["_opCenter", [], [[]]]
];

if !(missionNamespace getVariable ["civsub_v1_traffic_allow_moving", false]) exitWith {[objNull, objNull]};
if (_districtId isEqualTo "") exitWith {[objNull, objNull]};
if !(_d isEqualType createHashMap) exitWith {[objNull, objNull]};
if !(_pool isEqualType []) exitWith {[objNull, objNull]};
if ((count _pool) == 0) exitWith {[objNull, objNull]};

private _c = [_d, "centroid", [0,0]] call _hg;
if !(_c isEqualType []) exitWith {[objNull, objNull]};
if ((count _c) < 2) exitWith {[objNull, objNull]};

private _center = [_c select 0, _c select 1, 0];
if (_opCenter isEqualType [] && { (count _opCenter) >= 2 }) then
{
    _center = [_opCenter select 0, _opCenter select 1, 0];
};

private _spawnR = missionNamespace getVariable ["civsub_v1_traffic_spawnRadius_m", 600];
if (!(_spawnR isEqualType 0)) then { _spawnR = 600; };
// Upper bound raised to 1500 to support out-of-view-distance spawning (1 km+).
_spawnR = (_spawnR max 250) min 1500;
// Use _spawnR directly; the former district-radius cap would prevent spawning
// beyond the district edge even when spawnRadius_m is configured at 1400 m.
private _searchR = _spawnR;

private _pick = [_center, _searchR, (missionNamespace getVariable ["civsub_v1_traffic_minSeparation_m", 35])] call ARC_fnc_civsubTrafficPickRoadsidePos;
if ((count _pick) < 2) exitWith
{
    missionNamespace setVariable ["civsub_v1_traffic_lastMovingSpawnFail", "noRoadsidePos", false];
    [objNull, objNull]
};

private _pos = _pick select 0;
private _dir = _pick select 1;

private _pMin = missionNamespace getVariable ["civsub_v1_traffic_playerMinDistance_m", 60];
if (!(_pMin isEqualType 0)) then { _pMin = 60; };
// Upper bound raised to 1200 to allow out-of-view-distance enforcement (1 km view).
_pMin = (_pMin max 50) min 1200;
if (_pMin > 0) then
{
    private _nearP = false;
    {
        if ((getPosATL _x) distance2D _pos <= _pMin) exitWith { _nearP = true; };
    } forEach allPlayers;
    if (_nearP) exitWith
    {
        missionNamespace setVariable ["civsub_v1_traffic_lastMovingSpawnFail", "playerTooNear", false];
        [objNull, objNull]
    };
};

private _cls = selectRandom _pool;
private _veh = createVehicle [_cls, _pos, [], 0, "NONE"];
if (isNull _veh) exitWith
{
    missionNamespace setVariable ["civsub_v1_traffic_lastMovingSpawnFail", "createFail", false];
    [objNull, objNull]
};

_veh setDir _dir;
_veh setPosATL _pos;
_veh setVectorUp (surfaceNormal _pos);
_veh lock 0;

// Civilian driver
private _grp = createGroup [civilian, true];
private _drv = _grp createUnit [_driverCls, _pos, [], 0, "NONE"];
if (isNull _drv) exitWith
{
    deleteVehicle _veh;
    missionNamespace setVariable ["civsub_v1_traffic_lastMovingSpawnFail", "createFail", false];
    [objNull, objNull]
};

_drv moveInDriver _veh;

// Civilian-ish behavior
_drv setBehaviour "CARELESS";
_drv setCombatMode "BLUE";
_drv disableAI "AUTOCOMBAT";
_drv disableAI "TARGET";
_drv disableAI "SUPPRESSION";
_drv setSpeedMode "LIMITED";
_drv limitSpeed (missionNamespace getVariable ["civsub_v1_traffic_moving_maxSpeed", 35]);

// Tags
_veh setVariable ["ARC_civtraf_role", "MOVING", true];
_veh setVariable ["ARC_civtraf_districtId", _districtId, true];
_veh setVariable ["ARC_civtraf_spawnTs", serverTime, true];
_veh setVariable ["ARC_civtraf_nextMoveTs", serverTime, true];
_veh setVariable ["ARC_civtraf_moveTarget", _pos, true];
_veh setVariable ["ARC_dynamic_tod_phase_spawn", _todPhase, true];
_veh setVariable ["ARC_dynamic_tod_profile_spawn", [_todPolicy, "profile", "STANDARD"] call _hg, true];

_drv setVariable ["ARC_civtraf_role", "MOVING_DRIVER", true];

// Cleanup registration (delete both when bubble clears)
private _cleanupR = missionNamespace getVariable ["civsub_v1_traffic_cleanupRadius_m", 900];
if (!(_cleanupR isEqualType 0)) then { _cleanupR = 900; };
private _minDelay = missionNamespace getVariable ["civsub_v1_traffic_cleanupMinDelay_s", 60];
if (!(_minDelay isEqualType 0)) then { _minDelay = 60; };

[[_veh, _drv], _pos, _cleanupR, _minDelay, format ["CIVTRAF:MOVING:%1", _districtId]] call ARC_fnc_cleanupRegister;

[_veh, _drv]

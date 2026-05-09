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

// Moving vehicles spawn ON the road (lane centre) facing the direction of
// travel — not on the off-road shoulder used by parked vehicles. The picker
// also rejects road-network edges (dead-ends) so the AI has somewhere to drive.
private _pick = [_center, _searchR, (missionNamespace getVariable ["civsub_v1_traffic_minSeparation_m", 35])] call ARC_fnc_civsubTrafficPickRoadDrivePos;
if ((count _pick) < 3) exitWith
{
    // Reason string kept as "noRoadsidePos" for backward compatibility with the
    // diagnostics counter `civsub_v1_traffic_dbg_moving_spawnFail_noRoadsidePos`
    // tallied in fn_civsubTrafficTick.sqf.
    missionNamespace setVariable ["civsub_v1_traffic_lastMovingSpawnFail", "noRoadsidePos", false];
    [objNull, objNull]
};

private _pos = _pick select 0;
private _dir = _pick select 1;
private _nextRoadPos = _pick select 2;

private _pMin = missionNamespace getVariable ["civsub_v1_traffic_playerMinDistance_m", 60];
if (!(_pMin isEqualType 0)) then { _pMin = 60; };
// Upper bound raised to 1200 to allow out-of-view-distance enforcement (1 km view).
_pMin = (_pMin max 50) min 1200;
private _nearP = false;
if (_pMin > 0) then
{
    {
        if ((getPosATL _x) distance2D _pos <= _pMin) exitWith { _nearP = true; };
    } forEach allPlayers;
};
if (_nearP) exitWith
{
    missionNamespace setVariable ["civsub_v1_traffic_lastMovingSpawnFail", "playerTooNear", false];
    [objNull, objNull]
};

// Reject if too close to any active convoy vehicle. Convoy vehicles may be AI-led
// (no player aboard) so the player-distance gate above is not sufficient.
private _convoyMin = missionNamespace getVariable ["civsub_v1_traffic_convoyMinDistance_m", 1050];
if (!(_convoyMin isEqualType 0)) then { _convoyMin = 1050; };
_convoyMin = (_convoyMin max 0) min 1500;
private _nearC = false;
if (_convoyMin > 0) then
{
    private _cIds = missionNamespace getVariable ["ARC_activeConvoyNetIds", []];
    if (!(_cIds isEqualType [])) then { _cIds = []; };
    {
        private _cv = objectFromNetId _x;
        if (!isNull _cv && { alive _cv } && { (getPosATL _cv) distance2D _pos <= _convoyMin }) exitWith { _nearC = true; };
    } forEach _cIds;
};
if (_nearC) exitWith
{
    missionNamespace setVariable ["civsub_v1_traffic_lastMovingSpawnFail", "convoyTooNear", false];
    [objNull, objNull]
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
_veh forceFollowRoad true;

// Final post-create collision check using the actual vehicle bounding box.
// The picker reserves clearance against pre-existing scenery, but another
// subsystem may have spawned an object at the same position between pick
// and create. Compute the half-diagonal of the bounding box and reject if
// any non-road / non-self / non-driver object intersects that radius.
private _bb = boundingBoxReal _veh;
private _bbMin = _bb select 0;
private _bbMax = _bb select 1;
private _bbR = (((_bbMax select 0) - (_bbMin select 0)) max ((_bbMax select 1) - (_bbMin select 1))) * 0.6;
_bbR = (_bbR max 3) min 10;
private _collide = false;
{
    if (_collide) then { continue; };
    if (isNull _x) then { continue; };
    if (_x isEqualTo _veh) then { continue; };
    if (_x isKindOf "Road") then { continue; };
    if ((typeOf _x) isEqualTo "") then { continue; };
    _collide = true;
} forEach (_pos nearObjects _bbR);
if (_collide) exitWith
{
    deleteVehicle _veh;
    missionNamespace setVariable ["civsub_v1_traffic_lastMovingSpawnFail", "spawnCollision", false];
    [objNull, objNull]
};

// Civilian driver
private _grp = createGroup [civilian, true];
_grp setGroupIdGlobal ["CIV Traffic"];
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

// Seed initial movement toward the connected road segment so the AI begins
// driving in the heading we just set. Without this, the next traffic tick
// might pick a destination behind the vehicle and force an immediate U-turn,
// which would defeat the "spawn facing direction of travel" guarantee.
private _wpRefreshBase = missionNamespace getVariable ["civsub_v1_traffic_moving_waypointRefreshBase_s", 90];
if (!(_wpRefreshBase isEqualType 0)) then { _wpRefreshBase = 90; };
_wpRefreshBase = (_wpRefreshBase max 30) min 600;
private _wpRefreshJitter = missionNamespace getVariable ["civsub_v1_traffic_moving_waypointRefreshJitter_s", 60];
if (!(_wpRefreshJitter isEqualType 0)) then { _wpRefreshJitter = 60; };
_wpRefreshJitter = (_wpRefreshJitter max 0) min 300;

_drv doMove _nextRoadPos;

// Tags
_veh setVariable ["ARC_civtraf_role", "MOVING", true];
_veh setVariable ["ARC_civtraf_districtId", _districtId, true];
_veh setVariable ["ARC_civtraf_spawnTs", serverTime, true];
_veh setVariable ["ARC_civtraf_nextMoveTs", serverTime + (_wpRefreshBase + random _wpRefreshJitter), true];
_veh setVariable ["ARC_civtraf_moveTarget", _nextRoadPos, true];
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

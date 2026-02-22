/*
    File: functions/ambiance/fn_airbaseAttackTowDepart.sqf
    Author: ARC / Ambient Airbase Subsystem

    Description:
      Handles "tow out" departures for attack aircraft:
        1) A ground tug with a driver tows the aircraft along a captured tow path
        2) The tug returns to its start position and the driver resumes idle
        3) The normal departure routine (ARC_fnc_airbasePlaneDepart) takes over

    Key constraint:
      - NO moveIn* usage. Tug driver boards via assignAsDriver + orderGetIn.

    Params:
      0: STRING - flight id
      1: HASHMAP - asset runtime hash

    Returns:
      BOOL
*/

if (!isServer) exitWith { false };

params ["_fid", "_asset"];
if (isNil "_asset" || {!(_asset isEqualType createHashMap)}) exitWith { false };

private _debug    = missionNamespace getVariable ["airbase_v1_debug", false];
private _debugOps = missionNamespace getVariable ["airbase_v1_debugOpsLog", false];

private _veh = _asset getOrDefault ["veh", objNull];
if (isNull _veh) exitWith {
    _asset set ["state", "PARKED"]; 
    _asset set ["activeFlight", ""]; 
    false
};

private _vehType = typeOf _veh;
private _towVehVar  = _asset getOrDefault ["towVehVar", ""]; 
private _towCrewVar = _asset getOrDefault ["towCrewVar", ""]; 
private _towPathVar = _asset getOrDefault ["towPathVar", ""]; 

private _towVeh = if (_towVehVar != "") then { missionNamespace getVariable [_towVehVar, objNull] } else { objNull };
private _towCrew = if (_towCrewVar != "") then { missionNamespace getVariable [_towCrewVar, objNull] } else { objNull };

if (isNull _towVeh || {isNull _towCrew}) exitWith {
    if (_debug) then { diag_log format ["[AIRBASESUB] %1 tow assets missing for %2 (%3/%4)", _fid, _vehType, _towVehVar, _towCrewVar]; };
    // Fail back to a normal departure attempt (at least prevents deadlocking the queue).
    [_fid, _asset] call ARC_fnc_airbasePlaneDepart
};

// Helpers
private _fnNormalize = {
    params ["_data"]; 
    if (!(_data isEqualType [])) exitWith { [] };
    if ((count _data) == 1 && { (_data # 0) isEqualType [] } && { (count (_data # 0)) > 0 } && { ((_data # 0) # 0) isEqualType [] }) exitWith {
        _data # 0
    };
    _data
};

private _fnUnitPlayBlocking = {
    params ["_vehL", "_framesL"]; 
    if (isNull _vehL) exitWith { false };
    if ((count _framesL) == 0) exitWith { false };

    _vehL enableSimulationGlobal true;
    _vehL allowDamage false;
    _vehL engineOn true;
    _vehL setVelocity [0,0,0];
    _vehL setVelocityModelSpace [0,0,0];

    private _duration = 0;
    private _last = _framesL select ((count _framesL) - 1);
    if (_last isEqualType [] && { (count _last) > 0 } && { (_last # 0) isEqualType 0 }) then { _duration = (_last # 0); };
    private _tEnd = time + (_duration + 10);

    private _h = [_vehL, _framesL] spawn BIS_fnc_unitPlay;
    waitUntil {
        sleep 0.25;
        isNull _vehL || {!alive _vehL} || {scriptDone _h} || {time > _tEnd}
    };

    !(isNull _vehL) && {alive _vehL}
};

// --- Board tug driver (NO moveIn) ---
_towVeh lock false;
[_towCrew] call ARC_fnc_airbaseCrewIdleStop;
_towCrew forceWalk true;
unassignVehicle _towCrew;
_towCrew assignAsDriver _towVeh;
[_towCrew] orderGetIn true;

private _t0 = time;
waitUntil {
    sleep 1;
    isNull _towVeh || {!alive _towVeh} || {!alive _towCrew} ||
    ((driver _towVeh) isEqualTo _towCrew) ||
    ((time - _t0) > 90)
};
_towCrew forceWalk false;

if ((driver _towVeh) isNotEqualTo _towCrew) then {
    if (_debug) then { diag_log format ["[AIRBASESUB] %1 tow driver failed to board tug", _fid]; };
    // Continue anyway (tow will likely fail, but avoid hard deadlock)
};

// Capture start pos for tug return
private _towStartPos = getPosATL _towVeh;
private _towStartDir = getDir _towVeh;

// --- Tow playback ---
private _towData = missionNamespace getVariable [_towPathVar, []];
private _towFrames = [_towData] call _fnNormalize;

if ((count _towFrames) == 0) exitWith {
    if (_debug) then { diag_log format ["[AIRBASESUB] %1 tow path empty (%2)", _fid, _towPathVar]; };
    _asset set ["state", "PARKED"]; 
    _asset set ["activeFlight", ""]; 
    false
};

_towVeh enableSimulationGlobal true;
_veh enableSimulationGlobal true;
_towVeh allowDamage false;
_veh allowDamage false;

// Attach aircraft to tug (simple tow)
_veh attachTo [_towVeh, [0, -6, 0.6]];
_veh setDir (getDir _towVeh);

private _okTow = [_towVeh, _towFrames] call _fnUnitPlayBlocking;

detach _veh;
_veh setVelocity [0,0,0];
_veh setVelocityModelSpace [0,0,0];

if (!_okTow) then {
    if (_debug) then { diag_log format ["[AIRBASESUB] %1 tow playback aborted", _fid]; };
};

// --- Return tug to start and idle the driver ---
// Let the driver drive back; if it fails, we still hard-reset to keep ambience clean.
private _gTow = group _towCrew;
if (!isNull _gTow) then {
    _gTow setBehaviour "SAFE";
    _gTow setCombatMode "BLUE";
    _gTow move _towStartPos;
};

private _tRet = time + 120;
waitUntil {
    sleep 2;
    isNull _towVeh || {!alive _towVeh} || ((_towVeh distance2D _towStartPos) < 15) || (time > _tRet)
};

// Dismount + reset position to avoid tug wandering around taxiways
if (!isNull _towCrew && {alive _towCrew} && {(vehicle _towCrew) isEqualTo _towVeh}) then {
    unassignVehicle _towCrew;
    doGetOut _towCrew;
};

sleep 2;
if (!isNull _towVeh) then { _towVeh setPosATL _towStartPos; _towVeh setDir _towStartDir; };
if (!isNull _towCrew) then { _towCrew setPosATL (_towStartPos vectorAdd [2,0,0]); };

[_towCrew] call ARC_fnc_airbaseCrewIdleStart;

// --- Hand off to the standard departure routine (boarding + taxi + takeoff) ---
[_fid, _asset] call ARC_fnc_airbasePlaneDepart

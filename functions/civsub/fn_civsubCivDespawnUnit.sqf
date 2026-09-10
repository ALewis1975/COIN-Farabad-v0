/*
    ARC_fnc_civsubCivDespawnUnit

    Deletes an eligible living civilian and its group if empty.
    Returns false when deletion is refused; callers must retain its registry row.

    Params:
      0: unit (object)
*/

if (!isServer) exitWith {
    diag_log "[CIVSUB][CIVS][DESPAWN] GUARD FAIL not_server";
    false
};

params [
    ["_unit", objNull, [objNull]]
];
if (isNull _unit) exitWith {false};

private _grp = grpNull;
private _uid = "";
private _pos = [];
private _nid = "";
private _localTask = "";
private _overlayTask = "";
private _source = "";
private _deleted = false;

// Revalidate at the destructive boundary. Keep this section unscheduled so a
// protection change cannot interleave between the guard and deleteVehicle.
isNil {
    if (isNull _unit || { !alive _unit } || { isPlayer _unit }) exitWith {};
    if ([_unit] call ARC_fnc_civsubCivIsProtected) exitWith {};

    _grp = group _unit;
    _uid = _unit getVariable ["civ_uid", ""];
    _pos = getPosATL _unit;
    _nid = netId _unit;
    _localTask = _unit getVariable ["ARC_localSupportTaskId", ""];
    _overlayTask = _unit getVariable ["ARC_overlayTaskId", ""];
    _source = _unit getVariable ["civsub_v1_connectSource", ""];
    deleteVehicle _unit;
    _deleted = true;
};
if (!_deleted) exitWith {false};

if (!isNull _grp) then {
    uiSleep 0.01;
    if ((count units _grp) == 0) then { deleteGroup _grp; };
};

diag_log format [
    "[CIVSUB][CIVS][DESPAWN] OK civ_uid=%1 pos=%2 ts=%3 actor=SERVER netId=%4 localTask=%5 overlayTask=%6 grid=%7 source=%8",
    _uid, _pos, serverTime, _nid, _localTask, _overlayTask, mapGridPosition _pos, _source
];

true

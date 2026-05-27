/*
    ARC_fnc_civsubCivDespawnUnit

    Deletes a civilian unit and its group if empty.

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

private _grp = group _unit;
private _uid = _unit getVariable ["civ_uid", ""];
private _pos = getPosATL _unit;

deleteVehicle _unit;

if (!isNull _grp) then {
    uiSleep 0.01;
    if ((count units _grp) == 0) then { deleteGroup _grp; };
};

diag_log format ["[CIVSUB][CIVS][DESPAWN] OK civ_uid=%1 pos=%2", _uid, _pos];

true

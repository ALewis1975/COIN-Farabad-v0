/*
    ARC_fnc_civsubCivDespawnUnit

    Deletes a civilian unit and its group if empty.

    Params:
      0: unit (object)
*/

if (!isServer) exitWith {false};

params [
    ["_unit", objNull, [objNull]]
];
if (isNull _unit) exitWith {false};

private _grp = group _unit;

deleteVehicle _unit;

if (!isNull _grp) then {
    uiSleep 0.01;
    if ((count units _grp) == 0) then { deleteGroup _grp; };
};

true

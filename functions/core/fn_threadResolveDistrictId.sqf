/*
    Resolve thread district id from position when CIVSUB is enabled.

    Params:
      0: ARRAY position [x,y,z]

    Returns:
      STRING district id or "".
*/

if (!isServer) exitWith {""};

params [
    ["_pos", [], [[]]]
];

if !(_pos isEqualType []) exitWith {""};
if ((count _pos) < 2) exitWith {""};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {""};

[_pos] call ARC_fnc_civsubDistrictsFindByPos

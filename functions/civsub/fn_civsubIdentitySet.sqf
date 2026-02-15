/*
    ARC_fnc_civsubIdentitySet

    Params:
      0: civ_uid (string)
      1: record (HashMap)

    Returns: bool
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

params [
    ["_civUid", "", [""]],
    ["_rec", createHashMap, [createHashMap]]
];

if (_civUid isEqualTo "") exitWith {false};

private _ids = missionNamespace getVariable ["civsub_v1_identities", createHashMap];
if !(_ids isEqualType createHashMap) then { _ids = createHashMap; };

_ids set [_civUid, _rec];
missionNamespace setVariable ["civsub_v1_identities", _ids, true];

true

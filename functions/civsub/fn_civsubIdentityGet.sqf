/*
    ARC_fnc_civsubIdentityGet

    Params:
      0: civ_uid (string)

    Returns: HashMap identity record or empty HashMap
*/

if (!isServer) exitWith {createHashMap};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {createHashMap};

params [["_civUid", "", [""]]];
if (_civUid isEqualTo "") exitWith {createHashMap};

private _ids = missionNamespace getVariable ["civsub_v1_identities", createHashMap];
if !(_ids isEqualType createHashMap) exitWith {createHashMap};

private _rec = _ids getOrDefault [_civUid, createHashMap];
if !(_rec isEqualType createHashMap) exitWith {createHashMap};
_rec

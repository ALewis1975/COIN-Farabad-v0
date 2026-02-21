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

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; [(_h), _k, _d] call _hg";

private _ids = missionNamespace getVariable ["civsub_v1_identities", createHashMap];
if !(_ids isEqualType createHashMap) exitWith {createHashMap};

private _rec = [_ids, _civUid, createHashMap] call _hg;
if !(_rec isEqualType createHashMap) exitWith {createHashMap};
_rec

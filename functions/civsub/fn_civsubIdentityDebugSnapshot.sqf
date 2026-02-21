/*
    ARC_fnc_civsubIdentityDebugSnapshot

    Debug snapshot for identity layer (counts only).

    Returns: HashMap
*/

if (!isServer) exitWith {createHashMap};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {createHashMap};

// sqflint-compat helpers
private _keysFn   = compile "params ['_m']; keys _m";
private _hmFrom   = compile "params ['_pairs']; private _r = createHashMap; { _r set [_x select 0, _x select 1]; } forEach _pairs; _r";

private _ids = missionNamespace getVariable ["civsub_v1_identities", createHashMap];
if !(_ids isEqualType createHashMap) then { _ids = createHashMap; };

[[
    ["identity_count", count ([_ids] call _keysFn)],
    ["identity_evictions", missionNamespace getVariable ["civsub_v1_identity_evictions", 0]]
]] call _hmFrom

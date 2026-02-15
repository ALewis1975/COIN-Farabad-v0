/*
    ARC_fnc_civsubIdentityDebugSnapshot

    Debug snapshot for identity layer (counts only).

    Returns: HashMap
*/

if (!isServer) exitWith {createHashMap};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {createHashMap};

private _ids = missionNamespace getVariable ["civsub_v1_identities", createHashMap];
if !(_ids isEqualType createHashMap) then { _ids = createHashMap; };

createHashMapFromArray [
    ["identity_count", count (keys _ids)],
    ["identity_evictions", missionNamespace getVariable ["civsub_v1_identity_evictions", 0]]
]

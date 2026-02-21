/*
    ARC_fnc_civsubCivSamplerDebugSnapshot

    Returns a compact snapshot for debug inspector.
*/

if (!isServer) exitWith {[]};

// sqflint-compat helpers
private _keysFn   = compile "params ['_m']; keys _m";

private _reg = missionNamespace getVariable ["civsub_v1_civ_registry", createHashMap];
if !(_reg isEqualType createHashMap) then { _reg = createHashMap; };

[
    ["civs_enabled", missionNamespace getVariable ["civsub_v1_civs_enabled", false]],
    ["active_districts", missionNamespace getVariable ["civsub_v1_activeDistrictIds", []]],
    ["spawned", count ([_reg] call _keysFn)],
    ["queue", count (missionNamespace getVariable ["civsub_v1_civ_despawnQueue", []])],
    ["capG", missionNamespace getVariable ["civsub_v1_civ_cap_effectiveGlobal", -1]],
    ["capD", missionNamespace getVariable ["civsub_v1_civ_cap_effectivePerDistrict", -1]]
]

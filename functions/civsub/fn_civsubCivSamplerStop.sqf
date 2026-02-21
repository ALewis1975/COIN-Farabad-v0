/*
    ARC_fnc_civsubCivSamplerStop

    Disables CIV sampling and queues all spawned civs for despawn.
*/

if (!isServer) exitWith {false};

// sqflint-compat helpers
private _keysFn   = compile "params ['_m']; keys _m";

missionNamespace setVariable ["civsub_v1_civs_enabled", false, true];

private _reg = missionNamespace getVariable ["civsub_v1_civ_registry", createHashMap];
if !(_reg isEqualType createHashMap) then { _reg = createHashMap; };

private _q = missionNamespace getVariable ["civsub_v1_civ_despawnQueue", []];
if !(_q isEqualType []) then { _q = []; };

{ _q pushBackUnique _x; } forEach ([_reg] call _keysFn);
missionNamespace setVariable ["civsub_v1_civ_despawnQueue", _q, true];

true

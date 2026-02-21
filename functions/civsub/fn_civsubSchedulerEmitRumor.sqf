/*
    ARC_fnc_civsubSchedulerEmitRumor

    Optional scheduler emission: ambient rumor. Stubbed in Phase 5; disabled unless civsub_v1_rumor_enabled is true.

    Returns: HashMap bundle or empty HashMap
*/

if (!isServer) exitWith {createHashMap};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {createHashMap};
if !(missionNamespace getVariable ["civsub_v1_rumor_enabled", false]) exitWith {createHashMap};

params [
    ["_districtId", "", [""]],
    ["_d", createHashMap, [createHashMap]]
];

if (_districtId isEqualTo "") exitWith {createHashMap};

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; [(_h), _k, _d] call _hg";
private _hmFrom   = compile "params ['_pairs']; private _r = createHashMap; { _r set [_x select 0, _x select 1]; } forEach _pairs; _r";

private _leadEmit = [[["emit", false], ["lead_type", ""], ["lead_id", ""], ["confidence", 0.0], ["seed", createHashMap]]] call _hmFrom;
private _influenceDelta = [[["dW", 0], ["dR", 0], ["dG", 0]]] call _hmFrom;

private _bundle = [
    _districtId,
    [_d, "centroid", [0,0] call _hg],
    "SCHEDULER",
    "RUMOR_AMBIENT",
    createHashMap,
    [],
    _influenceDelta,
    _leadEmit,
    ["SCHEDULER", "RUMOR_AMBIENT"],
    "",
    "AI",
    "",
    "",
    "",
    ""
] call ARC_fnc_civsubBundleMake;

_bundle

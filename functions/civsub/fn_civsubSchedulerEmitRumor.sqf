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

private _leadEmit = createHashMapFromArray [["emit", false], ["lead_type", ""], ["lead_id", ""], ["confidence", 0.0], ["seed", createHashMap]];
private _influenceDelta = createHashMapFromArray [["dW", 0], ["dR", 0], ["dG", 0]];

private _bundle = [
    _districtId,
    _d getOrDefault ["centroid", [0,0]],
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

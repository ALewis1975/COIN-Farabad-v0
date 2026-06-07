/*
    ARC_fnc_civsubSchedulerEmitRumor

    Optional scheduler emission: bounded ambient rumor/informant lead.

    Returns: HashMap bundle or empty HashMap
*/

if (!isServer) exitWith {createHashMap};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {createHashMap};
if !(missionNamespace getVariable ["civsub_v1_rumor_enabled", false]) exitWith {createHashMap};

params [
    ["_districtId", "", [""]],
    ["_d", createHashMap, [createHashMap]],
    ["_intelConf", 0.25, [0]]
];

if (_districtId isEqualTo "") exitWith {createHashMap};

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";
if !(_intelConf isEqualType 0) then { _intelConf = 0.25; };
_intelConf = (_intelConf max 0.10) min 0.60;

private _seed = createHashMap;
_seed set ["district_centroid", _d getOrDefault ["centroid", [0,0]]];
_seed set ["district_id", _districtId];
_seed set ["rumor_kind", selectRandom ["CACHE", "MOVEMENT", "FACILITATOR", "IED_WARNING"]];

private _leadEmit = [[
    ["emit", true],
    ["lead_type", "TIP"],
    ["lead_id", [] call ARC_fnc_civsubUuid],
    ["confidence", _intelConf],
    ["seed", _seed]
]] call _hmCreate;
private _influenceDelta = [[["dW", 0], ["dR", 0], ["dG", 0]]] call _hmCreate;

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

private _cooldown = missionNamespace getVariable ["civsub_v1_rumor_cooldown_s", 7200];
if (!(_cooldown isEqualType 0) || { _cooldown < 1800 }) then { _cooldown = 7200; };
_d set ["cooldown_nextRumor_ts", serverTime + _cooldown];

missionNamespace setVariable ["civsub_v1_lastRumor_bundle_id", _bundle getOrDefault ["bundle_id", ""], true];
missionNamespace setVariable ["civsub_v1_lastRumor_ts", serverTime, true];

_bundle

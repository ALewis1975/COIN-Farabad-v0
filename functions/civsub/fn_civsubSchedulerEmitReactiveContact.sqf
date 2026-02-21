/*
    ARC_fnc_civsubSchedulerEmitReactiveContact

    Scheduler emission: reactive red contact (attack cue). This is a notification bundle only.

    Params:
      0: districtId (string)
      1: district (HashMap)
      2: p_tick_eff (number 0..1) (debug)
      3: active (bool) (debug)

    Returns:
      HashMap bundle
*/

if (!isServer) exitWith {createHashMap};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {createHashMap};

params [
    ["_districtId", "", [""]],
    ["_d", createHashMap, [createHashMap]],
    ["_pTickEff", 0, [0]],
    ["_active", false, [true]]
];

if (_districtId isEqualTo "") exitWith {createHashMap};

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; [(_h), _k, _d] call _hg";
private _hmFrom   = compile "params ['_pairs']; private _r = createHashMap; { _r set [_x select 0, _x select 1]; } forEach _pairs; _r";

private _payload = createHashMapFromArray [
    ["p_tick_eff", _pTickEff],
    ["active", _active],
    ["district_centroid", [_d, "centroid", [0,0] call _hg]]
];

private _leadEmit = [[["emit", false], ["lead_type", ""], ["lead_id", ""], ["confidence", 0.0], ["seed", createHashMap]]] call _hmFrom;
private _influenceDelta = [[["dW", 0], ["dR", 0], ["dG", 0]]] call _hmFrom;

private _bundle = [
    _districtId,
    [_d, "centroid", [0,0] call _hg],
    "SCHEDULER",
    "ATTACK_REACTIVE",
    _payload,
    [],
    _influenceDelta,
    _leadEmit,
    ["SCHEDULER", "ATTACK_REACTIVE"],
    "",
    "AI",
    "",
    "",
    "",
    ""
] call ARC_fnc_civsubBundleMake;

_d set ["cooldown_nextAttack_ts", serverTime + 1800];

missionNamespace setVariable ["civsub_v1_lastScheduler_bundle_id", [_bundle, "bundle_id", ""] call _hg, true];
missionNamespace setVariable ["civsub_v1_lastScheduler_event", "ATTACK_REACTIVE", true];
missionNamespace setVariable ["civsub_v1_lastScheduler_ts", serverTime, true];
missionNamespace setVariable ["civsub_v1_lastScheduler_bundle_pairs", [_bundle] call ARC_fnc_civsubBundleToPairs, true];

_bundle

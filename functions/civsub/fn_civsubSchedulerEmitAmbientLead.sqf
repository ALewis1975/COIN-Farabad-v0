/*
    ARC_fnc_civsubSchedulerEmitAmbientLead

    Scheduler emission: ambient lead (exact behavior locked by cooldowns; lead content is minimal v1).

    Params:
      0: districtId (string)
      1: district (HashMap)
      2: intel_conf (number 0..1)

    Returns:
      HashMap bundle
*/

if (!isServer) exitWith {createHashMap};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {createHashMap};

params [
    ["_districtId", "", [""]],
    ["_d", createHashMap, [createHashMap]],
    ["_intelConf", 0.20, [0]]
];

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _districtIdCheck = [_districtId, "NON_EMPTY_STRING", "districtId", [""]] call ARC_fnc_paramAssert;
_districtId = _districtIdCheck param [1, ""];
if !(_districtIdCheck param [0, false]) exitWith {
    ["CIVSUB", format ["scheduler emit lead guard: code=%1 msg=%2", _districtIdCheck param [2, "ARC_ASSERT_UNKNOWN"], _districtIdCheck param [3, "districtId invalid"]], [["code", _districtIdCheck param [2, "ARC_ASSERT_UNKNOWN"]], ["guard", "civsubSchedulerEmitAmbientLead"]]] call ARC_fnc_farabadWarn;
    createHashMap
};

// Pick a POI seed (optional). Prefer POIs that belong to the emitting district.
// Note: with 30 POIs across 20 districts, some districts will have no POIs. In that case we emit with an empty POI seed rather than cross-district mismatch.
private _poiId = [_districtId, false, false] call ARC_fnc_civsubCrimeDbPickPoiForDistrict;
private _poi = createHashMap;
if (_poiId != "") then {
    _poi = [_poiId] call ARC_fnc_civsubCrimeDbGetById;
};

private _seed = createHashMap;
_seed set ["poi_id", _poiId];
_seed set ["poi", _poi];
_seed set ["district_centroid", [_d, "centroid", [0,0]]] call _hg;
_seed set ["district_id", _districtId];

private _leadTypes = ["HUMINT", "TIP", "SUSPICIOUS_ACTIVITY"];
private _leadType = _leadTypes select (floor (random (count _leadTypes)));

private _leadId = [] call ARC_fnc_civsubUuid;

private _leadEmit = [[
    ["emit", true],
    ["lead_type", _leadType],
    ["lead_id", _leadId],
    ["confidence", _intelConf],
    ["seed", _seed]
]] call _hmCreate;

private _influenceDelta = [[["dW", 0], ["dR", 0], ["dG", 0]]] call _hmCreate;

private _bundle = [
    _districtId,
    [_d, "centroid", [0,0]] call _hg,
    "SCHEDULER",
    "LEAD_AMBIENT",
    createHashMap,
    [],
    _influenceDelta,
    _leadEmit,
    ["SCHEDULER", "LEAD_AMBIENT"],
    "",
    "AI",
    "",
    "",
    "",
    ""
] call ARC_fnc_civsubBundleMake;

// Update cooldown on district
_d set ["cooldown_nextLead_ts", serverTime + 3600];

// Publish last scheduler emission (debug)
missionNamespace setVariable ["civsub_v1_lastScheduler_bundle_id", [_bundle, "bundle_id", ""] call _hg, true];
missionNamespace setVariable ["civsub_v1_lastScheduler_event", "LEAD_AMBIENT", true];
missionNamespace setVariable ["civsub_v1_lastScheduler_ts", serverTime, true];
missionNamespace setVariable ["civsub_v1_lastScheduler_bundle_pairs", [_bundle] call ARC_fnc_civsubBundleToPairs, true];

_bundle

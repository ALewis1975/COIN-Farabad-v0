/*
    ARC_fnc_civsubDeltaApplyToDistrict

    Applies bundle.influence_delta to district state immediately (locked v1).

    Params:
      0: bundle hashmap
*/

params [["_bundle", createHashMap, [createHashMap]]];
if !(_bundle isEqualType createHashMap) exitWith {false};

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";

private _districtId = [_bundle, "districtId", ([_bundle, "district_id", ""] call _hg)] call _hg;
if !(_districtId isEqualType "") exitWith {
    diag_log format ["[CIVSUB][WARN] DeltaApply invalid districtId type=%1 value=%2", typeName _districtId, _districtId];
    false
};
if (_districtId isEqualTo "") exitWith {false};

private _deltaCoerceWarned = false;
private _coerceDelta = {
    params ["_name", "_value"];
    if (_value isEqualType 0) exitWith {_value};
    if !(_deltaCoerceWarned) then {
        _deltaCoerceWarned = true;
        diag_log format ["[CIVSUB][WARN] DeltaApply non-scalar delta coerced to 0 districtId=%1 type=%2 value=%3", _districtId, typeName _value, _value];
    };
    0
};

private _delta = _bundle getOrDefault ["influence_delta", createHashMap];
if !(_delta isEqualType createHashMap) exitWith {false};

// Support both legacy keys (dW/dR/dG) and contract keys (W/R/G)
private _dW = [_delta, "W", ([_delta, "dW", 0] call _hg)] call _hg;
private _dR = [_delta, "R", ([_delta, "dR", 0] call _hg)] call _hg;
private _dG = [_delta, "G", ([_delta, "dG", 0] call _hg)] call _hg;

_dW = ["W", _dW] call _coerceDelta;
_dR = ["R", _dR] call _coerceDelta;
_dG = ["G", _dG] call _coerceDelta;

private _d = [_districtId] call ARC_fnc_civsubDistrictsGetById;
if !(_d isEqualType createHashMap) exitWith {false};

_d set ["W_EFF_U", (_d getOrDefault ["W_EFF_U", 0]) + _dW];
_d set ["R_EFF_U", (_d getOrDefault ["R_EFF_U", 0]) + _dR];
_d set ["G_EFF_U", (_d getOrDefault ["G_EFF_U", 0]) + _dG];

[_d] call ARC_fnc_civsubDistrictsClamp;

// Phase 6 counters (best-effort). These are cumulative district totals.
private _src = _bundle getOrDefault ["source", createHashMap];
if (_src isEqualType []) then { _src = [_src] call _hmCreate; };
private _ev = "";
if (_src isEqualType createHashMap) then { _ev = toUpper (_src getOrDefault ["event", ""]); };

if (!(_ev isEqualTo "")) then
{
    switch (_ev) do
    {
        case "CRIME_DB_HIT": { _d set ["crime_db_hits", (_d getOrDefault ["crime_db_hits", 0]) + 1]; };
        case "DETENTION_INIT": { _d set ["detentions_initiated", (_d getOrDefault ["detentions_initiated", 0]) + 1]; };
        case "DETENTION_HANDOFF": { _d set ["detentions_handed_off", (_d getOrDefault ["detentions_handed_off", 0]) + 1]; };
        case "AID_WATER";
        case "AID_RATIONS";
        case "MED_AID_CIV": { _d set ["aid_events", (_d getOrDefault ["aid_events", 0]) + 1]; };
        case "CIV_KILLED": { _d set ["civ_cas_kia", (_d getOrDefault ["civ_cas_kia", 0]) + 1]; };
        case "CIV_WIA": { _d set ["civ_cas_wia", (_d getOrDefault ["civ_cas_wia", 0]) + 1]; };
        default {};
    };
};

// Publish a lightweight client-readable snapshot for this district.
// Reason: broadcasting a HashMap once does not replicate in-place mutations to nested HashMaps.
// We keep a simple array-of-pairs per district that clients can read reliably.
private _pub = [
    ["G", _d getOrDefault ["G_EFF_U", 35]],
    ["crime_db_hits", _d getOrDefault ["crime_db_hits", 0]],
    ["detentions_initiated", _d getOrDefault ["detentions_initiated", 0]],
    ["civ_cas_kia", _d getOrDefault ["civ_cas_kia", 0]],
    ["districtId", _districtId],
    ["detentions_handed_off", _d getOrDefault ["detentions_handed_off", 0]],
    ["R", _d getOrDefault ["R_EFF_U", 55]],
    ["civ_cas_wia", _d getOrDefault ["civ_cas_wia", 0]],
    ["ts", serverTime],
    ["aid_events", _d getOrDefault ["aid_events", 0]],
    ["W", _d getOrDefault ["W_EFF_U", 45]]
];
missionNamespace setVariable [format ["civsub_v1_district_pub_%1", _districtId], _pub, true];

// Minimal, low-noise instrumentation for the counters we care about.
if (_ev in ["CRIME_DB_HIT","DETENTION_INIT","DETENTION_HANDOFF","CIV_KILLED","CIV_WIA","AID_WATER","AID_RATIONS","MED_AID_CIV"]) then
{
    diag_log format ["[CIVSUB][DELTA][%1] did=%2 W=%3 R=%4 G=%5 kia=%6 wia=%7 hits=%8 detI=%9 detH=%10 aid=%11",
        _ev,
        _districtId,
        _d getOrDefault ["W_EFF_U", -1],
        _d getOrDefault ["R_EFF_U", -1],
        _d getOrDefault ["G_EFF_U", -1],
        _d getOrDefault ["civ_cas_kia", -1],
        _d getOrDefault ["civ_cas_wia", -1],
        _d getOrDefault ["crime_db_hits", -1],
        _d getOrDefault ["detentions_initiated", -1],
        _d getOrDefault ["detentions_handed_off", -1],
        _d getOrDefault ["aid_events", -1]
    ];
};

true

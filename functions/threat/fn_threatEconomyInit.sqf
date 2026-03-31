/*
    ARC_fnc_threatEconomyInit

    Threat Economy v0: initialise per-district risk model and attack budget.
    Called once at server bootstrap via ARC_fnc_threatInit.

    State keys written:
      threat_v0_district_risk     - HASHMAP districtId -> {risk_level, last_attack_ts, attack_count_30d, cooldown_until}
      threat_v0_attack_budget     - HASHMAP districtId -> {budget_points, last_reset_ts, spent_today}
      threat_v0_global_cooldown_until - NUMBER serverTime
      threat_v0_scheduler_last_ts     - NUMBER serverTime

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

// District list (D01-D20, canonical per fn_worldIsValidDistrictId)
private _districtIds = [
    "D01","D02","D03","D04","D05","D06","D07","D08","D09","D10",
    "D11","D12","D13","D14","D15","D16","D17","D18","D19","D20"
];

// ── District risk model ────────────────────────────────────────────────────
private _existingRisk = ["threat_v0_district_risk", createHashMap] call ARC_fnc_stateGet;
if (!(_existingRisk isEqualType createHashMap)) then { _existingRisk = createHashMap; };

{
    private _id = _x;
    if !(_id in _existingRisk) then
    {
        private _entry = createHashMap;
        _entry set ["risk_level", 30];
        _entry set ["last_attack_ts", -1];
        _entry set ["attack_count_30d", 0];
        _entry set ["cooldown_until", -1];
        _existingRisk set [_id, _entry];
    };
} forEach _districtIds;

["threat_v0_district_risk", _existingRisk] call ARC_fnc_stateSet;

// ── Attack budget ──────────────────────────────────────────────────────────
private _existingBudget = ["threat_v0_attack_budget", createHashMap] call ARC_fnc_stateGet;
if (!(_existingBudget isEqualType createHashMap)) then { _existingBudget = createHashMap; };

{
    private _id = _x;
    if !(_id in _existingBudget) then
    {
        private _entry = createHashMap;
        _entry set ["budget_points", 3];
        _entry set ["last_reset_ts", serverTime];
        _entry set ["spent_today", 0];
        _existingBudget set [_id, _entry];
    };
} forEach _districtIds;

["threat_v0_attack_budget", _existingBudget] call ARC_fnc_stateSet;

// ── Global cooldown + scheduler timestamp ─────────────────────────────────
private _gcExisting = ["threat_v0_global_cooldown_until", -1] call ARC_fnc_stateGet;
if (!(_gcExisting isEqualType 0)) then { _gcExisting = -1; };
["threat_v0_global_cooldown_until", _gcExisting] call ARC_fnc_stateSet;

private _stExisting = ["threat_v0_scheduler_last_ts", -1] call ARC_fnc_stateGet;
if (!(_stExisting isEqualType 0)) then { _stExisting = -1; };
["threat_v0_scheduler_last_ts", _stExisting] call ARC_fnc_stateSet;

diag_log format ["[ARC][INFO] ARC_fnc_threatEconomyInit: economy keys seeded for %1 districts.", count _districtIds];

true

/*
    ARC_fnc_threatEconomySnapshotBuild

    Build read-only Threat Economy observability snapshot for operator/admin surfaces.

    Returns:
      ARRAY snapshot pairs (threat_economy_obs_v1)
*/

if (!isServer) exitWith {[]};

if (isNil "ARC_fnc_threatEconomyReasonMeta") then
{
    ARC_fnc_threatEconomyReasonMeta = compile preprocessFileLineNumbers "functions\\threat\\fn_threatEconomyReasonMeta.sqf";
};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _pg = compile "params ['_pairs','_k','_d']; private _out = _d; { if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo _k }) exitWith { _out = _x select 1; }; } forEach _pairs; _out";

private _enabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };

private _now = serverTime;
private _schedulerIntervalS = missionNamespace getVariable ["ARC_threatSchedulerIntervalS", 120];
if (!(_schedulerIntervalS isEqualType 0) || { _schedulerIntervalS < 30 }) then { _schedulerIntervalS = 120; };

private _schedulerLastTs = ["threat_v0_scheduler_last_ts", -1] call ARC_fnc_stateGet;
if (!(_schedulerLastTs isEqualType 0)) then { _schedulerLastTs = -1; };
private _schedulerDueInS = 0;
if (_schedulerLastTs > 0) then
{
    _schedulerDueInS = (_schedulerIntervalS - (_now - _schedulerLastTs)) max 0;
};

private _globalCooldownUntil = ["threat_v0_global_cooldown_until", -1] call ARC_fnc_stateGet;
if (!(_globalCooldownUntil isEqualType 0)) then { _globalCooldownUntil = -1; };
private _globalCooldownRemainingS = 0;
if (_globalCooldownUntil > _now) then { _globalCooldownRemainingS = _globalCooldownUntil - _now; };

private _riskMap = ["threat_v0_district_risk", createHashMap] call ARC_fnc_stateGet;
if (!(_riskMap isEqualType createHashMap)) then { _riskMap = createHashMap; };

private _budgetMap = ["threat_v0_attack_budget", createHashMap] call ARC_fnc_stateGet;
if (!(_budgetMap isEqualType createHashMap)) then { _budgetMap = createHashMap; };

private _lastDecision = ["threat_v0_economy_last_decision", []] call ARC_fnc_stateGet;
if (!(_lastDecision isEqualType [])) then { _lastDecision = []; };
private _lastAllowedDecision = ["threat_v0_economy_last_allowed_decision", []] call ARC_fnc_stateGet;
if (!(_lastAllowedDecision isEqualType [])) then { _lastAllowedDecision = []; };
private _lastDeniedDecision = ["threat_v0_economy_last_denied_decision", []] call ARC_fnc_stateGet;
if (!(_lastDeniedDecision isEqualType [])) then { _lastDeniedDecision = []; };

private _denyCounts = ["threat_v0_economy_deny_counts", createHashMap] call ARC_fnc_stateGet;
if (!(_denyCounts isEqualType createHashMap)) then { _denyCounts = createHashMap; };

private _reasonTaxonomy = ["threat_v0_economy_reason_taxonomy", []] call ARC_fnc_stateGet;
if (!(_reasonTaxonomy isEqualType [])) then { _reasonTaxonomy = []; };
if (_reasonTaxonomy isEqualTo []) then { _reasonTaxonomy = ["__ALL__"] call ARC_fnc_threatEconomyReasonMeta; };

private _denyTaxonomy = ["threat_v0_economy_deny_reason_enum", []] call ARC_fnc_stateGet;
if (!(_denyTaxonomy isEqualType [])) then { _denyTaxonomy = []; };
if (_denyTaxonomy isEqualTo []) then
{
    {
        private _row = _x;
        private _code = [_row, "code", ""] call _pg;
        private _decision = [_row, "decision", ""] call _pg;
        private _blocksEvent = [_row, "blocks_event", false] call _pg;
        if ((_decision isEqualTo "DENY") && { _blocksEvent isEqualTo true } && { !(_code isEqualTo "") }) then
        {
            _denyTaxonomy pushBackUnique _code;
        };
    } forEach _reasonTaxonomy;
};

private _districtIds = [
    "D01","D02","D03","D04","D05","D06","D07","D08","D09","D10",
    "D11","D12","D13","D14","D15","D16","D17","D18","D19","D20"
];

private _rows = [];
private _riskRank = [];
private _spentRank = [];
private _hotRiskCount = 0;
private _criticalRiskCount = 0;
private _budgetExhaustedCount = 0;
private _cooldownActiveCount = 0;
private _totalBudgetPoints = 0;
private _totalSpentToday = 0;

{
    private _districtId = _x;
    private _secLevel = missionNamespace getVariable [format ["ARC_district_%1_secLevel", _districtId], "NORMAL"];
    if (!(_secLevel isEqualType "")) then { _secLevel = "NORMAL"; };
    private _postureTier = 0;
    if (_secLevel isEqualTo "ELEVATED") then { _postureTier = 1; };
    if (_secLevel isEqualTo "HIGH_RISK") then { _postureTier = 2; };
    if (_secLevel isEqualTo "CRITICAL") then { _postureTier = 3; };

    private _r = [_riskMap, _districtId, createHashMap] call _hg;
    if (!(_r isEqualType createHashMap)) then { _r = createHashMap; };
    private _b = [_budgetMap, _districtId, createHashMap] call _hg;
    if (!(_b isEqualType createHashMap)) then { _b = createHashMap; };

    private _riskLevel = [_r, "risk_level", 0] call _hg;
    if (!(_riskLevel isEqualType 0)) then { _riskLevel = 0; };
    private _attackCount30d = [_r, "attack_count_30d", 0] call _hg;
    if (!(_attackCount30d isEqualType 0)) then { _attackCount30d = 0; };
    private _lastAttackTs = [_r, "last_attack_ts", -1] call _hg;
    if (!(_lastAttackTs isEqualType 0)) then { _lastAttackTs = -1; };
    private _districtCooldownUntil = [_r, "cooldown_until", -1] call _hg;
    if (!(_districtCooldownUntil isEqualType 0)) then { _districtCooldownUntil = -1; };
    private _districtCooldownRemainingS = 0;
    if (_districtCooldownUntil > _now) then { _districtCooldownRemainingS = _districtCooldownUntil - _now; };

    private _budgetPoints = [_b, "budget_points", 3] call _hg;
    if (!(_budgetPoints isEqualType 0)) then { _budgetPoints = 3; };
    private _spentToday = [_b, "spent_today", 0] call _hg;
    if (!(_spentToday isEqualType 0)) then { _spentToday = 0; };
    private _capacityRemaining = (_budgetPoints - _spentToday) max 0;
    private _disruptionPenaltyPts = [_b, "disruption_penalty_pts", 0] call _hg;
    if (!(_disruptionPenaltyPts isEqualType 0)) then { _disruptionPenaltyPts = 0; };
    private _disruptionPenaltyUntil = [_b, "disruption_penalty_until", -1] call _hg;
    if (!(_disruptionPenaltyUntil isEqualType 0)) then { _disruptionPenaltyUntil = -1; };
    private _disruptionPenaltyRemainingS = 0;
    if (_disruptionPenaltyUntil > _now) then { _disruptionPenaltyRemainingS = _disruptionPenaltyUntil - _now; };

    _rows pushBack [
        ["district_id", _districtId],
        ["district_sec_level", _secLevel],
        ["posture_tier", _postureTier],
        ["risk_level", _riskLevel],
        ["attack_count_30d", _attackCount30d],
        ["last_attack_ts", _lastAttackTs],
        ["cooldown_until", _districtCooldownUntil],
        ["cooldown_remaining_s", _districtCooldownRemainingS],
        ["budget_points", _budgetPoints],
        ["spent_today", _spentToday],
        ["capacity_remaining", _capacityRemaining],
        ["disruption_penalty_pts", _disruptionPenaltyPts],
        ["disruption_penalty_until", _disruptionPenaltyUntil],
        ["disruption_penalty_remaining_s", _disruptionPenaltyRemainingS]
    ];

    _riskRank pushBack [_riskLevel, _districtId];
    _spentRank pushBack [_spentToday, _districtId, _budgetPoints];

    if (_riskLevel >= 70) then { _hotRiskCount = _hotRiskCount + 1; };
    if (_riskLevel >= 85) then { _criticalRiskCount = _criticalRiskCount + 1; };
    if (_districtCooldownRemainingS > 0) then { _cooldownActiveCount = _cooldownActiveCount + 1; };
    if (_spentToday >= _budgetPoints) then { _budgetExhaustedCount = _budgetExhaustedCount + 1; };
    _totalBudgetPoints = _totalBudgetPoints + _budgetPoints;
    _totalSpentToday = _totalSpentToday + _spentToday;
} forEach _districtIds;

_riskRank sort false;
_spentRank sort false;
if ((count _riskRank) > 5) then { _riskRank resize 5; };
if ((count _spentRank) > 5) then { _spentRank resize 5; };

private _denyRows = [];
{
    private _reason = _x;
    private _count = [_denyCounts, _reason, 0] call _hg;
    if (!(_count isEqualType 0)) then { _count = 0; };
    _denyRows pushBack [_reason, _count, _meta];
} forEach _denyTaxonomy;

[
    ["v", 1],
    ["schema", "threat_economy_obs_v1"],
    ["updatedAt", _now],
    ["summary", [
        ["enabled", _enabled],
        ["district_count", count _districtIds],
        ["hot_risk_count", _hotRiskCount],
        ["critical_risk_count", _criticalRiskCount],
        ["cooldown_active_count", _cooldownActiveCount],
        ["budget_exhausted_count", _budgetExhaustedCount],
        ["budget_points_total", _totalBudgetPoints],
        ["spent_today_total", _totalSpentToday]
    ]],
    ["scheduler", [
        ["interval_s", _schedulerIntervalS],
        ["last_tick_ts", _schedulerLastTs],
        ["next_tick_due_in_s", _schedulerDueInS]
    ]],
    ["cooldowns", [
        ["global_until", _globalCooldownUntil],
        ["global_remaining_s", _globalCooldownRemainingS],
        ["global_active", _globalCooldownRemainingS > 0]
    ]],
    ["thresholds", [
        ["risk_hot_gte", 70],
        ["risk_critical_gte", 85],
        ["budget_exhausted_when_spent_plus_cost_gt_budget", true],
        ["posture_tiers", [["NORMAL", 0], ["ELEVATED", 1], ["HIGH_RISK", 2], ["CRITICAL", 3]]],
        ["threat_costs", [["IED", 1], ["RAID", 2], ["AMBUSH", 2], ["ATTACK", 2], ["VBIED", 2], ["SUICIDE", 3]]]
    ]],
    ["reasonTaxonomy", _reasonTaxonomy],
    ["denyReasonTaxonomy", _denyTaxonomy],
    ["denyReasonCounts", _denyRows],
    ["lastDecision", _lastDecision],
    ["lastAllowedDecision", _lastAllowedDecision],
    ["lastDeniedDecision", _lastDeniedDecision],
    ["topRiskDistricts", _riskRank],
    ["topSpentDistricts", _spentRank],
    ["districtRows", _rows]
]

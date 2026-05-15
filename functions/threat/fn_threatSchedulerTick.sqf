/*
    ARC_fnc_threatSchedulerTick

    Threat Economy v0: rate-limited scheduler tick (call from bootstrapServer regular tick).
    Does NOT spawn anything — calls ARC_fnc_threatScheduleEvent per cleared district.

    Rate: controlled by ARC_threatSchedulerIntervalS (default 120s).

    Returns:
      BOOL (false = not fired this tick)
*/

if (!isServer) exitWith {false};

private _intervalS = missionNamespace getVariable ["ARC_threatSchedulerIntervalS", 120];
if (!(_intervalS isEqualType 0) || { _intervalS < 30 }) then { _intervalS = 120; };

private _lastTs = ["threat_v0_scheduler_last_ts", -1] call ARC_fnc_stateGet;
if (!(_lastTs isEqualType 0)) then { _lastTs = -1; };

// ── Daily budget reset (TEA-F5 fix) ────────────────────────────────────────
// A "day" is measured as a floor(serverTime / 86400) epoch. On rollover the
// per-district spent_today counters are reset to 0 so each day gets a fresh budget.
private _lastResetDay = ["threat_v0_budget_last_reset_day", -1] call ARC_fnc_stateGet;
if (!(_lastResetDay isEqualType 0)) then { _lastResetDay = -1; };
private _todayDay = floor (serverTime / 86400);
if (_todayDay != _lastResetDay) then
{
    private _budgetMap = ["threat_v0_attack_budget", createHashMap] call ARC_fnc_stateGet;
    if (!(_budgetMap isEqualType createHashMap)) then { _budgetMap = createHashMap; };
    private _hgReset = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
    // Iterate over the canonical 20-district list; avoids sqflint `keys` parser issue.
    private _distReset = [
        "D01","D02","D03","D04","D05","D06","D07","D08","D09","D10",
        "D11","D12","D13","D14","D15","D16","D17","D18","D19","D20"
    ];
    {
        private _bId  = _x;
        private _bEntry = [_budgetMap, _bId, createHashMap] call _hgReset;
        if (_bEntry isEqualType createHashMap) then
        {
            _bEntry set ["spent_today", 0];
            _budgetMap set [_bId, _bEntry];
        };
    } forEach _distReset;
    ["threat_v0_attack_budget", _budgetMap] call ARC_fnc_stateSet;
    ["threat_v0_budget_last_reset_day", _todayDay] call ARC_fnc_stateSet;
    diag_log format ["[ARC][THREAT] ARC_fnc_threatSchedulerTick: daily budget reset day=%1", _todayDay];
};

private _now = serverTime;
if (_lastTs > 0 && { (_now - _lastTs) < _intervalS }) exitWith {false};

["threat_v0_scheduler_last_ts", _now] call ARC_fnc_stateSet;

private _enabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {false};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _districtIds = [
    "D01","D02","D03","D04","D05","D06","D07","D08","D09","D10",
    "D11","D12","D13","D14","D15","D16","D17","D18","D19","D20"
];

private _riskMap = ["threat_v0_district_risk", createHashMap] call ARC_fnc_stateGet;
if (!(_riskMap isEqualType createHashMap)) then { _riskMap = createHashMap; };

private _civDistricts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if (!(_civDistricts isEqualType createHashMap)) then { _civDistricts = createHashMap; };

// GREEN score only nudges intel quality; posture still owns threat selection.
private _greenStrongMin = 70;
private _greenWeakMax = 25;
private _intelGreenAdjust = 0.10;
private _intelMaxFromGreen = 0.90;
private _intelMinFromGreen = 0.25;

// Build open threat district index (quick look-up to skip already-open districts)
private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
if (!(_records isEqualType [])) then { _records = []; };

private _openDistricts = [];
{
    private _rec = _x;
    // Extract state value from pairs array
    private _stateVal = "";
    {
        if ((_x isEqualType []) && { (count _x) >= 2 } && { ((_x select 0) isEqualTo "state") }) exitWith { _stateVal = _x select 1; };
    } forEach _rec;
    _stateVal = toUpper _stateVal;

    if (!(_stateVal in ["CLOSED","CLEANED","EXPIRED"])) then
    {
        private _links = [];
        { if ((_x isEqualType []) && {(count _x) >= 2} && {(_x select 0) isEqualTo "links"}) exitWith { _links = _x select 1; }; } forEach _rec;
        private _dId = "";
        { if ((_x isEqualType []) && {(count _x) >= 2} && {(_x select 0) isEqualTo "district_id"}) exitWith { _dId = _x select 1; }; } forEach _links;
        if (!(_dId isEqualTo "")) then { _openDistricts pushBackUnique _dId; };
    };
} forEach _records;

// Determine current escalation tier from AO posture
private _scheduledAny = false;

{
    private _districtId = _x;

    // Skip if already has an open threat
    if (_districtId in _openDistricts) then { continue; };

    // Read posture for tier and derive a network-driven threat profile.
    private _secLevel = missionNamespace getVariable [format ["ARC_district_%1_secLevel", _districtId], "NORMAL"];
    if (!(_secLevel isEqualType "")) then { _secLevel = "NORMAL"; };
    private _tier = 0;
    if (_secLevel isEqualTo "ELEVATED") then { _tier = 1; };
    if (_secLevel isEqualTo "HIGH_RISK") then { _tier = 2; };
    if (_secLevel isEqualTo "CRITICAL") then { _tier = 3; };

    private _rEntry = [_riskMap, _districtId, createHashMap] call _hg;
    if (!(_rEntry isEqualType createHashMap)) then { _rEntry = createHashMap; };
    private _riskLevel = [_rEntry, "risk_level", 30] call _hg;
    if (!(_riskLevel isEqualType 0)) then { _riskLevel = 30; };
    private _attackCount30d = [_rEntry, "attack_count_30d", 0] call _hg;
    if (!(_attackCount30d isEqualType 0)) then { _attackCount30d = 0; };

    private _greenScore = 35;
    private _civD = [_civDistricts, _districtId, createHashMap] call _hg;
    if (_civD isEqualType createHashMap) then
    {
        _greenScore = [_civD, "G", 35] call _hg;
        if (!(_greenScore isEqualType 0)) then { _greenScore = 35; };
    };

    private _threatType = "IED";
    private _threatSubtype = "IED_EMPLACED_SINGLE";
    private _spendCost = 1;
    private _intelQuality = 0.70;
    private _threatIntent = "IED_PRESSURE";

    if (_tier isEqualTo 1) then
    {
        _threatType = "RAID";
        _threatSubtype = "AMBUSH_ROADSIDE";
        _spendCost = 2;
        _intelQuality = 0.60;
        _threatIntent = "AMBUSH";
    };

    if (_tier isEqualTo 2) then
    {
        _threatType = "VBIED";
        _threatSubtype = "VBIED";
        _spendCost = 2;
        _intelQuality = 0.48;
        _threatIntent = "VBIED_ATTACK";
    };

    if (_tier >= 3) then
    {
        _threatType = "SUICIDE";
        _threatSubtype = "SB_CHECKPOINT_APPROACH";
        _spendCost = 3;
        _intelQuality = 0.38;
        _threatIntent = "SUICIDE_ATTACK";
    };

    if (_greenScore >= _greenStrongMin) then { _intelQuality = (_intelQuality + _intelGreenAdjust) min _intelMaxFromGreen; };
    if (_greenScore < _greenWeakMax) then { _intelQuality = (_intelQuality - _intelGreenAdjust) max _intelMinFromGreen; };

    private _govResult = [_districtId, _threatType, _tier] call ARC_fnc_threatGovernorCheck;
    private _allowed   = _govResult select 0;
    private _denyReason = _govResult select 1;
    if (!(_denyReason isEqualType "")) then { _denyReason = ""; };

    if (_allowed) then
    {
        private _allowDecision = [
            ["decision", "ALLOWED"],
            ["deny_reason", ""],
            ["district_id", _districtId],
            ["district_sec_level", _secLevel],
            ["risk_level", _riskLevel],
            ["attack_count_30d", _attackCount30d],
            ["green_score", _greenScore],
            ["threat_type", _threatType],
            ["threat_subtype", _threatSubtype],
            ["threat_intent", _threatIntent],
            ["tier", _tier],
            ["budget_cost", _spendCost],
            ["intel_quality", _intelQuality],
            ["ts", _now],
            ["source", "ARC_fnc_threatSchedulerTick"]
        ];
        ["threat_v0_economy_last_decision", _allowDecision] call ARC_fnc_stateSet;
        ["threat_v0_economy_last_allowed_decision", _allowDecision] call ARC_fnc_stateSet;
        diag_log format ["[ARC][THREAT] ARC_fnc_threatSchedulerTick: governor allowed district=%1 posture=%2 type=%3 subtype=%4 tier=%5 cost=%6 intel=%7", _districtId, _secLevel, _threatType, _threatSubtype, _tier, _spendCost, _intelQuality];

        // ARC_fnc_threatScheduleEvent args: district, tier, type, subtype, intelQuality, budgetCost, posture, intent.
        private _scheduled = [_districtId, _tier, _threatType, _threatSubtype, _intelQuality, _spendCost, _secLevel, _threatIntent] call ARC_fnc_threatScheduleEvent;

        if (_scheduled) then
        {
            private _budgetMap2 = ["threat_v0_attack_budget", createHashMap] call ARC_fnc_stateGet;
            if (!(_budgetMap2 isEqualType createHashMap)) then { _budgetMap2 = createHashMap; };
            private _bEntry2 = [_budgetMap2, _districtId, createHashMap] call _hg;
            if (!(_bEntry2 isEqualType createHashMap)) then { _bEntry2 = createHashMap; };
            private _spentNow = [_bEntry2, "spent_today", 0] call _hg;
            if (!(_spentNow isEqualType 0)) then { _spentNow = 0; };
            _bEntry2 set ["spent_today", _spentNow + _spendCost];
            _budgetMap2 set [_districtId, _bEntry2];
            ["threat_v0_attack_budget", _budgetMap2] call ARC_fnc_stateSet;
            diag_log format ["[ARC][THREAT] ARC_fnc_threatSchedulerTick: budget spend did=%1 posture=%2 tier=%3 spent=%4 cost=%5", _districtId, _secLevel, _tier, _spentNow + _spendCost, _spendCost];

            _scheduledAny = true;
        }
        else
        {
            diag_log format ["[ARC][WARN] ARC_fnc_threatSchedulerTick: governor allowed but schedule failed district=%1 posture=%2 type=%3 subtype=%4 tier=%5", _districtId, _secLevel, _threatType, _threatSubtype, _tier];
        };
    } else {
        private _denyDecision = [
            ["decision", "DENIED"],
            ["deny_reason", _denyReason],
            ["district_id", _districtId],
            ["district_sec_level", _secLevel],
            ["risk_level", _riskLevel],
            ["attack_count_30d", _attackCount30d],
            ["green_score", _greenScore],
            ["threat_type", _threatType],
            ["threat_subtype", _threatSubtype],
            ["threat_intent", _threatIntent],
            ["tier", _tier],
            ["budget_cost", _spendCost],
            ["intel_quality", _intelQuality],
            ["ts", _now],
            ["source", "ARC_fnc_threatSchedulerTick"]
        ];
        ["threat_v0_economy_last_decision", _denyDecision] call ARC_fnc_stateSet;
        ["threat_v0_economy_last_denied_decision", _denyDecision] call ARC_fnc_stateSet;

        if !(_denyReason isEqualTo "") then
        {
            private _denyCounts = ["threat_v0_economy_deny_counts", createHashMap] call ARC_fnc_stateGet;
            if (!(_denyCounts isEqualType createHashMap)) then { _denyCounts = createHashMap; };
            private _denySeen = [_denyCounts, _denyReason, 0] call _hg;
            if (!(_denySeen isEqualType 0)) then { _denySeen = 0; };
            _denyCounts set [_denyReason, _denySeen + 1];
            ["threat_v0_economy_deny_counts", _denyCounts] call ARC_fnc_stateSet;
        };

        diag_log format ["[ARC][THREAT] ARC_fnc_threatSchedulerTick: governor denied district=%1 posture=%2 type=%3 subtype=%4 tier=%5 reason=%6", _districtId, _secLevel, _threatType, _threatSubtype, _tier, _denyReason];
    };
} forEach _districtIds;

_scheduledAny

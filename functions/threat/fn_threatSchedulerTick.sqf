/*
    ARC_fnc_threatSchedulerTick

    Threat Economy v0: rate-limited scheduler tick (call from bootstrapServer regular tick).
    Does NOT spawn anything — calls ARC_fnc_threatScheduleEvent per cleared district.

    Rate: controlled by ARC_threatSchedulerIntervalS (default 120s).

    Returns:
      BOOL (false = not fired this tick)
*/

if (!isServer) exitWith {false};

if (isNil "ARC_fnc_threatEconomyReasonMeta") then
{
    ARC_fnc_threatEconomyReasonMeta = compile preprocessFileLineNumbers "functions\\threat\\fn_threatEconomyReasonMeta.sqf";
};

if (isNil "ARC_fnc_intelQualityCoupleDistrict") then
{
    ARC_fnc_intelQualityCoupleDistrict = compile preprocessFileLineNumbers "functions\\intel\\fn_intelQualityCoupleDistrict.sqf";
};

private _reasonMetaFn = {
    params [["_code", "UNKNOWN_REASON", [""]]];
    [_code] call ARC_fnc_threatEconomyReasonMeta
};

private _intervalS = missionNamespace getVariable ["ARC_threatSchedulerIntervalS", 120];
if (!(_intervalS isEqualType 0) || { _intervalS < 30 }) then { _intervalS = 120; };

private _lastTs = ["threat_v0_scheduler_last_ts", -1] call ARC_fnc_stateGet;
if (!(_lastTs isEqualType 0)) then { _lastTs = -1; };

// ── Daily budget reset (TEA-F5 fix) ────────────────────────────────────────
private _lastResetDay = ["threat_v0_budget_last_reset_day", -1] call ARC_fnc_stateGet;
if (!(_lastResetDay isEqualType 0)) then { _lastResetDay = -1; };
private _todayDay = floor (serverTime / 86400);
if (_todayDay != _lastResetDay) then
{
    private _budgetMap = ["threat_v0_attack_budget", createHashMap] call ARC_fnc_stateGet;
    if (!(_budgetMap isEqualType createHashMap)) then { _budgetMap = createHashMap; };
    private _hgReset = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
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
private _pget = compile "params ['_pairs','_k','_d']; private _out = _d; { if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo _k }) exitWith { _out = _x select 1; }; } forEach _pairs; _out";
private _clampScore = {
    params [["_v", 0, [0]]];
    if (_v < 0) then { _v = 0; };
    if (_v > 100) then { _v = 100; };
    _v
};

private _districtIds = [
    "D01","D02","D03","D04","D05","D06","D07","D08","D09","D10",
    "D11","D12","D13","D14","D15","D16","D17","D18","D19","D20"
];

private _riskMap = ["threat_v0_district_risk", createHashMap] call ARC_fnc_stateGet;
if (!(_riskMap isEqualType createHashMap)) then { _riskMap = createHashMap; };

private _civDistricts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if (!(_civDistricts isEqualType createHashMap)) then { _civDistricts = createHashMap; };

private _postureSelectionEnabled = missionNamespace getVariable ["ARC_threatDistrictPostureSelectionEnabled", true];
if (!(_postureSelectionEnabled isEqualType true) && !(_postureSelectionEnabled isEqualType false)) then { _postureSelectionEnabled = true; };

private _greenStrongMin = 70;
private _greenWeakMax = 25;
private _intelGreenAdjust = 0.10;
private _intelMaxFromGreen = 0.90;
private _intelMinFromGreen = 0.25;

private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
if (!(_records isEqualType [])) then { _records = []; };

private _openDistricts = [];
{
    private _rec = _x;
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

private _scheduledAny = false;

{
    private _districtId = _x;
    if (_districtId in _openDistricts) then { continue; };

    private _secLevel = missionNamespace getVariable [format ["ARC_district_%1_secLevel", _districtId], "NORMAL"];
    if (!(_secLevel isEqualType "")) then { _secLevel = "NORMAL"; };
    private _secTier = 0;
    if (_secLevel isEqualTo "ELEVATED") then { _secTier = 1; };
    if (_secLevel isEqualTo "HIGH_RISK") then { _secTier = 2; };
    if (_secLevel isEqualTo "CRITICAL") then { _secTier = 3; };

    private _rEntry = [_riskMap, _districtId, createHashMap] call _hg;
    if (!(_rEntry isEqualType createHashMap)) then { _rEntry = createHashMap; };
    private _riskLevel = [_rEntry, "risk_level", 30] call _hg;
    if (!(_riskLevel isEqualType 0)) then { _riskLevel = 30; };
    private _attackCount30d = [_rEntry, "attack_count_30d", 0] call _hg;
    if (!(_attackCount30d isEqualType 0)) then { _attackCount30d = 0; };

    private _whiteScore = 45;
    private _redScore = 55;
    private _greenScore = 35;
    private _civD = [_civDistricts, _districtId, createHashMap] call _hg;
    if (_civD isEqualType createHashMap) then
    {
        _whiteScore = [_civD, "W_EFF_U", [_civD, "W", 45] call _hg] call _hg;
        _redScore = [_civD, "R_EFF_U", [_civD, "R", 55] call _hg] call _hg;
        _greenScore = [_civD, "G_EFF_U", [_civD, "G", 35] call _hg] call _hg;
        if (!(_whiteScore isEqualType 0)) then { _whiteScore = 45; };
        if (!(_redScore isEqualType 0)) then { _redScore = 55; };
        if (!(_greenScore isEqualType 0)) then { _greenScore = 35; };
    };

    private _sCoop = [(0.55 * _whiteScore) + (0.35 * _greenScore) - (0.70 * _redScore)] call _clampScore;
    private _sThreat = [(1.00 * _redScore) - (0.35 * _whiteScore) - (0.25 * _greenScore)] call _clampScore;

    private _postureScoreRaw = (0.40 * _riskLevel) + (0.40 * _sThreat) + (0.10 * _redScore) - (0.15 * _greenScore) - (0.10 * _whiteScore) + (_secTier * 5) + ((_attackCount30d min 5) * 2);
    private _postureScore = [_postureScoreRaw] call _clampScore;

    private _postureTier = 0;
    private _postureBand = "NORMAL";
    if (_postureScore >= 35) then { _postureTier = 1; _postureBand = "ELEVATED"; };
    if (_postureScore >= 55) then { _postureTier = 2; _postureBand = "HIGH_RISK"; };
    if (_postureScore >= 75) then { _postureTier = 3; _postureBand = "CRITICAL"; };

    private _selectedTier = _secTier;
    private _tierSource = "SEC_LEVEL";
    if (_postureSelectionEnabled && { _postureTier > _selectedTier }) then
    {
        _selectedTier = _postureTier;
        _tierSource = "DISTRICT_POSTURE";
    };
    if (!_postureSelectionEnabled) then { _tierSource = "SEC_LEVEL_DISABLED"; };

    private _threatType = "IED";
    private _threatSubtype = "IED_EMPLACED_SINGLE";
    private _spendCost = 1;
    private _intelQuality = 0.70;
    private _threatIntent = "IED_PRESSURE";

    if (_selectedTier isEqualTo 1) then
    {
        _threatType = "RAID";
        _threatSubtype = "AMBUSH_ROADSIDE";
        _spendCost = 2;
        _intelQuality = 0.60;
        _threatIntent = "AMBUSH";
    };

    if (_selectedTier isEqualTo 2) then
    {
        _threatType = "VBIED";
        _threatSubtype = "VBIED";
        _spendCost = 2;
        _intelQuality = 0.48;
        _threatIntent = "VBIED_ATTACK";
    };

    if (_selectedTier >= 3) then
    {
        _threatType = "SUICIDE";
        _threatSubtype = "SB_CHECKPOINT_APPROACH";
        _spendCost = 3;
        _intelQuality = 0.38;
        _threatIntent = "SUICIDE_ATTACK";
    };

    if (_greenScore >= _greenStrongMin) then { _intelQuality = (_intelQuality + _intelGreenAdjust) min _intelMaxFromGreen; };
    if (_greenScore < _greenWeakMax) then { _intelQuality = (_intelQuality - _intelGreenAdjust) max _intelMinFromGreen; };

    private _baseIntelQuality = _intelQuality;
    private _qualityContext = [
        ["white", _whiteScore],
        ["red", _redScore],
        ["green", _greenScore],
        ["risk_level", _riskLevel],
        ["attack_count_30d", _attackCount30d],
        ["s_coop", _sCoop],
        ["s_threat", _sThreat],
        ["posture_score", _postureScore],
        ["threat_type", _threatType],
        ["threat_subtype", _threatSubtype],
        ["transition", "SCHEDULED"]
    ];
    private _intelQualityMeta = [_districtId, _baseIntelQuality, "THREAT_SCHEDULER", _qualityContext] call ARC_fnc_intelQualityCoupleDistrict;
    if (!(_intelQualityMeta isEqualType [])) then { _intelQualityMeta = []; };
    private _coupledIntelQuality = [_intelQualityMeta, "quality", _baseIntelQuality] call _pget;
    if (!(_coupledIntelQuality isEqualType 0)) then { _coupledIntelQuality = _baseIntelQuality; };
    _intelQuality = (_coupledIntelQuality max 0) min 1;

    private _selectionInputs = [
        ["selection_enabled", _postureSelectionEnabled],
        ["selection_policy", "DISTRICT_POSTURE_V1"],
        ["tier_source", _tierSource],
        ["district_sec_level", _secLevel],
        ["sec_level_tier", _secTier],
        ["posture_tier", _postureTier],
        ["selected_tier", _selectedTier],
        ["posture_band", _postureBand],
        ["posture_score", _postureScore],
        ["s_coop", _sCoop],
        ["s_threat", _sThreat],
        ["white", _whiteScore],
        ["red", _redScore],
        ["green", _greenScore],
        ["risk_level", _riskLevel],
        ["attack_count_30d", _attackCount30d],
        ["base_intel_quality", _baseIntelQuality],
        ["coupled_intel_quality", _intelQuality],
        ["intel_quality_meta", _intelQualityMeta]
    ];

    private _govResult = [_districtId, _threatType, _selectedTier] call ARC_fnc_threatGovernorCheck;
    private _allowed   = _govResult select 0;
    private _denyReason = _govResult select 1;
    if (!(_denyReason isEqualType "")) then { _denyReason = ""; };
    private _reasonMeta = if ((count _govResult) > 2) then { _govResult select 2 } else { [if (_allowed) then {"ALLOW_GOVERNOR"} else {_denyReason}] call _reasonMetaFn };
    if (!(_reasonMeta isEqualType [])) then { _reasonMeta = [if (_allowed) then {"ALLOW_GOVERNOR"} else {_denyReason}] call _reasonMetaFn; };

    if (_allowed) then
    {
        private _allowDecision = [
            ["decision", "ALLOWED"],
            ["reason_code", "ALLOW_GOVERNOR"],
            ["reason_meta", _reasonMeta],
            ["deny_reason", ""],
            ["district_id", _districtId],
            ["district_sec_level", _secLevel],
            ["risk_level", _riskLevel],
            ["attack_count_30d", _attackCount30d],
            ["green_score", _greenScore],
            ["white_score", _whiteScore],
            ["red_score", _redScore],
            ["s_coop", _sCoop],
            ["s_threat", _sThreat],
            ["posture_score", _postureScore],
            ["posture_band", _postureBand],
            ["posture_tier", _postureTier],
            ["sec_level_tier", _secTier],
            ["selected_tier", _selectedTier],
            ["tier_source", _tierSource],
            ["selection_inputs", _selectionInputs],
            ["base_intel_quality", _baseIntelQuality],
            ["intel_quality", _intelQuality],
            ["intel_quality_meta", _intelQualityMeta],
            ["threat_type", _threatType],
            ["threat_subtype", _threatSubtype],
            ["threat_intent", _threatIntent],
            ["tier", _selectedTier],
            ["budget_cost", _spendCost],
            ["ts", _now],
            ["source", "ARC_fnc_threatSchedulerTick"]
        ];
        ["threat_v0_economy_last_decision", _allowDecision] call ARC_fnc_stateSet;
        ["threat_v0_economy_last_allowed_decision", _allowDecision] call ARC_fnc_stateSet;
        diag_log format ["[ARC][THREAT] ARC_fnc_threatSchedulerTick: governor allowed district=%1 posture=%2 postureScore=%3 tierSource=%4 type=%5 subtype=%6 tier=%7 cost=%8 intel=%9 reason=%10", _districtId, _secLevel, _postureScore, _tierSource, _threatType, _threatSubtype, _selectedTier, _spendCost, _intelQuality, "ALLOW_GOVERNOR"];

        private _scheduled = [
            _districtId,
            _selectedTier,
            _threatType,
            _threatSubtype,
            _intelQuality,
            _spendCost,
            _secLevel,
            _threatIntent,
            _intelQualityMeta
        ] call ARC_fnc_threatScheduleEvent;

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

            private _scheduledMeta = ["ALLOW_SCHEDULED"] call _reasonMetaFn;
            private _scheduledDecision = +_allowDecision;
            _scheduledDecision set [1, ["reason_code", "ALLOW_SCHEDULED"]];
            _scheduledDecision set [2, ["reason_meta", _scheduledMeta]];
            ["threat_v0_economy_last_decision", _scheduledDecision] call ARC_fnc_stateSet;
            ["threat_v0_economy_last_allowed_decision", _scheduledDecision] call ARC_fnc_stateSet;

            diag_log format ["[ARC][THREAT] ARC_fnc_threatSchedulerTick: budget spend did=%1 posture=%2 postureScore=%3 tierSource=%4 tier=%5 spent=%6 cost=%7 intel=%8 reason=%9", _districtId, _secLevel, _postureScore, _tierSource, _selectedTier, _spentNow + _spendCost, _spendCost, _intelQuality, "ALLOW_SCHEDULED"];

            _scheduledAny = true;
        }
        else
        {
            private _failedMeta = ["SCHEDULE_FAILED"] call _reasonMetaFn;
            private _failedDecision = +_allowDecision;
            _failedDecision set [0, ["decision", "WARN"]];
            _failedDecision set [1, ["reason_code", "SCHEDULE_FAILED"]];
            _failedDecision set [2, ["reason_meta", _failedMeta]];
            ["threat_v0_economy_last_decision", _failedDecision] call ARC_fnc_stateSet;
            ["threat_v0_economy_last_warning_decision", _failedDecision] call ARC_fnc_stateSet;
            diag_log format ["[ARC][WARN] ARC_fnc_threatSchedulerTick: governor allowed but schedule failed district=%1 posture=%2 type=%3 subtype=%4 tier=%5 reason=%6", _districtId, _secLevel, _threatType, _threatSubtype, _selectedTier, "SCHEDULE_FAILED"];
        };
    } else {
        private _denyDecision = [
            ["decision", "DENIED"],
            ["reason_code", _denyReason],
            ["reason_meta", _reasonMeta],
            ["deny_reason", _denyReason],
            ["district_id", _districtId],
            ["district_sec_level", _secLevel],
            ["risk_level", _riskLevel],
            ["attack_count_30d", _attackCount30d],
            ["green_score", _greenScore],
            ["white_score", _whiteScore],
            ["red_score", _redScore],
            ["s_coop", _sCoop],
            ["s_threat", _sThreat],
            ["posture_score", _postureScore],
            ["posture_band", _postureBand],
            ["posture_tier", _postureTier],
            ["sec_level_tier", _secTier],
            ["selected_tier", _selectedTier],
            ["tier_source", _tierSource],
            ["selection_inputs", _selectionInputs],
            ["base_intel_quality", _baseIntelQuality],
            ["intel_quality", _intelQuality],
            ["intel_quality_meta", _intelQualityMeta],
            ["threat_type", _threatType],
            ["threat_subtype", _threatSubtype],
            ["threat_intent", _threatIntent],
            ["tier", _selectedTier],
            ["budget_cost", _spendCost],
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

        diag_log format ["[ARC][THREAT] ARC_fnc_threatSchedulerTick: governor denied district=%1 posture=%2 postureScore=%3 tierSource=%4 type=%5 subtype=%6 tier=%7 intel=%8 reason=%9", _districtId, _secLevel, _postureScore, _tierSource, _threatType, _threatSubtype, _selectedTier, _intelQuality, _denyReason];
    };
} forEach _districtIds;

_scheduledAny

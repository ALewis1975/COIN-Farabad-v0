/*
    ARC_fnc_threatAoPostureUpdate

    Threat Economy v0: update per-district security level based on cumulative attack_count_30d and risk posture.
    Slow cadence tick (>= 600s).

    Security levels:
      NORMAL   (0-1 attacks)
      ELEVATED (2-4 attacks)
      HIGH_RISK (5-7 attacks or risk >= 70)
      CRITICAL (8+ attacks or risk >= 85)

    Also applies:
      - Checkpoint alert level for HIGH_RISK/CRITICAL districts
      - Scheduler budget floor for HIGH_RISK/CRITICAL districts

    Returns:
      BOOL (false = not fired this tick)
*/

if (!isServer) exitWith {false};

private _intervalS = missionNamespace getVariable ["ARC_threatPostureIntervalS", 600];
if (!(_intervalS isEqualType 0) || { _intervalS < 120 }) then { _intervalS = 600; };

private _postureLastTs = missionNamespace getVariable ["ARC_threatPostureLastTs", -1];
if (!(_postureLastTs isEqualType 0)) then { _postureLastTs = -1; };

private _now = serverTime;
if (_postureLastTs > 0 && { (_now - _postureLastTs) < _intervalS }) exitWith {false};

missionNamespace setVariable ["ARC_threatPostureLastTs", _now];

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _riskMap = ["threat_v0_district_risk", createHashMap] call ARC_fnc_stateGet;
if (!(_riskMap isEqualType createHashMap)) then { _riskMap = createHashMap; };

private _districtIds = [
    "D01","D02","D03","D04","D05","D06","D07","D08","D09","D10",
    "D11","D12","D13","D14","D15","D16","D17","D18","D19","D20"
];

{
    private _id = _x;
    private _dEntry = [_riskMap, _id, createHashMap] call _hg;
    if (!(_dEntry isEqualType createHashMap)) then { _dEntry = createHashMap; };

    private _attackCount = [_dEntry, "attack_count_30d", 0] call _hg;
    if (!(_attackCount isEqualType 0)) then { _attackCount = 0; };

    private _riskLevel = [_dEntry, "risk_level", 30] call _hg;
    if (!(_riskLevel isEqualType 0)) then { _riskLevel = 30; };

    // Determine security level from observed attacks plus district risk.
    private _secLevel = "NORMAL";
    if (_attackCount >= 8 || { _riskLevel >= 85 }) then
    {
        _secLevel = "CRITICAL";
    }
    else
    {
        if (_attackCount >= 5 || { _riskLevel >= 70 }) then
        {
            _secLevel = "HIGH_RISK";
        }
        else
        {
            if (_attackCount >= 2) then { _secLevel = "ELEVATED"; };
        };
    };

    // Publish security level (replicated to all clients)
    missionNamespace setVariable [format ["ARC_district_%1_secLevel", _id], _secLevel, true];

    // Checkpoint alert level
    if (_secLevel in ["HIGH_RISK", "CRITICAL"]) then
    {
        private _alertLevel = if (_secLevel isEqualTo "CRITICAL") then { 3 } else { 2 };
        missionNamespace setVariable [format ["ARC_checkpointAlertLevel_%1", _id], _alertLevel, true];
    }
    else
    {
        if (_secLevel isEqualTo "ELEVATED") then
        {
            missionNamespace setVariable [format ["ARC_checkpointAlertLevel_%1", _id], 1, true];
        }
        else
        {
            missionNamespace setVariable [format ["ARC_checkpointAlertLevel_%1", _id], 0, true];
        };
    };

    // Budget floor for HIGH_RISK/CRITICAL: keep scheduler posture aligned with AO posture.
    if (_secLevel in ["HIGH_RISK", "CRITICAL"]) then
    {
        private _riskFloor = if (_secLevel isEqualTo "CRITICAL") then { 85 } else { 60 };
        if (_riskLevel < _riskFloor) then
        {
            _dEntry set ["risk_level", _riskFloor];
            _riskMap set [_id, _dEntry];
        };
    };

    diag_log format ["[ARC][INFO] ARC_fnc_threatAoPostureUpdate: district=%1 attacks=%2 risk=%3 secLevel=%4", _id, _attackCount, _riskLevel, _secLevel];

} forEach _districtIds;

["threat_v0_district_risk", _riskMap] call ARC_fnc_stateSet;

true

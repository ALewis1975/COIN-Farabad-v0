/*
    ARC_fnc_threatAoPostureUpdate

    Threat Economy v0: update per-district security level based on cumulative attack_count_30d.
    Slow cadence tick (>= 600s).

    Security levels:
      NORMAL   (0-1 attacks)
      ELEVATED (2-4 attacks)
      HIGH_RISK (5+ attacks)

    Also applies:
      - Checkpoint alert level for HIGH_RISK districts
      - Scheduler budget floor for HIGH_RISK districts (risk_level min 60)

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

    // Determine security level
    private _secLevel = "NORMAL";
    if (_attackCount >= 5) then { _secLevel = "HIGH_RISK"; };
    if (_attackCount >= 2 && { _attackCount < 5 }) then { _secLevel = "ELEVATED"; };

    // Publish security level (replicated to all clients)
    missionNamespace setVariable [format ["ARC_district_%1_secLevel", _id], _secLevel, true];

    // Checkpoint alert level
    if (_secLevel isEqualTo "HIGH_RISK") then
    {
        missionNamespace setVariable [format ["ARC_checkpointAlertLevel_%1", _id], 2, true];
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

    // Budget floor for HIGH_RISK: set risk_level min 60
    if (_secLevel isEqualTo "HIGH_RISK") then
    {
        private _riskLevel = [_dEntry, "risk_level", 30] call _hg;
        if (!(_riskLevel isEqualType 0)) then { _riskLevel = 30; };
        if (_riskLevel < 60) then
        {
            _dEntry set ["risk_level", 60];
            _riskMap set [_id, _dEntry];
        };
    };

    diag_log format ["[ARC][INFO] ARC_fnc_threatAoPostureUpdate: district=%1 attacks=%2 secLevel=%3", _id, _attackCount, _secLevel];

} forEach _districtIds;

["threat_v0_district_risk", _riskMap] call ARC_fnc_stateSet;

true

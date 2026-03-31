/*
    ARC_fnc_threatDistrictRiskDecay

    Threat Economy v0: slow-cadence district risk level decay/rise tick.
    Modulated by CIVSUB WHITE score when CIVSUB is active.

    Cadence: ARC_threatRiskDecayIntervalS (default 300s).
    Rate:    ARC_threatRiskDecayRate      (default 1, clamped 0..10).

    Returns:
      BOOL (false = not fired this tick)
*/

if (!isServer) exitWith {false};

private _intervalS = missionNamespace getVariable ["ARC_threatRiskDecayIntervalS", 300];
if (!(_intervalS isEqualType 0) || { _intervalS < 60 }) then { _intervalS = 300; };

private _decayLastTs = missionNamespace getVariable ["ARC_threatRiskDecayLastTs", -1];
if (!(_decayLastTs isEqualType 0)) then { _decayLastTs = -1; };

private _now = serverTime;
if (_decayLastTs > 0 && { (_now - _decayLastTs) < _intervalS }) exitWith {false};

missionNamespace setVariable ["ARC_threatRiskDecayLastTs", _now];

private _baseRate = missionNamespace getVariable ["ARC_threatRiskDecayRate", 1];
if (!(_baseRate isEqualType 0)) then { _baseRate = 1; };
_baseRate = (_baseRate max 0) min 10;

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _riskMap = ["threat_v0_district_risk", createHashMap] call ARC_fnc_stateGet;
if (!(_riskMap isEqualType createHashMap)) then { _riskMap = createHashMap; };

private _civEnabled = missionNamespace getVariable ["civsub_v1_enabled", false];
if (!(_civEnabled isEqualType true) && !(_civEnabled isEqualType false)) then { _civEnabled = false; };

private _civDistricts = createHashMap;
if (_civEnabled) then
{
    _civDistricts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
    if (!(_civDistricts isEqualType createHashMap)) then { _civDistricts = createHashMap; };
};

private _districtIds = [
    "D01","D02","D03","D04","D05","D06","D07","D08","D09","D10",
    "D11","D12","D13","D14","D15","D16","D17","D18","D19","D20"
];

{
    private _id = _x;

    private _dEntry = [_riskMap, _id, createHashMap] call _hg;
    if (!(_dEntry isEqualType createHashMap)) then
    {
        _dEntry = createHashMap;
        _dEntry set ["risk_level", 30];
        _dEntry set ["last_attack_ts", -1];
        _dEntry set ["attack_count_30d", 0];
        _dEntry set ["cooldown_until", -1];
    };

    private _riskLevel = [_dEntry, "risk_level", 30] call _hg;
    if (!(_riskLevel isEqualType 0)) then { _riskLevel = 30; };

    // CIVSUB modulation
    private _whiteScore = 50; // neutral fallback
    if (_civEnabled) then
    {
        private _d = [_civDistricts, _id, createHashMap] call _hg;
        _whiteScore = [_d, "W", 50] call _hg; // 50 = neutral WHITE baseline (mid-point of 0..100 W scale)
        if (!(_whiteScore isEqualType 0)) then { _whiteScore = 50; };
    };

    // Decay multiplier based on WHITE score
    private _effectiveRate = _baseRate;
    if (_whiteScore >= 70) then { _effectiveRate = _baseRate * 2; };  // high WHITE → faster decay

    // Apply decay or passive rise
    if (_whiteScore >= 50) then
    {
        _riskLevel = (_riskLevel - _effectiveRate) max 0;
    }
    else
    {
        if (_whiteScore < 30) then
        {
            _riskLevel = (_riskLevel + _effectiveRate) min 100;
        }
        else
        {
            _riskLevel = (_riskLevel - (_effectiveRate * 0.5)) max 0;
        };
    };

    _dEntry set ["risk_level", _riskLevel];
    _riskMap set [_id, _dEntry];

} forEach _districtIds;

["threat_v0_district_risk", _riskMap] call ARC_fnc_stateSet;

true

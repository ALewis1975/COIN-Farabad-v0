/*
    ARC_fnc_intelQualityCoupleDistrict

    Computes a bounded lead/intel quality adjustment from district posture.

    Inputs:
      0: STRING districtId
      1: NUMBER baseQuality (0..1)
      2: STRING sourceType/context label
      3: ARRAY optional context pairs. Recognized keys:
           white, red, green, risk_level, attack_count_30d, s_coop, s_threat,
           posture_score, threat_type, threat_subtype, transition.

    Returns:
      ARRAY pairs with quality, band, trust/intimidation/stability scores,
      and explainable factor metadata.

    Notes:
      - Read-only helper. Does not mutate state.
      - Uses CIVSUB W/R/G effective values when available.
      - Uses Threat Economy district risk/cooldown when available.
*/

params [
    ["_districtId", "", [""]],
    ["_baseQuality", 0.5, [0]],
    ["_sourceType", "UNKNOWN", [""]],
    ["_context", [], [[]]]
];

private _pget = {
    params ["_pairs", "_key", "_default"];
    if (!(_pairs isEqualType [])) exitWith { _default };
    private _out = _default;
    {
        if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith
        {
            _out = _x select 1;
        };
    } forEach _pairs;
    _out
};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _clampScore = {
    params [["_v", 0, [0]]];
    if (_v < 0) then { _v = 0; };
    if (_v > 100) then { _v = 100; };
    _v
};
private _clamp01 = {
    params [["_v", 0.5, [0]]];
    if (_v < 0) then { _v = 0; };
    if (_v > 1) then { _v = 1; };
    _v
};

if (!(_districtId isEqualType "")) then { _districtId = ""; };
_districtId = toUpper _districtId;
if (_districtId isEqualTo "") then { _districtId = "D00"; };

if (!(_baseQuality isEqualType 0)) then { _baseQuality = 0.5; };
_baseQuality = [_baseQuality] call _clamp01;

if (!(_sourceType isEqualType "")) then { _sourceType = "UNKNOWN"; };
_sourceType = toUpper _sourceType;
if (_sourceType isEqualTo "") then { _sourceType = "UNKNOWN"; };
if (!(_context isEqualType [])) then { _context = []; };

private _whiteScore = [_context, "white", -1] call _pget;
private _redScore = [_context, "red", -1] call _pget;
private _greenScore = [_context, "green", -1] call _pget;
private _riskLevel = [_context, "risk_level", -1] call _pget;
private _attackCount30d = [_context, "attack_count_30d", -1] call _pget;
private _sCoop = [_context, "s_coop", -1] call _pget;
private _sThreat = [_context, "s_threat", -1] call _pget;
private _postureScore = [_context, "posture_score", -1] call _pget;

private _civDistricts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if (_civDistricts isEqualType createHashMap) then
{
    private _d = [_civDistricts, _districtId, createHashMap] call _hg;
    if (_d isEqualType createHashMap) then
    {
        if (!(_whiteScore isEqualType 0) || { _whiteScore < 0 }) then { _whiteScore = [_d, "W_EFF_U", [_d, "W", 45] call _hg] call _hg; };
        if (!(_redScore isEqualType 0) || { _redScore < 0 }) then { _redScore = [_d, "R_EFF_U", [_d, "R", 55] call _hg] call _hg; };
        if (!(_greenScore isEqualType 0) || { _greenScore < 0 }) then { _greenScore = [_d, "G_EFF_U", [_d, "G", 35] call _hg] call _hg; };
    };
};

if (!(_whiteScore isEqualType 0) || { _whiteScore < 0 }) then { _whiteScore = 45; };
if (!(_redScore isEqualType 0) || { _redScore < 0 }) then { _redScore = 55; };
if (!(_greenScore isEqualType 0) || { _greenScore < 0 }) then { _greenScore = 35; };
_whiteScore = [_whiteScore] call _clampScore;
_redScore = [_redScore] call _clampScore;
_greenScore = [_greenScore] call _clampScore;

private _riskMap = ["threat_v0_district_risk", createHashMap] call ARC_fnc_stateGet;
if (_riskMap isEqualType createHashMap) then
{
    private _r = [_riskMap, _districtId, createHashMap] call _hg;
    if (_r isEqualType createHashMap) then
    {
        if (!(_riskLevel isEqualType 0) || { _riskLevel < 0 }) then { _riskLevel = [_r, "risk_level", 30] call _hg; };
        if (!(_attackCount30d isEqualType 0) || { _attackCount30d < 0 }) then { _attackCount30d = [_r, "attack_count_30d", 0] call _hg; };
    };
};

if (!(_riskLevel isEqualType 0) || { _riskLevel < 0 }) then { _riskLevel = 30; };
if (!(_attackCount30d isEqualType 0) || { _attackCount30d < 0 }) then { _attackCount30d = 0; };
_riskLevel = [_riskLevel] call _clampScore;
_attackCount30d = (_attackCount30d max 0) min 30;

if (!(_sCoop isEqualType 0) || { _sCoop < 0 }) then
{
    _sCoop = (0.55 * _whiteScore) + (0.35 * _greenScore) - (0.70 * _redScore);
};
if (!(_sThreat isEqualType 0) || { _sThreat < 0 }) then
{
    _sThreat = (1.00 * _redScore) - (0.35 * _whiteScore) - (0.25 * _greenScore);
};
_sCoop = [_sCoop] call _clampScore;
_sThreat = [_sThreat] call _clampScore;

if (!(_postureScore isEqualType 0) || { _postureScore < 0 }) then
{
    _postureScore = (0.50 * _riskLevel) + (0.50 * _sThreat);
};
_postureScore = [_postureScore] call _clampScore;

private _trustScore = [((0.55 * _whiteScore) + (0.45 * _greenScore))] call _clampScore;
private _intimidationScore = [((0.55 * _redScore) + (0.45 * _riskLevel))] call _clampScore;
private _attackPressure = [(_attackCount30d * 15)] call _clampScore;
private _stabilityScore = [(100 - ((0.45 * _sThreat) + (0.30 * _attackPressure) + (0.25 * (100 - _sCoop))))] call _clampScore;

private _trustAdjust = (_trustScore - 50) * 0.0025;
private _intimidationAdjust = (50 - _intimidationScore) * 0.0020;
private _stabilityAdjust = (_stabilityScore - 50) * 0.0015;
private _totalAdjust = _trustAdjust + _intimidationAdjust + _stabilityAdjust;
private _quality = [_baseQuality + _totalAdjust] call _clamp01;

// Keep quality useful but avoid perfect or hopeless outputs from one coupling pass.
_quality = (_quality max 0.15) min 0.95;

private _band = "LOW";
if (_quality >= 0.50) then { _band = "MED"; };
if (_quality >= 0.75) then { _band = "HIGH"; };
if (_quality < 0.25) then { _band = "POOR"; };

private _precision = "VAGUE";
if (_quality >= 0.45 && { _trustScore >= 45 } && { _stabilityScore >= 35 }) then { _precision = "AREA"; };
if (_quality >= 0.70 && { _trustScore >= 60 } && { _stabilityScore >= 55 }) then { _precision = "LOCALIZED"; };

private _timeliness = "DELAYED";
if (_quality >= 0.45 && { _intimidationScore < 70 }) then { _timeliness = "CURRENT"; };
if (_quality >= 0.70 && { _intimidationScore < 55 }) then { _timeliness = "FRESH"; };

private _note = format ["trust=%1 intimidation=%2 stability=%3", round _trustScore, round _intimidationScore, round _stabilityScore];

[
    ["schema", "intel_quality_coupling_v1"],
    ["district_id", _districtId],
    ["source_type", _sourceType],
    ["base_quality", _baseQuality],
    ["quality", _quality],
    ["quality_band", _band],
    ["precision", _precision],
    ["timeliness", _timeliness],
    ["trust_score", _trustScore],
    ["intimidation_score", _intimidationScore],
    ["stability_score", _stabilityScore],
    ["white_score", _whiteScore],
    ["red_score", _redScore],
    ["green_score", _greenScore],
    ["risk_level", _riskLevel],
    ["attack_count_30d", _attackCount30d],
    ["s_coop", _sCoop],
    ["s_threat", _sThreat],
    ["posture_score", _postureScore],
    ["trust_adjust", _trustAdjust],
    ["intimidation_adjust", _intimidationAdjust],
    ["stability_adjust", _stabilityAdjust],
    ["total_adjust", _totalAdjust],
    ["explanation", _note]
]

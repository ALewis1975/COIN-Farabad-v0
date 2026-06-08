/*
    ARC_fnc_intelQualityCouple

    Builds explainable intel-quality coupling metadata from district posture.

    Purpose:
      Make lead strength/quality reflect trust, intimidation, and stability
      without exposing hidden OPFOR state or changing physical threat behavior.

    Params:
      0: STRING districtId
      1: NUMBER baseQuality (0..1)
      2: STRING sourceType (e.g. THREAT_SCHEDULER, IED_DISCOVERED, VBIED_STAGED)
      3: STRING leadTag
      4: ARRAY context pairs

    Returns:
      ARRAY pairs, including ["quality", n] and explainability fields.
*/

if (!isServer) exitWith {[]};

params [
    ["_districtId", "D00", [""]],
    ["_baseQuality", 0.5, [0]],
    ["_sourceType", "UNKNOWN", [""]],
    ["_leadTag", "", [""]],
    ["_context", [], [[]]]
];

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _trimFn = compile "params ['_s']; trim _s";
private _clampScore = {
    params [["_v", 0, [0]]];
    if (_v < 0) then { _v = 0; };
    if (_v > 100) then { _v = 100; };
    _v
};
private _clamp01 = {
    params [["_v", 0, [0]]];
    if (_v < 0) then { _v = 0; };
    if (_v > 1) then { _v = 1; };
    _v
};

private _distU = toUpper ([_districtId] call _trimFn);
if (_distU isEqualTo "") then { _distU = "D00"; };

private _sourceU = toUpper ([_sourceType] call _trimFn);
if (_sourceU isEqualTo "") then { _sourceU = "UNKNOWN"; };

private _tagU = toUpper ([_leadTag] call _trimFn);

_baseQuality = [_baseQuality] call _clamp01;
if (!(_context isEqualType [])) then { _context = []; };

// CIVSUB district posture inputs. Prefer effective values; fall back to public/simple keys.
private _whiteScore = 45;
private _redScore = 55;
private _greenScore = 35;
private _civDistricts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if (_civDistricts isEqualType createHashMap) then
{
    private _civD = [_civDistricts, _distU, createHashMap] call _hg;
    if (_civD isEqualType createHashMap) then
    {
        _whiteScore = [_civD, "W_EFF_U", [_civD, "W", 45] call _hg] call _hg;
        _redScore = [_civD, "R_EFF_U", [_civD, "R", 55] call _hg] call _hg;
        _greenScore = [_civD, "G_EFF_U", [_civD, "G", 35] call _hg] call _hg;
    };
};
if (!(_whiteScore isEqualType 0)) then { _whiteScore = 45; };
if (!(_redScore isEqualType 0)) then { _redScore = 55; };
if (!(_greenScore isEqualType 0)) then { _greenScore = 35; };

private _sCoop = [(0.55 * _whiteScore) + (0.35 * _greenScore) - (0.70 * _redScore)] call _clampScore;
private _sThreat = [(1.00 * _redScore) - (0.35 * _whiteScore) - (0.25 * _greenScore)] call _clampScore;

// Threat-pressure inputs that approximate intimidation and instability without exposing hidden network internals.
private _riskLevel = 30;
private _attackCount30d = 0;
private _cooldownActive = false;
private _riskMap = ["threat_v0_district_risk", createHashMap] call ARC_fnc_stateGet;
if (_riskMap isEqualType createHashMap) then
{
    private _rEntry = [_riskMap, _distU, createHashMap] call _hg;
    if (_rEntry isEqualType createHashMap) then
    {
        _riskLevel = [_rEntry, "risk_level", 30] call _hg;
        _attackCount30d = [_rEntry, "attack_count_30d", 0] call _hg;
        private _coolUntil = [_rEntry, "cooldown_until", -1] call _hg;
        if (!(_coolUntil isEqualType 0)) then { _coolUntil = -1; };
        _cooldownActive = _coolUntil > serverTime;
    };
};
if (!(_riskLevel isEqualType 0)) then { _riskLevel = 30; };
if (!(_attackCount30d isEqualType 0)) then { _attackCount30d = 0; };

private _trust = [(0.55 * _whiteScore) + (0.45 * _greenScore)] call _clampScore;
private _intimidation = [(0.55 * _redScore) + (0.30 * _riskLevel) + ((_attackCount30d min 5) * 3)] call _clampScore;
private _instability = [(0.45 * _sThreat) + (0.25 * _riskLevel) + ((_attackCount30d min 5) * 5) + (if (_cooldownActive) then { 8 } else { 0 })] call _clampScore;
private _stability = [100 - _instability] call _clampScore;

// Civilian/HUMINT-style sources are more sensitive to trust and intimidation.
// Evidence/aftermath sources are still affected, but less strongly.
private _sourceSensitivity = 0.80;
if (_sourceU in ["CIVILIAN", "HUMINT", "RUMOR", "IED_DISCOVERED", "VBIED_STAGED", "SUICIDE_STAGED"]) then { _sourceSensitivity = 1.00; };
if (_sourceU in ["EVIDENCE", "POST_BLAST", "IED_DETONATED", "VBIED_DETONATED", "SUICIDE_DETONATED", "INTERDICTED"]) then { _sourceSensitivity = 0.60; };

private _deltaRaw = (( _trust - 50) * 0.0030) - ((_intimidation - 50) * 0.0025) + ((_stability - 50) * 0.0020);
private _delta = (_deltaRaw * _sourceSensitivity) max -0.30;
_delta = _delta min 0.25;

private _quality = [_baseQuality + _delta] call _clamp01;

private _confidenceBand = "VERY_LOW";
if (_quality >= 0.30) then { _confidenceBand = "LOW"; };
if (_quality >= 0.50) then { _confidenceBand = "MED"; };
if (_quality >= 0.75) then { _confidenceBand = "HIGH"; };

private _timeliness = "NORMAL";
if (_cooldownActive) then { _timeliness = "UNSTABLE"; };
if (_attackCount30d >= 3) then { _timeliness = "VOLATILE"; };

private _precision = "DISTRICT";
if (_quality >= 0.65 && { _trust >= 60 }) then { _precision = "AREA"; };
if (_quality < 0.35 || { _intimidation >= 75 }) then { _precision = "VAGUE"; };

[
    ["schema", "intel_quality_coupling_v1"],
    ["version", [1,0,0]],
    ["district_id", _distU],
    ["source_type", _sourceU],
    ["lead_tag", _tagU],
    ["base_quality", _baseQuality],
    ["quality", _quality],
    ["quality_delta", _quality - _baseQuality],
    ["confidence_band", _confidenceBand],
    ["timeliness", _timeliness],
    ["precision", _precision],
    ["trust", _trust],
    ["intimidation", _intimidation],
    ["stability", _stability],
    ["instability", _instability],
    ["white_score", _whiteScore],
    ["red_score", _redScore],
    ["green_score", _greenScore],
    ["s_coop", _sCoop],
    ["s_threat", _sThreat],
    ["risk_level", _riskLevel],
    ["attack_count_30d", _attackCount30d],
    ["cooldown_active", _cooldownActive],
    ["source_sensitivity", _sourceSensitivity],
    ["context", _context],
    ["builtAtServerTime", serverTime]
]

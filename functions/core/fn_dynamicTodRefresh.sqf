/*
    ARC_fnc_dynamicTodRefresh

    Server-authoritative dynamic time-of-day policy refresh.
    Reuses CIVSUB activity window settings as canonical phase logic.

    Returns: HASHMAP policy snapshot
*/

if (!isServer) exitWith { createHashMap };

private _tod = dayTime;

private _nightStart = missionNamespace getVariable ["civsub_v1_activity_night_start_h", 21];
private _nightEnd = missionNamespace getVariable ["civsub_v1_activity_night_end_h", 5];
private _peakAM0 = missionNamespace getVariable ["civsub_v1_activity_morning_peak_start_h", 7];
private _peakAM1 = missionNamespace getVariable ["civsub_v1_activity_morning_peak_end_h", 9];
private _peakPM0 = missionNamespace getVariable ["civsub_v1_activity_evening_peak_start_h", 16];
private _peakPM1 = missionNamespace getVariable ["civsub_v1_activity_evening_peak_end_h", 18];

if (!(_nightStart isEqualType 0)) then { _nightStart = 21; };
if (!(_nightEnd isEqualType 0)) then { _nightEnd = 5; };
if (!(_peakAM0 isEqualType 0)) then { _peakAM0 = 7; };
if (!(_peakAM1 isEqualType 0)) then { _peakAM1 = 9; };
if (!(_peakPM0 isEqualType 0)) then { _peakPM0 = 16; };
if (!(_peakPM1 isEqualType 0)) then { _peakPM1 = 18; };

private _isNight = (_tod >= _nightStart) || { _tod < _nightEnd };
private _isPeak = ((_tod >= _peakAM0) && { _tod <= _peakAM1 }) || { ((_tod >= _peakPM0) && { _tod <= _peakPM1 }) };

private _phase = "DAY";
if (_isNight) then { _phase = "NIGHT"; };
if (_isPeak) then { _phase = "PEAK"; };

private _profile = "STANDARD";
if (_phase isEqualTo "NIGHT") then { _profile = "LOW_VIS"; };
if (_phase isEqualTo "PEAK") then { _profile = "HIGH_VIS"; };

private _canSpawnCivil = true;
if (_phase isEqualTo "NIGHT") then
{
    _canSpawnCivil = missionNamespace getVariable ["ARC_dynamic_tod_allowCivilNight", true];
};
if (!(_canSpawnCivil isEqualType true) && !(_canSpawnCivil isEqualType false)) then { _canSpawnCivil = true; };

private _canSpawnAirbase = true;
if (_phase isEqualTo "NIGHT") then
{
    _canSpawnAirbase = missionNamespace getVariable ["ARC_dynamic_tod_allowAirbaseNight", false];
};
if (!(_canSpawnAirbase isEqualType true) && !(_canSpawnAirbase isEqualType false)) then { _canSpawnAirbase = true; };

private _canSpawnThreat = true;
if (_phase isEqualTo "NIGHT") then
{
    _canSpawnThreat = missionNamespace getVariable ["ARC_dynamic_tod_allowThreatNight", true];
};
if (!(_canSpawnThreat isEqualType true) && !(_canSpawnThreat isEqualType false)) then { _canSpawnThreat = true; };

private _canSpawnOps = true;
if (_phase isEqualTo "NIGHT") then
{
    _canSpawnOps = missionNamespace getVariable ["ARC_dynamic_tod_allowOpsNight", true];
};
if (!(_canSpawnOps isEqualType true) && !(_canSpawnOps isEqualType false)) then { _canSpawnOps = true; };

missionNamespace setVariable ["ARC_dynamic_tod_phase", _phase, true];
missionNamespace setVariable ["ARC_dynamic_tod_profile", _profile, true];
missionNamespace setVariable ["ARC_dynamic_tod_tod", _tod, true];
missionNamespace setVariable ["ARC_dynamic_tod_canSpawnCivil", _canSpawnCivil, true];
missionNamespace setVariable ["ARC_dynamic_tod_canSpawnAirbase", _canSpawnAirbase, true];
missionNamespace setVariable ["ARC_dynamic_tod_canSpawnThreat", _canSpawnThreat, true];
missionNamespace setVariable ["ARC_dynamic_tod_canSpawnOps", _canSpawnOps, true];
missionNamespace setVariable ["ARC_dynamic_tod_lastUpdateTs", serverTime, true];

// Keep legacy CIVSUB activity vars aligned to canonical TOD state.
missionNamespace setVariable ["civsub_v1_activity_phase", _phase, false];
missionNamespace setVariable ["civsub_v1_activity_tod", _tod, false];

private _policy = createHashMap;
_policy set ["phase", _phase];
_policy set ["profile", _profile];
_policy set ["tod", _tod];
_policy set ["canSpawnCivil", _canSpawnCivil];
_policy set ["canSpawnAirbase", _canSpawnAirbase];
_policy set ["canSpawnThreat", _canSpawnThreat];
_policy set ["canSpawnOps", _canSpawnOps];
_policy;

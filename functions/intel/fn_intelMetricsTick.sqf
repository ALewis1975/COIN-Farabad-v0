/*
    ARC_fnc_intelMetricsTick

    Server: sample key campaign metrics on a fixed cadence and retain a rolling
    window for TOC "change monitoring".

    Snapshot format stored in ARC_state:
      metricsSnapshots = [
        [sampleTimeServerTime, [ [key,value], ... ] ],
        ...
      ]

    Returns:
      BOOL - true if a new snapshot was recorded
*/

if (!isServer) exitWith {false};

private _interval = missionNamespace getVariable ["ARC_metricsIntervalSec", 900];
if (!(_interval isEqualType 0)) then { _interval = 900; };
_interval = (_interval max 60) min 7200;

private _cap = missionNamespace getVariable ["ARC_metricsSnapshotsCap", 24];
if (!(_cap isEqualType 0)) then { _cap = 24; };
_cap = (_cap max 4) min 96;

private _now = serverTime;
private _last = ["metricsLastAt", -1] call ARC_fnc_stateGet;
if (!(_last isEqualType 0)) then { _last = -1; };

private _do = false;
if (_last < 0) then
{
    _do = true; // seed
}
else
{
    if ((_now - _last) >= _interval) then { _do = true; };
};

if (!_do) exitWith {false};

// -------------------------------------------------------------------------
// Build the snapshot
// -------------------------------------------------------------------------
private _pairs = [];

private _p    = ["insurgentPressure", 0.60] call ARC_fnc_stateGet;
private _s    = ["civSentiment", 0.55] call ARC_fnc_stateGet;
private _leg  = ["govLegitimacy", 0.50] call ARC_fnc_stateGet;
private _corr = ["corruption", 0.55] call ARC_fnc_stateGet;
private _inf  = ["infiltration", 0.35] call ARC_fnc_stateGet;

private _fuel = ["baseFuel", 1.00] call ARC_fnc_stateGet;
private _ammo = ["baseAmmo", 1.00] call ARC_fnc_stateGet;
private _med  = ["baseMed", 1.00] call ARC_fnc_stateGet;

private _cas = ["civCasualties", 0] call ARC_fnc_stateGet;
if (!(_cas isEqualType 0)) then { _cas = 0; };

private _hist = ["incidentHistory", []] call ARC_fnc_stateGet;
private _incidentCount = if (_hist isEqualType []) then { count _hist } else { 0 };

private _ilog = ["intelLog", []] call ARC_fnc_stateGet;
private _intelCount = if (_ilog isEqualType []) then { count _ilog } else { 0 };

// Coerce numeric scalars
private _toNum = {
    params ["_v", "_d"];
    if (!(_v isEqualType 0)) then { _v = _d; };
    _v
};

_p    = (([_p, 0.60] call _toNum) max 0) min 1;
_s    = (([_s, 0.55] call _toNum) max 0) min 1;
_leg  = (([_leg, 0.50] call _toNum) max 0) min 1;
_corr = (([_corr, 0.55] call _toNum) max 0) min 1;
_inf  = (([_inf, 0.35] call _toNum) max 0) min 1;
_fuel = (([_fuel, 1.00] call _toNum) max 0) min 1;
_ammo = (([_ammo, 1.00] call _toNum) max 0) min 1;
_med  = (([_med, 1.00] call _toNum) max 0) min 1;

_pairs pushBack ["insurgentPressure", _p];
_pairs pushBack ["civSentiment", _s];
_pairs pushBack ["govLegitimacy", _leg];
_pairs pushBack ["corruption", _corr];
_pairs pushBack ["infiltration", _inf];
_pairs pushBack ["civCasualties", _cas];
_pairs pushBack ["baseFuel", _fuel];
_pairs pushBack ["baseAmmo", _ammo];
_pairs pushBack ["baseMed", _med];
_pairs pushBack ["incidentCount", _incidentCount];
_pairs pushBack ["intelCount", _intelCount];

private _snap = [_now, _pairs];

private _snaps = ["metricsSnapshots", []] call ARC_fnc_stateGet;
if (!(_snaps isEqualType [])) then { _snaps = []; };
_snaps pushBack _snap;

// Cap history
while { (count _snaps) > _cap } do
{
    _snaps deleteAt 0;
};

["metricsSnapshots", _snaps] call ARC_fnc_stateSet;
["metricsLastAt", _now] call ARC_fnc_stateSet;

true

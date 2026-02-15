/*
    ARC WorldTime v1 (server-owned)

    Goals:
      - Provide a single authoritative world-time snapshot for UI + systems.
      - Conservative defaults: DO NOT force date or time multiplier unless toggles are enabled.
      - Low-frequency broadcast (default 45s) to avoid performance/regression risk.

    Public state:
      - ARC_worldTimeSnap (JIP-safe): [dateArray, daytime, phaseStr, timeMultiplier, serverTime]
      - ARC_worldTime_dayPhase (JIP-safe): "NIGHT"|"MORNING"|"WORK"|"EVENING"

    Tunables (missionNamespace, safe defaults applied if nil):
      - ARC_worldTime_enabled (bool) default true
      - ARC_worldTime_forceDate (bool) default false
      - ARC_worldTime_startDate (array [Y,M,D,H,MIN]) default [2011,7,1,6,0]
      - ARC_worldTime_forceMultiplier (bool) default false
      - ARC_worldTime_timeMultiplier (number) default 4
      - ARC_worldTime_broadcastIntervalSec (number) default 45
      - ARC_worldTime_phaseThresholds (array) default [5.5, 9.0, 17.0, 20.5]
          Meaning: [nightEnd, morningEnd, workEnd, eveningEnd]
*/

if (!isServer) exitWith {};

// Prevent double-starts across hot-reloads.
if (missionNamespace getVariable ["ARC_worldTime_running", false]) exitWith { diag_log "[ARC][WORLD TIME] already running"; };
missionNamespace setVariable ["ARC_worldTime_running", true];

// Safe defaults
if (isNil { missionNamespace getVariable "ARC_worldTime_enabled" }) then { missionNamespace setVariable ["ARC_worldTime_enabled", true, true]; };
private _enabled = missionNamespace getVariable ["ARC_worldTime_enabled", true];
if (!(_enabled isEqualType true)) then { _enabled = true; };

if (!_enabled) exitWith
{
    missionNamespace setVariable ["ARC_worldTime_running", false];
    diag_log "[ARC][WORLD TIME] disabled";
};

if (isNil { missionNamespace getVariable "ARC_worldTime_forceDate" }) then { missionNamespace setVariable ["ARC_worldTime_forceDate", false, true]; };
if (isNil { missionNamespace getVariable "ARC_worldTime_startDate" }) then { missionNamespace setVariable ["ARC_worldTime_startDate", [2011,7,1,6,0], true]; };
if (isNil { missionNamespace getVariable "ARC_worldTime_forceMultiplier" }) then { missionNamespace setVariable ["ARC_worldTime_forceMultiplier", false, true]; };
if (isNil { missionNamespace getVariable "ARC_worldTime_timeMultiplier" }) then { missionNamespace setVariable ["ARC_worldTime_timeMultiplier", 4, true]; };
if (isNil { missionNamespace getVariable "ARC_worldTime_broadcastIntervalSec" }) then { missionNamespace setVariable ["ARC_worldTime_broadcastIntervalSec", 45, true]; };
if (isNil { missionNamespace getVariable "ARC_worldTime_phaseThresholds" }) then { missionNamespace setVariable ["ARC_worldTime_phaseThresholds", [5.5, 9.0, 17.0, 20.5], true]; };

// Optional forcing (OFF by default)
private _forceDate = missionNamespace getVariable ["ARC_worldTime_forceDate", false];
if (!(_forceDate isEqualType true)) then { _forceDate = false; };

if (_forceDate) then
{
    private _d = missionNamespace getVariable ["ARC_worldTime_startDate", [2011,7,1,6,0]];
    if (!(_d isEqualType [])) then { _d = [2011,7,1,6,0]; };
    if ((count _d) >= 5) then
    {
        setDate _d;
        diag_log format ["[ARC][WORLD TIME] setDate forced: %1", _d];
    };
};

private _forceMult = missionNamespace getVariable ["ARC_worldTime_forceMultiplier", false];
if (!(_forceMult isEqualType true)) then { _forceMult = false; };

if (_forceMult) then
{
    private _m = missionNamespace getVariable ["ARC_worldTime_timeMultiplier", 4];
    if (_m isEqualType 0) then { _m = _m max 1; };
    setTimeMultiplier _m;
    diag_log format ["[ARC][WORLD TIME] setTimeMultiplier forced: %1", _m];
};

// Phase helper (closure avoids CfgFunctions changes)
if (isNil { missionNamespace getVariable "ARC_fnc_worldTimePhaseFromDaytime" }) then
{
    missionNamespace setVariable ["ARC_fnc_worldTimePhaseFromDaytime", {
        params ["_t"]; // daytime (0..24)
        private _thr = missionNamespace getVariable ["ARC_worldTime_phaseThresholds", [5.5, 9.0, 17.0, 20.5]];
        if (!(_thr isEqualType []) || { (count _thr) < 4 }) then { _thr = [5.5, 9.0, 17.0, 20.5]; };

        private _nightEnd   = _thr # 0;
        private _morningEnd = _thr # 1;
        private _workEnd    = _thr # 2;
        private _eveningEnd = _thr # 3;

        if (_t < _nightEnd || { _t >= _eveningEnd }) exitWith { "NIGHT" };
        if (_t < _morningEnd) exitWith { "MORNING" };
        if (_t < _workEnd) exitWith { "WORK" };
        "EVENING"
    }];
};

// Broadcast loop
[] spawn
{
    private _interval = missionNamespace getVariable ["ARC_worldTime_broadcastIntervalSec", 45];
    if (!(_interval isEqualType 0) || { _interval < 5 }) then { _interval = 45; };

    diag_log format ["[ARC][WORLD TIME] loop start (interval=%1s, forceDate=%2, forceMult=%3)", _interval, missionNamespace getVariable ["ARC_worldTime_forceDate", false], missionNamespace getVariable ["ARC_worldTime_forceMultiplier", false] ];

    while { missionNamespace getVariable ["ARC_worldTime_running", false] } do
    {
        private _d = date;
        private _t = daytime;
        private _phaseFn = missionNamespace getVariable ["ARC_fnc_worldTimePhaseFromDaytime", { "WORK" }];
        private _phase = [_t] call _phaseFn;
        private _mult = timeMultiplier;
        private _snap = [_d, _t, _phase, _mult, serverTime];

        missionNamespace setVariable ["ARC_worldTime_dayPhase", _phase, true];
        missionNamespace setVariable ["ARC_worldTimeSnap", _snap, true];

        // Optional debug
        if (missionNamespace getVariable ["ARC_debugLogEnabled", false]) then
        {
            diag_log format ["[ARC][WORLD TIME] %1 t=%2 phase=%3 mult=%4", _d, _t, _phase, _mult];
        };

        sleep _interval;
    };
};


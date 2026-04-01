/*
    Starts a lightweight loop that periodically tries to ensure one active incident exists.

    Notes:
      - Server only.
      - Single-run guard to prevent double loops.
      - Respects ["systemPauseUntil"] in ARC_state (serverTime) to temporarily pause spawning.
      - Logging is safe even if ARC_fnc_log is not present.
      - Tick interval is adaptive: lower insurgentPressure → longer sleep (AO breathing).
        Calm  (pressure < 0.30): sleep 90 s
        Normal(0.30–0.60):       sleep 60 s
        Hot   (0.60–0.80):       sleep 40 s
        Critical (> 0.80):       sleep 25 s
      - Configurable via ARC_incidentLoopSleepMin (default 25) / ARC_incidentLoopSleepMax (default 90).
*/

if (!isServer) exitWith {false};

if (!isNil { missionNamespace getVariable "ARC_incidentLoopRunning" }) exitWith {true};
missionNamespace setVariable ["ARC_incidentLoopRunning", true];

// Safe log (do not hard-depend on ARC_fnc_log)
if (!isNil "ARC_fnc_log") then
{
    ["INC", "Incident loop started"] call ARC_fnc_log;
}
else
{
    diag_log "[ARC][INC] Incident loop started";
};

[] spawn
{
    while {true} do
    {
        // Global pause (maintenance, admin pause, etc.)
        private _pauseUntil = ["systemPauseUntil", -1] call ARC_fnc_stateGet;
        if (_pauseUntil isEqualType 0 && { _pauseUntil > serverTime }) then
        {
            sleep 10;
        }
        else
        {
            [] call ARC_fnc_incidentTick;

            // Adaptive sleep: modulate tick frequency from insurgentPressure and threat
            // district heat so the AO "breathes" — calm districts slow the loop,
            // hot districts accelerate it.
            private _sleepMin = missionNamespace getVariable ["ARC_incidentLoopSleepMin", 25];
            private _sleepMax = missionNamespace getVariable ["ARC_incidentLoopSleepMax", 90];
            if (!(_sleepMin isEqualType 0)) then { _sleepMin = 25; };
            if (!(_sleepMax isEqualType 0)) then { _sleepMax = 90; };
            _sleepMin = (_sleepMin max 10) min 60;
            _sleepMax = (_sleepMax max _sleepMin) min 180;

            private _pressure = ["insurgentPressure", 0.35] call ARC_fnc_stateGet;
            if (!(_pressure isEqualType 0)) then { _pressure = 0.35; };
            _pressure = (_pressure max 0) min 1;

            // Also factor in average threat district heat (normalised 0..1 from 0..100)
            private _riskMap = ["threat_v0_district_risk", createHashMap] call ARC_fnc_stateGet;
            if (!(_riskMap isEqualType createHashMap)) then { _riskMap = createHashMap; };
            private _riskSum = 0;
            private _riskCnt = 0;
            {
                private _rEntry = _y;
                if (_rEntry isEqualType createHashMap) then
                {
                    private _rl = _rEntry getOrDefault ["risk_level", 30];
                    if (_rl isEqualType 0) then { _riskSum = _riskSum + _rl; _riskCnt = _riskCnt + 1; };
                };
            } forEach _riskMap;
            private _avgRisk = if (_riskCnt > 0) then { (_riskSum / _riskCnt) / 100 } else { 0 };
            _avgRisk = (_avgRisk max 0) min 1;

            // Combined heat (insurgent pressure dominates, district risk adds colour)
            private _heat = ((_pressure * 0.7) + (_avgRisk * 0.3)) min 1;

            // Map heat → sleep duration (linear interpolation, high heat = short sleep)
            private _sleepSec = _sleepMax - (_heat * (_sleepMax - _sleepMin));
            _sleepSec = (_sleepSec max _sleepMin) min _sleepMax;

            diag_log format ["[ARC][INC] incidentLoop: adaptive sleep=%1s (heat=%2 pressure=%3 avgRisk=%4)", round _sleepSec, round (_heat * 100) / 100, round (_pressure * 100) / 100, round (_avgRisk * 100) / 100];

            sleep _sleepSec;
        };
    };
};

true

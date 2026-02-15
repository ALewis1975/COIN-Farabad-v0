/*
    ARC_fnc_civsubProbHourToTick

    Convert hourly probability to per-tick probability (exact, locked v1):
      p_tick = 1 - (1 - p_hour)^(scheduler_s / 3600)

    Params:
      0: p_hour (0..1)
      1: scheduler_s (seconds)

    Returns: p_tick (0..1)
*/

params [
    ["_pHour", 0, [0]],
    ["_schedulerS", 300, [0]]
];

if (_pHour < 0) then { _pHour = 0; };
if (_pHour > 1) then { _pHour = 1; };
if (_schedulerS <= 0) exitWith {0};

private _exp = _schedulerS / 3600;
private _pTick = 1 - ( (1 - _pHour) ^ _exp );
if (_pTick < 0) then { _pTick = 0; };
if (_pTick > 1) then { _pTick = 1; };
_pTick

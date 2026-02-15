/*
    ARC_fnc_civsubProbLeadHour

    Piecewise-linear ambient lead probability per hour (exact, locked v1).

      If S_COOP <= 30: p = 0.05
      If 30 < S_COOP < 80: p = 0.05 + (S_COOP-30)*(0.30/50)
      If S_COOP >= 80: p = 0.35

    Params:
      0: S_COOP (number 0..100)

    Returns: number (0..1)
*/

params [["_S", 0, [0]]];

if (_S <= 30) exitWith {0.05};
if (_S >= 80) exitWith {0.35};

private _p = 0.05 + (_S - 30) * (0.30 / 50);
if (_p < 0) then { _p = 0; };
if (_p > 1) then { _p = 1; };
_p

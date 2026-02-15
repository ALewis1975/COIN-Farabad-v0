/*
    ARC_fnc_civsubProbAttackHour

    Piecewise-linear reactive red contact probability per hour (exact, locked v1).

      If S_THREAT <= 20: p = 0.03
      If 20 < S_THREAT < 80: p = 0.03 + (S_THREAT-20)*(0.22/60)
      If S_THREAT >= 80: p = 0.25

    Params:
      0: S_THREAT (number 0..100)

    Returns: number (0..1)
*/

params [["_S", 0, [0]]];

if (_S <= 20) exitWith {0.03};
if (_S >= 80) exitWith {0.25};

private _p = 0.03 + (_S - 20) * (0.22 / 60);
if (_p < 0) then { _p = 0; };
if (_p > 1) then { _p = 1; };
_p

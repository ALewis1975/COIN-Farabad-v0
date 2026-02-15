/*
    ARC_fnc_civsubIntelConfidence

    Intel confidence (0..1) from S_COOP and S_THREAT (exact, locked v1).

      intel_conf = clamp( 0.20 + 0.006*S_COOP - 0.004*S_THREAT , 0.10, 0.90 )

    Params:
      0: S_COOP (number)
      1: S_THREAT (number)

    Returns: number (0.10..0.90)
*/

params [
    ["_Scoop", 0, [0]],
    ["_Sthreat", 0, [0]]
];

private _c = 0.20 + 0.006 * _Scoop - 0.004 * _Sthreat;
if (_c < 0.10) then { _c = 0.10; };
if (_c > 0.90) then { _c = 0.90; };
_c

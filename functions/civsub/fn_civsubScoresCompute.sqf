/*

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; [(_h), _k, _d] call _hg";
private _hmFrom   = compile "params ['_pairs']; private _r = createHashMap; { _r set [_x select 0, _x select 1]; } forEach _pairs; _r";
    ARC_fnc_civsubScoresCompute

    Computes derived district scores (locked v1 math).

      S_COOP   = clamp( 0.55*W + 0.35*G - 0.70*R , 0, 100 )
      S_THREAT = clamp( 1.00*R - 0.35*W - 0.25*G , 0, 100 )

    Defensive: accepts HashMap or array-of-pairs. If invalid type, returns zeros.

    Params:
      0: district (HashMap or array-of-pairs)

    Returns:
      HashMap: {"S_COOP":n,"S_THREAT":n}
*/

private _d = objNull;
if ((count _this) > 0) then { _d = _this select 0; };

if (_d isEqualType []) then
{
    // Convert array-of-pairs to HashMap
    _d = [_d] call _hmFrom;
};

if !(_d isEqualType createHashMap) exitWith
{
    // One-time warning per mission session (prevents log spam)
    if (isNil { missionNamespace getVariable "civsub_v1_warn_scoresComputeBadType" }) then
    {
        missionNamespace setVariable ["civsub_v1_warn_scoresComputeBadType", true];
        diag_log format ["[CIVSUB][WARN] ScoresCompute expected district HashMap but got %1; returning zeros.", typeName _d];
    };
    [[["S_COOP", 0], ["S_THREAT", 0]]] call _hmFrom
};

private _W = [_d, "W_EFF_U", 45] call _hg;
private _R = [_d, "R_EFF_U", 55] call _hg;
private _G = [_d, "G_EFF_U", 35] call _hg;

private _Scoop = (0.55 * _W) + (0.35 * _G) - (0.70 * _R);
private _Sthreat = (1.00 * _R) - (0.35 * _W) - (0.25 * _G);

if (_Scoop < 0) then { _Scoop = 0; };
if (_Scoop > 100) then { _Scoop = 100; };

if (_Sthreat < 0) then { _Sthreat = 0; };
if (_Sthreat > 100) then { _Sthreat = 100; };

[[["S_COOP", _Scoop], ["S_THREAT", _Sthreat]]] call _hmFrom

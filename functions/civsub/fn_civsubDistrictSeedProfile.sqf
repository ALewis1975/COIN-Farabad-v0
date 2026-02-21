/*
    ARC_fnc_civsubDistrictSeedProfile

    Builds deterministic district baseline/effective W/R/G values from stable inputs.

    Params:
      0: districtId (string)
      1: pop_total (number)
      2: centroid ([x,y] or [x,y,z])
      3: campaign seed (number)

    Returns: hashmap with W_BASE_U/R_BASE_U/G_BASE_U and matching W_EFF_U/R_EFF_U/G_EFF_U
*/

params [
    ["_districtId", "", [""]],
    ["_popTotal", 0, [0]],
    ["_centroid", [0,0], [[]]],
    ["_campaignSeed", 1337, [0]]
];

// sqflint-compat helpers
private _trimFn     = compile "params ['_s']; trim _s";
private _hmFrom   = compile "params ['_pairs']; private _r = createHashMap; { _r set [_x select 0, _x select 1]; } forEach _pairs; _r";

private _idNorm = toUpper ([_districtId] call _trimFn);
if (_idNorm isEqualTo "") then { _idNorm = "D00"; };

private _pop = _popTotal;
if !(_pop isEqualType 0) then { _pop = 0; };
_pop = 0 max _pop;

private _seed = _campaignSeed;
if !(_seed isEqualType 0) then { _seed = 1337; };

private _cx = 0;
private _cy = 0;
if (_centroid isEqualType [] && { (count _centroid) >= 2 }) then {
    _cx = _centroid select 0;
    _cy = _centroid select 1;
};
if !(_cx isEqualType 0) then { _cx = 0; };
if !(_cy isEqualType 0) then { _cy = 0; };

private _idHash = 0;
{
    _idHash = (_idHash * 131 + _x) mod 2147483647;
} forEach (toArray _idNorm);

private _cxi = floor _cx;
private _cyi = floor _cy;
private _xyMix = ((_cxi * 73) + (_cyi * 37)) mod 97;
private _popBand = _pop min 4000;
private _popShift = floor (_popBand / 80); // 0..50
private _seedMix = (_seed mod 89);
private _idMix = (_idHash mod 41);

private _wBase = 45 + ((_idMix + _seedMix + _xyMix) mod 23) - 11;
private _rBase = 55 + (((_idMix * 2) + _popShift + _seedMix) mod 27) - 13;
private _gBase = 35 + (((_xyMix * 2) + _popShift + (_seed mod 53)) mod 25) - 12;

private _profile = [[
    ["W_BASE_U", _wBase],
    ["R_BASE_U", _rBase],
    ["G_BASE_U", _gBase],
    ["W_EFF_U", _wBase],
    ["R_EFF_U", _rBase],
    ["G_EFF_U", _gBase]
]] call _hmFrom;

[_profile] call ARC_fnc_civsubDistrictsClamp;
_profile

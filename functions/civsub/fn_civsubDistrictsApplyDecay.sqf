/*
    ARC_fnc_civsubDistrictsApplyDecay

    Applies locked v1 influence decay toward baseline per tick.

    Params:
      0: districts hashmap (districtId -> districtState)
*/

params [
    ["_districts", createHashMap, [createHashMap]]
];

if (!(_districts isEqualType createHashMap)) exitWith {false};


// sqflint-compatible helpers
private _hg      = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
{
    private _d = _districts get _x;
    if !(_d isEqualType createHashMap) then { continue; };

    private _w = [_d, "W_EFF_U", 0] call _hg;
    private _r = [_d, "R_EFF_U", 0] call _hg;
    private _g = [_d, "G_EFF_U", 0] call _hg;

    private _wb = [_d, "W_BASE_U", 45] call _hg;
    private _rb = [_d, "R_BASE_U", 55] call _hg;
    private _gb = [_d, "G_BASE_U", 35] call _hg;

    // Locked constants (v1)
    _w = _w + (_wb - _w) * 0.0020;
    _r = _r + (_rb - _r) * 0.0010;
    _g = _g + (_gb - _g) * 0.0015;

    _d set ["W_EFF_U", (0 max (_w min 100))];
    _d set ["R_EFF_U", (0 max (_r min 100))];
    _d set ["G_EFF_U", (0 max (_g min 100))];
} forEach (keys _districts);

true

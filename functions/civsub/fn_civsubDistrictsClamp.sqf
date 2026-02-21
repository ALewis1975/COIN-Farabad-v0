/*
    ARC_fnc_civsubDistrictsClamp

    Clamps W/R/G effective values to 0..100.

    Params:
      0: districtState hashmap
*/

params [["_d", createHashMap, [createHashMap]]];
if !(_d isEqualType createHashMap) exitWith {false};

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

{
    private _v = [_d, _x, 0] call _hg;
    _d set [_x, (0 max (_v min 100))];
} forEach ["W_EFF_U","R_EFF_U","G_EFF_U","W_BASE_U","R_BASE_U","G_BASE_U","food_idx","water_idx","fear_idx"];

true

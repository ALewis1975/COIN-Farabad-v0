/*
    ARC_fnc_civsubDistrictsClamp

    Clamps W/R/G effective values to 0..100.

    Params:
      0: districtState hashmap
*/

private _d = if (_this isEqualType [] && { (count _this) > 0 }) then { _this select 0 } else { objNull };
if !(_d isEqualType createHashMap) exitWith {false};

private _hget = compile "params ['_h','_k']; (_h) get _k";

{
    private _v = [_d, _x] call _hget;
    if (isNil "_v") then { _v = 0; };
    if (!(_v isEqualType 0)) then { _v = 0; };
    _d set [_x, (0 max (_v min 100))];
} forEach ["W_EFF_U","R_EFF_U","G_EFF_U","W_BASE_U","R_BASE_U","G_BASE_U","food_idx","water_idx","fear_idx"];

true
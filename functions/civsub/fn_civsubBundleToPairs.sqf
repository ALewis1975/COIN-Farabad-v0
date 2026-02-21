/*

// sqflint-compat helpers
private _mapGet   = compile "params ['_h','_k']; _h get _k";
private _keysFn   = compile "params ['_m']; keys _m";
    ARC_fnc_civsubBundleToPairs

    Phase 5.5 helper: convert a HashMap (and nested HashMaps) into a
    stable array-of-pairs representation for debug console/log output.

    Params:
      0: value (any)

    Returns:
      value with HashMaps converted into [ [k,v], ... ] recursively
*/

private _v = _this param [0, nil];

if (_v isEqualType createHashMap) exitWith {
    private _out = [];
    {
        private _val = [_v, _x] call _mapGet;
        _out pushBack [_x, [_val] call ARC_fnc_civsubBundleToPairs];
    } forEach ([_v] call _keysFn);
    _out
};

if (_v isEqualType []) exitWith {
    _v apply { [_x] call ARC_fnc_civsubBundleToPairs }
};

_v

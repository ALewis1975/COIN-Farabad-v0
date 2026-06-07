/*
    ARC_fnc_cfgClassExists

    Memoized check for whether a class exists under a config root (default
    "CfgVehicles"). Config classes are static for the mission session, so the
    result is deterministic and safe to cache permanently — this avoids the
    repeated `isClass (configFile >> "CfgVehicles" >> _x)` engine lookups that
    the virtual-OpFor pool ran every tick when validating its unit-class list.

    Params:
      0: _class (String) — class name to test
      1: _root  (String, optional, default "CfgVehicles") — config root

    Returns:
      Bool — true when the class exists under the given root.
*/

params [["_class", "", [""]], ["_root", "CfgVehicles", [""]]];
if (_class isEqualTo "") exitWith { false };

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _cache = missionNamespace getVariable ["ARC_cfgClassExistsCache", createHashMap];
private _key = _root + ">>" + _class;

private _hit = [_cache, _key, -1] call _hg;
if (!(_hit isEqualTo -1)) exitWith { _hit };

private _exists = isClass (configFile >> _root >> _class);
_cache set [_key, _exists];
missionNamespace setVariable ["ARC_cfgClassExistsCache", _cache];

_exists

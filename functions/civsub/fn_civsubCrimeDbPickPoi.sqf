/*
    ARC_fnc_civsubCrimeDbPickPoi

    Picks a random POI id from the Crime DB.

    Params:
      0: wantHvt (bool, optional, default false)

    Returns: poi_id (string) or ""
*/

if (!isServer) exitWith {""};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {""};

params [["_wantHvt", false, [true]]];


// sqflint-compatible helpers
private _hg      = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _db = missionNamespace getVariable ["civsub_v1_crimedb", createHashMap];
if !(_db isEqualType createHashMap) exitWith {""};

private _keys = keys _db;
if ((count _keys) == 0) exitWith {""};

if (!_wantHvt) exitWith { _keys select (floor (random (count _keys))) };

private _hvts = _keys select {
    private _r = _db get _x;
    (_r isEqualType createHashMap) && { [_r, "is_hvt", false] call _hg }
};
if ((count _hvts) == 0) exitWith {""};
_hvts select (floor (random (count _hvts)))

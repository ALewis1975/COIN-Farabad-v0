/*
    ARC_fnc_civsubCrimeDbPickPoiForDistrict

    Picks a random POI id from the Crime DB scoped to a district.

    Params:
      0: districtId (string)
      1: wantHvt (bool, optional, default false)
      2: allowFallback (bool, optional, default false)  // if no match in district, fall back to global pool

    Returns: poi_id (string) or ""
*/

if (!isServer) exitWith {""};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {""};

params [
    ["_districtId", "", [""]],
    ["_wantHvt", false, [true]],
    ["_allowFallback", false, [true]]
];

if (_districtId isEqualTo "") exitWith {""};

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; [(_h), _k, _d] call _hg";
private _mapGet   = compile "params ['_h','_k']; _h get _k";
private _keysFn   = compile "params ['_m']; keys _m";

private _db = missionNamespace getVariable ["civsub_v1_crimedb", createHashMap];
if !(_db isEqualType createHashMap) exitWith {""};

private _keys = [_db] call _keysFn;
if ((count _keys) == 0) exitWith {""};

private _candidates = _keys select {
    private _r = [_db, _x] call _mapGet;
    (_r isEqualType createHashMap)
    && { ([_r, "homeDistrictId", ""] call _hg) isEqualTo _districtId }
    && { (!_wantHvt) || { [_r, "is_hvt", false] call _hg } }
};

if ((count _candidates) == 0) then {
    if (_allowFallback) exitWith {
        // Fall back to existing global picker for consistent behavior
        [_wantHvt] call ARC_fnc_civsubCrimeDbPickPoi
    };
    ""
} else {
    _candidates select (floor (random (count _candidates)))
};

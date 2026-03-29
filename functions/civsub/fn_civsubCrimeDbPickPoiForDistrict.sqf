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


// sqflint-compatible helpers
private _hg      = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
if (_districtId isEqualTo "") exitWith {""};

private _db = missionNamespace getVariable ["civsub_v1_crimedb", createHashMap];
if !(_db isEqualType createHashMap) exitWith {""};

private _keys = keys _db;
if ((count _keys) == 0) exitWith {""};

private _candidates = _keys select {
    private _r = _db get _x;
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

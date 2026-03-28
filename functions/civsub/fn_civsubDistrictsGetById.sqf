/*
    ARC_fnc_civsubDistrictsGetById

    Tolerant getter for civsub_v1_districts.
    - Accepts HashMap or legacy array-of-pairs store.
    - Tries key variants: exact, lower, upper.

    Params:
      0: districtId (string)

    Returns:
      districtState HashMap (or createHashMap if missing)
*/

params [["_districtId", "", ["", []]]];

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

if (_districtId isEqualType [] && {(count _districtId) == 1} && {(_districtId select 0) isEqualType ""}) then {
    _districtId = _districtId select 0;
};
if !(_districtId isEqualType "") exitWith {
    diag_log format ["[CIVSUB][WARN] DistrictsGetById invalid districtId type=%1 value=%2", typeName _districtId, _districtId];
    createHashMap
};
if (_districtId isEqualTo "") exitWith {createHashMap};

private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if (_districts isEqualType []) then { _districts = [_districts] call _hmCreate; };
if !(_districts isEqualType createHashMap) exitWith {createHashMap};

private _k1 = _districtId;
private _k2 = toLower _districtId;
private _k3 = toUpper _districtId;

private _d = [_districts, _k1, createHashMap] call _hg;
if (!(_d isEqualType createHashMap) || {(count _d) == 0}) then { _d = [_districts, _k2, createHashMap] call _hg; };
if (!(_d isEqualType createHashMap) || {(count _d) == 0}) then { _d = [_districts, _k3, createHashMap] call _hg; };

if !(_d isEqualType createHashMap) then { createHashMap } else { _d };


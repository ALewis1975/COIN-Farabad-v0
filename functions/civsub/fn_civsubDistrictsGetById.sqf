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

params [["_districtId", "", [""]]];
if (_districtId isEqualTo "") exitWith {createHashMap};

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; [(_h), _k, _d] call _hg";
private _hmFrom   = compile "params ['_pairs']; private _r = createHashMap; { _r set [_x select 0, _x select 1]; } forEach _pairs; _r";

private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if (_districts isEqualType []) then { _districts = [_districts] call _hmFrom; };
if !(_districts isEqualType createHashMap) exitWith {createHashMap};

private _k1 = _districtId;
private _k2 = toLower _districtId;
private _k3 = toUpper _districtId;

private _d = [_districts, _k1, createHashMap] call _hg;
if (!(_d isEqualType createHashMap) || {(count _d) == 0}) then { _d = [_districts, _k2, createHashMap] call _hg; };
if (!(_d isEqualType createHashMap) || {(count _d) == 0}) then { _d = [_districts, _k3, createHashMap] call _hg; };

if !(_d isEqualType createHashMap) then { createHashMap } else { _d };


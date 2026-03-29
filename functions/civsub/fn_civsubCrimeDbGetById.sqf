/*
    ARC_fnc_civsubCrimeDbGetById

    Params:
      0: poi_id (string)

    Returns: HashMap crime_record or empty HashMap
*/

if (!isServer) exitWith {createHashMap};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {createHashMap};

params [["_poiId", "", [""]]];

// sqflint-compatible helpers
private _hg      = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
if (_poiId isEqualTo "") exitWith {createHashMap};

private _db = missionNamespace getVariable ["civsub_v1_crimedb", createHashMap];
if !(_db isEqualType createHashMap) exitWith {createHashMap};

private _rec = [_db, _poiId, createHashMap] call _hg;
if !(_rec isEqualType createHashMap) exitWith {createHashMap};
_rec

/*
    ARC_fnc_civsubCrimeDbGetById

    Params:
      0: poi_id (string)

    Returns: HashMap crime_record or empty HashMap
*/

if (!isServer) exitWith {createHashMap};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {createHashMap};

params [["_poiId", "", [""]]];
if (_poiId isEqualTo "") exitWith {createHashMap};

private _db = missionNamespace getVariable ["civsub_v1_crimedb", createHashMap];
if !(_db isEqualType createHashMap) exitWith {createHashMap};

private _rec = _db getOrDefault [_poiId, createHashMap];
if !(_rec isEqualType createHashMap) exitWith {createHashMap};
_rec

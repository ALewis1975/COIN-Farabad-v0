/*
    ARC_fnc_civsubCrimeDbInit

    Phase 3: Ensure Crime DB exists and is seeded (30 POIs).

    Returns: bool
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

// sqflint-compat helpers
private _keysFn   = compile "params ['_m']; keys _m";

private _db = missionNamespace getVariable ["civsub_v1_crimedb", createHashMap];
if !(_db isEqualType createHashMap) then { _db = createHashMap; };

if ((count ([_db] call _keysFn)) == 0) then {
    _db = [] call ARC_fnc_civsubCrimeDbSeed;
    missionNamespace setVariable ["civsub_v1_crimedb", _db, true];
};

true

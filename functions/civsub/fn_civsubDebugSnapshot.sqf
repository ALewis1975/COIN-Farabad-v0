/*
    ARC_fnc_civsubDebugSnapshot

    Returns a small list of [key,value] pairs for ARC_pub_debug.
*/

if (!isServer) exitWith {[]};

// sqflint-compat helpers
private _keysFn   = compile "params ['_m']; keys _m";

private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
private _dc = 0;
if (_districts isEqualType createHashMap) then { _dc = count ([_districts] call _keysFn); };

[
    ["civsubEnabled", missionNamespace getVariable ["civsub_v1_enabled", false]],
    ["civsubDistrictCount", _dc],
    ["civsubLastTick_ts", missionNamespace getVariable ["civsub_v1_lastTick_ts", -1]],
    ["civsubLastSave_ts", missionNamespace getVariable ["civsub_v1_lastSave_ts", -1]],
    ["civsubLastDelta_id", missionNamespace getVariable ["civsub_v1_lastDelta_id", ""]]
]

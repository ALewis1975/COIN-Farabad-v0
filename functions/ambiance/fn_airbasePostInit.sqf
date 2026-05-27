/*
    AIRBASESUB v1 scaffold (server-only)

    Server bootstrap entrypoint.
    Waits for ARC bootstrap to create/load persistent state, then starts AIRBASESUB.

    Notes:
      - Server is single writer.
      - This function intentionally avoids touching initServer.sqf to reduce merge conflicts.
*/

if (!isServer) exitWith {
    diag_log "[ARC][AIRBASE][INIT] GUARD FAIL airbasePostInit not_server";
    false
};

if (!(["airbasePostInit"] call ARC_fnc_airbaseRuntimeEnabled)) exitWith {
    diag_log "[ARC][AIRBASE][INIT] GUARD FAIL airbase runtime disabled (airbasePostInit)";
    false
};

// Prevent duplicate init if postInit runs more than once (rare, but safe)
if (missionNamespace getVariable ["airbase_v1_postInit_ran", false]) exitWith {true};
missionNamespace setVariable ["airbase_v1_postInit_ran", true];

diag_log "[ARC][AIRBASE][INIT] airbasePostInit start";

private _ambianceEnabled = missionNamespace getVariable ["airbase_v1_ambiance_enabled", true];
if (!(_ambianceEnabled isEqualType true) && !(_ambianceEnabled isEqualType false)) then { _ambianceEnabled = true; };

if (!_ambianceEnabled) exitWith
{
    diag_log "[ARC][SAFE MODE] AIRBASESUB ambiance init skipped (airbase_v1_ambiance_enabled=false).";
    true
};

[] spawn
{
    // Wait until mission time has started and ARC has loaded state.
    waitUntil
    {
        (time > 0) && { !isNil { missionNamespace getVariable "ARC_state" } }
    };

    uiSleep 1;

    if (!isServer) exitWith {
        diag_log "[ARC][AIRBASE][INIT] GUARD FAIL delayed init thread lost server authority";
    };

    private _airbaseInitOk = [] call ARC_fnc_airbaseInit;

    // Start perimeter patrol ambience (editor-placed vehicles)
    private _securityInitOk = [] call ARC_fnc_airbaseSecurityInit;

    // Start ambient ground vehicle traffic (ORBAT-aligned vehicle pool)
    private _groundTrafficInitOk = [] call ARC_fnc_airbaseGroundTrafficInit;

    // Dynamically populate the 8 ORBAT layers that have no Eden-placed units
    private _orbatSpawnCount = [] call ARC_fnc_airbaseOrbatPopulate;
    diag_log format ["[ARC][AIRBASE][INIT] airbasePostInit post airbaseInit=%1 security=%2 groundTraffic=%3 orbatUnits=%4", _airbaseInitOk, _securityInitOk, _groundTrafficInitOk, _orbatSpawnCount];
};

true

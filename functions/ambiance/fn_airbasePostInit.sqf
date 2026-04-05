/*
    AIRBASESUB v1 scaffold (server-only)

    PostInit entrypoint.
    Waits for ARC bootstrap to create/load persistent state, then starts AIRBASESUB.

    Notes:
      - Server is single writer.
      - This function intentionally avoids touching initServer.sqf to reduce merge conflicts.
*/

if (!isServer) exitWith {false};

if (!(["airbasePostInit"] call ARC_fnc_airbaseRuntimeEnabled)) exitWith {false};

// Prevent duplicate init if postInit runs more than once (rare, but safe)
if (missionNamespace getVariable ["airbase_v1_postInit_ran", false]) exitWith {true};
missionNamespace setVariable ["airbase_v1_postInit_ran", true];

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

    [] call ARC_fnc_airbaseInit;

    // Start perimeter patrol ambience (editor-placed vehicles)
    [] call ARC_fnc_airbaseSecurityInit;

    // Start ambient ground vehicle traffic (ORBAT-aligned vehicle pool)
    [] call ARC_fnc_airbaseGroundTrafficInit;

    // Dynamically populate the 8 ORBAT layers that have no Eden-placed units
    [] call ARC_fnc_airbaseOrbatPopulate;
};

true

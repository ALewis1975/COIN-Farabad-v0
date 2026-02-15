/*
    AIRBASESUB v1 scaffold (server-only)

    PostInit entrypoint.
    Waits for ARC bootstrap to create/load persistent state, then starts AIRBASESUB.

    Notes:
      - Server is single writer.
      - This function intentionally avoids touching initServer.sqf to reduce merge conflicts.
*/

if (!isServer) exitWith {false};

// Prevent duplicate init if postInit runs more than once (rare, but safe)
if (missionNamespace getVariable ["airbase_v1_postInit_ran", false]) exitWith {true};
missionNamespace setVariable ["airbase_v1_postInit_ran", true];

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
};

true

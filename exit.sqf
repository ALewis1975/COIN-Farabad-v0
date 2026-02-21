/*
    COIN Farabad - exit.sqf

    Mission teardown / cleanup script.

    Called when the mission ends (via a trigger, `endMission`, or operator
    request). Runs on the SERVER only.

    Purpose:
      - Signal subsystems to stop their loops cleanly.
      - Flush any unsaved persistent state.
      - Log the shutdown event for post-session review.

    Authority: SERVER only.
    Do NOT rely on this file being called in a crash or forced-end scenario.
    Treat it as a best-effort graceful shutdown.
*/

if (!isServer) exitWith {};

diag_log "[ARC][INFO] exit.sqf: mission teardown starting.";

// ---------------------------------------------------------------------------
// Signal subsystems to stop their loops.
// Setting these flags causes any while{} loop that checks them to exit
// gracefully on the next iteration.
// ---------------------------------------------------------------------------
missionNamespace setVariable ["ARC_missionActive", false, false];

// ---------------------------------------------------------------------------
// Flush persistent state to missionProfileNamespace.
// Guard with !isNil in case the function was never compiled (safe-mode runs).
// ---------------------------------------------------------------------------
if (!isNil "ARC_fnc_stateSave") then
{
    [] call ARC_fnc_stateSave;
    diag_log "[ARC][INFO] exit.sqf: ARC_fnc_stateSave called.";
};

// ---------------------------------------------------------------------------
// CIVSUB state finalizer: flush district influence + civ identity to profile.
// ---------------------------------------------------------------------------
if (missionNamespace getVariable ["civsub_v1_persist", false]) then
{
    if (!isNil "ARC_fnc_civsubPersistSave") then
    {
        [] call ARC_fnc_civsubPersistSave;
        diag_log "[ARC][INFO] exit.sqf: CIVSUB persist save called.";
    };
};

// ---------------------------------------------------------------------------
// Generic cleanup hook (future: ARC_fnc_cleanup).
// ---------------------------------------------------------------------------
if (!isNil "ARC_fnc_cleanup") then
{
    [] call ARC_fnc_cleanup;
    diag_log "[ARC][INFO] exit.sqf: ARC_fnc_cleanup called.";
};

diag_log "[ARC][INFO] exit.sqf: mission teardown complete.";

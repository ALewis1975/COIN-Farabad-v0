/*
    Runs on server.
    Forces a save. Useful for admin / TOC operators.

    Phase 6:
      - Also forces CIVSUB persistence save (if enabled), so "Save World" includes CIVSUB.
*/

if (!isServer) exitWith {};

if (missionNamespace getVariable ["civsub_v1_enabled", false]) then
{
    // Best-effort: do not hard error if CIVSUB not initialized yet
    if (!isNil "ARC_fnc_civsubPersistSave") then { [] call ARC_fnc_civsubPersistSave; };
};

[] call ARC_fnc_stateSave;

/*
    ARC_fnc_prisonInit

    Server: initialise the Karkanak Prison overlay subsystem.

    Creates ARC_prisonState and starts the non-blocking prison tick loop
    (ARC_fnc_prisonTick). Must be called AFTER ARC_fnc_sitePopStateInit so that
    ARC_sitePopSiteStates is available on the first tick.

    State written (server missionNamespace, NOT replicated):
        ARC_prisonState (HASHMAP) — runtime overlay state for the active prison.

    ARC_prisonState schema:
        phase               STRING  — "DAY_OPERATIONS" | "LOCKDOWN" | "INCIDENT_LOCKDOWN"
        overlayState        STRING  — auxiliary overlay label ("" = none)
        prayerActive        BOOL    — true while a prayer window is active
        lastTickAt          NUMBER  — serverTime of last prisonTick iteration
        activeBreakoutGroups ARRAY  — handles of live hostile breakout GROUPs
        disorderActive      BOOL    — true while an internal disorder event is in progress

    Returns: BOOLEAN — true on success.
*/

if (!isServer) exitWith { false };

private _prisonState = createHashMap;
_prisonState set ["phase",                "DAY_OPERATIONS"];
_prisonState set ["overlayState",         ""];
_prisonState set ["prayerActive",         false];
_prisonState set ["lastTickAt",           -1];
_prisonState set ["activeBreakoutGroups", []];
_prisonState set ["disorderActive",       false];

missionNamespace setVariable ["ARC_prisonState", _prisonState];

// Spawn the non-blocking overlay tick loop.
[] spawn ARC_fnc_prisonTick;

diag_log "[ARC][PRISON][INFO] ARC_fnc_prisonInit: prison overlay subsystem started.";

true

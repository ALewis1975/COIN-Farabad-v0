/*
    ARC_fnc_uiConsoleActionRequestFollowOn

    Client: invoked from the console "FOLLOW-ON (via SITREP)" button.

    UI11+ workflow: standalone Follow-on requests were retired to avoid
    deadlocks and duplicate submissions. The follow-on payload is now
    captured inside the SITREP wizard, so this entry point only informs
    the player how to reach the new flow.

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

[
    "SITREP",
    "Follow-on requests are now collected as part of the SITREP submission flow. Use SEND SITREP to request a follow-on."
] call ARC_fnc_clientToast;

false

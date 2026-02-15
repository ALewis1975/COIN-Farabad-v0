/*
    ARC_fnc_uiConsoleActionWorkboardSecondary

    Client: Workboard secondary action.
      - Requests TOC follow-on (requires SITREP and no pending orders).
*/

if (!hasInterface) exitWith {false};

// Uses ARC_fnc_uiFollowOnPrompt; needs scheduled execution.
if (!canSuspend) exitWith { _this spawn ARC_fnc_uiConsoleActionWorkboardSecondary; false };

[] call ARC_fnc_uiConsoleActionRequestFollowOn;
true

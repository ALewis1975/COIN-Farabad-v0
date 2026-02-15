/*
    ARC_fnc_uiOpenSitrepScreen

    Legacy station entry point.
    UI09: opens the Farabad Console on the Operations (S3) tab.
*/
if (!hasInterface) exitWith {false};

uiNamespace setVariable ["ARC_console_forceTab", "OPS"];
[] call ARC_fnc_uiConsoleOpen;

true

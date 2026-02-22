/*
    ARC_fnc_uiOpenS1Screen

    Legacy/new station entry point.
    Opens the Farabad Console on the S-1 Personnel tab.
*/
if (!hasInterface) exitWith {false};

uiNamespace setVariable ["ARC_console_forceTab", "S1"];
[] call ARC_fnc_uiConsoleOpen;

true

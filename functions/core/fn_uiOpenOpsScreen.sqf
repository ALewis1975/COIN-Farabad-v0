/*
    ARC_fnc_uiOpenOpsScreen

    Legacy station entry point.
    UI09: repurposed to open the Farabad Console on the Command (TOC) tab.
*/
if (!hasInterface) exitWith {false};

uiNamespace setVariable ["ARC_console_forceTab", "CMD"];
[] call ARC_fnc_uiConsoleOpen;

true

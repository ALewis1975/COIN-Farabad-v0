/*
    ARC_fnc_uiOpenIntelScreen

    Legacy station entry point.
    UI09: opens the Farabad Console on the Intelligence (S2) tab.
*/
if (!hasInterface) exitWith {false};

uiNamespace setVariable ["ARC_console_forceTab", "INTEL"];
[] call ARC_fnc_uiConsoleOpen;

true

/*
    ARC_fnc_uiOpenAirScreen

    Tower station entry point.
    Opens the Farabad Console on the AIR / TOWER tab.
*/
if (!hasInterface) exitWith {false};

uiNamespace setVariable ["ARC_console_forceTab", "AIR"];
[] call ARC_fnc_uiConsoleOpen;

true

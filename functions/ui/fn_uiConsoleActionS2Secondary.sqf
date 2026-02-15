/*
    ARC_fnc_uiConsoleActionS2Secondary

    Client: opens the TOC queue manager (view or approve depending on role).
*/

if (!hasInterface) exitWith {false};

[] call ARC_fnc_uiConsoleActionOpenTocQueue;
true

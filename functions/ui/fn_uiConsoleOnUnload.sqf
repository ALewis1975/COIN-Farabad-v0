/*
    ARC_fnc_uiConsoleOnUnload

    Client: dialog onUnload for ARC_FarabadConsoleDialog.
*/

if (!hasInterface) exitWith {false};

uiNamespace setVariable ["ARC_console_refreshLoop", false];

// Clear state so a fresh open rebuilds everything cleanly
uiNamespace setVariable ["ARC_console_activeTab", nil];
uiNamespace setVariable ["ARC_console_tabIds", nil];

true

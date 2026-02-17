/*
    ARC_fnc_uiConsoleOnUnload

    Client: dialog onUnload for ARC_FarabadConsoleDialog.
*/

if (!hasInterface) exitWith {false};

// Stop refresh loop (Phase 2 rev-driven loop uses this as its shutdown flag)
uiNamespace setVariable ["ARC_console_refreshLoop", false];

// Best-effort: clear lifecycle guards/handles so open/close can't multiply handlers.
uiNamespace setVariable ["ARC_consoleHandlersAttached", false];
uiNamespace setVariable ["ARC_console_refreshHandle", nil];

// Clear VM tracking for a clean reopen.
uiNamespace setVariable ["ARC_consoleVM_lastRev", nil];
uiNamespace setVariable ["ARC_consoleVM_pendingRev", nil];
uiNamespace setVariable ["ARC_consoleVM_lastPaintAt", nil];
uiNamespace setVariable ["ARC_consoleVM_lastFallbackLogAt", nil];
uiNamespace setVariable ["ARC_consoleVM_lastIgnoreLogAt", nil];

diag_log format ["[FARABAD][v0][CONSOLE_VM][DETACH][%1] handlers detached", diag_tickTime];

// Clear state so a fresh open rebuilds everything cleanly
// Clear console-specific CIVSUB interaction context so INTEL returns to default tools mode.
uiNamespace setVariable ["ARC_civsubInteract_target", objNull];
uiNamespace setVariable ["ARC_civsubInteract_mode", "A"];
uiNamespace setVariable ["ARC_civsubInteract_lastPane", "A"];
uiNamespace setVariable ["ARC_civsubInteract_selectedQid", ""];
uiNamespace setVariable ["ARC_civsubInteract_snapshot", createHashMap];
uiNamespace setVariable ["ARC_civsubInteract_idCardHtml", ""];
uiNamespace setVariable ["ARC_civsubInteract_actionInProgress", false];
uiNamespace setVariable ["ARC_civsubInteract_hasUserOutput", false];
uiNamespace setVariable ["ARC_console_intelMode", "TOOLS"];
uiNamespace setVariable ["ARC_console_intelSelData", ""];

uiNamespace setVariable ["ARC_console_activeTab", nil];
uiNamespace setVariable ["ARC_console_tabIds", nil];

true

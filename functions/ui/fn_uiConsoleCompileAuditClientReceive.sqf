/*
    ARC_fnc_uiConsoleCompileAuditClientReceive

    Receives compile audit report (structured text string) from server and stores it for
    display in Headquarters tab.

    Params:
      0: report (STRING)
*/

if (!hasInterface) exitWith { false };

params [
    ["_report", "", [""]]
];

if (!(_report isEqualType "")) then { _report = ""; };

uiNamespace setVariable ["ARC_console_lastCompileReport", _report];

["HQ", "Compile audit complete. Open Headquarters tab -> Run Compile Audit to view the last report."] call ARC_fnc_clientToast;

// If console is open, refresh the current tab (best-effort)
[] call ARC_fnc_uiConsoleRefresh;

true

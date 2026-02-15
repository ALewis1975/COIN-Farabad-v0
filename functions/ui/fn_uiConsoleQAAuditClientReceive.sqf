/*
    ARC_fnc_uiConsoleQAAuditClientReceive

    Receives QA audit report (structured text string) from server and stores it for
    display in Headquarters tab.

    Params:
      0: report (STRING)
*/

if (!hasInterface) exitWith { false };

params [
    ["_report", "", [""]]
];

if (!(_report isEqualType "")) then { _report = ""; };

uiNamespace setVariable ["ARC_console_lastQAReport", _report];

["HQ", "Console QA audit complete. Open Headquarters tab -> Run Console QA Audit to view the last report."] call ARC_fnc_clientToast;

// If console is open, refresh the current tab (best-effort)
[] call ARC_fnc_uiConsoleRefresh;

true

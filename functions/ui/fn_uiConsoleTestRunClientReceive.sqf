/*
    ARC_fnc_uiConsoleTestRunClientReceive

    Receives ARC test-suite summary report (structured text string) from server
    and stores it for display in Headquarters tab.

    Params:
      0: report (STRING)
*/

if (!hasInterface) exitWith { false };

params [
    ["_report", "", [""]]
];

if (!(_report isEqualType "")) then { _report = ""; };

uiNamespace setVariable ["ARC_console_lastTestReport", _report];

["HQ", "ARC test suite report received. Open Headquarters tab -> Run SQF Test Suite to view the summary."] call ARC_fnc_clientToast;

// If console is open, refresh the current tab (best-effort)
[] call ARC_fnc_uiConsoleRefresh;

true

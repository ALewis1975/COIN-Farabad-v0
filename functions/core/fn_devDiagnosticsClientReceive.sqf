/*
    ARC_fnc_devDiagnosticsClientReceive

    Client-side receiver for diagnostics snapshot report.
    Stores the report for HQ console display and shows a hint.

    Params:
      0: STRING - HTML report from server
*/

if (!hasInterface) exitWith { false };

params [
    ["_report", "", [""]]
];

if (_report isEqualTo "") exitWith { false };

uiNamespace setVariable ["ARC_console_lastDiagReport", _report];

// Refresh the HQ details pane if the console is open
private _disp = findDisplay 78000;
if (!isNull _disp) then {
    [_disp, false] call ARC_fnc_uiConsoleHQPaint;
};

hintSilent "Diagnostics snapshot received. See HQ console for details.";

diag_log "[ARC][DIAG] Diagnostics snapshot received on client.";

true

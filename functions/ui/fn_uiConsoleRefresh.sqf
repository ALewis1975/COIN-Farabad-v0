/*
    ARC_fnc_uiConsoleRefresh

    Client: repaint ARC_FarabadConsoleDialog based on the active top-level tab.

    UI09 tab model:
      DASH      - Dashboard
      INTEL     - Intelligence (S2)
      OPS       - Operations (S3)
      HANDOFF   - Handoff (Intel/EPW)
      CMD       - Command (TOC)
      HQ        - Headquarters (Admin)

    Params:
      0: DISPLAY (optional; falls back to uiNamespace stored display)

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

params [
    ["_display", displayNull, [displayNull]]
];

if (isNull _display) then
{
    _display = uiNamespace getVariable ["ARC_console_display", displayNull];
};
if (isNull _display) exitWith {false};

private _ctrlMainGrp = _display displayCtrl 78015;
private _ctrlMain = _display displayCtrl 78010;
private _ctrlList = _display displayCtrl 78011;
private _ctrlDetailsGrp = _display displayCtrl 78016;
private _ctrlDetails = _display displayCtrl 78012;
private _b1 = _display displayCtrl 78021;
private _b2 = _display displayCtrl 78022;

// Ops frame controls
private _opsCtrls = [
    _display displayCtrl 78030,
    _display displayCtrl 78031,
    _display displayCtrl 78032,
    _display displayCtrl 78033,
    _display displayCtrl 78034,
    _display displayCtrl 78035,
    _display displayCtrl 78036,
    _display displayCtrl 78037,
    _display displayCtrl 78038
];

// Baseline: main panel on, everything else off
if (!isNull _ctrlMainGrp) then { _ctrlMainGrp ctrlShow true; };
if (!isNull _ctrlMain) then { _ctrlMain ctrlShow true; };
if (!isNull _ctrlList) then { _ctrlList ctrlShow false; };
if (!isNull _ctrlDetailsGrp) then { _ctrlDetailsGrp ctrlShow false; };
if (!isNull _ctrlDetails) then { _ctrlDetails ctrlShow false; };
{ if (!isNull _x) then { _x ctrlShow false; }; } forEach _opsCtrls;

// Baseline: hide S2 workflow controls (shown only on Intelligence tab)
private _s2Ctrls = [
    _display displayCtrl 78050,
    _display displayCtrl 78051,
    _display displayCtrl 78052,
    _display displayCtrl 78053,
    _display displayCtrl 78054,
    _display displayCtrl 78055
];
{ if (!isNull _x) then { _x ctrlShow false; }; } forEach _s2Ctrls;

// Baseline: hide action buttons
{ if (!isNull _x) then { _x ctrlShow false; _x ctrlEnable false; }; } forEach [_b1, _b2];

private _tab = uiNamespace getVariable ["ARC_console_activeTab", "DASH"];
if (!(_tab isEqualType "")) then { _tab = "DASH"; };
_tab = toUpper (trim _tab);

private _opsSecondaryLabel = "FOLLOW-ON (SITREP)";

switch (_tab) do
{
    case "BOARDS":
    {
        // Snapshot view (read-only)
        if (!isNull _b1) then { _b1 ctrlShow false; _b1 ctrlEnable false; _b1 ctrlSetText ""; };
        if (!isNull _b2) then { _b2 ctrlShow false; _b2 ctrlEnable false; _b2 ctrlSetText ""; };

        [_display] call ARC_fnc_uiConsoleBoardsPaint;
    };


case "DASH":
    {
        [_display] call ARC_fnc_uiConsoleDashboardPaint;
    };

    case "INTEL":
    {
        // List/details layout
        if (!isNull _ctrlMainGrp) then { _ctrlMainGrp ctrlShow false; };
        if (!isNull _ctrlMain) then { _ctrlMain ctrlShow false; };
        if (!isNull _ctrlList) then { _ctrlList ctrlShow true; };
        if (!isNull _ctrlDetailsGrp) then { _ctrlDetailsGrp ctrlShow true; };
        if (!isNull _ctrlDetails) then { _ctrlDetails ctrlShow true; };

        if (!isNull _b1) then { _b1 ctrlShow true; _b1 ctrlEnable true; _b1 ctrlSetText "EXECUTE"; };
        if (!isNull _b2) then { _b2 ctrlShow true; _b2 ctrlEnable true; _b2 ctrlSetText "TOC QUEUE"; };

        [_display, false] call ARC_fnc_uiConsoleIntelPaint;
    };

    case "OPS":
    {
        // Ops frame layout
        if (!isNull _ctrlMainGrp) then { _ctrlMainGrp ctrlShow false; };
        if (!isNull _ctrlMain) then { _ctrlMain ctrlShow false; };
        if (!isNull _ctrlList) then { _ctrlList ctrlShow false; };
        if (!isNull _ctrlDetailsGrp) then { _ctrlDetailsGrp ctrlShow true; };
        if (!isNull _ctrlDetails) then { _ctrlDetails ctrlShow true; };
        { if (!isNull _x) then { _x ctrlShow true; }; } forEach _opsCtrls;

        if (!isNull _b1) then { _b1 ctrlShow true; _b1 ctrlEnable true; _b1 ctrlSetText "ACTION"; };
        if (!isNull _b2) then { _b2 ctrlShow true; _b2 ctrlEnable false; _b2 ctrlSetText _opsSecondaryLabel; };

        [_display, true] call ARC_fnc_uiConsoleOpsPaint;
    };

    case "HANDOFF":
    {
        if (!isNull _b1) then { _b1 ctrlShow true; _b1 ctrlSetText "INTEL DEBRIEF"; };
        if (!isNull _b2) then { _b2 ctrlShow true; _b2 ctrlSetText "EPW PROCESS"; };
        [_display] call ARC_fnc_uiConsoleHandoffPaint;
    };

    case "CMD":
    {
        if (!isNull _b1) then { _b1 ctrlShow true; _b1 ctrlEnable true; _b1 ctrlSetText "QUEUE MGR"; };
        if (!isNull _b2) then
        {
            private _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""]; 
            if (!(_taskId isEqualType "")) then { _taskId = ""; };
            private _acc = missionNamespace getVariable ["ARC_activeIncidentAccepted", false];
            if (!(_acc isEqualType true) && !(_acc isEqualType false)) then { _acc = false; };
            private _lbl = if (_taskId isEqualTo "") then {"GENERATE"} else { if (!_acc) then {"ACCEPT"} else {"CLOSEOUT"} };
            _b2 ctrlShow true; _b2 ctrlEnable true; _b2 ctrlSetText _lbl;
        };
        [_display] call ARC_fnc_uiConsoleCommandPaint;
    };

    case "HQ":
    {
        // List/details layout
        if (!isNull _ctrlMainGrp) then { _ctrlMainGrp ctrlShow false; };
        if (!isNull _ctrlMain) then { _ctrlMain ctrlShow false; };
        if (!isNull _ctrlList) then { _ctrlList ctrlShow true; };
        if (!isNull _ctrlDetailsGrp) then { _ctrlDetailsGrp ctrlShow true; };
        if (!isNull _ctrlDetails) then { _ctrlDetails ctrlShow true; };

        if (!isNull _b1) then { _b1 ctrlShow true; _b1 ctrlEnable true; _b1 ctrlSetText "EXECUTE"; };
        // HQ normally uses the main list for admin actions.
        // Secondary is only shown when HQ is in INCIDENT PICKER mode.
        private _hqMode = uiNamespace getVariable ["ARC_console_hqMode", "TOOLS"];
        if (!(_hqMode isEqualType "")) then { _hqMode = "TOOLS"; };
        _hqMode = toUpper (trim _hqMode);
        private _showBack = (_hqMode isEqualTo "INCIDENTS");
        if (!isNull _b2) then { _b2 ctrlShow _showBack; _b2 ctrlEnable _showBack; _b2 ctrlSetText (if (_showBack) then {"BACK"} else {""}); };

        [_display, true] call ARC_fnc_uiConsoleHQPaint;
    };

    default
    {
        [_display] call ARC_fnc_uiConsoleDashboardPaint;
    };
};

true

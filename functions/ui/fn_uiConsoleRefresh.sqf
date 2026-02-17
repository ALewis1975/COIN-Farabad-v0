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


private _statusLeft = _display displayCtrl 78060;
private _statusCenter = _display displayCtrl 78061;
private _statusRight = _display displayCtrl 78062;
private _statusCtrl = _display displayCtrl 78063;

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

private _prevRefreshTab = uiNamespace getVariable ["ARC_console_prevRefreshTab", ""];
if (!(_prevRefreshTab isEqualType "")) then { _prevRefreshTab = ""; };

// ---------------------------------------------------------------------------

// Hide S2 category panels (if present) when leaving INTEL to prevent cross-tab UI leak.
private _s2CatPanels = uiNamespace getVariable ["ARC_s2_catPanels", []];
if (_tab != "INTEL" && { _s2CatPanels isEqualType [] }) then {
    {
        if (_x isEqualType [] && { (count _x) == 3 }) then {
            { if (!isNull _x) then { _x ctrlShow false; }; } forEach _x;
        };
    } forEach _s2CatPanels;
};

// Hide HQ stacked sub-panels (if present) unless HQ tab is active.
private _hqSubPanels = uiNamespace getVariable ["ARC_hq_subPanels", []];
if (_tab != "HQ" && { _hqSubPanels isEqualType [] }) then {
    {
        if (_x isEqualType [] && { (count _x) == 3 }) then {
            { if (!isNull _x) then { _x ctrlShow false; _x ctrlEnable false; }; } forEach _x;
        };
    } forEach _hqSubPanels;
};

// Regression guard: restore shared control positions when leaving S2/INTEL.
// S2 Intel paint may temporarily resize/reposition MainList and workflow controls.
// Other tabs must not inherit that layout.
// ---------------------------------------------------------------------------
private _s2Ctrls = [
    _display displayCtrl 78050,
    _display displayCtrl 78051,
    _display displayCtrl 78052,
    _display displayCtrl 78053,
    _display displayCtrl 78054,
    _display displayCtrl 78055
];

if (!isNull _ctrlList) then {
    private _kList = "ARC_ui_mainListPosDefault";
    private _p0 = uiNamespace getVariable [_kList, []];
    if (_p0 isEqualTo []) then {
        uiNamespace setVariable [_kList, ctrlPosition _ctrlList];
        _p0 = uiNamespace getVariable [_kList, ctrlPosition _ctrlList];
    };

    if (_tab != "INTEL") then {
        _ctrlList ctrlSetPosition _p0;
        _ctrlList ctrlCommit 0;
        { if (!isNull _x) then { _x ctrlShow false; }; } forEach _s2Ctrls;
    };
};

private _opsSecondaryLabel = "FOLLOW-ON (SITREP)";


private _atStation = [player] call ARC_fnc_uiConsoleIsAtStation;
private _netText = if (_atStation) then {"NET: TOC-LINK"} else {"NET: FIELD"};
if (!isNull _statusLeft) then { _statusLeft ctrlSetText _netText; };
private _cmdMode = uiNamespace getVariable ["ARC_console_cmdMode", "OVERVIEW"];
if (!(_cmdMode isEqualType "")) then { _cmdMode = "OVERVIEW"; };
_cmdMode = toUpper (trim _cmdMode);
private _modeText = if (_tab isEqualTo "CMD" && { _cmdMode isEqualTo "QUEUE" }) then { "MODE: CMD / QUEUE" } else { format ["MODE: %1", _tab] };
if (!isNull _statusCenter) then { _statusCenter ctrlSetText _modeText; };
private _timeText = daytime call BIS_fnc_timeToString;
if (!isNull _statusRight) then { _statusRight ctrlSetText format ["TIME: %1", _timeText]; };
if (!isNull _statusCtrl) then { _statusCtrl ctrlEnable false; };

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
        private _cmdMode = uiNamespace getVariable ["ARC_console_cmdMode", "OVERVIEW"];
        if (!(_cmdMode isEqualType "")) then { _cmdMode = "OVERVIEW"; };
        _cmdMode = toUpper (trim _cmdMode);

        if (_cmdMode isEqualTo "QUEUE") then
        {
            // Queue mode uses list/details layout in-console (no standalone dialog).
            if (!isNull _ctrlMainGrp) then { _ctrlMainGrp ctrlShow false; };
            if (!isNull _ctrlMain) then { _ctrlMain ctrlShow false; };
            if (!isNull _ctrlList) then { _ctrlList ctrlShow true; };
            if (!isNull _ctrlDetailsGrp) then { _ctrlDetailsGrp ctrlShow true; };
            if (!isNull _ctrlDetails) then { _ctrlDetails ctrlShow true; };

            private _forceQueueRebuild = (_prevRefreshTab isNotEqualTo _tab) || { uiNamespace getVariable ["ARC_console_cmdQueueForceRebuild", false] };
            uiNamespace setVariable ["ARC_console_cmdQueueForceRebuild", false];

            private _queueState = [_display, _forceQueueRebuild] call ARC_fnc_uiConsoleTocQueuePaint;
            private _selectedQid = "";
            private _selectedPending = false;
            if (_queueState isEqualType [] && { (count _queueState) >= 2 }) then
            {
                _selectedQid = _queueState # 0;
                _selectedPending = _queueState # 1;
            };
            uiNamespace setVariable ["ARC_console_cmdQueueSelectedQid", _selectedQid];
            uiNamespace setVariable ["ARC_console_cmdQueueSelectedPending", _selectedPending];

            private _canDecide = [player] call ARC_fnc_rolesCanApproveQueue;
            if (_canDecide && _selectedPending) then
            {
                if (!isNull _b1) then { _b1 ctrlShow true; _b1 ctrlEnable true; _b1 ctrlSetText "APPROVE"; };
                if (!isNull _b2) then { _b2 ctrlShow true; _b2 ctrlEnable true; _b2 ctrlSetText "REJECT"; };
            }
            else
            {
                if (!isNull _b1) then { _b1 ctrlShow true; _b1 ctrlEnable true; _b1 ctrlSetText "REFRESH"; };
                if (!isNull _b2) then { _b2 ctrlShow true; _b2 ctrlEnable true; _b2 ctrlSetText "BACK"; };
            };
        }
        else
        {
            if (!isNull _b1) then { _b1 ctrlShow true; _b1 ctrlEnable true; _b1 ctrlSetText "TOC QUEUE"; };
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
    };

    case "HQ":
    {
        // List/details layout
        if (!isNull _ctrlMainGrp) then { _ctrlMainGrp ctrlShow false; };
        if (!isNull _ctrlMain) then { _ctrlMain ctrlShow false; };
        if (!isNull _ctrlList) then { _ctrlList ctrlShow true; };
        if (!isNull _ctrlDetailsGrp) then { _ctrlDetailsGrp ctrlShow true; };
        if (!isNull _ctrlDetails) then { _ctrlDetails ctrlShow true; };

        // HQ button label ownership lives in ARC_fnc_uiConsoleHQPaint
        // so mode-specific text (EXECUTE/SPAWN) does not get stomped by refresh ticks.
        if (!isNull _b1) then { _b1 ctrlShow true; _b1 ctrlEnable true; };
        // HQ normally uses the main list for admin actions.
        // Secondary is only shown when HQ is in INCIDENT PICKER mode.
        private _hqMode = uiNamespace getVariable ["ARC_console_hqMode", "TOOLS"];
        if (!(_hqMode isEqualType "")) then { _hqMode = "TOOLS"; };
        _hqMode = toUpper (trim _hqMode);
        private _showBack = (_hqMode isEqualTo "INCIDENTS");
        if (!isNull _b2) then { _b2 ctrlShow _showBack; _b2 ctrlEnable _showBack; _b2 ctrlSetText (if (_showBack) then {"BACK"} else {""}); };

        private _rebuildHQ = false;
        private _prevHqMode = uiNamespace getVariable ["ARC_console_prevRefreshHQMode", ""];
        if (!(_prevHqMode isEqualType "")) then { _prevHqMode = ""; };

        if (_prevRefreshTab isNotEqualTo _tab) then { _rebuildHQ = true; };
        if (_prevHqMode isNotEqualTo _hqMode) then { _rebuildHQ = true; };

        if (uiNamespace getVariable ["ARC_console_incidentCatalogInvalidate", false]) then
        {
            _rebuildHQ = true;
            uiNamespace setVariable ["ARC_console_incidentCatalogInvalidate", false];
        };

        if (uiNamespace getVariable ["ARC_console_hqForceRebuild", false]) then
        {
            _rebuildHQ = true;
            uiNamespace setVariable ["ARC_console_hqForceRebuild", false];
        };

        uiNamespace setVariable ["ARC_console_prevRefreshHQMode", _hqMode];

        [_display, _rebuildHQ] call ARC_fnc_uiConsoleHQPaint;
    };

    default
    {
        [_display] call ARC_fnc_uiConsoleDashboardPaint;
    };
};

uiNamespace setVariable ["ARC_console_prevRefreshTab", _tab];

true

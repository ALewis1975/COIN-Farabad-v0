/*
    ARC_fnc_uiConsoleRefresh

    Client: repaint ARC_FarabadConsoleDialog based on the active top-level tab.

    UI09 tab model:
      DASH      - Dashboard
      INTEL     - Intelligence (S2)
      OPS       - Operations (S3)
      AIR       - Airbase snapshot + tower controls
      HANDOFF   - Handoff (Intel/EPW)
      CMD       - Command (TOC)
      HQ        - Headquarters (Admin)
      S1        - Personnel registry (S-1)

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

private _tab = ["ARC_console_activeTab", "DASH"] call ARC_fnc_uiNsGetString;
_tab = toUpper _tab;

private _prevRefreshTab = ["ARC_console_prevRefreshTab", "", false] call ARC_fnc_uiNsGetString;

// ---------------------------------------------------------------------------

// Hide S2 category panels (if present) when leaving INTEL to prevent cross-tab UI leak.
private _s2CatPanels = ["ARC_s2_catPanels", []] call ARC_fnc_uiNsGetArray;
if (_tab != "INTEL" && { _s2CatPanels isEqualType [] }) then {
    {
        if (_x isEqualType [] && { (count _x) == 3 }) then {
            { if (!isNull _x) then { _x ctrlShow false; }; } forEach _x;
        };
    } forEach _s2CatPanels;
};

// Hide HQ stacked sub-panels (if present) unless HQ tab is active.
private _hqSubPanels = ["ARC_hq_subPanels", []] call ARC_fnc_uiNsGetArray;
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
if (!isNull _ctrlList) then {
    private _kList = "ARC_ui_mainListPosDefault";
    private _p0 = [_kList, []] call ARC_fnc_uiNsGetArray;
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
private _cmdMode = ["ARC_console_cmdMode", "OVERVIEW"] call ARC_fnc_uiNsGetString;
_cmdMode = toUpper _cmdMode;
private _modeText = if (_tab isEqualTo "CMD" && { _cmdMode isEqualTo "QUEUE" }) then { "MODE: CMD / QUEUE" } else { format ["MODE: %1", _tab] };
if (!isNull _statusCenter) then { _statusCenter ctrlSetText _modeText; };
private _timeText = daytime call BIS_fnc_timeToString;
if (!isNull _statusRight) then { _statusRight ctrlSetText format ["TIME: %1", _timeText]; };
if (!isNull _statusCtrl) then { _statusCtrl ctrlEnable false; };

// Regression guard: restore MainGroup (78015) to its full-width default whenever we are NOT
// in CMD OVERVIEW mode.  CMD OVERVIEW narrows the group to the middle-panel width so that its
// structured-text content (which includes the "TOC Queue" section) does not visually overlap
// with MainDetailsGroup (78016) at the panel boundary.
if (!isNull _ctrlMainGrp) then {
    private _kMainGrp = "ARC_ui_mainGrpPosDefault";
    private _p0Grp = [_kMainGrp, []] call ARC_fnc_uiNsGetArray;
    if (_p0Grp isEqualTo []) then {
        uiNamespace setVariable [_kMainGrp, ctrlPosition _ctrlMainGrp];
        _p0Grp = uiNamespace getVariable [_kMainGrp, ctrlPosition _ctrlMainGrp];
    };
    if (!(_tab isEqualTo "CMD" && { _cmdMode isEqualTo "OVERVIEW" })) then {
        _ctrlMainGrp ctrlSetPosition _p0Grp;
        _ctrlMainGrp ctrlCommit 0;
    };
};

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
        // Show right details panel (populated by the painter).
        if (!isNull _ctrlDetailsGrp) then { _ctrlDetailsGrp ctrlShow true; };
        if (!isNull _ctrlDetails) then { _ctrlDetails ctrlShow true; };
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


    case "AIR":
    {
        // List/details layout
        if (!isNull _ctrlMainGrp) then { _ctrlMainGrp ctrlShow false; };
        if (!isNull _ctrlMain) then { _ctrlMain ctrlShow false; };
        if (!isNull _ctrlList) then { _ctrlList ctrlShow true; };
        if (!isNull _ctrlDetailsGrp) then { _ctrlDetailsGrp ctrlShow true; };
        if (!isNull _ctrlDetails) then { _ctrlDetails ctrlShow true; };

        private _canAirHoldRelease = ["ARC_console_airCanHoldRelease", false] call ARC_fnc_uiNsGetBool;
        private _canAirQueueManage = ["ARC_console_airCanQueueManage", false] call ARC_fnc_uiNsGetBool;
        private _canAirStaff = ["ARC_console_airCanStaff", false] call ARC_fnc_uiNsGetBool;
        private _canAirRead = ["ARC_console_airCanRead", false] call ARC_fnc_uiNsGetBool;
        private _canAirPilot = ["ARC_console_airCanPilot", false] call ARC_fnc_uiNsGetBool;
        private _canAirControl = _canAirHoldRelease || _canAirQueueManage || _canAirStaff;

        private _airMode = ["ARC_console_airMode", if (_canAirPilot && !_canAirControl) then {"PILOT"} else {"TOWER"}] call ARC_fnc_uiNsGetString;
        _airMode = toUpper _airMode;
        _airMode = (_airMode splitString " ") joinString "";
        if !(_airMode in ["TOWER", "PILOT"]) then { _airMode = if (_canAirPilot && !_canAirControl) then {"PILOT"} else {"TOWER"}; };
        uiNamespace setVariable ["ARC_console_airMode", _airMode];

        if (!isNull _b1) then {
            _b1 ctrlShow true;
            if (_airMode isEqualTo "PILOT") then {
                _b1 ctrlEnable _canAirPilot;
                _b1 ctrlSetText (if (_canAirPilot) then {"SEND REQUEST"} else {"NO PILOT AUTH"});
            } else {
                _b1 ctrlEnable _canAirHoldRelease;
                _b1 ctrlSetText (if (_canAirHoldRelease) then {"HOLD/RELEASE"} else {"NO HOLD AUTH"});
            };
        };
        if (!isNull _b2) then {
            _b2 ctrlShow true;
            if (_airMode isEqualTo "PILOT") then {
                _b2 ctrlEnable (_canAirPilot || _canAirControl);
                _b2 ctrlSetText (if (_canAirControl) then {"MODE: TOWER"} else {"REFRESH"});
            } else {
                _b2 ctrlEnable _canAirQueueManage;
                _b2 ctrlSetText (if (_canAirQueueManage) then {"EXPEDITE/CANCEL"} else {"NO QUEUE AUTH"});
            };
        };

        if (!_canAirRead && !_canAirControl && !_canAirPilot) then
        {
            if (!isNull _b1) then { _b1 ctrlEnable false; _b1 ctrlSetText "NO ACCESS"; };
            if (!isNull _b2) then { _b2 ctrlEnable false; _b2 ctrlSetText "NO ACCESS"; };
        };

        [_display, false] call ARC_fnc_uiConsoleAirPaint;
    };
    case "HANDOFF":
    {
        if (!isNull _b1) then { _b1 ctrlShow true; _b1 ctrlSetText "INTEL DEBRIEF"; };
        if (!isNull _b2) then { _b2 ctrlShow true; _b2 ctrlSetText "EPW PROCESS"; };
        [_display] call ARC_fnc_uiConsoleHandoffPaint;
    };

    case "CMD":
    {
        private _cmdMode = ["ARC_console_cmdMode", "OVERVIEW"] call ARC_fnc_uiNsGetString;
        _cmdMode = toUpper _cmdMode;

        if (_cmdMode isEqualTo "QUEUE") then
        {
            // Queue mode uses list/details layout in-console (no standalone dialog).
            if (!isNull _ctrlMainGrp) then { _ctrlMainGrp ctrlShow false; };
            if (!isNull _ctrlMain) then { _ctrlMain ctrlShow false; };
            if (!isNull _ctrlList) then { _ctrlList ctrlShow true; };
            if (!isNull _ctrlDetailsGrp) then { _ctrlDetailsGrp ctrlShow true; };
            if (!isNull _ctrlDetails) then { _ctrlDetails ctrlShow true; };

            private _forceQueueRebuild = (_prevRefreshTab != _tab) || { ["ARC_console_cmdQueueForceRebuild", false] call ARC_fnc_uiNsGetBool };
            uiNamespace setVariable ["ARC_console_cmdQueueForceRebuild", false];

            private _queueState = [_display, _forceQueueRebuild] call ARC_fnc_uiConsoleTocQueuePaint;
            private _selectedQid = "";
            private _selectedPending = false;
            if (_queueState isEqualType [] && { (count _queueState) >= 2 }) then
            {
                _selectedQid = _queueState select 0;
                _selectedPending = _queueState select 1;
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
            // Show right panel (populated by the painter).
            if (!isNull _ctrlDetailsGrp) then { _ctrlDetailsGrp ctrlShow true; };
            if (!isNull _ctrlDetails) then { _ctrlDetails ctrlShow true; };

            // Clamp MainGroup (78015) to the middle-panel width so its content (including
            // the TOC Queue section) does not extend into the right-panel area occupied by
            // MainDetailsGroup (78016).  Use MainList (78011) as the middle-panel reference.
            if (!isNull _ctrlMainGrp && { !isNull _ctrlList }) then {
                private _lp = ctrlPosition _ctrlList;
                private _gp = ctrlPosition _ctrlMainGrp;
                if ((count _lp) == 4 && { (count _gp) == 4 }) then {
                    _ctrlMainGrp ctrlSetPosition [_lp select 0, _gp select 1, _lp select 2, _gp select 3];
                    _ctrlMainGrp ctrlCommit 0;
                };
            };

            [_display] call ARC_fnc_uiConsoleCommandPaint;
        };
    };


    case "S1":
    {
        // Read-only list/details layout
        if (!isNull _ctrlMainGrp) then { _ctrlMainGrp ctrlShow false; };
        if (!isNull _ctrlMain) then { _ctrlMain ctrlShow true; };
        if (!isNull _ctrlList) then { _ctrlList ctrlShow true; };
        if (!isNull _ctrlDetailsGrp) then { _ctrlDetailsGrp ctrlShow true; };
        if (!isNull _ctrlDetails) then { _ctrlDetails ctrlShow true; };

        if (!isNull _b1) then { _b1 ctrlShow true; _b1 ctrlEnable true; _b1 ctrlSetText "REFRESH"; };
        if (!isNull _b2) then { _b2 ctrlShow true; _b2 ctrlEnable false; _b2 ctrlSetText "READ-ONLY"; };

        [_display] call ARC_fnc_uiConsoleS1Paint;
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
        private _hqMode = ["ARC_console_hqMode", "TOOLS"] call ARC_fnc_uiNsGetString;
        _hqMode = toUpper _hqMode;
        private _showBack = (_hqMode isEqualTo "INCIDENTS");
        if (!isNull _b2) then { _b2 ctrlShow _showBack; _b2 ctrlEnable _showBack; _b2 ctrlSetText (if (_showBack) then {"BACK"} else {""}); };

        private _rebuildHQ = false;
        private _prevHqMode = ["ARC_console_prevRefreshHQMode", "", false] call ARC_fnc_uiNsGetString;

        if (_prevRefreshTab != _tab) then { _rebuildHQ = true; };
        if (_prevHqMode != _hqMode) then { _rebuildHQ = true; };

        if (["ARC_console_incidentCatalogInvalidate", false] call ARC_fnc_uiNsGetBool) then
        {
            _rebuildHQ = true;
            uiNamespace setVariable ["ARC_console_incidentCatalogInvalidate", false];
        };

        if (["ARC_console_hqForceRebuild", false] call ARC_fnc_uiNsGetBool) then
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

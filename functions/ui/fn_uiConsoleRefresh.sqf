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
private _ctrlTabs = _display displayCtrl 78001;


private _statusNet  = _display displayCtrl 78060;
private _statusGps  = _display displayCtrl 78061;
private _statusBatt = _display displayCtrl 78062;
private _statusSync = _display displayCtrl 78063;

private _ctrlState = {
    params ["_ctrl"];
    if (isNull _ctrl) exitWith { [false, false, []] };
    [ctrlShown _ctrl, ctrlEnabled _ctrl, ctrlPosition _ctrl]
};

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

// Baseline: main panel on, everything else off.
// Re-enable shared controls here so tabs that temporarily disable the shared
// MainList as a hidden master (INTEL/HQ tool modes) cannot leak disabled state
// into list-driven tabs after a tab switch.
if (!isNull _ctrlTabs) then { _ctrlTabs ctrlShow true; _ctrlTabs ctrlEnable true; };
if (!isNull _ctrlMainGrp) then { _ctrlMainGrp ctrlShow true; _ctrlMainGrp ctrlEnable true; };
if (!isNull _ctrlMain) then { _ctrlMain ctrlShow true; _ctrlMain ctrlEnable true; };
if (!isNull _ctrlList) then { _ctrlList ctrlShow false; _ctrlList ctrlEnable true; };
if (!isNull _ctrlDetailsGrp) then { _ctrlDetailsGrp ctrlShow false; _ctrlDetailsGrp ctrlEnable true; };
if (!isNull _ctrlDetails) then { _ctrlDetails ctrlShow false; _ctrlDetails ctrlEnable true; };
{ if (!isNull _x) then { _x ctrlShow false; }; } forEach _opsCtrls;

// Baseline: hide AIR / TOWER dedicated controls (shown only on AIR tab)
private _airStripGroup = _display displayCtrl 78130;
private _airDecisionBand = _display displayCtrl 78136;
private _airTrafficMap = _display displayCtrl 78137;
private _airDedicatedCtrls = [_airStripGroup, _airDecisionBand, _airTrafficMap];
{ if (!isNull _x) then { _x ctrlShow false; }; } forEach _airDedicatedCtrls;

// Baseline: hide Region C Visual Panel (shown only when tab declares useVisualPanel)
private _visualPanel = _display displayCtrl 78140;
if (!isNull _visualPanel) then { _visualPanel ctrlShow false; };

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
// Shared tab-difference flag drives both diagnostics/refresh forcing and
// stale-state cleanup; cleanup intentionally excludes the first empty->tab pass.
private _tabDiffers = !(_prevRefreshTab isEqualTo _tab);
// Exclude initial empty -> first tab from stale-state cleanup; include it in tab-entry diagnostics.
private _tabChanged = !(_prevRefreshTab isEqualTo "") && { _tabDiffers };

if (_tabChanged) then
{
    uiNamespace setVariable ["ARC_console_mainListOwner", ""];
    uiNamespace setVariable ["ARC_s2_catPanels_suppressSel", false];
    uiNamespace setVariable ["ARC_hq_subPanels_suppressSel", false];
    uiNamespace setVariable ["ARC_console_cmdQueuePainting", false];
};

if (_tabDiffers) then
{
    diag_log format [
        "[ARC][UI] ARC_fnc_uiConsoleRefresh: tab enter prev=%1 tab=%2 tabs=%3 main=%4 list=%5 details=%6",
        _prevRefreshTab,
        _tab,
        [_ctrlTabs] call _ctrlState,
        [_ctrlMainGrp] call _ctrlState,
        [_ctrlList] call _ctrlState,
        [_ctrlDetailsGrp] call _ctrlState
    ];
};

// Phase 4: clear AIR confirmation state when switching away from AIR tab.
if (_tab != "AIR") then {
    uiNamespace setVariable ["ARC_console_airConfirmPending", ""];
    uiNamespace setVariable ["ARC_console_airConfirmLabel", ""];
    uiNamespace setVariable ["ARC_console_airConfirmRid", ""];
    uiNamespace setVariable ["ARC_console_airConfirmFid", ""];
    // Phase 7: reset map initialization flag so it re-centers on next AIR tab entry.
    uiNamespace setVariable ["ARC_console_airMapInitialized", false];
    // Phase 7: clean up map markers when leaving AIR tab.
    private _mapMarkers = uiNamespace getVariable ["ARC_console_airMapMarkers", []];
    if (_mapMarkers isEqualType []) then {
        { if (_x isEqualType "") then { deleteMarkerLocal _x; }; } forEach _mapMarkers;
    };
    uiNamespace setVariable ["ARC_console_airMapMarkers", []];
};

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


// TSH-INC1: Top status strip — four indicators (NET / GPS / BATT / SYNC).
// NET: network link type (TOC terminal or field).
private _atStation = [player] call ARC_fnc_uiConsoleIsAtStation;
private _netText = if (_atStation) then {"NET: TOC-LINK"} else {"NET: FIELD"};
if (!isNull _statusNet) then { _statusNet ctrlSetText _netText; };

// GPS: display-only, always active in this increment.
if (!isNull _statusGps) then { _statusGps ctrlSetText "GPS: ACTIVE"; };

// BATT: display-only, shows OK in this increment.
if (!isNull _statusBatt) then { _statusBatt ctrlSetText "BATT: OK"; };

// SYNC: live if mission pub-state is available; otherwise indicates no sync.
private _hasPubState = !isNil { missionNamespace getVariable "ARC_pub_state" };
private _syncText = if (_hasPubState) then {"SYNC: LIVE"} else {"SYNC: --"};
if (!isNull _statusSync) then { _statusSync ctrlSetText _syncText; };

private _cmdMode = ["ARC_console_cmdMode", "OVERVIEW"] call ARC_fnc_uiNsGetString;
_cmdMode = toUpper _cmdMode;

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

// Re-apply layout with the current tab so the correct center/right split ratio
// is used (equal-width for DASH/BOARDS/OPS/CMD/HQ; default 47/53 for others).
// This runs after the regression guards so it wins over any stale restored positions.
[_display, _tab] call ARC_fnc_uiConsoleApplyLayout;

private _clampMainGroupToListRegion = {
    // Clamp MainGroup (78015) to the center/list region so structured text
    // tabs with a visible right details pane cannot overlap MainDetailsGroup.
    // Uses outer-scope _ctrlMainGrp/_ctrlList; returns true on successful
    // reposition and false when required controls/positions are unavailable.
    if (isNull _ctrlMainGrp || { isNull _ctrlList }) exitWith { false };

    private _lp = ctrlPosition _ctrlList;
    private _gp = ctrlPosition _ctrlMainGrp;
    if (!(_lp isEqualType []) || { !(_gp isEqualType []) }) exitWith { false };
    if ((count _lp) != 4 || { (count _gp) != 4 }) exitWith { false };

    _ctrlMainGrp ctrlSetPosition [_lp select 0, _gp select 1, _lp select 2, _gp select 3];
    _ctrlMainGrp ctrlCommit 0;
    true
};

private _auditLayout = {
    if (!(missionNamespace getVariable ["ARC_console_layout_audit", false])) exitWith { true };

    private _failures = [];
    private _overlaps = {
        params ["_a", "_b"];
        if (!(_a isEqualType []) || { !(_b isEqualType []) }) exitWith { false };
        if ((count _a) != 4 || { (count _b) != 4 }) exitWith { false };
        private _ax1 = _a select 0;
        private _ay1 = _a select 1;
        private _ax2 = _ax1 + (_a select 2);
        private _ay2 = _ay1 + (_a select 3);
        private _bx1 = _b select 0;
        private _by1 = _b select 1;
        private _bx2 = _bx1 + (_b select 2);
        private _by2 = _by1 + (_b select 3);
        (_ax1 < _bx2) && { _ax2 > _bx1 } && { _ay1 < _by2 } && { _ay2 > _by1 }
    };

    private _addOverlap = {
        params ["_labelA", "_ctrlA", "_labelB", "_ctrlB"];
        if (isNull _ctrlA || { isNull _ctrlB }) exitWith {};
        if (!(ctrlShown _ctrlA) || { !(ctrlShown _ctrlB) }) exitWith {};
        if ([ctrlPosition _ctrlA, ctrlPosition _ctrlB] call _overlaps) then {
            _failures pushBack format ["overlap %1/%2 a=%3 b=%4", _labelA, _labelB, ctrlPosition _ctrlA, ctrlPosition _ctrlB];
        };
    };

    ["MainGroup", _ctrlMainGrp, "DetailsGroup", _ctrlDetailsGrp] call _addOverlap;
    ["MainList", _ctrlList, "DetailsGroup", _ctrlDetailsGrp] call _addOverlap;
    ["AirMap", _airTrafficMap, "DetailsGroup", _ctrlDetailsGrp] call _addOverlap;
    if (_tab isEqualTo "AIR") then {
        ["AirStatusStrip", _airStripGroup, "MainList", _ctrlList] call _addOverlap;
        ["AirDecisionBand", _airDecisionBand, "MainList", _ctrlList] call _addOverlap;
        ["AirMap", _airTrafficMap, "MainList", _ctrlList] call _addOverlap;
    };

    if ((count _failures) > 0) then
    {
        diag_log format ["[ARC][UI][CONSOLE_LAYOUT_AUDIT_FAIL] tab=%1 failures=%2", _tab, _failures];
    }
    else
    {
        diag_log format ["[ARC][UI][CONSOLE_LAYOUT_AUDIT_OK] tab=%1 main=%2 list=%3 details=%4 map=%5", _tab, ctrlPosition _ctrlMainGrp, ctrlPosition _ctrlList, ctrlPosition _ctrlDetailsGrp, ctrlPosition _airTrafficMap];
    };

    (count _failures) isEqualTo 0
};

switch (_tab) do
{
    case "BOARDS":
    {
        // Snapshot view (read-only)
        if (!isNull _b1) then { _b1 ctrlShow false; _b1 ctrlEnable false; _b1 ctrlSetText ""; };
        if (!isNull _b2) then { _b2 ctrlShow false; _b2 ctrlEnable false; _b2 ctrlSetText ""; };
        call _clampMainGroupToListRegion;

        [_display] call ARC_fnc_uiConsoleBoardsPaint;
    };


case "DASH":
    {
        // Show right details panel (populated by the painter).
        if (!isNull _ctrlDetailsGrp) then { _ctrlDetailsGrp ctrlShow true; };
        if (!isNull _ctrlDetails) then { _ctrlDetails ctrlShow true; };
        call _clampMainGroupToListRegion;
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

        [_b1, "EXECUTE", true, true] call ARC_fnc_uiConsoleButtonState;
        [_b2, "TOC QUEUE", true, true] call ARC_fnc_uiConsoleButtonState;

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

        [_b1, "ACTION", true, true] call ARC_fnc_uiConsoleButtonState;
        [_b2, _opsSecondaryLabel, false, true] call ARC_fnc_uiConsoleButtonState;

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

        // Show AIR-dedicated controls (Phase 1 scaffold)
        { if (!isNull _x) then { _x ctrlShow true; }; } forEach _airDedicatedCtrls;

        private _canAirHoldRelease = ["ARC_console_airCanHoldRelease", false] call ARC_fnc_uiNsGetBool;
        private _canAirQueueManage = ["ARC_console_airCanQueueManage", false] call ARC_fnc_uiNsGetBool;
        private _canAirStaff = ["ARC_console_airCanStaff", false] call ARC_fnc_uiNsGetBool;
        private _canAirRead = ["ARC_console_airCanRead", false] call ARC_fnc_uiNsGetBool;
        private _canAirPilot = ["ARC_console_airCanPilot", false] call ARC_fnc_uiNsGetBool;
        private _canAirControl = _canAirHoldRelease || _canAirQueueManage || _canAirStaff;
        private _debugAir = missionNamespace getVariable ["ARC_debugInspectorEnabled", false];
        if (!(_debugAir isEqualType true) && !(_debugAir isEqualType false)) then { _debugAir = false; };

        private _airMode = ["ARC_console_airMode", if (_canAirPilot && !_canAirControl) then {"PILOT"} else {"TOWER"}] call ARC_fnc_uiNsGetString;
        _airMode = toUpper _airMode;
        _airMode = (_airMode splitString " ") joinString "";
        if !(_airMode in ["TOWER", "PILOT"]) then { _airMode = if (_canAirPilot && !_canAirControl) then {"PILOT"} else {"TOWER"}; };
        uiNamespace setVariable ["ARC_console_airMode", _airMode];

        private _airSubmode = ["ARC_console_airSubmode", "AIRFIELD_OPS"] call ARC_fnc_uiNsGetString;
        _airSubmode = toUpper _airSubmode;
        _airSubmode = (_airSubmode splitString " ") joinString "";
        if !(_airSubmode in ["AIRFIELD_OPS", "CLEARANCES", "DEBUG"]) then { _airSubmode = "AIRFIELD_OPS"; };
        if (!_canAirControl && { _airSubmode isEqualTo "CLEARANCES" }) then { _airSubmode = "AIRFIELD_OPS"; };
        if (!_debugAir && { _airSubmode isEqualTo "DEBUG" }) then { _airSubmode = "AIRFIELD_OPS"; };
        uiNamespace setVariable ["ARC_console_airSubmode", _airSubmode];
        private _layoutModeActive = uiNamespace getVariable ["ARC_console_layoutModeActive", "FULL"];

        // AIRFIELD_OPS runtime layout pass:
        // chips + decision band above the board, map in dedicated Region C.
        if (!isNull _ctrlList && { !isNull _ctrlDetailsGrp } && { !isNull _airStripGroup } && { !isNull _airDecisionBand }) then
        {
            private _AIR_MIN_PANE_H = safeZoneH * 0.10;
            private _AIR_PAD_Y = safeZoneH * 0.004;
            private _AIR_STRIP_H_FRAC = 0.08;
            private _AIR_STRIP_H_MIN = safeZoneH * 0.024;
            private _AIR_BAND_H_FRAC = 0.06;
            private _AIR_BAND_H_MIN = safeZoneH * 0.020;
            private _AIR_BOARD_H_MIN = safeZoneH * 0.08;
            private _AIR_MAP_PAD = safeZoneH * 0.004;
            private _AIR_MAP_MIN_W = safeZoneW * 0.12;
            private _AIR_MAP_MIN_H = safeZoneH * 0.08;
            private _AIR_MAP_REGION_FRAC = 0.42;

            private _listP = ctrlPosition _ctrlList;
            private _detailsP = ctrlPosition _ctrlDetailsGrp;
            private _paneX = _listP select 0;
            private _paneY = _listP select 1;
            private _paneW = ((_detailsP select 0) + (_detailsP select 2)) - _paneX;
            private _paneH = ((_listP select 3) max (_detailsP select 3)) max _AIR_MIN_PANE_H;
            private _stripH = (_paneH * _AIR_STRIP_H_FRAC) max _AIR_STRIP_H_MIN;
            private _bandH = (_paneH * _AIR_BAND_H_FRAC) max _AIR_BAND_H_MIN;
            private _boardY = _paneY + _stripH + _AIR_PAD_Y + _bandH + _AIR_PAD_Y;
            private _boardH = ((_paneY + _paneH) - _boardY) max _AIR_BOARD_H_MIN;
            private _regionCX = _paneX;
            private _regionCY = _boardY + _boardH;
            private _regionCW = _paneW;
            private _regionCH = 0;
            if (_layoutModeActive isEqualTo "DOCK_RIGHT") then {
                _regionCX = uiNamespace getVariable ["ARC_console_regionCX", _paneX];
                _regionCY = uiNamespace getVariable ["ARC_console_regionCY", _boardY + _boardH];
                _regionCW = uiNamespace getVariable ["ARC_console_regionCW", _paneW];
                _regionCH = uiNamespace getVariable ["ARC_console_regionCH", 0];
            };

            // FULL layout does not activate Region C, so reserve a local bottom
            // pane to keep the CT_MAP from using its config-time detail overlay.
            if (_regionCH <= 0) then {
                private _paneBottom = _paneY + _paneH;
                // Leave at least _AIR_BOARD_H_MIN above the fallback map pane.
                private _availableMapRegionH = (_paneBottom - _boardY - _AIR_BOARD_H_MIN - _AIR_MAP_PAD) max 0;
                private _desiredMapRegionH = (_paneH * _AIR_MAP_REGION_FRAC) max _AIR_MAP_MIN_H;
                _regionCH = _desiredMapRegionH min _availableMapRegionH;
                if (_regionCH > 0) then {
                    _regionCX = _paneX;
                    _regionCW = _paneW;
                    _regionCY = _paneBottom - _regionCH;
                    _boardH = (_regionCY - _AIR_MAP_PAD - _boardY) max _AIR_BOARD_H_MIN;
                };
            };

            _airStripGroup ctrlSetPosition [_paneX, _paneY, _paneW, _stripH];
            _airStripGroup ctrlCommit 0;
            _airDecisionBand ctrlSetPosition [_paneX, _paneY + _stripH + _AIR_PAD_Y, _paneW, _bandH];
            _airDecisionBand ctrlCommit 0;

            _ctrlList ctrlSetPosition [_listP select 0, _boardY, _listP select 2, _boardH];
            _ctrlList ctrlCommit 0;
            _ctrlDetailsGrp ctrlSetPosition [_detailsP select 0, _boardY, _detailsP select 2, _boardH];
            _ctrlDetailsGrp ctrlCommit 0;
            if (!isNull _ctrlDetails) then {
                _ctrlDetails ctrlSetPosition [0.005, 0.005, 0.99, 0.99];
                _ctrlDetails ctrlCommit 0;
            };

            if (!isNull _airTrafficMap) then {
                if (_regionCH > 0) then {
                    private _mapW = (_regionCW - (2 * _AIR_MAP_PAD)) max _AIR_MAP_MIN_W;
                    private _mapH = (_regionCH - (2 * _AIR_MAP_PAD)) max _AIR_MAP_MIN_H;
                    _airTrafficMap ctrlSetPosition [_regionCX + _AIR_MAP_PAD, _regionCY + _AIR_MAP_PAD, _mapW, _mapH];
                    _airTrafficMap ctrlCommit 0;
                };
            };
        };

        [_b1, (if (_airMode isEqualTo "PILOT") then {"SEND REQUEST"} else {"AIR ACTION"}), true, true] call ARC_fnc_uiConsoleButtonState;
        [_b2, (if (_airMode isEqualTo "PILOT") then {"UPDATE"} else {"VIEW"}), true, true] call ARC_fnc_uiConsoleButtonState;

        if (!_canAirRead && !_canAirControl && !_canAirPilot) then
        {
            [_b1, "READ-ONLY", false, true] call ARC_fnc_uiConsoleButtonState;
            [_b2, "READ-ONLY", false, true] call ARC_fnc_uiConsoleButtonState;
        };

        [_display, false] call ARC_fnc_uiConsoleAirPaint;
    };
    case "HANDOFF":
    {
        [_b1, "INTEL DEBRIEF", true, true] call ARC_fnc_uiConsoleButtonState;
        [_b2, "EPW PROCESS", true, true] call ARC_fnc_uiConsoleButtonState;
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
                [_b1, "APPROVE", true, true] call ARC_fnc_uiConsoleButtonState;
                [_b2, "REJECT", true, true] call ARC_fnc_uiConsoleButtonState;
            }
            else
            {
                [_b1, "REFRESH", true, true] call ARC_fnc_uiConsoleButtonState;
                [_b2, "BACK", true, true] call ARC_fnc_uiConsoleButtonState;
            };
        }
        else
        {
            [_b1, "TOC QUEUE", true, true] call ARC_fnc_uiConsoleButtonState;
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
            call _clampMainGroupToListRegion;

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

        [_b1, "REFRESH", true, true] call ARC_fnc_uiConsoleButtonState;
        [_b2, "READ-ONLY", false, true] call ARC_fnc_uiConsoleButtonState;

        if (_tabDiffers) then { uiNamespace setVariable ["ARC_console_s1ExpandToggled", true]; };
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

call _auditLayout;

uiNamespace setVariable ["ARC_console_prevRefreshTab", _tab];

true

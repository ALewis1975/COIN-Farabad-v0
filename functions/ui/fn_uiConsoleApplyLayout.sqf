/*
    ARC_fnc_uiConsoleApplyLayout

    Client: applies runtime console layout mode with declared tab layout regions.

    Refactored per Farabad Console Refactor Plan §4.1–§4.2:
    - Each tab declares its layout needs via a tab layout config array.
    - The shell layout engine reads the active tab's declaration and positions
      Regions A–E accordingly.
    - Region C (Visual Panel, IDC 78140) is shown/hidden and sized from declaration.

    Mission var:
      ARC_console_layoutMode = "FULL" | "DOCK_RIGHT"

    Params:
      0: DISPLAY
      1: STRING (optional) — active tab key.

    Returns:
      STRING selected mode
*/

if (!hasInterface) exitWith {"FULL"};

params [
    ["_display", displayNull, [displayNull]],
    ["_activeTab", "", [""]]
];

if (isNull _display) exitWith {"FULL"};

// -----------------------------------------------------------------------
// Tab layout declarations (Refactor Plan §4.2)
// [tabId, useStatusStrip, mainBoardMode, useVisualPanel, visualPanelHeightFrac, splitRatio]
// -----------------------------------------------------------------------
private _tabLayouts = [
    ["DASH",    false, "STRUCTURED_TEXT", false, 0,    0.50],
    ["BOARDS",  false, "STRUCTURED_TEXT", false, 0,    0.50],
    ["INTEL",   false, "LIST",            false, 0,    0.47],
    ["OPS",     false, "FRAMES_3",        false, 0,    0.50],
    ["AIR",     true,  "LIST",            true,  0.35, 0.47],
    ["HANDOFF", false, "STRUCTURED_TEXT", false, 0,    0.47],
    ["CMD",     false, "STRUCTURED_TEXT", false, 0,    0.50],
    ["HQ",      false, "LIST",            false, 0,    0.50],
    ["S1",      false, "LIST",            false, 0,    0.47]
];

// Look up active tab's layout declaration
private _useStatusStrip = false;
private _mainBoardMode = "STRUCTURED_TEXT";
private _useVisualPanel = false;
private _visualPanelFrac = 0;
private _splitRatio = 0.50;

{
    if (_x isEqualType [] && { (count _x) >= 6 } && { (_x select 0) isEqualTo _activeTab }) exitWith {
        _useStatusStrip = _x select 1;
        _mainBoardMode = _x select 2;
        _useVisualPanel = _x select 3;
        _visualPanelFrac = _x select 4;
        _splitRatio = _x select 5;
    };
} forEach _tabLayouts;

// Store layout declaration for painters to query
uiNamespace setVariable ["ARC_console_layoutUseStatusStrip", _useStatusStrip];
uiNamespace setVariable ["ARC_console_layoutMainBoardMode", _mainBoardMode];
uiNamespace setVariable ["ARC_console_layoutUseVisualPanel", _useVisualPanel];
uiNamespace setVariable ["ARC_console_layoutVisualPanelFrac", _visualPanelFrac];
uiNamespace setVariable ["ARC_console_layoutSplitRatio", _splitRatio];

private _modeRaw = missionNamespace getVariable ["ARC_console_layoutMode", "FULL"];
if (!(_modeRaw isEqualType "")) then { _modeRaw = "FULL"; };
private _mode = toUpper (trim _modeRaw);
if !(_mode in ["FULL", "DOCK_RIGHT"]) then { _mode = "FULL"; };

uiNamespace setVariable ["ARC_console_layoutModeActive", _mode];

private _trackedIdcs = [
    // shell + status
    78090,78091,78092,78093,78094,78095,78096,78097,78098,
    78060,78061,78062,78063,
    // nav + core panes
    78001,78015,78011,78016,
    // Region C: Visual Panel
    78140,
    // S2 workflow controls
    78050,78051,78052,78053,78054,78055,
    // OPS frames
    78030,78031,78032,78033,78034,78035,78036,78037,78038,
    // actions
    78021,78022,78023,78024
];

private _defaultsKey = "ARC_ui_consoleLayoutDefaults";
private _defaults = uiNamespace getVariable [_defaultsKey, createHashMap];
if !(_defaults isEqualType createHashMap) then { _defaults = createHashMap; };

{
    private _idc = _x;
    private _ctrl = _display displayCtrl _idc;
    if (!isNull _ctrl) then {
        private _k = str _idc;
        if (isNil { _defaults get _k }) then {
            _defaults set [_k, ctrlPosition _ctrl];
        };
    };
} forEach _trackedIdcs;
uiNamespace setVariable [_defaultsKey, _defaults];

private _setPos = {
    params ["_idc", "_x", "_y", "_w", "_h"];
    private _ctrl = _display displayCtrl _idc;
    if (isNull _ctrl) exitWith {};
    _ctrl ctrlSetPosition [_x, _y, _w, _h];
    _ctrl ctrlCommit 0;
};

if (_mode isEqualTo "FULL") exitWith {
    {
        private _ctrl = _display displayCtrl _x;
        if (!isNull _ctrl) then {
            private _p = _defaults get (str _x);
            if (isNil "_p") then { _p = []; };
            if (_p isEqualType [] && { (count _p) == 4 }) then {
                _ctrl ctrlSetPosition _p;
                _ctrl ctrlCommit 0;
            };
        };
    } forEach _trackedIdcs;
    _mode
};

private _frameCtrl = _display displayCtrl 78099;
private _frame = if (!isNull _frameCtrl) then { ctrlPosition _frameCtrl } else {
    [safeZoneX + (safeZoneW * 0.66), safeZoneY + (safeZoneH * 0.01), safeZoneW * 0.34, safeZoneH * 0.98]
};
_frame params ["_fx", "_fy", "_fw", "_fh"];

private _titleH = _fh * 0.045;
private _statusH = _fh * 0.03;
private _contentY = _fy + _titleH + _statusH + (_fh * 0.008);
private _contentBottom = _fy + _fh - (_fh * 0.08);
private _contentH = (_contentBottom - _contentY) max (_fh * 0.70);

private _tabsX = _fx + (_fw * 0.012);
private _tabsW = _fw * 0.27;
private _gap = _fw * 0.012;
private _mainX = _tabsX + _tabsW + _gap;
private _mainW = (_fx + _fw - _mainX - (_fw * 0.012)) max (_fw * 0.24);
// Use declared split ratio from tab layout declaration
private _mainSplitW = _mainW * _splitRatio;
private _detailsX = _mainX + _mainSplitW + _gap;
private _detailsW = (_fx + _fw - _detailsX - (_fw * 0.012)) max (_fw * 0.18);

// -----------------------------------------------------------------------
// Region C: Visual Panel (IDC 78140)
// When useVisualPanel is true, Region C occupies a declared fraction of
// the content height.  Region B shrinks accordingly.  When false, Region C
// is hidden with height 0.
// -----------------------------------------------------------------------
private _visualPanelCtrl = _display displayCtrl 78140;
private _regionCH = 0;
private _regionCY = _contentY;

if (_useVisualPanel && { _visualPanelFrac > 0 }) then {
    _regionCH = _contentH * _visualPanelFrac;
    // Region C sits at the bottom of the content area, above the action row
    _regionCY = _contentY + _contentH - _regionCH;

    if (!isNull _visualPanelCtrl) then {
        [78140, _mainX, _regionCY, _mainW + _detailsW + _gap, _regionCH] call _setPos;
        _visualPanelCtrl ctrlShow true;
    };

    // Shrink Region B (main list) and Region D (details) to fit above Region C
    _contentH = _contentH - _regionCH - (_fh * 0.008);
} else {
    if (!isNull _visualPanelCtrl) then {
        [78140, _mainX, _contentY + _contentH, _mainW + _detailsW + _gap, 0] call _setPos;
        _visualPanelCtrl ctrlShow false;
    };
};

// Store computed Region C position for painters (e.g. AIR map reposition)
uiNamespace setVariable ["ARC_console_regionCY", _regionCY];
uiNamespace setVariable ["ARC_console_regionCH", _regionCH];

// Frame + shell
[78090, _fx, _fy, _fw, _fh] call _setPos;
[78092, _fx, _fy, _fw, _fh] call _setPos;
[78093, _fx, _fy, _fw, _fh] call _setPos;
[78091, _fx, _fy, _fw, _titleH] call _setPos;
[78098, _fx, _fy + _titleH, _fw, _statusH] call _setPos;

private _gripW = _fw * 0.018;
private _gripH = _fh * 0.018;
[78094, _fx, _fy, _gripW, _gripH] call _setPos;
[78095, _fx + _fw - _gripW, _fy, _gripW, _gripH] call _setPos;
[78096, _fx, _fy + _fh - _gripH, _gripW, _gripH] call _setPos;
[78097, _fx + _fw - _gripW, _fy + _fh - _gripH, _gripW, _gripH] call _setPos;

// Status row
[78060, _fx + (_fw * 0.01), _fy + _titleH + (_statusH * 0.12), _fw * 0.36, _statusH * 0.74] call _setPos;
[78061, _fx + (_fw * 0.39), _fy + _titleH + (_statusH * 0.12), _fw * 0.36, _statusH * 0.74] call _setPos;
[78062, _fx + (_fw * 0.77), _fy + _titleH + (_statusH * 0.12), _fw * 0.13, _statusH * 0.74] call _setPos;
[78063, _fx + (_fw * 0.91), _fy + _titleH + (_statusH * 0.08), _fw * 0.08, _statusH * 0.78] call _setPos;

// Core panes
[78001, _tabsX, _contentY, _tabsW, _contentH] call _setPos;
[78015, _mainX, _contentY, _mainW + _detailsW + _gap, _contentH] call _setPos;
[78011, _mainX, _contentY, _mainSplitW, _contentH] call _setPos;
[78016, _detailsX, _contentY, _detailsW, _contentH] call _setPos;

// S2 controls (Intel painter will finalize fine split based on ctrlPosition).
private _s2CtlX = _detailsX;
private _s2CtlW = _detailsW;
[78050, _s2CtlX, _contentY + (_contentH * 0.00), _s2CtlW, _fh * 0.03] call _setPos;
[78051, _s2CtlX, _contentY + (_contentH * 0.035), _s2CtlW, _fh * 0.04] call _setPos;
[78052, _s2CtlX, _contentY + (_contentH * 0.09), _s2CtlW, _fh * 0.03] call _setPos;
[78053, _s2CtlX, _contentY + (_contentH * 0.125), _s2CtlW, _fh * 0.04] call _setPos;
[78054, _s2CtlX, _contentY + (_contentH * 0.00), _s2CtlW, _fh * 0.03] call _setPos;
[78055, _s2CtlX, _contentY + (_contentH * 0.035), _s2CtlW, _fh * 0.04] call _setPos;

// OPS panels in left middle pane
private _opsX = _mainX;
private _opsW = _mainSplitW;
private _hdrH = _fh * 0.03;
private _h1 = _contentH * 0.20;
private _h2 = _contentH * 0.20;
private _h3 = _contentH - _h1 - _h2 - (_fh * 0.05);
private _y1 = _contentY;
private _y2 = _y1 + _h1 + (_fh * 0.02);
private _y3 = _y2 + _h2 + (_fh * 0.02);

[78030, _opsX, _y1, _opsW, _h1] call _setPos;
[78031, _opsX, _y1, _opsW, _hdrH] call _setPos;
[78032, _opsX, _y1 + _hdrH, _opsW, (_h1 - _hdrH) max (_fh * 0.08)] call _setPos;

[78033, _opsX, _y2, _opsW, _h2] call _setPos;
[78034, _opsX, _y2, _opsW, _hdrH] call _setPos;
[78035, _opsX, _y2 + _hdrH, _opsW, (_h2 - _hdrH) max (_fh * 0.08)] call _setPos;

[78036, _opsX, _y3, _opsW, _h3] call _setPos;
[78037, _opsX, _y3, _opsW, _hdrH] call _setPos;
[78038, _opsX, _y3 + _hdrH, _opsW, (_h3 - _hdrH) max (_fh * 0.10)] call _setPos;

// Actions row
private _btnY = _fy + _fh - (_fh * 0.06);
private _btnH = _fh * 0.045;
private _btnGap = _fw * 0.012;
private _btnW = ((_fw - (_btnGap * 5)) / 4) max (_fw * 0.14);
private _btnX0 = _fx + _btnGap;
[78021, _btnX0, _btnY, _btnW, _btnH] call _setPos;
[78022, _btnX0 + _btnW + _btnGap, _btnY, _btnW, _btnH] call _setPos;
[78023, _btnX0 + ((_btnW + _btnGap) * 2), _btnY, _btnW, _btnH] call _setPos;
[78024, _btnX0 + ((_btnW + _btnGap) * 3), _btnY, _btnW, _btnH] call _setPos;

_mode

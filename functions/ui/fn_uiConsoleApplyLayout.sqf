/*
    ARC_fnc_uiConsoleApplyLayout

    Client: applies runtime console layout mode.

    Mission var:
      ARC_console_layoutMode = "FULL" | "DOCK_RIGHT"

    Params:
      0: DISPLAY
      1: STRING (optional) — active tab key.  When the tab is one of
         DASH | BOARDS | OPS | CMD | HQ the center and right panes are
         given equal width (50 / 50 split).  All other tabs use the
         default 47 / 53 split.

    Returns:
      STRING selected mode
*/

if (!hasInterface) exitWith {"FULL"};

params [
    ["_display", displayNull, [displayNull]],
    ["_activeTab", "", [""]]
];

if (isNull _display) exitWith {"FULL"};

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
// Equal-width (50/50) split for ops-facing screens; 47/53 for all others.
private _equalSplitTabs = ["DASH", "BOARDS", "OPS", "CMD", "HQ"];
private _splitRatio = if (_activeTab in _equalSplitTabs) then { 0.50 } else { 0.47 };
private _mainSplitW = _mainW * _splitRatio;
private _detailsX = _mainX + _mainSplitW + _gap;
private _detailsW = (_fx + _fw - _detailsX - (_fw * 0.012)) max (_fw * 0.18);

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

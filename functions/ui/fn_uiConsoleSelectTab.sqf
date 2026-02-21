/*
    ARC_fnc_uiConsoleSelectTab

    Client: handles tab selection changes from the console listbox.

    Params:
      Pattern A (normal):
        0: CONTROL listbox
        1: NUMBER selected index

      Pattern B (scripted):
        0: STRING tab id ("DASH" | "INTEL" | "OPS" | "AIR" | "HANDOFF" | "CMD" | "HQ")
        1: (optional) DISPLAY (defaults to current console display)

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

// Allow scripted calls like ["HQ"] call ARC_fnc_uiConsoleSelectTab;
// This avoids params type errors and simply sets the listbox selection.
if (_this isEqualType "" || { (_this isEqualType []) && { (count _this) > 0 } && { (_this select 0) isEqualType "" } }) exitWith

// sqflint-compat helpers
private _trimFn     = compile "params ['_s']; trim _s";
{
    private _tab = if (_this isEqualType "") then { _this } else { _this select 0 };
    _tab = toUpper ([_tab] call _trimFn);

    private _display = displayNull;
    if ((_this isEqualType []) && { (count _this) > 1 } && { (_this select 1) isEqualType displayNull }) then
    {
        _display = _this select 1;
    }
    else
    {
        _display = uiNamespace getVariable ["ARC_console_display", displayNull];
        if (isNull _display) then { _display = findDisplay 78000; };
    };

    if (isNull _display) exitWith {false};

    private _ctrlTabs = _display displayCtrl 78001;
    if (isNull _ctrlTabs) exitWith {false};

    private _tabIds = uiNamespace getVariable ["ARC_console_tabIds", []];
    if (!(_tabIds isEqualType [])) exitWith {false};

    private _i = _tabIds find _tab;
    if (_i < 0) exitWith {false};

    _ctrlTabs lbSetCurSel _i;
    true
};

params [
    ["_ctrl", controlNull, [controlNull]],
    ["_index", -1, [0]]
];

if (isNull _ctrl || { _index < 0 }) exitWith {false};

private _tabIds = uiNamespace getVariable ["ARC_console_tabIds", []];
if (!(_tabIds isEqualType []) || { _index >= (count _tabIds) }) exitWith {false};

private _tab = _tabIds select _index;
if (!(_tab isEqualType "")) exitWith {false};

uiNamespace setVariable ["ARC_console_activeTab", _tab];

private _display = ctrlParent _ctrl;
if (!isNull _display) then
{
    [_display] call ARC_fnc_uiConsoleRefresh;
};

true

/*
    ARC_fnc_recruitDialogRecruitSelected

    Client: submit the selected recruitment class and quantity to the server.

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

private _display = findDisplay 78400;
if (isNull _display) exitWith {false};

private _container = uiNamespace getVariable ["ARC_recruitDialog_container", objNull];
if (isNull _container) exitWith
{
    uiNamespace setVariable ["ARC_recruitDialog_status", "Recruitment object unavailable."];
    [_display] call ARC_fnc_recruitDialogOnLoad;
    false
};

private _list = _display displayCtrl 78410;
private _qty = _display displayCtrl 78420;
if (isNull _list || { isNull _qty }) exitWith {false};

private _sel = lbCurSel _list;
if (_sel < 0) exitWith
{
    uiNamespace setVariable ["ARC_recruitDialog_status", "Select a unit type first."];
    [_display] call ARC_fnc_recruitDialogOnLoad;
    false
};

private _class = _list lbData _sel;
if (_class isEqualTo "") exitWith
{
    uiNamespace setVariable ["ARC_recruitDialog_status", "Selected unit type is invalid."];
    [_display] call ARC_fnc_recruitDialogOnLoad;
    false
};

private _qtySel = lbCurSel _qty;
private _count = 1;
if (_qtySel >= 0) then { _count = _qty lbValue _qtySel; };
if (_count <= 0) exitWith
{
    uiNamespace setVariable ["ARC_recruitDialog_status", "Recruitment cap reached."];
    [_display] call ARC_fnc_recruitDialogOnLoad;
    false
};

uiNamespace setVariable ["ARC_recruitDialog_status", "Recruitment request sent."];
[player, _container, _class, _count] remoteExec ["ARC_fnc_recruitSpawnRequest", 2];
[_display] call ARC_fnc_recruitDialogOnLoad;

[] spawn {
    uiSleep 1;
    private _display = findDisplay 78400;
    if (!isNull _display) then
    {
        uiNamespace setVariable ["ARC_recruitDialog_status", ""];
        [_display] call ARC_fnc_recruitDialogOnLoad;
    };
};

true

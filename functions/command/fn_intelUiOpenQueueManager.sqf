/*
    ARC_fnc_intelUiOpenQueueManager

    Client: route TOC queue access through the Farabad Console BOARDS/CMD tabs.
*/

if (!hasInterface) exitWith {false};

// Safety: require an authorized role, but allow view-only access for non-approvers.
if !([player] call ARC_fnc_rolesIsAuthorized) exitWith { false };

if !([player] call ARC_fnc_rolesCanApproveQueue) then
{
    ["TOC Queue", "View-only: Approve/Reject disabled (S3/Command only)."] call ARC_fnc_clientHint;
};

private _focusConsole = {
    params ["_display"];
    if (isNull _display) exitWith {false};

    private _tabs = uiNamespace getVariable ["ARC_console_tabIds", []];
    if (!(_tabs isEqualType [])) then { _tabs = []; };

    private _idx = _tabs find "BOARDS";
    if (_idx < 0) then { _idx = _tabs find "CMD"; };
    if (_idx < 0) exitWith {false};

    uiNamespace setVariable ["ARC_console_activeTab", _tabs # _idx];
    private _ctrlTabs = _display displayCtrl 78001;
    if (!isNull _ctrlTabs) then { _ctrlTabs lbSetCurSel _idx; };
    [_display] call ARC_fnc_uiConsoleRefresh;
    true
};

private _disp = findDisplay 78000;
if (isNull _disp) then
{
    uiNamespace setVariable ["ARC_console_forceTab", "BOARDS"];
    [] call ARC_fnc_uiConsoleOpen;
    _disp = findDisplay 78000;
};

if ([_disp] call _focusConsole) exitWith {true};

createDialog "ARC_TOCQueueManagerDialog";
true

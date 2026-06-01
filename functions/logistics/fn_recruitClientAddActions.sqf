/*
    ARC_fnc_recruitClientAddActions

    Client: attach the AI recruitment addAction to one recruitment object.

    Params:
      0: OBJECT container

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};
private _remoteOwner = -1;
if (!isNil "remoteExecutedOwner") then { _remoteOwner = remoteExecutedOwner; };
if (_remoteOwner > 0 && { _remoteOwner != 2 }) exitWith
{
    diag_log format ["[ARC][SEC][RECRUIT] ARC_fnc_recruitClientAddActions: denied non-server remoteExec sender=%1", _remoteOwner];
    false
};

params [
    ["_container", objNull, [objNull]]
];

if (isNull _container) exitWith {false};
if (!(missionNamespace getVariable ["ARC_recruitContainerEnabled", true])) exitWith
{
    if (isNil "ARC_recruit_diagContainerDisabledLogged") then
    {
        ARC_recruit_diagContainerDisabledLogged = true;
        diag_log "[ARC][INFO][RECRUIT] ARC_fnc_recruitClientAddActions: skipped, ARC_recruitContainerEnabled=false";
    };
    false
};

private _vanillaActionsEnabled = missionNamespace getVariable ["ARC_vanillaAddActionsEnabled", false];
if (!(_vanillaActionsEnabled isEqualType true)) then { _vanillaActionsEnabled = false; };

private _recruitActionsEnabled = missionNamespace getVariable ["ARC_recruitAddActionsEnabled", _vanillaActionsEnabled];
if (!(_recruitActionsEnabled isEqualType true)) then { _recruitActionsEnabled = _vanillaActionsEnabled; };
if (!_recruitActionsEnabled) exitWith
{
    if (isNil "ARC_recruit_diagActionsDisabledLogged") then
    {
        ARC_recruit_diagActionsDisabledLogged = true;
        diag_log format ["[ARC][INFO][RECRUIT] ARC_fnc_recruitClientAddActions: skipped, ARC_recruitAddActionsEnabled=false (vanilla=%1)", _vanillaActionsEnabled];
    };
    false
};

private _signature = "Recruit AI";
if ((_container getVariable ["ARC_recruitActionsSignature", ""]) isEqualTo _signature) exitWith {true};

private _actionRangeM = missionNamespace getVariable ["ARC_recruitActionRangeM", 50];
if (!(_actionRangeM isEqualType 0)) then { _actionRangeM = 50; };
_actionRangeM = _actionRangeM max 0;

private _old = _container getVariable ["ARC_recruitActionIds", []];
if (_old isEqualType []) then
{
    {
        if (_x isEqualType 0 && { _x >= 0 }) then
        {
            _container removeAction _x;
        };
    } forEach _old;
};

private _id = _container addAction [
    "Recruit AI",
    {
        params ["_target", "_caller", ["_actionId", -1, [0]]];
        if (_actionId < 0) exitWith {false};
        if (isNull _target || { isNull _caller }) exitWith {false};
        [_target] call ARC_fnc_recruitDialogOpen;
        true
    },
    [],
    1.1,
    true,
    true,
    "",
    "alive _target",
    _actionRangeM
];

private _ids = [_id];

_container setVariable ["ARC_recruitActionIds", _ids, false];
_container setVariable ["ARC_recruitActionsSignature", _signature, false];

diag_log format ["[ARC][INFO][RECRUIT] ARC_fnc_recruitClientAddActions: attached Recruit AI action to object netId=%1", netId _container];

true

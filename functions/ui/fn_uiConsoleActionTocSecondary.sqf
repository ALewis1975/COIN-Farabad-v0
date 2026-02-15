/*
    ARC_fnc_uiConsoleActionTocSecondary

    Client: TOC tab secondary action.

    Context:
      - If an active incident is waiting for acceptance: accept it.
      - If an active incident is accepted: open Closeout (SUCCESS/FAIL).
      - Otherwise: request generation of the next incident.

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

// UI event handlers are unscheduled; any dialogs/prompts require scheduled context.
if (!canSuspend) exitWith { _this spawn ARC_fnc_uiConsoleActionTocSecondary; false };

// OMNI override (playtesting)
private _omniTokens = missionNamespace getVariable ["ARC_consoleOmniTokens", ["OMNI"]];
if (!(_omniTokens isEqualType [])) then { _omniTokens = ["OMNI"]; };
private _isOmni = false;
{
    if (_x isEqualType "" && { [player, _x] call ARC_fnc_rolesHasGroupIdToken }) exitWith { _isOmni = true; };
} forEach _omniTokens;

private _canApprove = _isOmni || { [player] call ARC_fnc_rolesCanApproveQueue };
if (!_canApprove) exitWith
{
    ["TOC", "TOC Ops actions are restricted to S3/Command (or OMNI)."] call ARC_fnc_clientToast;
    false
};

private _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""]; 
if (!(_taskId isEqualType "")) then { _taskId = ""; };
private _acc = missionNamespace getVariable ["ARC_activeIncidentAccepted", false];
if (!(_acc isEqualType true) && !(_acc isEqualType false)) then { _acc = false; };

// No incident: generate next incident.
if (_taskId isEqualTo "") exitWith
{
    [] call ARC_fnc_uiConsoleActionRequestNextIncident;
    true
};

// Incident exists but not accepted yet: accept it.
if (!_acc) exitWith
{
    [] call ARC_fnc_uiConsoleActionAcceptIncident;
    true
};

// Incident accepted: open closeout panel/dialog.
[] call ARC_fnc_uiConsoleActionOpenCloseout;
true

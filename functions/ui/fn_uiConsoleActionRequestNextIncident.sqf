/*
    ARC_fnc_uiConsoleActionRequestNextIncident

    Client: request TOC to generate the next incident.

    Server validation remains authoritative.

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

// UI event handlers are unscheduled; BIS_fnc_guiMessage requires scheduled.
if (!canSuspend) exitWith { _this spawn ARC_fnc_uiConsoleActionRequestNextIncident; false };

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
    ["TOC", "Incident generation restricted to TOC (S3/Command) or OMNI."] call ARC_fnc_clientToast;
    false
};

// Do not spam requests while an incident is active.
private _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""]; 
if (!(_taskId isEqualType "")) then { _taskId = ""; };
if (_taskId isNotEqualTo "") exitWith
{
    ["TOC", "An incident is already active. Close it (and complete SITREP workflow) before generating a new one."] call ARC_fnc_clientToast;
    false
};

private _ok = ["Generate the next incident now?", "TOC", true, true] call BIS_fnc_guiMessage;
if (!_ok) exitWith {false};

[player] remoteExec ["ARC_fnc_tocRequestNextIncident", 2];
["TOC", "Requested next incident."] call ARC_fnc_clientToast;

true

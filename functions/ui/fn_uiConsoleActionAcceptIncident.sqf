/*
    ARC_fnc_uiConsoleActionAcceptIncident

    Client: invoked from the console "Accept Incident" button.

    Purpose:
      - Moves "incident acceptance" into the Farabad Console so we are not
        dependent on scroll-menu addActions or ACE self-interact actions.

    Rules (mirrors field-command addAction condition in fn_tocInitPlayer.sqf):
      - Requires an authorized leader OR OMNI token (playtest override).
      - Requires an active incident taskId.
      - Can only be used if the incident has not already been accepted.

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

// OMNI override (playtesting)
private _omniTokens = missionNamespace getVariable ["ARC_consoleOmniTokens", ["OMNI"]];
if (!(_omniTokens isEqualType [])) then { _omniTokens = ["OMNI"]; };
private _isOmni = false;
{
    if (_x isEqualType "" && { [player, _x] call ARC_fnc_rolesHasGroupIdToken }) exitWith { _isOmni = true; };
} forEach _omniTokens;

private _isLeader = ([player] call ARC_fnc_rolesIsAuthorized) || _isOmni;
if (!_isLeader) exitWith
{
    ["Incident", "A leader (SL/PL/CO) must accept incidents (unless OMNI)."] call ARC_fnc_clientToast;
    false
};

private _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""];
if (!(_taskId isEqualType "") || { _taskId isEqualTo "" }) exitWith
{
    ["Incident", "No active incident is pending acceptance."] call ARC_fnc_clientToast;
    false
};

private _accepted = missionNamespace getVariable ["ARC_activeIncidentAccepted", false];
if (!(_accepted isEqualType true) && !(_accepted isEqualType false)) then { _accepted = false; };

if (_accepted) exitWith
{
    ["Incident", "Incident already accepted."] call ARC_fnc_clientToast;
    false
};

// Request acceptance server-side (server validates role again)
[player] remoteExec ["ARC_fnc_tocRequestAcceptIncident", 2];

["Incident", "Acceptance request sent."] call ARC_fnc_clientToast;
true

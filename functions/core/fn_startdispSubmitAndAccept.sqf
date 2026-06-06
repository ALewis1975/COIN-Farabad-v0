/*
    Client->server RPC: submit STARTDISP leader inputs, server captures disposition, then accepts incident.
*/

if (!isServer) exitWith { false };
if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\\core\\fn_rpcValidateSender.sqf"; };
if (isNil "ARC_fnc_rolesIsAuthorized") then { ARC_fnc_rolesIsAuthorized = compile preprocessFileLineNumbers "functions\\core\\fn_rolesIsAuthorized.sqf"; };

params [
    ["_caller", objNull],
    ["_lace", [], [[]]],
    ["_deficiencies", "", [""]],
    ["_additionalRequested", false, [false]],
    ["_additionalNotes", "", [""]]
];

private _reoOwner = if (!isNil "remoteExecutedOwner") then { remoteExecutedOwner } else { -1 };
if (!([_caller, "ARC_fnc_startdispSubmitAndAccept", "STARTDISP rejected: sender verification failed.", "STARTDISP_SECURITY_DENIED", true, _reoOwner] call ARC_fnc_rpcValidateSender)) exitWith { false };

if (isNull _caller || { !([_caller] call ARC_fnc_rolesIsAuthorized) }) exitWith
{
    if (!isNull _caller) then { ["Incident", "You are not authorized to accept incidents."] remoteExec ["ARC_fnc_clientToast", owner _caller]; };
    false
};

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (_taskId isEqualTo "") exitWith
{
    ["INCIDENT_ACCEPT", "REJECTED", "No active incident is pending acceptance."] remoteExec ["ARC_fnc_uiConsoleOpsActionStatus", owner _caller];
    false
};

private _accepted = ["activeIncidentAccepted", false] call ARC_fnc_stateGet;
if (_accepted isEqualType true && { _accepted }) exitWith
{
    ["INCIDENT_ACCEPT", "REJECTED", "Incident already accepted."] remoteExec ["ARC_fnc_uiConsoleOpsActionStatus", owner _caller];
    false
};

private _capture = [_caller] call ARC_fnc_startdispCaptureGroup;
if (_capture isEqualTo []) exitWith
{
    ["INCIDENT_ACCEPT", "REJECTED", "Could not capture STARTDISP for your group."] remoteExec ["ARC_fnc_uiConsoleOpsActionStatus", owner _caller];
    false
};

private _record = [_caller, _capture, _lace, _deficiencies, _additionalRequested, _additionalNotes] call ARC_fnc_startdispBuildRecord;
if (_record isEqualTo []) exitWith { false };
if (!([_record] call ARC_fnc_startdispBindToIncident)) exitWith { false };

missionNamespace setVariable ["startdisp_v1_accept_guard_uid", getPlayerUID _caller];
private _ok = [_caller] call ARC_fnc_tocRequestAcceptIncident;
missionNamespace setVariable ["startdisp_v1_accept_guard_uid", ""];

if (_ok) then { [] call ARC_fnc_publicBroadcastState; };
_ok

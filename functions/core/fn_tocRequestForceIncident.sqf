/*
    ARC_fnc_tocRequestForceIncident

    Server: spawn a specific incident from the incident catalog (admin/HQ tool).

    Params:
      0: OBJECT - caller
      1: STRING - marker name (raw catalog marker)
      2: STRING - display name
      3: STRING - incident type

    Notes:
      - Server remains authoritative.
      - Blocks if an incident is already active.
      - Does not consume leads; this is an explicit admin override.
*/

if (!isServer) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\core\fn_rpcValidateSender.sqf"; };

params [
    ["_caller", objNull, [objNull]],
    ["_markerRaw", "", [""]],
    ["_displayName", "", [""]],
    ["_incidentType", "", [""]]
];

private _owner = -1;
if (!isNil "remoteExecutedOwner") then { _owner = remoteExecutedOwner; };

// RemoteExec-only validation path: requires remoteExecutedOwner context.
if (!([_caller, "ARC_fnc_tocRequestForceIncident", "Force incident rejected: sender verification failed.", "TOC_FORCE_INCIDENT_SECURITY_DENIED", true] call ARC_fnc_rpcValidateSender)) exitWith {false};


// sqflint-compatible helpers
private _trimFn  = compile "params ['_s']; trim _s";
_markerRaw = [_markerRaw] call _trimFn;
_displayName = [_displayName] call _trimFn;
_incidentType = [_incidentType] call _trimFn;

if (_markerRaw isEqualTo "" || { _displayName isEqualTo "" } || { _incidentType isEqualTo "" }) exitWith
{
    if (_owner > 0) then { ["HQ", "Invalid incident request payload."] remoteExec ["ARC_fnc_clientToast", _owner]; };
    false
};

// Access gating mirrors HQ tab.
private _isOmni = [_caller, "OMNI"] call ARC_fnc_rolesHasGroupIdToken;
private _isCmd = [_caller] call ARC_fnc_rolesIsTocCommand;
private _isTocS3 = [_caller] call ARC_fnc_rolesIsTocS3;

private _hqTokens = missionNamespace getVariable [
    "ARC_consoleHQTokens",
    ["BNHQ","BN CMD","BN_COMMAND","BNCOMMAND","BN CO","BNCO","BN CDR","REDFALCON 6","REDFALCON6","FALCON 6","FALCON6"]
];
if (!(_hqTokens isEqualType [])) then { _hqTokens = ["BNHQ","BN CMD"]; };

private _isBnCmd = false;
{
    if (_x isEqualType "" && { [_caller, _x] call ARC_fnc_rolesHasGroupIdToken }) exitWith { _isBnCmd = true; };
} forEach _hqTokens;

if (!(_isOmni || _isCmd || _isTocS3 || _isBnCmd)) exitWith
{
    if (_owner > 0) then { ["HQ", "Incident picker restricted to HQ/TOC leadership."] remoteExec ["ARC_fnc_clientToast", _owner]; };
    false
};

// Do not allow overlap.
private _activeTaskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (!(_activeTaskId isEqualType "")) then { _activeTaskId = ""; };
if (!(_activeTaskId isEqualTo "")) exitWith
{
    if (_owner > 0) then { ["HQ", "An incident is already active. Close it (and complete SITREP) before spawning a new one."] remoteExec ["ARC_fnc_clientToast", _owner]; };
    false
};

// Resolve marker
private _m = [_markerRaw] call ARC_fnc_worldResolveMarker;
if (!(_m in allMapMarkers)) exitWith
{
    if (_owner > 0) then { ["HQ", format ["Marker not found: %1", _markerRaw]] remoteExec ["ARC_fnc_clientToast", _owner]; };
    false
};

// Manual override: ensure auto-incident suppression doesn't block deliberate testing.
["autoIncidentSuspendUntil", -1] call ARC_fnc_stateSet;

private _posATL = + (getMarkerPos _m);
_posATL resize 3;
private _zone = [_markerRaw] call ARC_fnc_worldGetZoneForMarker;

// New task id
private _counter = ["taskCounter", 0] call ARC_fnc_stateGet;
if (!(_counter isEqualType 0)) then { _counter = 0; };
_counter = _counter + 1;
["taskCounter", _counter] call ARC_fnc_stateSet;

private _taskId = format ["ARC_inc_%1", _counter];

// Core incident state
["activeTaskId", _taskId] call ARC_fnc_stateSet;
["activeIncidentType", _incidentType] call ARC_fnc_stateSet;
["activeIncidentMarker", _markerRaw] call ARC_fnc_stateSet;
["activeIncidentDisplayName", _displayName] call ARC_fnc_stateSet;
["activeIncidentCreatedAt", serverTime] call ARC_fnc_stateSet;
["activeIncidentZone", _zone] call ARC_fnc_stateSet;
["activeIncidentPos", _posATL] call ARC_fnc_stateSet;

// Acceptance
["activeIncidentAccepted", false] call ARC_fnc_stateSet;
["activeIncidentAcceptedAt", -1] call ARC_fnc_stateSet;
["activeIncidentAcceptedBy", ""] call ARC_fnc_stateSet;
["activeIncidentAcceptedByName", ""] call ARC_fnc_stateSet;
["activeIncidentAcceptedByUID", ""] call ARC_fnc_stateSet;
["activeIncidentAcceptedByRoleTag", ""] call ARC_fnc_stateSet;
["activeIncidentAcceptedByGroup", ""] call ARC_fnc_stateSet;

// SITREP gating
["activeIncidentSitrepSent", false] call ARC_fnc_stateSet;
["activeIncidentSitrepSentAt", -1] call ARC_fnc_stateSet;
["activeIncidentSitrepFrom", ""] call ARC_fnc_stateSet;
["activeIncidentSitrepFromUID", ""] call ARC_fnc_stateSet;
["activeIncidentSitrepFromGroup", ""] call ARC_fnc_stateSet;
["activeIncidentSitrepFromRoleTag", ""] call ARC_fnc_stateSet;
["activeIncidentSitrepSummary", ""] call ARC_fnc_stateSet;
["activeIncidentSitrepDetails", ""] call ARC_fnc_stateSet;

missionNamespace setVariable ["ARC_activeIncidentSitrepSent", false, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepFrom", "", true];
missionNamespace setVariable ["ARC_activeIncidentSitrepFromGroup", "", true];
missionNamespace setVariable ["ARC_activeIncidentSitrepSummary", "", true];
missionNamespace setVariable ["ARC_activeIncidentSitrepDetails", "", true];

// Close-ready suggestion
["activeIncidentCloseReady", false] call ARC_fnc_stateSet;
["activeIncidentSuggestedResult", ""] call ARC_fnc_stateSet;
["activeIncidentCloseReason", ""] call ARC_fnc_stateSet;
["activeIncidentCloseMarkedAt", -1] call ARC_fnc_stateSet;

// Thread / lead context (none for forced incidents)
["activeLeadId", ""] call ARC_fnc_stateSet;
["activeThreadId", ""] call ARC_fnc_stateSet;
["activeLeadTag", ""] call ARC_fnc_stateSet;

// Reset execution bookkeeping
["activeExecTaskId", ""] call ARC_fnc_stateSet;
["activeExecKind", ""] call ARC_fnc_stateSet;
["activeExecPos", []] call ARC_fnc_stateSet;
["activeExecRadius", 0] call ARC_fnc_stateSet;
["activeExecStartedAt", -1] call ARC_fnc_stateSet;
["activeExecDeadlineAt", -1] call ARC_fnc_stateSet;
["activeExecArrivalReq", 0] call ARC_fnc_stateSet;
["activeExecArrived", false] call ARC_fnc_stateSet;
["activeExecHoldReq", 0] call ARC_fnc_stateSet;
["activeExecHoldAccum", 0] call ARC_fnc_stateSet;
["activeExecLastProg", -1] call ARC_fnc_stateSet;
["activeExecLastProgressAt", -1] call ARC_fnc_stateSet;
["activeObjectiveKind", ""] call ARC_fnc_stateSet;
["activeObjectiveClass", ""] call ARC_fnc_stateSet;
["activeObjectivePos", []] call ARC_fnc_stateSet;
["activeObjectiveNetId", ""] call ARC_fnc_stateSet;

// Create task entity
[_taskId, _markerRaw, _displayName, _incidentType, _posATL, ""] call ARC_fnc_taskCreateIncident;

// Log
private _grid = mapGridPosition _posATL;
private _sum = format ["Tasked (ADMIN): %1 (%2) at %3. Zone: %4.", _displayName, toUpper _incidentType, _grid, _zone];
["OPS", _sum, _posATL, [["taskId", _taskId], ["marker", _markerRaw], ["incidentType", _incidentType], ["event", "INCIDENT_CREATED_ADMIN"]]] call ARC_fnc_intelLog;

// Visual prompt
[
    "New Incident Pending Acceptance",
    format ["%1 (%2) at %3. Accept the incident to start execution.", _displayName, toUpper _incidentType, _grid],
    8
] remoteExec ["ARC_fnc_clientToast", 0];

// Publish state
[] call ARC_fnc_publicBroadcastState;

// Helpful public vars
missionNamespace setVariable ["ARC_activeTaskId", _taskId, true];
missionNamespace setVariable ["ARC_activeIncidentMarker", _markerRaw, true];
missionNamespace setVariable ["ARC_activeIncidentType", _incidentType, true];
missionNamespace setVariable ["ARC_activeIncidentDisplayName", _displayName, true];
missionNamespace setVariable ["ARC_activeIncidentPos", _posATL, true];
missionNamespace setVariable ["ARC_activeIncidentAccepted", false, true];
missionNamespace setVariable ["ARC_activeIncidentAcceptedAt", -1, true];
missionNamespace setVariable ["ARC_activeIncidentAcceptedByGroup", "", true];

missionNamespace setVariable ["ARC_activeIncidentSitrepSent", false, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepSentAt", -1, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepFrom", "", true];
missionNamespace setVariable ["ARC_activeIncidentSitrepFromGroup", "", true];
missionNamespace setVariable ["ARC_activeIncidentSitrepSummary", "", true];
missionNamespace setVariable ["ARC_activeIncidentSitrepDetails", "", true];
missionNamespace setVariable ["ARC_activeIncidentCloseReady", false, true];
missionNamespace setVariable ["ARC_activeIncidentSuggestedResult", "", true];
missionNamespace setVariable ["ARC_activeIncidentCloseReason", "", true];
missionNamespace setVariable ["ARC_activeIncidentCloseMarkedAt", -1, true];
missionNamespace setVariable ["ARC_activeLeadId", "", true];
missionNamespace setVariable ["ARC_activeThreadId", "", true];

true

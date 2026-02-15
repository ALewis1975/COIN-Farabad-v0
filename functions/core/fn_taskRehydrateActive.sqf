/*
    Attempt to recreate/broadcast the active incident task after a restart or desync.

    Returns:
        true if active task exists or was recreated; false if no active task.
*/

if (!isServer) exitWith {false};

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (_taskId isEqualTo "") exitWith {false};

// If task already exists, nothing to do.
if ([_taskId] call BIS_fnc_taskExists) exitWith {true};

private _marker = ["activeIncidentMarker", ""] call ARC_fnc_stateGet;
private _type = ["activeIncidentType", ""] call ARC_fnc_stateGet;
private _display = ["activeIncidentDisplayName", ""] call ARC_fnc_stateGet;
private _posATL = ["activeIncidentPos", []] call ARC_fnc_stateGet;
private _threadId = ["activeThreadId", ""] call ARC_fnc_stateGet;

if (_type isEqualTo "" || _display isEqualTo "") exitWith {false};

[_taskId, _marker, _display, _type, _posATL, _threadId] call ARC_fnc_taskCreateIncident;

// Broadcast helpful variables (for TOC UI, hints, etc.)
missionNamespace setVariable ["ARC_activeTaskId", _taskId, true];
missionNamespace setVariable ["ARC_activeIncidentMarker", _marker, true];
missionNamespace setVariable ["ARC_activeIncidentType", _type, true];
missionNamespace setVariable ["ARC_activeIncidentDisplayName", _display, true];
missionNamespace setVariable ["ARC_activeIncidentPos", _posATL, true];

// UI/menu gating state (clients do not have full server-side ARC_state)
private _accepted = ["activeIncidentAccepted", false] call ARC_fnc_stateGet;
if (!(_accepted isEqualType true)) then { _accepted = false; };

// Backward compatibility: if we have exec timers but no acceptance flag, treat as accepted.
if (!_accepted) then
{
    private _legacyStartedAt = ["activeExecStartedAt", -1] call ARC_fnc_stateGet;
    if (_legacyStartedAt isEqualType 0 && { _legacyStartedAt >= 0 }) then
    {
        _accepted = true;
        ["activeIncidentAccepted", true] call ARC_fnc_stateSet;
        ["activeIncidentAcceptedAt", _legacyStartedAt] call ARC_fnc_stateSet;
    };
};
missionNamespace setVariable ["ARC_activeIncidentAccepted", _accepted, true];
missionNamespace setVariable ["ARC_activeIncidentAcceptedAt", ["activeIncidentAcceptedAt", -1] call ARC_fnc_stateGet, true];
missionNamespace setVariable ["ARC_activeIncidentAcceptedByGroup", ["activeIncidentAcceptedByGroup", ""] call ARC_fnc_stateGet, true];


// SITREP gating (clients need this to hide SITREP menu options after submission)
private _sitrepSent = ["activeIncidentSitrepSent", false] call ARC_fnc_stateGet;
if (!(_sitrepSent isEqualType true)) then { _sitrepSent = false; };

missionNamespace setVariable ["ARC_activeIncidentSitrepSent", _sitrepSent, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepSentAt", ["activeIncidentSitrepSentAt", -1] call ARC_fnc_stateGet, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepFrom", ["activeIncidentSitrepFrom", ""] call ARC_fnc_stateGet, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepFromGroup", ["activeIncidentSitrepFromGroup", ""] call ARC_fnc_stateGet, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepSummary", ["activeIncidentSitrepSummary", ""] call ARC_fnc_stateGet, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepDetails", ["activeIncidentSitrepDetails", ""] call ARC_fnc_stateGet, true];

missionNamespace setVariable ["ARC_activeIncidentCloseReady", ["activeIncidentCloseReady", false] call ARC_fnc_stateGet, true];
missionNamespace setVariable ["ARC_activeIncidentSuggestedResult", ["activeIncidentSuggestedResult", ""] call ARC_fnc_stateGet, true];
missionNamespace setVariable ["ARC_activeIncidentCloseReason", ["activeIncidentCloseReason", ""] call ARC_fnc_stateGet, true];
missionNamespace setVariable ["ARC_activeIncidentCloseMarkedAt", ["activeIncidentCloseMarkedAt", -1] call ARC_fnc_stateGet, true];

// Follow-on request cache (informational only; submitted with SITREP)
missionNamespace setVariable ["ARC_activeIncidentFollowOnRequest", ["activeIncidentFollowOnRequest", []] call ARC_fnc_stateGet, true];
missionNamespace setVariable ["ARC_activeIncidentFollowOnQueueId", ["activeIncidentFollowOnQueueId", ""] call ARC_fnc_stateGet, true];
missionNamespace setVariable ["ARC_activeIncidentFollowOnSummary", ["activeIncidentFollowOnSummary", ""] call ARC_fnc_stateGet, true];
missionNamespace setVariable ["ARC_activeIncidentFollowOnDetails", ["activeIncidentFollowOnDetails", ""] call ARC_fnc_stateGet, true];
missionNamespace setVariable ["ARC_activeIncidentFollowOnFromGroup", ["activeIncidentFollowOnFromGroup", ""] call ARC_fnc_stateGet, true];
missionNamespace setVariable ["ARC_activeIncidentFollowOnAt", ["activeIncidentFollowOnAt", -1] call ARC_fnc_stateGet, true];

// Closeout staging (awaiting unit acceptance)
missionNamespace setVariable ["ARC_activeIncidentClosePending", ["activeIncidentClosePending", false] call ARC_fnc_stateGet, true];
missionNamespace setVariable ["ARC_activeIncidentClosePendingAt", ["activeIncidentClosePendingAt", -1] call ARC_fnc_stateGet, true];
missionNamespace setVariable ["ARC_activeIncidentClosePendingResult", ["activeIncidentClosePendingResult", ""] call ARC_fnc_stateGet, true];
missionNamespace setVariable ["ARC_activeIncidentClosePendingOrderId", ["activeIncidentClosePendingOrderId", ""] call ARC_fnc_stateGet, true];
missionNamespace setVariable ["ARC_activeIncidentClosePendingGroup", ["activeIncidentClosePendingGroup", ""] call ARC_fnc_stateGet, true];


// Refresh public snapshots + task text (useful after restarts)
[] call ARC_fnc_taskUpdateActiveDescription;
[] call ARC_fnc_execInitActive;
[] call ARC_fnc_publicBroadcastState;
[] call ARC_fnc_intelBroadcast;
true

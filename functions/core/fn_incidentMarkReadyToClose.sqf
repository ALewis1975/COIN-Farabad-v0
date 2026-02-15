/*
    Server: mark the active incident as ready for TOC closure.

    This does NOT close the incident and does NOT create a new incident.
    The execution layer uses this to recommend an outcome while keeping
    TOC as the sole authority for closure.

    Params:
        0: STRING - suggested result ("SUCCEEDED" or "FAILED")
        1: STRING - reason code (short, e.g. "CONVOY_DESTROYED", "DEADLINE", "OBJECTIVE_COMPLETE")
        2: STRING - (optional) human detail for intel feed
        3: ARRAY  - (optional) posATL for logging

    Returns:
        BOOL - true if the state was updated
*/

if (!isServer) exitWith {false};

params [
    ["_result", ""],
    ["_reason", ""],
    ["_detail", ""],
    ["_posATL", []]
];

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (_taskId isEqualTo "") exitWith {false};

_result = toUpper _result;
if !(_result in ["SUCCEEDED","FAILED"]) exitWith {false};

_reason = toUpper _reason;
if (!(_reason isEqualType "")) then { _reason = ""; };

// If already marked, keep the first mark unless TOC cleared it.
private _already = ["activeIncidentCloseReady", false] call ARC_fnc_stateGet;
if (_already isEqualType true && { _already }) exitWith {false};

["activeIncidentCloseReady", true] call ARC_fnc_stateSet;
["activeIncidentSuggestedResult", _result] call ARC_fnc_stateSet;
["activeIncidentCloseReason", _reason] call ARC_fnc_stateSet;
["activeIncidentCloseMarkedAt", serverTime] call ARC_fnc_stateSet;

// Broadcast lightweight state for UI/menu gating (clients don't have full server state).
missionNamespace setVariable ["ARC_activeIncidentCloseReady", true, true];
missionNamespace setVariable ["ARC_activeIncidentSuggestedResult", _result, true];
missionNamespace setVariable ["ARC_activeIncidentCloseReason", _reason, true];
missionNamespace setVariable ["ARC_activeIncidentCloseMarkedAt", serverTime, true];

// Optional: add an OPS feed entry so the TOC sees a crisp prompt.
private _pos = _posATL;
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then
{
    _pos = ["activeIncidentPos", []] call ARC_fnc_stateGet;
};

if (_detail isEqualTo "") then
{
    _detail = format ["Incident ready to close. Recommended: %1 (Reason: %2).", _result, _reason];
};

if (_pos isEqualType [] && { (count _pos) >= 2 }) then
{
    ["OPS", _detail, _pos, [["taskId", _taskId], ["event", "INCIDENT_READY_TO_CLOSE"], ["result", _result], ["reason", _reason]]] call ARC_fnc_intelLog;
}
else
{
    ["OPS", _detail, [0,0,0], [["taskId", _taskId], ["event", "INCIDENT_READY_TO_CLOSE"], ["result", _result], ["reason", _reason]]] call ARC_fnc_intelLog;
};

// Refresh task description so players/TOC see the prompt.
[] call ARC_fnc_taskUpdateActiveDescription;
[] call ARC_fnc_publicBroadcastState;

true

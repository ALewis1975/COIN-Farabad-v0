/*
    Ensure an intel "case" parent task exists for a given thread.

    A case task is a parent task that groups child tasks (lead-driven incidents)
    under a coherent campaign thread.

    Per BIS task framework, taskID parameter can be an array [taskID, parentTaskID]
    to create a subtask. We use that in ARC_fnc_taskCreateIncident.

    Params:
        0: STRING - threadId (e.g. "ARC_thr_3")
        1: STRING - threadType (e.g. "IED_CELL")
        2: STRING - zoneBias (optional)
        3: ARRAY  - basePos [x,y,z] (optional)

    Returns:
        STRING - parentTaskId (e.g. "ARC_case_3")
*/

if (!isServer) exitWith {""};

params [
    "_threadId",
    ["_threadType", "GENERIC"],
    ["_zoneBias", ""],
    ["_basePos", []]
];

if (_threadId isEqualTo "") exitWith {""};

// Derive a stable parent task ID
private _suffix = _threadId;
private _u = toUpper _threadId;
private _idx = _u find "ARC_THR_";
if (_idx == 0) then
{
    _suffix = _threadId select [8];
};
private _parentTaskId = format ["ARC_case_%1", _suffix];

// If the task exists already, nothing to do.
if ([_parentTaskId] call BIS_fnc_taskExists) exitWith { _parentTaskId };

private _typeU = toUpper _threadType;

private _caseName = switch (_typeU) do
{
    case "IED_CELL": {"IED Cell"};
    case "INSIDER_NETWORK": {"Insider / Contraband Network"};
    case "SMUGGLING_RING": {"Smuggling Ring"};
    default {"Security Lead"};
};

private _loc = "";
if (_basePos isEqualType [] && { (count _basePos) >= 2 }) then
{
    _loc = mapGridPosition _basePos;
};

private _zoneTxt = if (_zoneBias isEqualTo "") then {""} else { format [" (%1)", _zoneBias] };
private _locTxt  = if (_loc isEqualTo "") then {""} else { format ["<br/><br/>Focus Area: %1", _loc] };

private _title = format ["Case File: %1%2", _caseName, _zoneTxt];

private _desc = format [
    "This case groups related lead follow-ups.<br/><br/>Work the thread to raise confidence without generating too much heat. High heat can force the commander to relocate or flee.%1",
    _locTxt
];

// Destination is deliberately objNull so the parent doesn't drag the team around.
// Priority -1 prevents auto-assignment. showNotification false keeps it quiet.
[true, _parentTaskId, [_desc, _title, ""], objNull, "CREATED", -1, false, "", false] call BIS_fnc_taskCreate;

_parentTaskId

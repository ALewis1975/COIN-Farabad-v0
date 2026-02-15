/*
    Rebuild and set the description for the currently active incident task.

    This keeps tasks "user friendly" and allows intel updates to surface without creating new tasks.
*/

if (!isServer) exitWith {false};

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (_taskId isEqualTo "") exitWith {false};

if (!([_taskId] call BIS_fnc_taskExists)) exitWith {false};

private _marker = ["activeIncidentMarker", ""] call ARC_fnc_stateGet;
private _type   = ["activeIncidentType", ""] call ARC_fnc_stateGet;
private _disp   = ["activeIncidentDisplayName", ""] call ARC_fnc_stateGet;
private _posATL = ["activeIncidentPos", []] call ARC_fnc_stateGet;

if (_type isEqualTo "" || _disp isEqualTo "") exitWith {false};

private _desc = [_taskId, _marker, _disp, _type, _posATL] call ARC_fnc_taskBuildDescription;

// Syntax: [taskId, [taskDescription, taskTitle, taskMarker]] call BIS_fnc_taskSetDescription
[_taskId, [_desc, _disp, ""]] call BIS_fnc_taskSetDescription;

true

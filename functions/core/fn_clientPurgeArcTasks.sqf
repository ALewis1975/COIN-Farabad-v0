/*
    Client-side helper: remove any remaining ARC tasks after a server reset.

    This is intentionally conservative: it tries to delete tasks only by known IDs.
*/

if (!hasInterface) exitWith {false};

params [["_taskIds", []]];
if (!(_taskIds isEqualType [])) then { _taskIds = []; };

{
    if (_x isEqualType "" && {_x != ""}) then
    {
        // Best-effort local cleanup; server should already delete globally.
        [_x, true, true] call BIS_fnc_deleteTask;
    };
} forEach _taskIds;

private _focused = missionNamespace getVariable ["ARC_uiFocusTaskId", ""];
if (_focused in _taskIds) then
{
    missionNamespace setVariable ["ARC_uiFocusTaskId", ""];
    missionNamespace setVariable ["ARC_uiFocusTaskTitle", ""];
    missionNamespace setVariable ["ARC_uiFocusTaskKind", ""];
    missionNamespace setVariable ["ARC_uiFocusTaskPos", []];
    missionNamespace setVariable ["ARC_uiFocusTaskUpdatedAt", diag_tickTime];
};
true

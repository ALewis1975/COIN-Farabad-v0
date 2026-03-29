/*
    Client-side helper: remove any remaining ARC tasks after a server reset.

    This is intentionally conservative: it tries to delete tasks only by known IDs.
*/

if (!hasInterface) exitWith {false};

params [["_taskIds", []]];
if (!(_taskIds isEqualType [])) then { _taskIds = []; };

{
    if (_x isEqualType "" && {!(_x isEqualTo "")}) then
    {
        // Best-effort local cleanup; server should already delete globally.
        [_x, true, true] call BIS_fnc_deleteTask;
    };
} forEach _taskIds;

true

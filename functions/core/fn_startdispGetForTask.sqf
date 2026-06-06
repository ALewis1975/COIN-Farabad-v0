/* Lookup STARTDISP record by taskId. */
params [["_taskId", "", [""]]];
private _byTask = ["startdisp_v1_by_task", []] call ARC_fnc_stateGet;
if (!(_byTask isEqualType [])) exitWith { [] };
private _sid = "";
{ if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _taskId }) exitWith { _sid = _x select 1; }; } forEach _byTask;
if (_sid isEqualTo "") exitWith { [] };
private _records = ["startdisp_v1_records", []] call ARC_fnc_stateGet;
if (!(_records isEqualType [])) exitWith { [] };
private _out = [];
{
    private _r = _x;
    if (_r isEqualType []) then
    {
        { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "startdisp_id" } && { (_x select 1) isEqualTo _sid }) exitWith { _out = _r; }; } forEach _r;
    };
    if !(_out isEqualTo []) exitWith {};
} forEach _records;
_out

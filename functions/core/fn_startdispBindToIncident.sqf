/* Store and bind STARTDISP record to the active incident. */
if (!isServer) exitWith { false };
params [["_record", [], [[]]]];
if (_record isEqualTo []) exitWith { false };

private _get = {
    params ["_pairs", "_key", "_def"];
    private _out = _def;
    { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _out = _x select 1; }; } forEach _pairs;
    _out
};
private _sid = [_record, "startdisp_id", ""] call _get;
private _taskId = [_record, "task_id", ""] call _get;
if (_sid isEqualTo "" || { _taskId isEqualTo "" }) exitWith { false };

private _records = ["startdisp_v1_records", []] call ARC_fnc_stateGet;
if (!(_records isEqualType [])) then { _records = []; };
_records pushBack _record;
["startdisp_v1_records", _records] call ARC_fnc_stateSet;

private _byTask = ["startdisp_v1_by_task", []] call ARC_fnc_stateGet;
if (!(_byTask isEqualType [])) then { _byTask = []; };
private _idx = -1;
{ if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _taskId }) exitWith { _idx = _forEachIndex; }; } forEach _byTask;
if (_idx < 0) then { _byTask pushBack [_taskId, _sid]; } else { _byTask set [_idx, [_taskId, _sid]]; };
["startdisp_v1_by_task", _byTask] call ARC_fnc_stateSet;

private _summary = [_record] call ARC_fnc_startdispBuildSummary;
["activeIncidentStartdispId", _sid] call ARC_fnc_stateSet;
["activeIncidentStartdispSummary", _summary] call ARC_fnc_stateSet;
["lastStartdispId", _sid] call ARC_fnc_stateSet;
["lastStartdispAt", serverTime] call ARC_fnc_stateSet;
missionNamespace setVariable ["ARC_activeIncidentStartdispId", _sid, true];
missionNamespace setVariable ["ARC_activeIncidentStartdispSummary", _summary, true];
true

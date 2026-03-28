/*
    Client: set the current BIS task for the local player UI.

    Params:
      0: STRING - taskId

    Why this exists:
      - The "current task" focus is local per-client.
      - We want the server to be able to direct the client UI without remoteExec'ing
        anonymous code blocks (which is not valid for remoteExecCall in practice).

    Notes:
      - Uses a short retry loop to avoid race conditions with task replication.
*/

if (!hasInterface) exitWith {false};

params [
    ["_taskId", "", [""]],
    ["_meta", [], [[]]]
];

if (!(_taskId isEqualType "")) exitWith {false};
if (_taskId isEqualTo "") exitWith {false};

// Provide a client-local "focus" channel for the Assigned Task Helper (ATH)
// so it can display non-incident tasks (orders, leads, etc.) when focused.
missionNamespace setVariable ["ARC_uiFocusTaskId", _taskId];
missionNamespace setVariable ["ARC_uiFocusTaskUpdatedAt", diag_tickTime];

if (_meta isEqualType [] && { (count _meta) > 0 }) then
{
    private _kvGet = {
        params ["_pairs", "_k", "_d"]; 
        if (!(_pairs isEqualType [])) exitWith { _d };
        private _idx = -1;
        { if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo _k }) exitWith { _idx = _forEachIndex; }; } forEach _pairs;
        if (_idx < 0) exitWith { _d };
        (_pairs select _idx) select 1
    };

    private _kind = [_meta, "kind", "TASK"] call _kvGet;
    if (!(_kind isEqualType "")) then { _kind = "TASK"; };
    missionNamespace setVariable ["ARC_uiFocusTaskKind", _kind];

    private _title = [_meta, "title", ""] call _kvGet;
    if (_title isEqualType "" && { !(_title isEqualTo "") }) then
    {
        missionNamespace setVariable ["ARC_uiFocusTaskTitle", _title];
    };

    private _pos = [_meta, "pos", []] call _kvGet;
    if (_pos isEqualType [] && { (count _pos) >= 2 }) then
    {
        _pos = +_pos; _pos resize 3;
        missionNamespace setVariable ["ARC_uiFocusTaskPos", _pos];
    };
};

[_taskId] spawn
{
    params ["_tid"];

    private _tries = 20;
    while {_tries > 0} do
    {
        // If the task hasn't propagated yet, taskSetCurrent can fail; retry briefly.
        private _ok = false;
        if (!isNil "BIS_fnc_taskSetCurrent") then
        {
            // Disable notifications here; the mission already manages messaging.
            private _rv = [_tid, false] call BIS_fnc_taskSetCurrent;
            _ok = (_rv isEqualType true) && { _rv };
        };

        if (_ok) exitWith {};

        _tries = _tries - 1;
        uiSleep 0.1;
    };
};

true

/*
    Server: after loading persisted state, ensure case parent tasks exist
    for any saved threads.

    Tasks are not persisted by Arma, so after a restart we must recreate
    the parent "case" tasks or child tasks won't have an anchor.

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

private _threads = ["threads", []] call ARC_fnc_stateGet;
if (!(_threads isEqualType [])) then { _threads = []; };

if (_threads isEqualTo []) exitWith { [] call ARC_fnc_threadBroadcast; true };

private _changed = false;
private _store = ["taskeng_v0_thread_store", createHashMap] call ARC_fnc_stateGet;
if (!(_store isEqualType createHashMap)) then { _store = createHashMap; };
private _storeChanged = false;

{
    private _thr = [_x] call ARC_fnc_threadNormalizeRecord;
    if (_thr isEqualTo []) then { continue; };

    private _id = _thr select 0;
    private _type = _thr select 1;
    private _zone = _thr select 2;
    private _base = _thr select 3;
    private _districtId = _thr select 14;
    if (_districtId isEqualTo "") then
    {
        _districtId = [_base] call ARC_fnc_threadResolveDistrictId;
        _thr set [14, _districtId];
        _threads set [_forEachIndex, _thr];
        _changed = true;
    };

    private _parent = [_id, _type, _zone, _base] call ARC_fnc_taskEnsureThreadParent;
    if (!(_parent isEqualTo "") && { !((_thr select 13) isEqualTo _parent) }) then
    {
        _thr set [13, _parent];
        _threads set [_forEachIndex, _thr];
        _changed = true;
    };

    // Sync thread_store (TASKENG v0 schema rev 4)
    if (!(_id isEqualTo "")) then {
        private _rec = createHashMap;
        _rec set ["thread_id", _id];
        _rec set ["type", _type];
        _rec set ["confidence", _thr select 4];
        _rec set ["heat", _thr select 5];
        _rec set ["parent_task_id", _thr select 13];
        _store set [_id, _rec];
        _storeChanged = true;
    };

} forEach _threads;

if (_changed) then
{
    ["threads", _threads] call ARC_fnc_stateSet;
};

if (_storeChanged) then
{
    ["taskeng_v0_thread_store", _store] call ARC_fnc_stateSet;
};

[] call ARC_fnc_threadBroadcast;
true

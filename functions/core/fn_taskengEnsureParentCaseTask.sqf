/* Compatibility adapter: one production ARC_case parent, one tuple value shape.
   The independent CASE creator is deprecated pending the separate v00 migration. */
if (!isServer) exitWith {""};
params [["_threadId", "", [""]]];
if (_threadId isEqualTo "") exitWith {""};
private _threads = ["threads", []] call ARC_fnc_stateGet;
if (!(_threads isEqualType [])) then {_threads = [];};
private _record = [];
private _index = -1;
{
    if (_x isEqualType [] && {count _x >= 14} && {(_x select 0) isEqualTo _threadId}) exitWith
    {_record = +_x; _index = _forEachIndex;};
} forEach _threads;
private _type = if (_index >= 0) then {_record select 1} else {"GENERIC"};
private _zone = if (_index >= 0) then {_record select 2} else {""};
private _pos = if (_index >= 0) then {_record select 3} else {[]};
private _parent = [_threadId,_type,_zone,_pos] call ARC_fnc_taskEnsureThreadParent;
if (_index >= 0 && {!(_parent isEqualTo "")}) then
{
    _record set [13,_parent];
    _threads set [_index,_record];
    ["threads",_threads] call ARC_fnc_stateSet;
    private _store = ["taskeng_v0_thread_store",createHashMap] call ARC_fnc_stateGet;
    if (!(_store isEqualType createHashMap)) then {_store = createHashMap;};
    _store set [_threadId,+_record];
    ["taskeng_v0_thread_store",_store] call ARC_fnc_stateSet;
};
_parent

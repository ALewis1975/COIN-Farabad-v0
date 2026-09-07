/* Attach current task actors to the existing threat record and cleanup owner. */
if (!isServer) exitWith {false};
params [["_threatId", "", [""]], ["_taskId", "", [""]], ["_objects", [], [[]]], ["_units", [], [[]]]];
if !((["activeTaskId", ""] call ARC_fnc_stateGet) isEqualTo _taskId) exitWith {false};
if !((["activeIedThreatId", ""] call ARC_fnc_stateGet) isEqualTo _threatId) exitWith {false};
if (["activeIncidentCloseReady", false] call ARC_fnc_stateGet) exitWith {false};
if (_threatId isEqualTo "" || {_taskId isEqualTo ""}) exitWith {false};
private _get = {
    params ["_pairs", "_key", "_default"];
    private _out = _default;
    { if (_x isEqualType [] && {count _x >= 2} && {(_x select 0) isEqualTo _key}) exitWith { _out = _x select 1; }; } forEach _pairs;
    _out
};
private _set = {
    params ["_pairs", "_key", "_value"];
    private _i = -1;
    { if (_x isEqualType [] && {count _x >= 2} && {(_x select 0) isEqualTo _key}) exitWith { _i = _forEachIndex; }; } forEach _pairs;
    if (_i < 0) then { _pairs pushBack [_key, _value]; } else { _pairs set [_i, [_key, _value]]; };
    _pairs
};
private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
private _idx = -1;
{ if (([_x, "threat_id", ""] call _get) isEqualTo _threatId) exitWith { _idx = _forEachIndex; }; } forEach _records;
if (_idx < 0) exitWith {false};
private _rec = _records select _idx;
if !(([[ _rec, "links", []] call _get, "task_id", ""] call _get) isEqualTo _taskId) exitWith {false};
if !(([_rec, "state", ""] call _get) in ["ACTIVE", "STAGED", "DISCOVERED"]) exitWith {false};
private _world = [_rec, "world", []] call _get;
private _label = format ["THREAT:%1:%2", toUpper ([_rec, "type", "IED"] call _get), _threatId];
private _objIds = [_world, "objects_net_ids", []] call _get;
private _unitIds = [_world, "units_net_ids", []] call _get;
private _groupIds = [_world, "groups_net_ids", []] call _get;
private _actors = (_objects + _units) select { !isNull _x && {!isPlayer _x} };
if (_actors isEqualTo []) exitWith {false};
{
    _x setVariable ["ARC_threatId", _threatId, true];
    _x setVariable ["ARC_threatTaskId", _taskId, true];
    _x setVariable ["ARC_threatCleanupLabel", _label, true];
    _x setVariable ["ARC_cleanupDeferTaskId", _taskId, false];
} forEach _actors;
{ if (!isNull _x) then { _objIds pushBackUnique (netId _x); }; } forEach _objects;
{
    if (!isNull _x) then {
        _unitIds pushBackUnique (netId _x);
        if (!isNull (group _x)) then { _groupIds pushBackUnique (netId (group _x)); };
    };
} forEach _units;
_world = [_world, "spawned", true] call _set;
_world = [_world, "spawned_at", serverTime] call _set;
_world = [_world, "cleanup_completed", false] call _set;
_world = [_world, "objects_net_ids", _objIds] call _set;
_world = [_world, "units_net_ids", _unitIds] call _set;
_world = [_world, "groups_net_ids", _groupIds] call _set;
_world = [_world, "cleanup_label", _label] call _set;
_rec = [_rec, "world", _world] call _set;
_rec = [_rec, "updated_ts", serverTime] call _set;
_rec = [_rec, "rev", ([_rec, "rev", 1] call _get) + 1] call _set;
_records set [_idx, _rec];
["threat_v0_records", _records] call ARC_fnc_stateSet;
private _pos = getPosATL (_actors select 0);
private _minDelay = missionNamespace getVariable ["ARC_cleanupMinDelaySec", 25];
if !(_minDelay isEqualType 0) then { _minDelay = 25; };
[_actors, _pos, -1, (_minDelay max 0) min 600, _label] call ARC_fnc_cleanupRegister;
["OPS", format ["THREAT_WORLD_SPAWNED %1", _threatId], _pos, [["event", "THREAT_WORLD_SPAWNED"], ["threat_id", _threatId], ["task_id", _taskId], ["actor", "SYSTEM"], ["ts", serverTime], ["objects", _objIds], ["units", _unitIds]]] call ARC_fnc_intelLog;
true

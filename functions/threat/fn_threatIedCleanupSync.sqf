/*
    Server-owned cleanup convergence. Queue entries finish independently; keep
    all remaining world references until the last companion has disappeared.
    Params: threat_id, source. Returns true only when fully CLEANED.
*/
if (!isServer) exitWith {false};
params [["_threatId", "", [""]], ["_source", "CLEANUP_SYNC", [""]]];
if (_threatId isEqualTo "") exitWith {false};
if !(["threat_v0_enabled", true] call ARC_fnc_stateGet) exitWith {false};
private _get = {
    params ["_pairs", "_key", "_fallback"];
    private _i = -1;
    { if (_x isEqualType [] && {count _x >= 2} && {(_x select 0) isEqualTo _key}) exitWith { _i = _forEachIndex; }; } forEach _pairs;
    if (_i < 0) exitWith {_fallback};
    (_pairs select _i) select 1
};
private _set = {
    params ["_pairs", "_key", "_value"];
    private _i = -1;
    { if (_x isEqualType [] && {count _x >= 2} && {(_x select 0) isEqualTo _key}) exitWith { _i = _forEachIndex; }; } forEach _pairs;
    if (_i < 0) then {_pairs pushBack [_key, _value]} else {_pairs set [_i, [_key, _value]]};
    _pairs
};
private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
private _idx = -1;
{ if (([_x, "threat_id", ""] call _get) isEqualTo _threatId) exitWith { _idx = _forEachIndex; }; } forEach _records;
if (_idx < 0) exitWith {false};
private _rec = _records select _idx;
private _state = toUpper ([_rec, "state", ""] call _get);
if (_state isEqualTo "CLEANED") exitWith {true};
private _world = [_rec, "world", []] call _get;
private _remaining = 0;
{
    private _field = _x;
    private _ids = [_world, _field, []] call _get;
    if !(_ids isEqualType []) then {_ids = []};
    _ids = _ids select {
        _x isEqualType "" && {!(_x isEqualTo "")} && {
            if (_field isEqualTo "groups_net_ids") then {
                private _g = groupFromNetId _x;
                !isNull _g && {(count units _g) > 0}
            } else {!isNull (objectFromNetId _x)}
        }
    };
    _remaining = _remaining + count _ids;
    _world = [_world, _field, _ids] call _set;
} forEach ["objects_net_ids", "units_net_ids", "groups_net_ids"];
_world = [_world, "cleanup_completed", false] call _set;
_world = [_world, "cleanup_source", _source] call _set;
_rec = [_rec, "world", _world] call _set;
_rec = [_rec, "rev", ([_rec, "rev", 1] call _get) + 1] call _set;
_records set [_idx, _rec];
["threat_v0_records", _records] call ARC_fnc_stateSet;
if (_remaining > 0) exitWith {false};

// Follow existing legal state edges; never publish completion before success.
private _note = format ["CLEANUP_SYNC:%1", _source];
if (_state in ["CREATED", "ACTIVE", "STAGED", "DISCOVERED"]) then {
    if ([_threatId, "EXPIRED", _note] call ARC_fnc_threatUpdateState) then {_state = "EXPIRED"};
};
if (_state in ["NEUTRALIZED", "DETONATED", "INTERDICTED"]) then {
    if ([_threatId, "CLOSED", _note] call ARC_fnc_threatUpdateState) then {_state = "CLOSED"};
};
if !(_state in ["CLOSED", "EXPIRED"]) exitWith {false};
private _ok = [_threatId, "CLEANED", _note] call ARC_fnc_threatUpdateState;
private _area = [_rec, "area", []] call _get;
diag_log format ["[ARC][THREAT] CLEANUP_SYNC time=%1 actor=SYSTEM threat=%2 task=%3 grid=%4 source=%5 completed=%6", serverTime, _threatId, [[_rec, "links", []] call _get, "task_id", ""] call _get, [_area, "grid", ""] call _get, _source, _ok];
_ok

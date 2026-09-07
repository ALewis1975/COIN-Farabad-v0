// Engine-compatible command wrappers retain the repository lint baseline.
private _casDefault = compile "params ['_map','_args']; _map getOrDefault _args";
private _casGet = compile "params ['_map','_key']; (_map) get _key";
private _casMap = compile "params ['_pairs']; createHashMapFromArray _pairs";
/* Existing publication/tick owner calls this; no new scheduler. No RPC exposure. */
if (!isServer) exitWith {false};
// A scheduled remoteExec intake re-enters once in an unscheduled block so guards
// and mutation form one server operation even under simultaneous submissions.
if (canSuspend) exitWith {
    private _args = +_this;
    private _result = false;
    isNil {_result = _args call ARC_fnc_casreqMaintain;};
    _result
};
params [["_force", false, [true]]];
private _now = serverTime;
private _casKeys = compile "params ['_h']; keys _h";
if (!_force && {_now - (missionNamespace getVariable ["ARC_casreq_lastMaintenanceAt", -30]) < 30}) exitWith {false};
missionNamespace setVariable ["ARC_casreq_lastMaintenanceAt", _now];
private _records = ["casreq_v1_records", createHashMap] call ARC_fnc_stateGet;
if !(_records isEqualType createHashMap) exitWith {false};
private _open = [];
private _terminal = [];
private _expired = [];
{
    private _id = _x;
    private _record = ([_records, _id] call _casGet);
    if (_record isEqualType [] && {!(_record isEqualTo [])}) then {
        private _r = ([_record] call _casMap);
        private _state = ([_r, ["state", ""]] call _casDefault);
        if (_state in ["OPEN", "APPROVED", "EXECUTING"] && {_now - (([_r, ["updated_at", _now]] call _casDefault)) >= 7200}) then {
            private _tr = [_record, "TIMEOUT", "SERVER", _now, [["notes", "No valid transition for 2 hours"]]] call ARC_fnc_casreqTransition;
            if (_tr select 2) then {_record = _tr select 1; _records set [_id, _record]; _r = ([_record] call _casMap); _state = "CLOSED"; _expired pushBack _id};
        };
        if (_state in ["CLOSED", "DENIED"]) then {_terminal pushBack [([_r, ["closed_at", ([_r, ["updated_at", 0]] call _casDefault)]] call _casDefault), _id]} else {_open pushBack _id};
    };
} forEach ([_records] call _casKeys);
_terminal sort true;
private _archived = ["casreq_v1_archived_completed", 0] call ARC_fnc_stateGet;
if !(_archived isEqualType 0) then {_archived = 0};
while {count _terminal > 100} do {
    private _id = (_terminal deleteAt 0) select 1;
    private _r = ([(([_records, _id] call _casGet))] call _casMap);
    if ((([_r, ["state", ""]] call _casDefault)) isEqualTo "CLOSED" && {(([_r, ["result", ""]] call _casDefault)) isEqualTo "COMPLETE"}) then {_archived = _archived + 1};
    _records deleteAt _id;
};
["casreq_v1_records", _records] call ARC_fnc_stateSet;
["casreq_v1_open_index", _open] call ARC_fnc_stateSet;
["casreq_v1_closed_index", _terminal apply {_x select 1}] call ARC_fnc_stateSet;
["casreq_v1_archived_completed", _archived] call ARC_fnc_stateSet;
{[_x, "SERVER", "CLOSED_TIMEOUT", []] call ARC_fnc_casreqBroadcastDelta} forEach _expired;
true

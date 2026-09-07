// Engine-compatible command wrappers retain the repository lint baseline.
private _casDefault = compile "params ['_map','_args']; _map getOrDefault _args";
private _casGet = compile "params ['_map','_key']; (_map) get _key";
private _casMap = compile "params ['_pairs']; createHashMapFromArray _pairs";
private _casTrim = compile "params ['_s']; trim _s";
/* COMPLETE supplies BDA notes; ABORT is requester/controller cancellation. TIMEOUT is internal. */
if (!isServer) exitWith {false};
// A scheduled remoteExec intake re-enters once in an unscheduled block so guards
// and mutation form one server operation even under simultaneous submissions.
if (canSuspend) exitWith {
    private _args = +_this;
    private _result = false;
    isNil {_result = _args call ARC_fnc_casreqClose;};
    _result
};
params [["_unit", objNull, [objNull]], ["_id", "", [""]], ["_result", "", [""]], ["_notes", "", [""]]];
private _reoOwner = remoteExecutedOwner;
if (!([_unit, "ARC_fnc_casreqClose", "CAS closure rejected: sender mismatch.", "CASREQ_CLOSE_SEC_DENIED", true, _reoOwner] call ARC_fnc_rpcValidateSender)) exitWith {false};
private _deny = {params ["_why"]; ["CAS closure rejected: " + _why] remoteExecCall ["ARC_fnc_clientHint", owner _unit]; false};
_result = toUpper (([_result] call _casTrim));
if (!(_result in ["COMPLETE", "ABORT"]) || {count _notes > 500} || {count _id > 32}) exitWith {["invalid result or notes"] call _deny};
private _record = [_id] call ARC_fnc_casreqSnapshotGet;
if (_record isEqualTo [] || {!([_unit, _result, _record] call ARC_fnc_casreqCan)}) exitWith {["unauthorized closure"] call _deny};
private _actor = [_unit] call ARC_fnc_rolesFormatUnit;
private _tr = [_record, _result, _actor, serverTime, [["notes", ([_notes] call _casTrim)]]] call ARC_fnc_casreqTransition;
if !(_tr select 0) exitWith {[_tr select 3] call _deny};
if !(_tr select 2) exitWith {true};
private _records = ["casreq_v1_records", createHashMap] call ARC_fnc_stateGet;
_records set [_id, _tr select 1];
["casreq_v1_records", _records] call ARC_fnc_stateSet;
[true] call ARC_fnc_casreqMaintain;
[_id, _actor, "CLOSED_" + _result, [["notes", _notes]]] call ARC_fnc_casreqBroadcastDelta;
private _r = ([(_tr select 1)] call _casMap);
private _area = ([(([_r, "area"] call _casGet))] call _casMap);
["CASREQ", format ["%1 closed %2", _id, _result], ([_area, ["target_pos", [0,0,0]]] call _casDefault), [["notes", _notes], ["actor", _actor], ["casreq_id", _id]]] call ARC_fnc_intelLog;
true

// Engine-compatible command wrappers retain the repository lint baseline.
private _casDefault = compile "params ['_map','_args']; _map getOrDefault _args";
private _casGet = compile "params ['_map','_key']; (_map) get _key";
private _casMap = compile "params ['_pairs']; createHashMapFromArray _pairs";
/* Assigned crew/controller execution through the existing compact API. */
if (!isServer) exitWith {false};
// A scheduled remoteExec intake re-enters once in an unscheduled block so guards
// and mutation form one server operation even under simultaneous submissions.
if (canSuspend) exitWith {
    private _args = +_this;
    private _result = false;
    isNil {_result = _args call ARC_fnc_casreqExecute;};
    _result
};
params [["_unit", objNull, [objNull]], ["_id", "", [""]], ["_ttt", -1, [0]]];
private _reoOwner = remoteExecutedOwner;
if (!([_unit, "ARC_fnc_casreqExecute", "CAS execution rejected: sender mismatch.", "CASREQ_EXECUTE_SEC_DENIED", true, _reoOwner] call ARC_fnc_rpcValidateSender)) exitWith {false};
private _deny = {params ["_why"]; ["CAS execution rejected: " + _why] remoteExecCall ["ARC_fnc_clientHint", owner _unit]; false};
if (count _id > 32 || {!finite _ttt} || {_ttt < -1} || {_ttt > 7200}) exitWith {["invalid timing or ID"] call _deny};
private _record = [_id] call ARC_fnc_casreqSnapshotGet;
if (_record isEqualTo [] || {!([_unit, "EXECUTE", _record] call ARC_fnc_casreqCan)}) exitWith {["assigned crew/controller required"] call _deny};
private _r = ([_record] call _casMap);
if ((([_r, "state"] call _casGet)) isEqualTo "EXECUTING") exitWith {true};
private _availability = [] call ARC_fnc_casreqAirbaseAvailability;
private _av = ([_availability] call _casMap);
private _airborne = false;
private _uids = [];
{private _m = ([_x] call _casMap); if ((([_m, ["event", ""]] call _casDefault)) isEqualTo "APPROVED") then {_uids = ([_m, ["crew_uids", []]] call _casDefault)}} forEach (([_r, ["messages", []]] call _casDefault));
{private _a = _x; if (!isNull _a && {alive _a} && {(getPosATL _a select 2) > 5} && {({isPlayer _x && {getPlayerUID _x in _uids}} count (crew _a)) > 0}) exitWith {_airborne = true}} forEach (localNamespace getVariable ["ARC_casreq_attackObjects", []]);
if (!(([_av, ["available", false]] call _casDefault)) && {!_airborne}) exitWith {["attack aircraft unavailable"] call _deny};
private _actor = [_unit] call ARC_fnc_rolesFormatUnit;
private _tr = [_record, "EXECUTING", _actor, serverTime, [["ttt", _ttt], ["airbase_availability", _availability]]] call ARC_fnc_casreqTransition;
if !(_tr select 0) exitWith {[_tr select 3] call _deny};
private _records = ["casreq_v1_records", createHashMap] call ARC_fnc_stateGet;
_records set [_id, _tr select 1];
["casreq_v1_records", _records] call ARC_fnc_stateSet;
[true] call ARC_fnc_casreqMaintain;
[_id, _actor, "EXECUTING", []] call ARC_fnc_casreqBroadcastDelta;
true

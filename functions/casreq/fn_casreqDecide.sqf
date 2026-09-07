// Engine-compatible command wrappers retain the repository lint baseline.
private _casDefault = compile "params ['_map','_args']; _map getOrDefault _args";
private _casGet = compile "params ['_map','_key']; (_map) get _key";
private _casMap = compile "params ['_pairs']; createHashMapFromArray _pairs";
private _casTrim = compile "params ['_s']; trim _s";
/* Controller decision. Optional fifth argument selects an aircraft; never accepts client UID lists. */
if (!isServer) exitWith {false};
// A scheduled remoteExec intake re-enters once in an unscheduled block so guards
// and mutation form one server operation even under simultaneous submissions.
if (canSuspend) exitWith {
    private _args = +_this;
    private _result = false;
    isNil {_result = _args call ARC_fnc_casreqDecide;};
    _result
};
params [["_unit", objNull, [objNull]], ["_id", "", [""]], ["_decision", "", [""]], ["_reason", "", [""]], ["_aircraft", objNull, [objNull]]];
private _reoOwner = remoteExecutedOwner;
if (!([_unit, "ARC_fnc_casreqDecide", "CAS decision rejected: sender mismatch.", "CASREQ_DECIDE_SEC_DENIED", true, _reoOwner] call ARC_fnc_rpcValidateSender)) exitWith {false};
private _deny = {params ["_why"]; ["CAS decision rejected: " + _why] remoteExecCall ["ARC_fnc_clientHint", owner _unit]; false};
if (!([_unit, "DECIDE"] call ARC_fnc_casreqCan)) exitWith {["controller required"] call _deny};
_decision = toUpper (([_decision] call _casTrim));
if (!(_decision in ["APPROVED", "DENIED"]) || {count _reason > 500} || {count _id > 32}) exitWith {["invalid decision"] call _deny};
private _record = [_id] call ARC_fnc_casreqSnapshotGet;
if (_record isEqualTo []) exitWith {["unknown request"] call _deny};
private _r = ([_record] call _casMap);
if ((([_r, "state"] call _casGet)) isEqualTo _decision) exitWith {true};
if ((([_r, "state"] call _casGet)) != "OPEN") exitWith {["request is no longer open"] call _deny};
private _availability = [] call ARC_fnc_casreqAirbaseAvailability;
private _av = ([_availability] call _casMap);
private _crewUids = [];
private _assetOk = true;
if (_decision isEqualTo "APPROVED") then {
    private _allowedAircraft = localNamespace getVariable ["ARC_casreq_attackObjects", []];
    _assetOk = !isNull _aircraft && {alive _aircraft} && {_aircraft in _allowedAircraft};
    if (_assetOk) then {
        {if (isPlayer _x && {side group _x == west}) then {_crewUids pushBackUnique (getPlayerUID _x)}} forEach crew _aircraft;
        _assetOk = count _crewUids > 0;
    };
    // A selected aircraft already airborne does not need a second parked asset.
    private _airborne = _assetOk && {(getPosATL _aircraft select 2) > 5};
    _assetOk = _assetOk && {(([_av, ["available", false]] call _casDefault)) || _airborne};
};
if (!_assetOk) exitWith {[format ["select a ready or airborne attack aircraft with player crew (AIRBASESUB: %1)", [_av, ["reason", "UNAVAILABLE"]] call _casDefault]] call _deny};
private _actor = [_unit] call ARC_fnc_rolesFormatUnit;
private _aircraftVar = "";
{if ((_x select 1) isEqualTo _aircraft) exitWith {_aircraftVar = _x select 0}} forEach (localNamespace getVariable ["ARC_casreq_attackObjectRows", []]);
private _extra = [["reason", ([_reason] call _casTrim)], ["crew_uids", _crewUids], ["aircraft_var", _aircraftVar], ["airbase_availability", _availability]];
private _tr = [_record, _decision, _actor, serverTime, _extra] call ARC_fnc_casreqTransition;
if !(_tr select 0) exitWith {[_tr select 3] call _deny};
if !(_tr select 2) exitWith {true};
private _records = ["casreq_v1_records", createHashMap] call ARC_fnc_stateGet;
_records set [_id, _tr select 1];
["casreq_v1_records", _records] call ARC_fnc_stateSet;
[true] call ARC_fnc_casreqMaintain;
[_id, _actor, _decision, [["reason", _reason]]] call ARC_fnc_casreqBroadcastDelta;
true

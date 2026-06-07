/*
    ARC_fnc_casreqExecute

    Server-only: mark an approved CASREQ as EXECUTING (aircraft on station).

    Params:
      0: OBJECT - unit invoking (typically the pilot or S3)
      1: STRING - casreq_id
      2: NUMBER - time-to-target in seconds (TTT, optional, -1 = unknown)

    Returns: BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_unit",   objNull, [objNull]],
    ["_id",     "",      [""]],
    ["_ttt",    -1,      [0]]
];

private _reoOwner = if (!isNil "remoteExecutedOwner") then { remoteExecutedOwner } else { -1 };
if (!([_unit, "ARC_fnc_casreqExecute", "CASREQ execute rejected: sender mismatch.", "CASREQ_EXECUTE_SEC_DENIED", true, _reoOwner] call ARC_fnc_rpcValidateSender)) exitWith {false};

if (_id isEqualTo "") exitWith {false};

private _records = ["casreq_v1_records", createHashMap] call ARC_fnc_stateGet;
if (!(_records isEqualType createHashMap)) exitWith {false};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _record = [_records, _id, []] call _hg;
if (!(_record isEqualType []) || { _record isEqualTo [] }) exitWith
{
    diag_log format ["[ARC][CASREQ] casreqExecute: record %1 not found.", _id];
    false
};

private _stateIdx = -1;
{ if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "state" }) exitWith { _stateIdx = _forEachIndex; }; } forEach _record;
if (_stateIdx < 0) exitWith { false };

private _curState = toUpper ((_record select _stateIdx) select 1);
if (_curState isEqualTo "EXECUTING") exitWith { true };
if (!(_curState in ["APPROVED"])) exitWith
{
    diag_log format ["[ARC][CASREQ] casreqExecute: %1 in state %2, needs APPROVED first.", _id, _curState];
    false
};

private _pairGet = {
    params ["_pairs", "_key", "_def"];
    private _out = _def;
    { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _out = _x select 1; }; } forEach _pairs;
    _out
};

private _airbaseAvailability = [];
if (!isNil "ARC_fnc_casreqAirbaseAvailability") then { _airbaseAvailability = [] call ARC_fnc_casreqAirbaseAvailability; };
if (!(_airbaseAvailability isEqualType [])) then { _airbaseAvailability = []; };

if (!([_airbaseAvailability, "available", true] call _pairGet)) exitWith
{
    private _reasonAir = [_airbaseAvailability, "reason", "AIRBASE_UNAVAILABLE"] call _pairGet;
    diag_log format ["[ARC][CASREQ] casreqExecute: %1 execution blocked by AIRBASESUB availability (%2).", _id, _reasonAir];
    if (!isNull _unit) then {
        [format ["CASREQ execution blocked: AIRBASESUB reports %1.", _reasonAir]] remoteExec ["ARC_fnc_clientHint", owner _unit];
    };
    false
};

(_record select _stateIdx) set [1, "EXECUTING"];

private _now = serverTime;
private _updIdx = -1;
{ if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "updated_at" }) exitWith { _updIdx = _forEachIndex; }; } forEach _record;
if (_updIdx >= 0) then { (_record select _updIdx) set [1, _now]; };

private _msgIdx = -1;
{ if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "messages" }) exitWith { _msgIdx = _forEachIndex; }; } forEach _record;
if (_msgIdx >= 0) then
{
    private _msgs = (_record select _msgIdx) select 1;
    if (!(_msgs isEqualType [])) then { _msgs = []; };
    private _actor = if (!isNull _unit) then { [_unit] call ARC_fnc_rolesFormatUnit } else { "SYSTEM" };
    _msgs pushBack [["event", "EXECUTING"], ["at", _now], ["by", _actor], ["ttt", _ttt], ["airbase_availability", _airbaseAvailability]];
    (_record select _msgIdx) set [1, _msgs];
};

private _airIdx = -1;
{ if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "airbase_availability" }) exitWith { _airIdx = _forEachIndex; }; } forEach _record;
if (_airIdx >= 0) then { (_record select _airIdx) set [1, _airbaseAvailability]; } else { _record pushBack ["airbase_availability", _airbaseAvailability]; };

_records set [_id, _record];
["casreq_v1_records", _records] call ARC_fnc_stateSet;

[_id, if (!isNull _unit) then { [_unit] call ARC_fnc_rolesFormatUnit } else { "SYSTEM" }, "EXECUTING", [["ttt", _ttt]]] call ARC_fnc_casreqBroadcastDelta;

diag_log format ["[ARC][CASREQ] casreqExecute: %1 now EXECUTING ttt=%2.", _id, _ttt];
true

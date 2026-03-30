/*
    ARC_fnc_casreqClose

    Server-only: close a CASREQ with a final result.

    Params:
      0: OBJECT - unit invoking
      1: STRING - casreq_id
      2: STRING - result: "COMPLETE" | "ABORT" | "TIMEOUT"
      3: STRING - notes (optional)

    Returns: BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_unit",   objNull, [objNull]],
    ["_id",     "",      [""]],
    ["_result", "",      [""]],
    ["_notes",  "",      [""]]
];

if (_id isEqualTo "") exitWith {false};

private _trimFn = compile "params ['_s']; trim _s";
private _resU = toUpper ([_result] call _trimFn);
if (!(_resU in ["COMPLETE", "ABORT", "TIMEOUT"])) exitWith
{
    diag_log format ["[ARC][CASREQ] casreqClose: invalid result '%1' for %2.", _result, _id];
    false
};

private _records = ["casreq_v1_records", createHashMap] call ARC_fnc_stateGet;
if (!(_records isEqualType createHashMap)) exitWith {false};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _record = [_records, _id, []] call _hg;
if (!(_record isEqualType []) || { _record isEqualTo [] }) exitWith
{
    diag_log format ["[ARC][CASREQ] casreqClose: record %1 not found.", _id];
    false
};

private _stateIdx = -1;
{ if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "state" }) exitWith { _stateIdx = _forEachIndex; }; } forEach _record;
if (_stateIdx < 0) exitWith { false };

private _curState = toUpper ((_record select _stateIdx) select 1);
if (_curState isEqualTo "CLOSED") exitWith { true };

(_record select _stateIdx) set [1, "CLOSED"];

private _now = serverTime;

// Set closed_at
private _cIdx = -1;
{ if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "closed_at" }) exitWith { _cIdx = _forEachIndex; }; } forEach _record;
if (_cIdx >= 0) then { (_record select _cIdx) set [1, _now]; };

// Set result
private _rIdx = -1;
{ if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "result" }) exitWith { _rIdx = _forEachIndex; }; } forEach _record;
if (_rIdx >= 0) then { (_record select _rIdx) set [1, _resU]; };

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
    _msgs pushBack [["event", format ["CLOSED_%1", _resU]], ["at", _now], ["by", _actor], ["notes", _notes]];
    (_record select _msgIdx) set [1, _msgs];
};

_records set [_id, _record];
["casreq_v1_records", _records] call ARC_fnc_stateSet;

// Move from open to closed index
private _openIdx = ["casreq_v1_open_index", []] call ARC_fnc_stateGet;
if (_openIdx isEqualType []) then
{
    private _pos = -1;
    { if (_x isEqualTo _id) exitWith { _pos = _forEachIndex; }; } forEach _openIdx;
    if (_pos >= 0) then { _openIdx deleteAt _pos; };
    ["casreq_v1_open_index", _openIdx] call ARC_fnc_stateSet;
};

private _closedIdx = ["casreq_v1_closed_index", []] call ARC_fnc_stateGet;
if (!(_closedIdx isEqualType [])) then { _closedIdx = []; };
_closedIdx pushBackUnique _id;
["casreq_v1_closed_index", _closedIdx] call ARC_fnc_stateSet;

[_id, if (!isNull _unit) then { [_unit] call ARC_fnc_rolesFormatUnit } else { "SYSTEM" }, format ["CLOSED_%1", _resU], [["result", _resU]]] call ARC_fnc_casreqBroadcastDelta;

// Log to OPS intel for traceability
private _logLine = format ["CASREQ %1 closed: %2.", _id, _resU];
if (_notes isEqualType "" && { !(_notes isEqualTo "") }) then
{
    _logLine = _logLine + format [" Notes: %1", _notes];
};
["OPS", _logLine, [0,0,0], [["event", "CASREQ_CLOSED"], ["casreq_id", _id], ["result", _resU]]] call ARC_fnc_intelLog;

diag_log format ["[ARC][CASREQ] casreqClose: %1 closed with result=%2.", _id, _resU];
true

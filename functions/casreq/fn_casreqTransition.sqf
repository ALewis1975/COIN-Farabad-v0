/* Pure compact transition, not an RPC. Returns [ok, copiedRecord, changed, reason].
   Authorization and server-owned actor/assignment metadata belong to the RPCs. */
params [["_record", [], [[]]], ["_action", "", [""]], ["_actor", "SERVER", [""]], ["_now", 0, [0]], ["_extra", [], [[]]]];
if (_record isEqualTo []) exitWith {[false, [], false, "UNKNOWN_REQUEST"]};
private _copy = +_record;
private _get = {
    params ["_pairs", "_key", "_default"];
    private _idx = -1;
    {if ((_x select 0) isEqualTo _key) exitWith {_idx = _forEachIndex}} forEach _pairs;
    if (_idx < 0) then {_default} else {(_pairs select _idx) select 1}
};
private _state = [_copy, "state", ""] call _get;
_action = toUpper _action;
private _result = [_copy, "result", ""] call _get;
private _notes = [_extra, "notes", ""] call _get;
private _hasBda = ({!(_x in [9,10,13,32])} count (toArray _notes)) > 0;
private _same = (_action isEqualTo _state && {_action in ["APPROVED", "DENIED", "EXECUTING"]}) || {_state isEqualTo "CLOSED" && {_action isEqualTo _result}};
if (_same) exitWith {[true, _copy, false, "ALREADY_APPLIED"]};
private _allowed = switch (_action) do {
    case "APPROVED": {_state isEqualTo "OPEN"};
    case "DENIED": {_state isEqualTo "OPEN"};
    case "EXECUTING": {_state isEqualTo "APPROVED"};
    case "COMPLETE": {_state isEqualTo "EXECUTING" && _hasBda};
    case "ABORT": {_state in ["OPEN", "APPROVED", "EXECUTING"]};
    case "TIMEOUT": {_state in ["OPEN", "APPROVED", "EXECUTING"]};
    default {false};
};
if (!_allowed) exitWith {[false, _copy, false, "INVALID_STATE_OR_MISSING_BDA"]};
private _terminal = _action in ["COMPLETE", "ABORT", "TIMEOUT", "DENIED"];
private _next = if (_action in ["COMPLETE", "ABORT", "TIMEOUT"]) then {"CLOSED"} else {_action};
private _set = {
    params ["_key", "_value"];
    private _idx = -1;
    {if ((_x select 0) isEqualTo _key) exitWith {_idx = _forEachIndex}} forEach _copy;
    if (_idx < 0) then {_copy pushBack [_key, _value]} else {_copy set [_idx, [_key, _value]]};
};
["state", _next] call _set;
["updated_at", _now] call _set;
if (_terminal) then { ["closed_at", _now] call _set; ["result", _action] call _set; };
private _messages = +([_copy, "messages", []] call _get);
private _message = [["event", if (_next isEqualTo "CLOSED") then {"CLOSED_" + _action} else {_action}], ["at", _now], ["by", _actor]];
_message append _extra;
_messages pushBack _message;
// Keep the opening identity and recent lifecycle events; a valid lifecycle needs <=4.
if (count _messages > 16) then {_messages = [_messages select 0] + (_messages select [(count _messages) - 15, 15])};
["messages", _messages] call _set;
if (({(_x select 0) isEqualTo "airbase_availability"} count _extra) > 0) then {["airbase_availability", [_extra, "airbase_availability", []] call _get] call _set};
[true, _copy, true, "OK"]

/*
    ARC_fnc_supplyLedgerAppend
    Append a bounded SUPPLYLEDGER v1 event. Server single-writer.
*/

if (!isServer) exitWith { [] };

params [
    ["_eventType", "SUPPLY_MANUAL_ADJUST", [""]],
    ["_delta", [], [[]]],
    ["_before", [], [[]]],
    ["_after", [], [[]]],
    ["_actor", "SERVER", [""]],
    ["_taskId", "", [""]],
    ["_meta", [], [[]]]
];
private _trimFn = compile "params ['_s']; trim _s";

_eventType = toUpper ([_eventType] call _trimFn);
if !(_eventType in ["SUPPLY_INIT", "SUPPLY_AMBIENT_DRAIN", "SUPPLY_LAUNCH_COST", "SUPPLY_MANUAL_ADJUST", "SUPPLY_RESET"]) then
{
    _eventType = "SUPPLY_MANUAL_ADJUST";
};

private _seq = ["supply_v1_seq", 0] call ARC_fnc_stateGet;
if (!(_seq isEqualType 0) || { _seq < 0 }) then { _seq = 0; };
_seq = _seq + 1;
["supply_v1_seq", _seq] call ARC_fnc_stateSet;

private _entry = [
    ["v", 1],
    ["seq", _seq],
    ["type", _eventType],
    ["ts", serverTime],
    ["actor", _actor],
    ["task_id", _taskId],
    ["delta", _delta],
    ["before", _before],
    ["after", _after],
    ["meta", _meta]
];

private _ledger = ["supply_v1_ledger", []] call ARC_fnc_stateGet;
if (!(_ledger isEqualType [])) then { _ledger = []; };
_ledger pushBack _entry;

private _max = ["supply_v1_ledger_max", 300] call ARC_fnc_stateGet;
if (!(_max isEqualType 0) || { _max < 1 }) then { _max = 300; };
_max = (_max max 25) min 1000;
if ((count _ledger) > _max) then
{
    _ledger = _ledger select [((count _ledger) - _max), _max];
};

["supply_v1_ledger", _ledger] call ARC_fnc_stateSet;
["supply_v1_debug_last_event", _entry] call ARC_fnc_stateSet;
_entry

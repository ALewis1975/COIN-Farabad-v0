/*
    Utility: move a queued flight to the front.
    Params: [ARRAY queue, STRING flightId]
    Returns: [ARRAY queueOut, BOOL moved, ARRAY movedItem]
*/

params [
    ["_queue", [], [[]]],
    ["_flightId", "", [""]]
];

// sqflint-compat helpers
private _trimFn     = compile "params ['_s']; trim _s";
private _findIfFn   = compile "params ['_arr','_cond']; private _r = -1; { if (_x call _cond) exitWith { _r = _forEachIndex; }; } forEach _arr; _r";
private _insertFn = compile "params ['_arr','_pos','_items']; _arr insert [_pos, _items]";

if (!(_queue isEqualType [])) then { _queue = []; };
if (!(_flightId isEqualType "")) then { _flightId = ""; };
_flightId = [_flightId] call _trimFn;

if (_flightId isEqualTo "") exitWith { [_queue, false, []] };

private _idx = -1;
{ if (((_x param [0, ""]) isEqualTo _flightId)) exitWith { _idx = _forEachIndex; }; } forEach _queue;
if (_idx < 0) exitWith { [_queue, false, []] };

private _item = _queue deleteAt _idx;
[_queue, 0, [_item] call _insertFn];

[_queue, true, _item]

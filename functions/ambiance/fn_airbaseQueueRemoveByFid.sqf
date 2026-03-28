/*
    Utility: remove a queued flight by fid.
    Params: [ARRAY queue, STRING flightId]
    Returns: [ARRAY queueOut, BOOL removed, ARRAY removedItem]
*/

params [
    ["_queue", [], [[]]],
    ["_flightId", "", [""]]
];

private _trimFn = compile "params ['_s']; trim _s";

if (!(_queue isEqualType [])) then { _queue = []; };
if (!(_flightId isEqualType "")) then { _flightId = ""; };
_flightId = [_flightId] call _trimFn;

if (_flightId isEqualTo "") exitWith { [_queue, false, []] };

private _idx = -1;
{ if ((_x param [0, ""]) isEqualTo _flightId) exitWith { _idx = _forEachIndex; }; } forEach _queue;
if (_idx < 0) exitWith { [_queue, false, []] };

private _item = _queue deleteAt _idx;
[_queue, true, _item]

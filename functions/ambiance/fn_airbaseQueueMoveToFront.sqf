/*
    Utility: move a queued flight to the front.
    Params: [ARRAY queue, STRING flightId]
    Returns: [ARRAY queueOut, BOOL moved, ARRAY movedItem]
*/

params [
    ["_queue", [], [[]]],
    ["_flightId", "", [""]]
];

if (!(_queue isEqualType [])) then { _queue = []; };
if (!(_flightId isEqualType "")) then { _flightId = ""; };
_flightId = trim _flightId;

if (_flightId isEqualTo "") exitWith { [_queue, false, []] };

private _idx = -1;
{ if ((_x param [0, ""]) isEqualTo _flightId) exitWith { _idx = _forEachIndex; }; } forEach _queue;
if (_idx < 0) exitWith { [_queue, false, []] };

private _item = _queue deleteAt _idx;
_queue insert [0, [_item]];

[_queue, true, _item]

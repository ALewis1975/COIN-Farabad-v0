/*
    Utility: remove a queued flight by fid.
    Params: [ARRAY queue, STRING flightId]
    Returns: [ARRAY queueOut, BOOL removed, ARRAY removedItem]
*/

params [
    ["_queue", [], [[]]],
    ["_flightId", "", [""]]
];

if (!(_queue isEqualType [])) then { _queue = []; };
if (!(_flightId isEqualType "")) then { _flightId = ""; };
_flightId = trim _flightId;

if (_flightId isEqualTo "") exitWith { [_queue, false, []] };

private _idx = _queue findIf { ((_x param [0, ""]) isEqualTo _flightId) };
if (_idx < 0) exitWith { [_queue, false, []] };

private _item = _queue deleteAt _idx;
[_queue, true, _item]

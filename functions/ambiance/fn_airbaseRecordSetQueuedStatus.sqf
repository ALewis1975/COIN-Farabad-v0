/*
    Utility: update queued record status by flight id.
    Params: [ARRAY records, STRING flightId, STRING status, ARRAY metaAppend]
    Returns: [ARRAY recordsOut, BOOL updated]
*/

params [
    ["_records", [], [[]]],
    ["_flightId", "", [""]],
    ["_status", "", [""]],
    ["_metaAppend", [], [[]]]
];


// sqflint-compatible helpers
private _trimFn  = compile "params ['_s']; trim _s";
if (!(_records isEqualType [])) then { _records = []; };
if (!(_flightId isEqualType "")) then { _flightId = ""; };
if (!(_status isEqualType "")) then { _status = ""; };
if (!(_metaAppend isEqualType [])) then { _metaAppend = []; };

_flightId = [_flightId] call _trimFn;
_status = toUpper ([_status] call _trimFn);

if (_flightId isEqualTo "") exitWith { [_records, false] };
if !(_status in ["CANCELED", "PRIORITIZED", "ACTIVE", "COMPLETE", "FAILED"]) exitWith { [_records, false] };

private _idx = -1;
{ if ((_x param [0, ""]) isEqualTo _flightId) exitWith { _idx = _forEachIndex; }; } forEach _records;
if (_idx < 0) exitWith { [_records, false] };

private _rec = _records select _idx;
private _curr = _rec param [5, ""];

if ((!(_curr isEqualTo "QUEUED")) && { !(_status in ["ACTIVE", "COMPLETE", "FAILED"]) }) exitWith { [_records, false] };

_rec set [5, _status];
_rec set [6, serverTime];

private _meta = _rec param [7, []];
if (!(_meta isEqualType [])) then { _meta = []; };
{ _meta pushBack _x; } forEach _metaAppend;
_rec set [7, _meta];

_records set [_idx, _rec];
[_records, true]

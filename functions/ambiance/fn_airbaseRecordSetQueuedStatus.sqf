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

if (!(_records isEqualType [])) then { _records = []; };
if (!(_flightId isEqualType "")) then { _flightId = ""; };
if (!(_status isEqualType "")) then { _status = ""; };
if (!(_metaAppend isEqualType [])) then { _metaAppend = []; };

_flightId = trim _flightId;
_status = toUpperANSI (trim _status);

if (_flightId isEqualTo "") exitWith { [_records, false] };
if !(_status in ["CANCELED", "PRIORITIZED", "ACTIVE", "COMPLETE", "FAILED"]) exitWith { [_records, false] };

private _idx = _records findIf { ((_x param [0, ""]) isEqualTo _flightId) };
if (_idx < 0) exitWith { [_records, false] };

private _rec = _records # _idx;
private _curr = _rec param [5, ""];

if ((_curr isNotEqualTo "QUEUED") && { !(_status in ["ACTIVE", "COMPLETE", "FAILED"]) }) exitWith { [_records, false] };

_rec set [5, _status];
_rec set [6, serverTime];

private _meta = _rec param [7, []];
if (!(_meta isEqualType [])) then { _meta = []; };
{ _meta pushBack _x; } forEach _metaAppend;
_rec set [7, _meta];

_records set [_idx, _rec];
[_records, true]

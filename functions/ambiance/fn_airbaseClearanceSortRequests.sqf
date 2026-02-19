/*
    Utility: sort clearance requests by operational priority.
    Priority order:
      1) REQ_EMERGENCY
      2) PRIORITY arrivals/departures
      3) Routine arrivals/departures
      4) REQ_TAXI
*/
params [["_requests", [], [[]]]];
if (!(_requests isEqualType [])) exitWith { [] };

private _openStates = ["SUBMIT", "QUEUED", "PENDING", "AWAITING_TOWER_DECISION", "APPROVED", "ACTIVE"];

private _rankFor = {
    params ["_rec"];
    private _type = toUpperANSI (_rec param [1, ""]);
    private _status = toUpperANSI (_rec param [6, ""]);
    private _meta = _rec param [10, []];
    if (!(_meta isEqualType [])) then { _meta = []; };

    private _priorityClass = "ROUTINE";
    {
        if ((toLowerANSI str (_x param [0, ""])) isEqualTo "priorityclass") then {
            _priorityClass = toUpperANSI str (_x param [1, "ROUTINE"]);
        };
    } forEach _meta;

    private _openRank = if (_status in _openStates) then { 0 } else { 1 };
    if (_type isEqualTo "REQ_EMERGENCY") exitWith { [_openRank, 0] };

    private _isArrDep = _type in ["REQ_INBOUND", "REQ_LAND", "REQ_TAKEOFF"];
    if (_isArrDep && {_priorityClass isEqualTo "PRIORITY"}) exitWith { [_openRank, 1] };
    if (_isArrDep) exitWith { [_openRank, 2] };
    if (_type isEqualTo "REQ_TAXI") exitWith { [_openRank, 3] };

    [_openRank, 4]
};

private _decorated = [];
{
    private _rank = [_x] call _rankFor;
    _decorated pushBack [_rank param [0, 1], _rank param [1, 9], _x param [7, 0], _forEachIndex, _x];
} forEach _requests;

_decorated sort true;
_decorated apply { _x param [4, []] }

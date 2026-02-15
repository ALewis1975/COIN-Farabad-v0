/*
    ARC_fnc_intelUiQueueManagerRefresh

    Client UI: refresh the TOC Queue Manager list.

    Notes:
      - Prefer ARC_pub_queueTail when available so the UI can show pending + decided items,
        and so TOC can see downstream status after approval.
*/

if (!hasInterface) exitWith {false};

private _disp = uiNamespace getVariable ["ARC_queueMgr_display", displayNull];
if (isNull _disp) then { _disp = findDisplay 61000; };
if (isNull _disp) exitWith {false};

private _lb = _disp displayCtrl 61001;
private _detailsCtrl = _disp displayCtrl 61002;

// Preserve current selection by queueId if possible.
private _prevId = "";
private _curSel = lbCurSel _lb;
if (_curSel >= 0) then { _prevId = _lb lbData _curSel; };

lbClear _lb;

// Prefer the broadcast tail (pending + decided). Fallback to pending-only list.
private _q = missionNamespace getVariable ["ARC_pub_queueTail", []];
if (!(_q isEqualType [])) then { _q = []; };
if (_q isEqualTo []) then
{
    _q = missionNamespace getVariable ["ARC_pub_queue", []];
    if (!(_q isEqualType [])) then { _q = []; };
};

// Keep only valid queue items.
private _items = _q select { (_x isEqualType []) && { (count _x) >= 12 } };

// Split pending vs decided so pending stays on top for S3/Command.
private _pending = _items select {
    private _st = _x param [2, "", [""]];
    (toUpper _st) isEqualTo "PENDING"
};
private _decided = _items select {
    private _st = _x param [2, "", [""]];
    (toUpper _st) isNotEqualTo "PENDING"
};

// Sort pending oldest-first.
if ((count _pending) > 1) then
{
    _pending = [_pending, [], { _x # 1 }, "ASCEND"] call BIS_fnc_sortBy;
};

// Sort decided newest-first (for quick review).
if ((count _decided) > 1) then
{
    _decided = [_decided, [], { _x # 1 }, "DESCEND"] call BIS_fnc_sortBy;
};

_items = _pending + _decided;

private _getMeta = {
    private _pairs = _this param [0, [], [[]]];
    private _key = _this param [1, "", [""]];
    private _default = _this param [2, nil];

    if (!(_pairs isEqualType [])) exitWith { _default };
    if (_key isEqualTo "") exitWith { _default };

    private _idx = _pairs findIf {
        (_x isEqualType []) && { (count _x) >= 2 } && { (_x # 0) isEqualTo _key }
    };
    if (_idx < 0) exitWith { _default };
    (_pairs # _idx) # 1
};

private _statusColor = {
    params [ ["_stU", "", [""]] ];
    _stU = toUpper _stU;
    switch (_stU) do
    {
        case "PENDING":  { [1, 0.85, 0.15, 1] };
        case "APPROVED": { [0.55, 1, 0.55, 1] };
        case "REJECTED": { [1, 0.55, 0.55, 1] };
        default          { [0.9, 0.9, 0.9, 1] };
    };
};

{
    private _it = _x;

    private _qid = _it param [0, "", [""]];
    private _createdAt = _it param [1, -1, [0]];
    private _status = _it param [2, "UNKNOWN", [""]];
    private _kind = _it param [3, "", [""]];
    private _from = _it param [4, "", [""]];
    private _fromGroup = _it param [5, "", [""]];
    private _posATL = _it param [7, [], [[]]];
    private _sum = _it param [8, "", [""]];
    private _det = _it param [9, "", [""]];
    private _meta = _it param [11, [], [[]]];

    private _stU = toUpper _status;

    private _zone = [_meta, "zone", "Unzoned"] call _getMeta;
    if (!(_zone isEqualType "")) then { _zone = "Unzoned"; };

    private _grid = [_meta, "grid", ""] call _getMeta;
    if (!(_grid isEqualType "")) then { _grid = ""; };

    if (_grid isEqualTo "") then
    {
        if (_posATL isEqualType [] && { (count _posATL) >= 2 } && { (_posATL # 0) isEqualType 0 } && { (_posATL # 1) isEqualType 0 }) then
        {
            _grid = mapGridPosition _posATL;
        }
        else
        {
            _grid = "????";
        };
    };

    private _ageMin = 0;
    if (_createdAt isEqualType 0) then
    {
        _ageMin = floor ((serverTime - _createdAt) / 60);
        if (_ageMin < 0) then { _ageMin = 0; };
    };

    private _who = if (_fromGroup isEqualType "" && { _fromGroup != "" }) then { _fromGroup } else { _from };
    if (!(_who isEqualType "")) then { _who = ""; };

    private _line = format ["%1 | %2 | %3 | %4 | %5m | %6", _qid, _stU, _kind, _zone, _ageMin, _sum];
    private _row = _lb lbAdd _line;
    _lb lbSetData [_row, _qid];

    private _tipFmt = "Status: %1\nKind: %2\nFrom: %3\nZone: %4\nGrid: %5\n\n%6\n%7";
    private _tip = format [_tipFmt, _stU, _kind, _who, _zone, _grid, _sum, _det];
    _lb lbSetTooltip [_row, _tip];

    _lb lbSetColor [_row, [_stU] call _statusColor];
} forEach _items;

if ((count _items) isEqualTo 0) then
{
    _detailsCtrl ctrlSetStructuredText parseText "<t size='1.1'>No queue items.</t><br/><t size='0.9'>Requests appear here after player follow-ons or S2 lead requests.</t>";
    (_disp displayCtrl 61011) ctrlEnable false;
    (_disp displayCtrl 61012) ctrlEnable false;
    true
}
else
{
    // Restore selection.
    private _sel = 0;
    if (_prevId isNotEqualTo "") then
    {
        for "_i" from 0 to ((lbSize _lb) - 1) do
        {
            if ((_lb lbData _i) isEqualTo _prevId) exitWith { _sel = _i; };
        };
    };

    _lb lbSetCurSel _sel;
    [_lb, _sel] call ARC_fnc_intelUiQueueManagerUpdateDetails;
    true
};

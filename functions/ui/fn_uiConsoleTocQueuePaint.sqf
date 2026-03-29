/*
    ARC_fnc_uiConsoleTocQueuePaint

    Client UI: paint in-console TOC queue list + details for the CMD tab queue mode.

    Params:
      0: DISPLAY
      1: BOOL force list rebuild (default false)

    Returns:
      ARRAY [STRING selectedQueueId, BOOL selectedPending]
*/

if (!hasInterface) exitWith {["", false]};

params [
    ["_display", displayNull, [displayNull]],
    ["_forceRebuild", false, [true]]
];

if (isNull _display) exitWith {["", false]};

private _lb = _display displayCtrl 78011;
private _detailsCtrl = _display displayCtrl 78012;
if (isNull _lb || isNull _detailsCtrl) exitWith {["", false]};

private _getPair = {
    private _pairs = _this param [0, [], [[]]];
    private _k = _this param [1, "", [""]];
    private _d = _this param [2, nil];

    if (!(_pairs isEqualType [])) exitWith { _d };
    if (_k isEqualTo "") exitWith { _d };

    private _j = -1;
    { if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x # 0) isEqualTo _k }) exitWith { _j = _forEachIndex; }; } forEach _pairs;
    if (_j < 0) exitWith { _d };
    (_pairs # _j) # 1
};

private _statusColor = {
    params [["_stU", "", [""]]];
    switch (toUpper _stU) do
    {
        case "PENDING":  { [1, 0.85, 0.15, 1] };
        case "APPROVED": { [0.55, 1, 0.55, 1] };
        case "REJECTED": { [1, 0.55, 0.55, 1] };
        default          { [0.9, 0.9, 0.9, 1] };
    };
};

// Prefer the broadcast tail (pending + decided). Fallback to pending-only list.
private _q = missionNamespace getVariable ["ARC_pub_queueTail", []];
if (!(_q isEqualType [])) then { _q = []; };
if (_q isEqualTo []) then
{
    _q = missionNamespace getVariable ["ARC_pub_queue", []];
    if (!(_q isEqualType [])) then { _q = []; };
};

private _items = _q select { (_x isEqualType []) && { (count _x) >= 12 } };
private _pending = _items select { (toUpper (_x param [2, "", [""]])) isEqualTo "PENDING" };
private _decided = _items select { (toUpper (_x param [2, "", [""]])) isNotEqualTo "PENDING" };

if ((count _pending) > 1) then
{
    _pending = [_pending, [], { _x # 1 }, "ASCEND"] call BIS_fnc_sortBy;
};
if ((count _decided) > 1) then
{
    _decided = [_decided, [], { _x # 1 }, "DESCEND"] call BIS_fnc_sortBy;
};
_items = _pending + _decided;

private _selectedId = "";
private _curSel = lbCurSel _lb;
if (_curSel >= 0) then { _selectedId = _lb lbData _curSel; };

if (_forceRebuild) then
{
    lbClear _lb;

    {
        private _it = _x;
        private _qid = _it param [0, "", [""]];
        private _createdAt = _it param [1, -1, [0]];
        private _status = _it param [2, "UNKNOWN", [""]];
        private _kind = _it param [3, "", [""]];
        private _posATL = _it param [7, [], [[]]];
        private _sum = _it param [8, "", [""]];
        private _det = _it param [9, "", [""]];
        private _meta = _it param [11, [], [[]]];

        private _stU = toUpper _status;
        private _zone = [_meta, "zone", "Unzoned"] call _getPair;
        if (!(_zone isEqualType "")) then { _zone = "Unzoned"; };

        private _grid = [_meta, "grid", ""] call _getPair;
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

        private _line = format ["%1 | %2 | %3 | %4 | %5m | %6", _qid, _stU, _kind, _zone, _ageMin, _sum];
        private _row = _lb lbAdd _line;
        _lb lbSetData [_row, _qid];
        _lb lbSetTooltip [_row, format ["Status: %1\nKind: %2\nZone: %3\nGrid: %4\n\n%5\n%6", _stU, _kind, _zone, _grid, _sum, _det]];
        _lb lbSetColor [_row, [_stU] call _statusColor];
    } forEach _items;
};

if ((count _items) isEqualTo 0) exitWith
{
    _detailsCtrl ctrlSetStructuredText parseText "<t size='1.1'>No queue items.</t><br/><t size='0.9'>Requests appear here after player follow-ons or S2 lead requests.</t>";
    ["", false]
};

private _sel = 0;
if (_selectedId isNotEqualTo "") then
{
    for "_i" from 0 to ((lbSize _lb) - 1) do
    {
        if ((_lb lbData _i) isEqualTo _selectedId) exitWith { _sel = _i; };
    };
};
// Guard: lbSetCurSel fires onSelChanged synchronously; flag prevents re-entrant paint cycle.
uiNamespace setVariable ["ARC_console_cmdQueuePainting", true];
_lb lbSetCurSel _sel;
uiNamespace setVariable ["ARC_console_cmdQueuePainting", false];

private _qid = _lb lbData _sel;
if (_qid isEqualTo "") exitWith {["", false]};

private _it = [];
{
    if (_x isEqualType [] && { (count _x) >= 12 } && { (_x param [0, "", [""]]) isEqualTo _qid }) exitWith { _it = _x; };
} forEach _items;

if (_it isEqualTo []) exitWith
{
    _detailsCtrl ctrlSetStructuredText parseText format ["<t size='1.1'>%1</t><br/><t size='0.9'>Queue item not found in client snapshot (out of range / old).</t>", _qid];
    ["", false]
};

private _createdAt = _it param [1, -1, [0]];
private _status = _it param [2, "UNKNOWN", [""]];
private _kind = _it param [3, "", [""]];
private _from = _it param [4, "", [""]];
private _fromGroup = _it param [5, "", [""]];
private _posATL = _it param [7, [], [[]]];
private _sum = _it param [8, "", [""]];
private _det = _it param [9, "", [""]];
private _payload = _it param [10, [], [[]]];
private _meta = _it param [11, [], [[]]];
private _dec = _it param [12, [], [[]]];

private _stU = toUpper _status;
private _isPending = _stU isEqualTo "PENDING";

private _zone = [_meta, "zone", "Unzoned"] call _getPair;
if (!(_zone isEqualType "")) then { _zone = "Unzoned"; };

private _grid = [_meta, "grid", ""] call _getPair;
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

private _payloadTxt = "";
private _statusTxt = "";
private _kindU = toUpper _kind;
switch (_kindU) do
{
    case "LEAD_REQUEST":
    {
        private _leadType = [_payload, "leadType", "RECON"] call _getPair;
        private _dispName = [_payload, "displayName", _sum] call _getPair;
        private _pri = [_payload, "priority", 3] call _getPair;
        private _tag = [_payload, "tag", "S2_REQUEST"] call _getPair;

        if (!(_leadType isEqualType "")) then { _leadType = "RECON"; };
        if (!(_dispName isEqualType "")) then { _dispName = _sum; };
        if (!(_pri isEqualType 0)) then { _pri = 3; };
        if (!(_tag isEqualType "")) then { _tag = "S2_REQUEST"; };

        _payloadTxt = format ["Lead Request: <t color='#FFD700'>%1</t> (P%2)<br/>Grid: %3 | Zone: %4<br/>Tag: %5<br/>Title: %6", toUpper (trim _leadType), (_pri max 1) min 5, _grid, _zone, trim _tag, trim _dispName];
        if (_stU isEqualTo "APPROVED") then
        {
            _statusTxt = "Lead Status: APPROVED (follow-on handling shown in TOC lead/order views).";
        };
    };

    case "FOLLOWON_PACKAGE":
    {
        private _srcTask = [_payload, "sourceTaskId", ""] call _getPair;
        private _incType = [_payload, "sourceIncidentType", ""] call _getPair;
        private _res = [_payload, "result", ""] call _getPair;
        private _rec = [_payload, "recommendation", ""] call _getPair;
        private _purpose = [_payload, "purpose", ""] call _getPair;
        private _leadIds = [_payload, "leadIds", []] call _getPair;
        if (!(_leadIds isEqualType [])) then { _leadIds = []; };

        _payloadTxt = format [
            "Follow-on Package<br/>TaskId: %1 | Type: %2 | Result: <t color='#FFD700'>%3</t><br/>Recommendation: %4 %5<br/>Leads (%6): %7",
            _srcTask,
            toUpper (trim _incType),
            toUpper (trim _res),
            toUpper (trim _rec),
            toUpper (trim _purpose),
            count _leadIds,
            if ((count _leadIds) > 0) then { _leadIds joinString ", " } else { "None" }
        ];
    };

    case "FOLLOWON_REQUEST":
    {
        private _req = [_payload, "request", "RTB"] call _getPair;
        private _purpose = [_payload, "purpose", "REFIT"] call _getPair;
        private _reqGroup = [_payload, "requestorGroup", _fromGroup] call _getPair;

        if (!(_req isEqualType "")) then { _req = "RTB"; };
        if (!(_purpose isEqualType "")) then { _purpose = "REFIT"; };
        if (!(_reqGroup isEqualType "")) then { _reqGroup = _fromGroup; };

        _payloadTxt = format ["Follow-on Request: <t color='#FFD700'>%1</t><br/>Purpose: %2<br/>Requestor: %3", toUpper (trim _req), toUpper (trim _purpose), _reqGroup];
    };

    default
    {
        _payloadTxt = "";
    };
};

private _decTxt = "";
if (_dec isEqualType [] && { (count _dec) >= 4 }) then
{
    _dec params ["_decAt", "_decBy", "_decOk", "_decNote"];
    private _d = if (_decOk) then {"APPROVED"} else {"REJECTED"};

    private _decAge = 0;
    if (_decAt isEqualType 0) then
    {
        _decAge = floor ((serverTime - _decAt) / 60);
        if (_decAge < 0) then { _decAge = 0; };
    };

    if (!(_decNote isEqualType "")) then { _decNote = ""; };
    _decNote = trim _decNote;
    if (_decNote isEqualTo "") then { _decNote = "(no note)"; };

    _decTxt = format ["Decision: <t color='#FFD700'>%1</t> by %2 (%3m ago)<br/>Note: %4", _d, _decBy, _decAge, _decNote];
};

if (_payloadTxt isEqualTo "") then { _payloadTxt = "(No payload details)"; };

private _who = if (_fromGroup isEqualType "" && { _fromGroup != "" }) then { _fromGroup } else { _from };
if (!(_who isEqualType "")) then { _who = ""; };

private _hdr = format ["<t size='1.15'>%1</t><br/><t size='0.95'>Status: %2 | Kind: %3 | Age: %4m</t><br/><t size='0.9'>From: %5</t><br/><t size='0.9'>Grid: %6 | Zone: %7</t>", _qid, _stU, toUpper _kind, _ageMin, _who, _grid, _zone];
private _body = format ["<br/><t size='1.0'>%1</t><br/><t size='0.9'>%2</t>", _sum, _det];
private _extra = "";
if (_decTxt != "") then { _extra = format ["<br/><t size='0.95'>%1</t>", _decTxt]; };
if (_statusTxt != "") then { _extra = format ["%1<br/><t size='0.95'>%2</t>", _extra, _statusTxt]; };

_detailsCtrl ctrlSetStructuredText parseText (_hdr + _body + "<br/><t size='0.95'>" + _payloadTxt + "</t>" + _extra);

[_qid, _isPending]

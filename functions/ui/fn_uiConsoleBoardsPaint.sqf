/*
    ARC_fnc_uiConsoleBoardsPaint

    UI09: paint the BOARDS tab.

    Purpose:
      A TOC-style snapshot (at-a-glance) of:
        - Active incident status
        - TOC queue (pending)
        - Pending orders (ISSUED, awaiting ACK)
        - Last SITREP (from ops log)

    Params:
      0: DISPLAY

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

params [
    ["_display", displayNull, [displayNull]]
];

if (isNull _display) exitWith {false};

private _ctrlMain = _display displayCtrl 78010;
if (isNull _ctrlMain) exitWith {false};

// -------------------------------------------------------------------------
// Helpers
// -------------------------------------------------------------------------
private _getPair = {
    params ["_pairs", "_k", "_d"];
    if (!(_pairs isEqualType [])) exitWith { _d };
    private _idx = _pairs findIf { (_x isEqualType []) && { (count _x) >= 2 } && { (_x # 0) isEqualTo _k } };
    if (_idx < 0) exitWith { _d };
    (_pairs # _idx) # 1
};

private _fmtHdr = {
    params ["_t"];
    format ["<t size='1.05' font='PuristaMedium' color='#B89B6B'>%1</t><br/>", _t]
};

private _fmtKV = {
    params ["_k", "_v"];
    private _vv = _v; if (!(_vv isEqualType "")) then { _vv = str _vv; }; if ((_vv find "<t") >= 0) then { format ["<t color='#B89B6B'>%1:</t> %2<br/>", _k, _vv ] } else { format ["<t color='#B89B6B'>%1:</t> <t color='#FFFFFF'>%2</t><br/>", _k, _vv ] }
};

// -------------------------------------------------------------------------
// Active incident snapshot (client-public vars)
// -------------------------------------------------------------------------
private _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""]; 
if (!(_taskId isEqualType "")) then { _taskId = ""; };

private _incName = missionNamespace getVariable ["ARC_activeIncidentDisplayName", ""]; 
if (!(_incName isEqualType "")) then { _incName = ""; };

private _incType = missionNamespace getVariable ["ARC_activeIncidentType", ""]; 
if (!(_incType isEqualType "")) then { _incType = ""; };

private _incPos = missionNamespace getVariable ["ARC_activeIncidentPos", []];
if (!(_incPos isEqualType []) || { (count _incPos) < 2 }) then { _incPos = []; };
private _grid = if ((count _incPos) >= 2) then { mapGridPosition _incPos } else { "" };
private _zone = if ((count _incPos) >= 2) then { [_incPos] call ARC_fnc_worldGetZoneForPos } else { "" };
if (!(_zone isEqualType "")) then { _zone = ""; };

private _acc = missionNamespace getVariable ["ARC_activeIncidentAccepted", false];
if (!(_acc isEqualType true) && !(_acc isEqualType false)) then { _acc = false; };

private _accBy = missionNamespace getVariable ["ARC_activeIncidentAcceptedByGroup", ""]; 
if (!(_accBy isEqualType "")) then { _accBy = ""; };

private _gidSelf = groupId (group player);
private _availRows = missionNamespace getVariable ["ARC_pub_groupTaskingAvailability", []];
if (!(_availRows isEqualType [])) then { _availRows = []; };
private _idxAvail = _availRows findIf {
    (_x isEqualType []) && { (count _x) >= 2 } &&
    { ((_x # 0) isEqualType "") && { (toUpper (_x # 0)) isEqualTo (toUpper _gidSelf) } }
};
private _isTaskingAvailable = true;
if (_idxAvail >= 0) then { _isTaskingAvailable = (_availRows # _idxAvail) param [1, true]; };

private _closeReady = missionNamespace getVariable ["ARC_activeIncidentCloseReady", false];
if (!(_closeReady isEqualType true) && !(_closeReady isEqualType false)) then { _closeReady = false; };

private _sitrepSent = missionNamespace getVariable ["ARC_activeIncidentSitrepSent", false];
if (!(_sitrepSent isEqualType true) && !(_sitrepSent isEqualType false)) then { _sitrepSent = false; };

// -------------------------------------------------------------------------
// Queue snapshot (published pending)
// -------------------------------------------------------------------------
private _queue = missionNamespace getVariable ["ARC_pub_queuePending", []];
if (!(_queue isEqualType [])) then { _queue = []; };

private _qInc = 0;
private _qFollow = 0;
private _qLead = 0;
private _qOther = 0;

private _queueLines = [];
{
    if (!(_x isEqualType []) || { (count _x) < 8 }) then { continue; };
    _x params ["_qid", "_createdAt", "_qSt", "_qKind", "_qFrom", "_qFromGrp", "_qPos", "_qSummary"]; 

    private _k = toUpper (trim _qKind);
    switch (_k) do
    {
        case "INCIDENT": { _qInc = _qInc + 1; };
        case "FOLLOWON_REQUEST": { _qFollow = _qFollow + 1; };
        case "LEAD_REQUEST": { _qLead = _qLead + 1; };
        default { _qOther = _qOther + 1; };
    };

    // Keep the snapshot short (top 10)
    if ((count _queueLines) < 10) then
    {
        private _g = if (_qFromGrp isEqualType "" && { _qFromGrp isNotEqualTo "" }) then { _qFromGrp } else { "" };
        private _s = if (_qSummary isEqualType "" && { _qSummary isNotEqualTo "" }) then { _qSummary } else { "(no summary)" };
        _queueLines pushBack format ["- <t color='#B89B6B'>%1</t> %2 <t color='#FFFFFF'>(%3)</t>", _k, _s, if (_g isEqualTo "") then {"TOC"} else {_g}];
    };
} forEach _queue;

// -------------------------------------------------------------------------
// Orders snapshot (published)
// -------------------------------------------------------------------------
private _orders = missionNamespace getVariable ["ARC_pub_orders", []];
if (!(_orders isEqualType [])) then { _orders = []; };

private _issued = [];
{
    if (!(_x isEqualType []) || { (count _x) < 7 }) then { continue; };
    _x params ["_oid", "_iat", "_st", "_ty", "_tg", "_data", "_meta"]; 
    if ((toUpper _st) isEqualTo "ISSUED") then
    {
        _issued pushBack _x;
    };
} forEach _orders;

private _ordLines = [];
{
    if (!(_x isEqualType []) || { (count _x) < 7 }) then { continue; };
    _x params ["_oid", "_iat", "_st", "_ty", "_tg", "_data", "_meta"]; 
    private _note = [_meta, "note", ""] call _getPair;
    if (!(_note isEqualType "")) then { _note = ""; };
    private _suffix = if (_note isEqualTo "") then { "" } else { format [" - <t color='#FFFFFF'>%1</t>", _note] };
    _ordLines pushBack format ["- <t color='#B89B6B'>%1</t> to <t color='#DDDDDD'>%2</t>%3", toUpper _ty, _tg, _suffix];
    if ((count _ordLines) >= 10) exitWith {};
} forEach _issued;

// -------------------------------------------------------------------------
// Last SITREP (from published ops log slice)
// -------------------------------------------------------------------------
private _ops = missionNamespace getVariable ["ARC_pub_opsLog", []];
if (!(_ops isEqualType [])) then { _ops = []; };

private _sit = [];
for "_i" from ((count _ops) - 1) to 0 step -1 do
{
    private _e = _ops # _i;
    if (!(_e isEqualType []) || { (count _e) < 6 }) then { continue; };
    _e params ["_id", "_ts", "_cat", "_summary", "_pos", "_meta"]; 
    private _evt = [_meta, "event", ""] call _getPair;
    if (!(_evt isEqualType "")) then { _evt = ""; };
    if (toUpper _evt isEqualTo "SITREP") exitWith { _sit = _e; };
};

private _sitTxt = "<t color='#FFFFFF'>(none)</t>";
if (_sit isNotEqualTo []) then
{
    _sit params ["_id", "_ts", "_cat", "_summary", "_pos", "_meta"]; 
    private _from = [_meta, "from", ""] call _getPair;
    if (!(_from isEqualType "")) then { _from = ""; };
    private _rec = [_meta, "recommend", ""] call _getPair;
    if (!(_rec isEqualType "")) then { _rec = ""; };

    private _grid2 = if (_pos isEqualType [] && { (count _pos) >= 2 }) then { mapGridPosition _pos } else { "" };
    _sitTxt = format [
        "<t color='#A0A0A0'>From:</t> %1<br/><t color='#A0A0A0'>Rec:</t> %2<br/><t color='#A0A0A0'>Grid:</t> %3<br/><br/>%4",
        if (_from isEqualTo "") then {"(n/a)"} else {_from},
        if (_rec isEqualTo "") then {"(n/a)"} else {toUpper _rec},
        if (_grid2 isEqualTo "") then {"(n/a)"} else {_grid2},
        if (_summary isEqualType "" && { _summary isNotEqualTo "" }) then {_summary} else {"(no summary)"}
    ];
};

// -------------------------------------------------------------------------
// Build text
// -------------------------------------------------------------------------
private _title = "<t size='1.15' font='PuristaMedium'>TOC BOARDS</t>";
private _sub = "<t size='0.9' color='#DDDDDD'>Snapshot: Incident | Queue | Orders | SITREP</t><br/><br/>";
private _taskingLine = format [
    "<t size='0.9' color='#A0A0A0'>Tasking Status (%1):</t> <t color='#FFFFFF'>%2</t><br/><br/>",
    if (_gidSelf isEqualTo "") then {"UNASSIGNED"} else {_gidSelf},
    if (_isTaskingAvailable) then {"AVAILABLE"} else {"OFFLINE"}
];

private _incBlock = "";
if (_taskId isEqualTo "") then
{
    _incBlock = (["Active Incident"] call _fmtHdr) + "<t color='#FFFFFF'>No active incident.</t><br/>";
}
else
{
    private _st = if (!_acc) then {"PENDING ACK"} else {"ASSIGNED"};
    private _cr = if (_closeReady) then {"YES"} else {"NO"};
    private _sr = if (_sitrepSent) then {"SENT"} else {"NOT SENT"};

    _incBlock = (["Active Incident"] call _fmtHdr) + (
        (["Title", if (_incName isEqualTo "") then {"(unnamed)"} else {_incName}] call _fmtKV) +
        (["Type", if (_incType isEqualTo "") then {"(n/a)"} else {_incType}] call _fmtKV) +
        (["Status", _st] call _fmtKV) +
        (["Assigned", if (_accBy isEqualTo "") then {"(unassigned)"} else {_accBy}] call _fmtKV) +
        (["Grid", if (_grid isEqualTo "") then {"(n/a)"} else {_grid}] call _fmtKV) +
        (["AO", if (_zone isEqualTo "") then {"(n/a)"} else {_zone}] call _fmtKV) +
        (["Closeout Ready", _cr] call _fmtKV) +
        (["SITREP", _sr] call _fmtKV)
    );
};

private _qCount = count _queue;
private _queueBlock = (["TOC Queue (Pending)"] call _fmtHdr) + format [
    "<t color='#A0A0A0'>Count:</t> %1 <t color='#FFFFFF'>(INC %2 | FOL %3 | LEAD %4 | OTHER %5)</t><br/>",
    _qCount, _qInc, _qFollow, _qLead, _qOther
];

if ((count _queueLines) > 0) then
{
    _queueBlock = _queueBlock + (_queueLines joinString "<br/>") + "<br/>";
}
else
{
    _queueBlock = _queueBlock + "<t color='#FFFFFF'>(none)</t><br/>";
};

private _issuedCount = count _issued;
private _ordersBlock = (["Orders (Issued / Awaiting ACK)"] call _fmtHdr) + format ["<t color='#A0A0A0'>Count:</t> %1<br/>", _issuedCount];
if ((count _ordLines) > 0) then
{
    _ordersBlock = _ordersBlock + (_ordLines joinString "<br/>") + "<br/>";
}
else
{
    _ordersBlock = _ordersBlock + "<t color='#FFFFFF'>(none)</t><br/>";
};

private _sitBlock = (["Last SITREP"] call _fmtHdr) + _sitTxt + "<br/>";

private _tip = "<br/><t size='0.85' color='#AAAAAA'>Tip: Primary toggles tasking availability. Secondary opens TOC queue/CMD actions.</t>";

private _txt = _title + "<br/>" + _sub + _taskingLine + _incBlock + "<br/>" + _queueBlock + "<br/>" + _ordersBlock + "<br/>" + _sitBlock + _tip;

_ctrlMain ctrlSetStructuredText parseText _txt;

// Auto-fit + clamp to viewport so the controls group can scroll when needed.
[_ctrlMain] call BIS_fnc_ctrlFitToTextHeight;
private _mainGrp = _display displayCtrl 78015;
private _minH = if (!isNull _mainGrp) then { (ctrlPosition _mainGrp) # 3 } else { 0.74 };
private _p = ctrlPosition _ctrlMain;
_p set [3, (_p # 3) max _minH];
_ctrlMain ctrlSetPosition _p;
_ctrlMain ctrlCommit 0;

true

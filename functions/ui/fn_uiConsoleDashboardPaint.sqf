/*
    ARC_fnc_uiConsoleDashboardPaint

    UI09: paint the Dashboard tab.
    This is a role-aware at-a-glance summary. It does not attempt to replace
    the Workboard; it provides fast situational awareness.

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

// sqflint 0.3.2 compat: wrap trim/fileExists via compile so the linter does not error on unknown operators.
private _trimFn = compile "params ['_s']; trim _s";
private _fileExistsFn = compile "params ['_p']; fileExists _p";

// TSH-INC1: Standardized typography and contrast tokens for shell-level text surfaces.
// These tokens are used by shell elements (title, strip labels, main panel contrast pairings).
// Existing structured-text markup that already encodes its own colors continues to work as-is.
private _tshCoyote = "#B89B6B";   // Coyote sand — labels, headers, status text
private _tshGreen  = "#4CAF50";   // Ready / linked state
private _tshAmber  = "#F5A623";   // Caution / incomplete state
private _tshRed    = "#E74C3C";   // Critical alerts only
private _tshBody   = "#C8C8C8";   // Body / value text

private _rxMaxItems = missionNamespace getVariable ["ARC_consoleRxMaxItems", 80];
if (!(_rxMaxItems isEqualType 0) || { _rxMaxItems < 10 }) then { _rxMaxItems = 80; };
_rxMaxItems = (_rxMaxItems min 160) max 10;

private _rxMaxText = missionNamespace getVariable ["ARC_consoleRxMaxTextLen", 220];
if (!(_rxMaxText isEqualType 0) || { _rxMaxText < 40 }) then { _rxMaxText = 220; };
_rxMaxText = (_rxMaxText min 500) max 40;

private _trimText = {
    params ["_v", ["_fallback", ""]];
    private _s = if (_v isEqualType "") then { [_v] call _trimFn } else { _fallback };
    if ((count _s) > _rxMaxText) then { _s = _s select [0, _rxMaxText]; };
    _s
};

private _ctrlMain = _display displayCtrl 78010;
if (isNull _ctrlMain) exitWith {false};

private _ctrlDetailsGrp = _display displayCtrl 78016;
private _ctrlDetails    = _display displayCtrl 78012;

private _gid = groupId (group player);
private _tag = [player] call ARC_fnc_rolesGetTag;
if (_tag isEqualTo "") then { _tag = "RFL"; };

private _isOmni = false;
private _omniTokens = missionNamespace getVariable ["ARC_consoleOmniTokens", ["OMNI"]];
if (!(_omniTokens isEqualType [])) then { _omniTokens = ["OMNI"]; };
{ if (_x isEqualType "" && { [player, _x] call ARC_fnc_rolesHasGroupIdToken }) exitWith { _isOmni = true; }; } forEach _omniTokens;

private _isAuth  = [player] call ARC_fnc_rolesIsAuthorized;
private _isS2    = [player] call ARC_fnc_rolesIsTocS2;
private _isS3    = [player] call ARC_fnc_rolesIsTocS3;
private _isCmd   = [player] call ARC_fnc_rolesIsTocCommand;
private _atStation = [player] call ARC_fnc_uiConsoleIsAtStation;

private _roleCat = "FIELD";
if (_isCmd) then { _roleCat = "TOC-CMD"; } else {
    if (_isS3) then { _roleCat = "TOC-S3"; } else {
        if (_isS2) then { _roleCat = "TOC-S2"; } else {
            if (!_isAuth) then { _roleCat = "GUEST"; };
        };
    };
};

private _pos = getPosATL player;
private _grid = mapGridPosition _pos;

// ── Console VM v1 primary path (Dashboard migration slice) ──────────────────
// Dashboard now sources incident, follow-on, ops, queue, unit status, backlog,
// airbase, and base-services data from Console VM when available.
// Direct missionNamespace reads remain fallback-only when the VM adapter is unavailable.
private _useVm = (!isNil "ARC_fnc_consoleVmAdapterV1");

private _taskId = "";
private _hasIncident = false;
private _incDisp = "(none)";
private _incType = "";
private _incPos = [];
private _incGrid = "";
private _acc = false;
private _accBy = "";
private _closeReady = false;
private _sitrepSent = false;
private _foSummary = "";
private _foLeadName = "";
private _foLeadGrid = "";
private _orders = [];
private _leadPool = [];
private _intelLog = [];
private _qPendingArr = [];
private _statusRows = [];
private _airSnap = [];
private _backlogArr = [];
private _baseServices = [];

if (_useVm) then
{
    _taskId      = ["incident",     "task_id",            ""]      call ARC_fnc_consoleVmAdapterV1;
    _incDisp     = ["incident",     "display_name",       "(none)"] call ARC_fnc_consoleVmAdapterV1;
    _incType     = ["incident",     "incident_type",      ""]      call ARC_fnc_consoleVmAdapterV1;
    _incPos      = ["incident",     "position",           []]      call ARC_fnc_consoleVmAdapterV1;
    _acc         = ["incident",     "accepted",           false]   call ARC_fnc_consoleVmAdapterV1;
    _accBy       = ["incident",     "accepted_by_group",  ""]      call ARC_fnc_consoleVmAdapterV1;
    _closeReady  = ["incident",     "close_ready",        false]   call ARC_fnc_consoleVmAdapterV1;
    _sitrepSent  = ["incident",     "sitrep_sent",        false]   call ARC_fnc_consoleVmAdapterV1;
    _foSummary   = ["followOn",     "summary",            ""]      call ARC_fnc_consoleVmAdapterV1;
    _foLeadName  = ["followOn",     "lead_name",          ""]      call ARC_fnc_consoleVmAdapterV1;
    _foLeadGrid  = ["followOn",     "lead_grid",          ""]      call ARC_fnc_consoleVmAdapterV1;
    _orders      = ["ops",          "orders",             []]      call ARC_fnc_consoleVmAdapterV1;
    _leadPool    = ["ops",          "lead_pool",          []]      call ARC_fnc_consoleVmAdapterV1;
    _intelLog    = ["ops",          "intel_log",          []]      call ARC_fnc_consoleVmAdapterV1;
    _qPendingArr = ["ops",          "queue_pending",      []]      call ARC_fnc_consoleVmAdapterV1;
    _statusRows  = ["ops",          "unit_statuses",      []]      call ARC_fnc_consoleVmAdapterV1;
    _backlogArr  = ["ops",          "toc_backlog",        []]      call ARC_fnc_consoleVmAdapterV1;
    _airSnap     = ["airbase",      "snapshot",           []]      call ARC_fnc_consoleVmAdapterV1;
    _baseServices = ["stateSummary", "base_services",      []]      call ARC_fnc_consoleVmAdapterV1;
}
else
{
    _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""];
    _incDisp = missionNamespace getVariable ["ARC_activeIncidentDisplayName", "(none)"];
    _incType = missionNamespace getVariable ["ARC_activeIncidentType", ""];
    _incPos  = missionNamespace getVariable ["ARC_activeIncidentPos", []];
    _acc = missionNamespace getVariable ["ARC_activeIncidentAccepted", false];
    _accBy = missionNamespace getVariable ["ARC_activeIncidentAcceptedByGroup", ""];
    _closeReady = missionNamespace getVariable ["ARC_activeIncidentCloseReady", false];
    _sitrepSent = missionNamespace getVariable ["ARC_activeIncidentSitrepSent", false];
    _foSummary = missionNamespace getVariable ["ARC_activeIncidentFollowOnSummary", ""];
    _foLeadName = missionNamespace getVariable ["ARC_activeIncidentFollowOnLeadName", ""];
    _foLeadGrid = missionNamespace getVariable ["ARC_activeIncidentFollowOnLeadGrid", ""];
    _orders = missionNamespace getVariable ["ARC_pub_orders", []];
    _leadPool = missionNamespace getVariable ["ARC_leadPoolPublic", []];
    _intelLog = missionNamespace getVariable ["ARC_pub_intelLog", []];
    _qPendingArr = missionNamespace getVariable ["ARC_pub_queuePending", []];
    _statusRows = missionNamespace getVariable ["ARC_pub_unitStatuses", []];
    _airSnap = missionNamespace getVariable ["ARC_pub_airbaseUiSnapshot", []];
    _backlogArr = missionNamespace getVariable ["ARC_pub_tocBacklog", []];
    _baseServices = missionNamespace getVariable ["ARC_pub_baseServices", []];
};

if (!(_taskId isEqualType "")) then { _taskId = ""; };
if (!(_incDisp isEqualType "")) then { _incDisp = "(none)"; };
if (!(_incType isEqualType "")) then { _incType = ""; };
if (!(_incPos isEqualType [])) then { _incPos = []; };
if (!(_acc isEqualType true) && !(_acc isEqualType false)) then { _acc = false; };
if (!(_accBy isEqualType "")) then { _accBy = ""; };
if (!(_closeReady isEqualType true) && !(_closeReady isEqualType false)) then { _closeReady = false; };
if (!(_sitrepSent isEqualType true) && !(_sitrepSent isEqualType false)) then { _sitrepSent = false; };
if (!(_foSummary isEqualType "")) then { _foSummary = ""; };
if (!(_foLeadName isEqualType "")) then { _foLeadName = ""; };
if (!(_foLeadGrid isEqualType "")) then { _foLeadGrid = ""; };
if (!(_orders isEqualType [])) then { _orders = []; };
if (!(_leadPool isEqualType [])) then { _leadPool = []; };
if (!(_intelLog isEqualType [])) then { _intelLog = []; };
if (!(_qPendingArr isEqualType [])) then { _qPendingArr = []; };
if (!(_statusRows isEqualType [])) then { _statusRows = []; };
if (!(_airSnap isEqualType [])) then { _airSnap = []; };
if (!(_backlogArr isEqualType [])) then { _backlogArr = []; };
if (!(_baseServices isEqualType [])) then { _baseServices = []; };

_foSummary = [_foSummary] call _trimFn;
_foLeadName = [_foLeadName] call _trimFn;
_foLeadGrid = [_foLeadGrid] call _trimFn;
_hasIncident = (_taskId != "");
_incGrid = if (_incPos isEqualType [] && { (count _incPos) >= 2 }) then { mapGridPosition _incPos } else { "" };

if ((count _orders) > _rxMaxItems) then { _orders = _orders select [0, _rxMaxItems]; };
if ((count _leadPool) > _rxMaxItems) then { _leadPool = _leadPool select [0, _rxMaxItems]; };
if ((count _intelLog) > _rxMaxItems) then { _intelLog = _intelLog select [((count _intelLog) - _rxMaxItems) max 0, _rxMaxItems]; };
if ((count _qPendingArr) > _rxMaxItems) then { _qPendingArr = _qPendingArr select [0, _rxMaxItems]; };
if ((count _statusRows) > _rxMaxItems) then { _statusRows = _statusRows select [0, _rxMaxItems]; };

// Active incident summary
private _incLine = if (!_hasIncident) then
{
    "<t color='#FFFFFF'>No active incident.</t>"
}
else
{
    private _titleColor = if (_closeReady && !_sitrepSent) then {"#FFFFA0"} else {"#DDDDDD"};
    private _typeSuffix = if (_incType isEqualTo "") then {""} else { format [" <t color='#AAAAAA'>(%1)</t>", toUpper _incType] };
    private _gridSuffix = if (_incGrid isEqualTo "") then {""} else { format [" <t color='#AAAAAA'>@ %1</t>", _incGrid] };
    private _accColor = if (_acc) then {"#9FE870"} else {"#FF7A7A"};
    private _srColor = if (_sitrepSent) then {"#9FE870"} else {"#FFD166"};
    private _srText  = if (_sitrepSent) then {"SENT"} else {"NOT SENT"};
    format [
        "<t color='%1'>%2</t>%3%4<br/><t color='#AAAAAA'>Accepted:</t> <t color='%5'>%6</t>  <t color='#AAAAAA'>Unit:</t> <t>%7</t><br/><t color='#AAAAAA'>Close-ready:</t> <t>%8</t>  <t color='#AAAAAA'>SITREP:</t> <t color='%9'>%10</t>",
        _titleColor,
        _incDisp,
        _typeSuffix,
        _gridSuffix,
        _accColor,
        if (_acc) then {"YES"} else {"NO"},
        if (_accBy isEqualTo "") then {"UNASSIGNED"} else {_accBy},
        if (_closeReady) then {"YES"} else {"NO"},
        _srColor,
        _srText
    ]
};

// Group orders summary
private _issued = [];
private _accepted = [];
{
    if (!(_x isEqualType [] && { (count _x) >= 6 })) then { continue; };
    private _st = toUpper (_x select 2);
    private _tg = _x select 4;
    if (_tg != _gid) then { continue; };
    if (_st isEqualTo "ISSUED") then { _issued pushBack _x; };
    if (_st isEqualTo "ACCEPTED") then { _accepted pushBack _x; };
} forEach _orders;

private _ordLine = if ((count _issued) isEqualTo 0 && { (count _accepted) isEqualTo 0 }) then
{
    "<t color='#BBBBBB'>No TOC orders for your group.</t>"
}
else
{
    private _parts = [];
    if ((count _issued) > 0) then { _parts pushBack format ["<t color='#FFFFA0'>ISSUED: %1</t>", count _issued]; };
    if ((count _accepted) > 0) then { _parts pushBack format ["<t color='#A0FFA0'>ACCEPTED: %1</t>", count _accepted]; };
    _parts joinString "  "
};

// Lead pool / intel feed summary
private _lastIntel = "<t color='#BBBBBB'>No intel logged yet.</t>";
if ((count _intelLog) > 0) then
{
    private _last = _intelLog select ((count _intelLog) - 1);
    if (_last isEqualType [] && { (count _last) >= 6 }) then
    {
        private _cat = _last select 2;
        private _sum = _last select 3;
        private _p = _last select 4;
        private _g = if (_p isEqualType [] && { (count _p) >= 2 }) then { mapGridPosition _p } else { "" };
        _sum = [_sum, ""] call _trimText;
        _lastIntel = format ["<t color='#DDDDDD'>[%1] %2</t><t color='#AAAAAA'> %3</t>", toUpper _cat, _sum, if (_g isEqualTo "") then {""} else { format ["@ %1", _g] }];
    };
};

// Queue summary
private _qPendingCnt = count _qPendingArr;

private _airRunway = [_airSnap, "runway", []] call ARC_fnc_uiConsoleGetPair;
if (!(_airRunway isEqualType [])) then { _airRunway = []; };
private _airArrivals = [_airSnap, "arrivals", []] call ARC_fnc_uiConsoleGetPair;
if (!(_airArrivals isEqualType [])) then { _airArrivals = []; };
private _airDepartures = [_airSnap, "departures", []] call ARC_fnc_uiConsoleGetPair;
if (!(_airDepartures isEqualType [])) then { _airDepartures = []; };
private _airAlerts = [_airSnap, "alerts", []] call ARC_fnc_uiConsoleGetPair;
if (!(_airAlerts isEqualType [])) then { _airAlerts = []; };
private _airRunwayState = [_airRunway, "state", "UNKNOWN"] call ARC_fnc_uiConsoleGetPair;
if (!(_airRunwayState isEqualType "")) then { _airRunwayState = "UNKNOWN"; };
private _airHoldState = [_airRunway, "holdState", false] call ARC_fnc_uiConsoleGetPair;
if (!(_airHoldState isEqualType true) && !(_airHoldState isEqualType false)) then { _airHoldState = false; };

// Phase 6: extract next inbound/outbound with callsign + phase/state.
// Snapshot Contract v1: arrival = [fid(0), callsign(1), category(2), phase(3), ageS(4), priority(5), status(6)]
// Snapshot Contract v1: departure = [fid(0), callsign(1), category(2), state(3), ageS(4), priority(5), status(6)]
private _airNextArrival = if ((count _airArrivals) > 0) then { _airArrivals select 0 } else { [] };
private _airNextDeparture = if ((count _airDepartures) > 0) then { _airDepartures select 0 } else { [] };

private _fmtFlight = {
    params [["_tuple", [], [[]]], ["_fallback", "?", [""]]];
    if (!(_tuple isEqualType []) || { (count _tuple) < 4 }) exitWith { _fallback };
    private _cs = _tuple param [1, ""];
    private _ph = _tuple param [3, ""];
    if (!(_cs isEqualType "")) then { _cs = ""; };
    if (!(_ph isEqualType "")) then { _ph = ""; };
    if (_cs isEqualTo "") then { _cs = _tuple param [0, "?"]; };
    if (_ph isEqualTo "") then { _cs } else { format ["%1 (%2)", _cs, _ph] }
};
if (!(_fmtFlight isEqualType {})) exitWith { false };

private _airInboundLabel  = [_airNextArrival, "No inbound"] call _fmtFlight;
private _airOutboundLabel = [_airNextDeparture, "No outbound"] call _fmtFlight;

private _airAlertLabel = if ((count _airAlerts) > 0) then { (_airAlerts select 0) param [0, "NONE"] } else { "NONE" };
private _airFreshnessState = [_airSnap, "freshnessState", "UNKNOWN"] call ARC_fnc_uiConsoleGetPair;
if (!(_airFreshnessState isEqualType "")) then { _airFreshnessState = "UNKNOWN"; };
private _airAlertColor = _tshGreen;
private _airTopCriticalAlert = "";
if ((count _airAlerts) > 0) then {
    private _severity = toUpper ((_airAlerts select 0) param [1, "INFO"]);
    if (_severity isEqualTo "CAUTION") then { _airAlertColor = _tshAmber; };
    if (_severity isEqualTo "CRITICAL") then {
        _airAlertColor = _tshRed;
        _airTopCriticalAlert = (_airAlerts select 0) param [0, ""];
    };
};

private _airDecisionQueue = [_airSnap, "decisionQueue", []] call ARC_fnc_uiConsoleGetPair;
if (!(_airDecisionQueue isEqualType [])) then { _airDecisionQueue = []; };
private _airTopBlocker = "";
if (_airHoldState) then {
    _airTopBlocker = "Departures on HOLD";
} else {
    if ((toUpper _airRunwayState) isEqualTo "BLOCKED") then {
        _airTopBlocker = "Runway BLOCKED";
    } else {
        if (_airTopCriticalAlert != "") then {
            _airTopBlocker = _airTopCriticalAlert;
        } else {
            if ((count _airDecisionQueue) > 0) then {
                private _dq0 = _airDecisionQueue select 0;
                if (_dq0 isEqualType [] && { (count _dq0) >= 1 }) then {
                    _airTopBlocker = _dq0 param [0, "Decision pending"];
                };
            };
        };
    };
};

private _unitLines = [];
{
    if (!(_x isEqualType []) || { (count _x) < 2 }) then { continue; };
    private _gidU = _x select 0;
    private _stRaw = if ((_x select 1) isEqualType "") then { toUpper ([_x select 1] call _trimFn) } else { "UNAVAILABLE" };
    if (_stRaw isEqualTo "OFFLINE") then { _stRaw = "UNAVAILABLE"; };
    private _why = if ((count _x) >= 5 && { (_x select 4) isEqualType "" }) then { [(_x select 4), ""] call _trimText } else { "" };
    private _stColor = "#FFD166";
    if (_stRaw in ["AVAILABLE", "ON SCENE"]) then { _stColor = "#9FE870"; };
    if (_stRaw in ["UNAVAILABLE", "FAILED"]) then { _stColor = "#FF7A7A"; };
    _unitLines pushBack format ["<t color='#BDBDBD'>%1:</t> <t color='%2'>%3</t>%4",
        if (_gidU isEqualTo "") then {"(UNKNOWN)"} else {_gidU},
        _stColor,
        _stRaw,
        if (_why isEqualTo "") then {""} else { format [" <t color='#AAAAAA'>(%1)</t>", _why] }
    ];
} forEach _statusRows;
private _unitsBlock = if ((count _unitLines) > 0) then { _unitLines joinString "<br/>" } else { "<t color='#BBBBBB'>No unit status reports.</t>" };

private _accessLine = format [
    "<t size='0.9'><t color='#B89B6B'>Access:</t> <t color='#FFFFFF'>%1%2%3%4%5</t></t>",
    if (_isAuth || _isS3 || _isS2 || _isCmd || _isOmni) then {"OPS "} else {""},
    if (_isAuth || _isS2 || _isCmd || _isOmni) then {"INTEL "} else {""},
    "HANDOFF ",
    if (_atStation || _isCmd || _isS3 || _isOmni) then {"CMD "} else {""},
    if (_isOmni) then {"(OMNI)"} else {""}
];

private _hdr = format [
    "<t size='1.15' font='PuristaMedium' color='%5'>COP / Dashboard</t><br/>" +
    "<t size='0.9'><t color='%5'>Role:</t> <t color='#FFFFFF'>%1</t> <t color='%5'>| Group:</t> <t color='#FFFFFF'>%2</t> <t color='%5'>| Tag:</t> <t color='#FFFFFF'>%3</t></t><br/>" +
    "<t size='0.85' color='#AAAAAA'>Your grid: %4 | Station: %6</t><br/>",
    _roleCat,
    if (_gid isEqualTo "") then {"(none)"} else {_gid},
    _tag,
    _grid,
    _tshCoyote,
    if (_atStation) then {"YES"} else {"NO"}
];

private _foLine = "";
if (_foSummary != "") then
{
    _foLine = _foLine + format ["<t size='0.85' color='#BBBBBB'>Field follow-on: %1</t><br/>", _foSummary];
};
if (_foLeadName != "") then
{
    _foLine = _foLine + format ["<t size='0.85' color='#BBBBBB'>System follow-on lead: %1</t><br/>", _foLeadName];
};
if (_foLine != "") then { _foLine = _foLine + "<br/>"; };

private _secIncident = "<t size='1.0' font='PuristaMedium' color='#B89B6B'>Current Incident</t><br/>" + _incLine + "<br/>" + _foLine + "<br/>";
private _secOrders   = "<t size='1.0' font='PuristaMedium' color='#B89B6B'>Orders</t><br/>" + _ordLine + "<br/><br/>";

private _qOldestDesc = "(none)";
if (_qPendingCnt > 0) then
{
    private _q0 = _qPendingArr select 0;
    if (_q0 isEqualType [] && { (count _q0) >= 4 }) then
    {
        private _q0Kind = toUpper ([_q0 select 3, "?"] call _trimText);
        private _q0Created = _q0 select 1;
        private _q0AgeS = if (_q0Created isEqualType 0 && { _q0Created > 0 }) then { round (serverTime - _q0Created) } else { -1 };
        private _q0AgeFmt = if (_q0AgeS < 0) then { "" } else { if (_q0AgeS < 60) then { format [" (%1s ago)", _q0AgeS] } else { format [" (%1m ago)", floor (_q0AgeS / 60)] } };
        _qOldestDesc = format ["<t color='#FFD166'>%1</t>%2", _q0Kind, _q0AgeFmt];
    };
};

private _backlogCnt = count _backlogArr;

private _svcManRaw = [_baseServices, "manpowerReadiness", 1] call ARC_fnc_uiConsoleGetPair;
private _svcS4Raw = [_baseServices, "s4Readiness", 1] call ARC_fnc_uiConsoleGetPair;
private _svcMedRaw = [_baseServices, "medicalReadiness", 1] call ARC_fnc_uiConsoleGetPair;
private _svcMayorRaw = [_baseServices, "mayorReadiness", 1] call ARC_fnc_uiConsoleGetPair;
if (!(_svcManRaw isEqualType 0)) then { _svcManRaw = 1; };
if (!(_svcS4Raw isEqualType 0)) then { _svcS4Raw = 1; };
if (!(_svcMedRaw isEqualType 0)) then { _svcMedRaw = 1; };
if (!(_svcMayorRaw isEqualType 0)) then { _svcMayorRaw = 1; };
private _svcMan = round ((_svcManRaw max 0) * 100);
private _svcS4 = round ((_svcS4Raw max 0) * 100);
private _svcMed = round ((_svcMedRaw max 0) * 100);
private _svcMayor = round ((_svcMayorRaw max 0) * 100);
private _svcIssues = [_baseServices, "issues", []] call ARC_fnc_uiConsoleGetPair;
if (!(_svcIssues isEqualType [])) then { _svcIssues = []; };
private _svcIssueLabel = if ((count _svcIssues) > 0) then { _svcIssues joinString ", " } else { "Base services nominal" };

private _leadFieldCnt = 0;
private _leadS2Cnt = 0;
{
    if (_x isEqualType []) then
    {
        private _mm = if ((count _x) >= 12 && { (_x select 11) isEqualType [] }) then { _x select 11 } else { [] };
        private _oRaw = [_mm, "origin", "FIELD"] call ARC_fnc_uiConsoleGetPair;
        private _o = if (_oRaw isEqualType "") then { toUpper _oRaw } else { "FIELD" };
        if (_o isEqualTo "S2") then { _leadS2Cnt = _leadS2Cnt + 1 } else { _leadFieldCnt = _leadFieldCnt + 1 };
    };
} forEach _leadPool;

private _secIntel    = format [
    "<t size='1.0' font='PuristaMedium' color='#B89B6B'>Intel / Leads</t><br/>" +
    "<t color='#DDDDDD'>Lead pool:</t> %1 <t color='#AAAAAA'>(field %5 / S2 %6)</t><br/>" +
    "<t color='#DDDDDD'>TOC Queue (follow-up):</t> %2<br/>" +
    "<t color='#DDDDDD'>Approval queue oldest:</t> %3<br/>" +
    "<t color='#DDDDDD'>Latest intel:</t> %4<br/><br/>",
    count _leadPool,
    _backlogCnt,
    _qOldestDesc,
    _lastIntel,
    _leadFieldCnt,
    _leadS2Cnt
];
private _secUnits = "<t size='1.0' font='PuristaMedium' color='#B89B6B'>Unit Availability</t><br/>" + _unitsBlock + "<br/><br/>";
private _secBase = format [
    "<t size='1.0' font='PuristaMedium' color='#B89B6B'>Base Services</t><br/>" +
    "<t color='#DDDDDD'>MAYOR:</t> %1%% | <t color='#DDDDDD'>S1:</t> %2%% | <t color='#DDDDDD'>S4:</t> %3%% | <t color='#DDDDDD'>MED:</t> %4%%<br/>" +
    "<t color='#DDDDDD'>Service notes:</t> %5<br/><br/>",
    _svcMayor,
    _svcMan,
    _svcS4,
    _svcMed,
    _svcIssueLabel
];

private _airRunwayColor = switch (toUpper _airRunwayState) do {
    case "OPEN": { _tshGreen };
    case "RESERVED": { _tshAmber };
    case "OCCUPIED": { _tshAmber };
    default { _tshRed };
};
private _secAir = "";
private _airFreshnessColor = if ((toUpper _airFreshnessState) isEqualTo "FRESH") then { _tshGreen } else { if ((toUpper _airFreshnessState) isEqualTo "STALE") then { _tshAmber } else { _tshRed } };
private _airFreshnessLine = format ["<t color='#DDDDDD'>Data:</t> <t color='%1'>%2</t><br/>", _airFreshnessColor, _airFreshnessState];
private _airBlockerLine = if (_airTopBlocker isEqualTo "") then { "" } else {
    format ["<t color='#DDDDDD'>Top blocker:</t> <t color='%1'>%2</t><br/>", _tshRed, _airTopBlocker]
};
_secAir = format [
    "<t size='1.0' font='PuristaMedium' color='%1'>Air Summary</t><br/>" +
    "<t color='#DDDDDD'>Runway:</t> <t color='%2'>%3</t><br/>" +
    "<t color='#DDDDDD'>Next inbound:</t> <t color='%4'>%5</t><br/>" +
    "<t color='#DDDDDD'>Next outbound:</t> <t color='%4'>%6</t><br/>" +
    "<t color='#DDDDDD'>Air alerts:</t> <t color='%7'>%8</t><br/>",
    _tshCoyote,
    _airRunwayColor,
    _airRunwayState,
    _tshBody,
    _airInboundLabel,
    _airOutboundLabel,
    _airAlertColor,
    _airAlertLabel
] + _airBlockerLine + _airFreshnessLine + "<br/>";

private _secNext = "";
private _nextArr = [];
if (isNil "ARC_fnc_uiIncidentGetNextActions") then
{
    private _p = "functions\\ui\\fn_uiIncidentGetNextActions.sqf";
    if ([_p] call _fileExistsFn) then
    {
        ARC_fnc_uiIncidentGetNextActions = compileFinal (preprocessFileLineNumbers _p);
    };
};
if (!(isNil "ARC_fnc_uiIncidentGetNextActions")) then
{
    _nextArr = [_roleCat] call ARC_fnc_uiIncidentGetNextActions;
};
if (_nextArr isEqualType [] && { (count _nextArr) > 0 }) then
{
    _secNext = "<t size='1.0' font='PuristaMedium' color='#B89B6B'>Next Actions</t><br/>" + (_nextArr joinString "<br/>") + "<br/><br/>";
};

private _sections = [];
switch (_roleCat) do
{
    case "TOC-CMD":
    {
        _sections pushBack _secAir;
        _sections pushBack _secBase;
        _sections pushBack _secIntel;
        _sections pushBack _secIncident;
        _sections pushBack _secOrders;
        _sections pushBack _secUnits;
    };
    case "TOC-S3":
    {
        _sections pushBack _secAir;
        _sections pushBack _secBase;
        _sections pushBack _secIncident;
        _sections pushBack _secOrders;
        _sections pushBack _secUnits;
        _sections pushBack _secIntel;
    };
    case "TOC-S2":
    {
        _sections pushBack _secIntel;
        _sections pushBack _secBase;
        _sections pushBack _secIncident;
        _sections pushBack _secUnits;
    };
    case "FIELD":
    {
        _sections pushBack _secIncident;
        _sections pushBack _secBase;
        _sections pushBack _secOrders;
        _sections pushBack _secUnits;
        _sections pushBack _secIntel;
    };
    default
    {
        _sections pushBack _secIncident;
        _sections pushBack _secBase;
        _sections pushBack _secOrders;
    };
};

private _txt =
    _hdr
    + _secNext
    + (_sections joinString "")
    + _accessLine
    + "<br/><br/><t size='0.85' color='#AAAAAA'>Tip: Use the station screens or your tablet to access the Farabad Console. Keybind: LCTRL + LSHIFT + T.</t>";

_ctrlMain ctrlSetStructuredText parseText _txt;

// Auto-fit + clamp to viewport so the controls group can scroll when needed.
[_ctrlMain] call BIS_fnc_ctrlFitToTextHeight;
private _mainGrp = _display displayCtrl 78015;
private _minH = if (!isNull _mainGrp) then { (ctrlPosition _mainGrp) select 3 } else { 0.74 };
private _p = ctrlPosition _ctrlMain;
_p set [3, (_p select 3) max _minH];
_ctrlMain ctrlSetPosition _p;
_ctrlMain ctrlCommit 0;

// Right panel: quick status summary / actionable context.
if (!isNull _ctrlDetailsGrp && { !isNull _ctrlDetails }) then
{
    _ctrlDetailsGrp ctrlShow true;
    _ctrlDetails ctrlShow true;

    private _incStatusColor = if (!_hasIncident) then {"#AAAAAA"} else { if (_closeReady) then {"#9FE870"} else {"#FFD166"} };
    private _incStatusText  = if (!_hasIncident) then {"No active incident"} else { if (_closeReady) then {"CLOSE-READY"} else { if (_acc) then {"In progress"} else {"Pending acceptance"} } };

    private _qColor = if (_qPendingCnt >= 5) then {"#FF7A7A"} else { if (_qPendingCnt >= 3) then {"#FFD166"} else {"#9FE870"} };

    private _rTxt =
        format ["<t size='1.0' font='PuristaMedium' color='%1'>Quick Status</t><br/>", _tshCoyote] +
        format ["<t size='0.9' color='#BDBDBD'>Incident:</t> <t size='0.9' color='%1'>%2</t><br/>", _incStatusColor, _incStatusText] +
        format ["<t size='0.9' color='#BDBDBD'>Queue pending:</t> <t size='0.9' color='%1'>%2</t><br/>", _qColor, _qPendingCnt] +
        format ["<t size='0.9' color='#BDBDBD'>Runway:</t> <t size='0.9' color='%1'>%2</t><br/>",
            _airRunwayColor,
            _airRunwayState
        ] +
        format ["<t size='0.9' color='#BDBDBD'>Next inbound:</t> <t size='0.9'>%1</t><br/>", _airInboundLabel] +
        format ["<t size='0.9' color='#BDBDBD'>Next outbound:</t> <t size='0.9'>%1</t><br/>", _airOutboundLabel] +
        (if (_airTopBlocker isEqualTo "") then { "" } else {
            format ["<t size='0.9' color='#BDBDBD'>Blocker:</t> <t size='0.9' color='%1'>%2</t><br/>", _tshRed, _airTopBlocker]
        }) +
        format ["<t size='0.9' color='#BDBDBD'>Air data:</t> <t size='0.9' color='%1'>%2</t><br/>", _airFreshnessColor, _airFreshnessState] +
        format ["<t size='0.9' color='#BDBDBD'>Base services:</t> <t size='0.9'>MAYOR %1%% | S1 %2%% | S4 %3%% | MED %4%%</t><br/>", _svcMayor, _svcMan, _svcS4, _svcMed] +
        format ["<t size='0.9' color='#BDBDBD'>Unit reports:</t> <t size='0.9'>%1</t><br/>", count _statusRows] +
        format ["<t size='0.9' color='#BDBDBD'>Intel leads:</t> <t size='0.9'>%1</t><br/>", count _leadPool] +
        format ["<br/><t size='1.0' font='PuristaMedium' color='%1'>Quick Reference</t><br/>", _tshCoyote] +
        "<t size='0.85' color='#DDDDDD'>DASH  — at-a-glance COP / status</t><br/>" +
        "<t size='0.85' color='#DDDDDD'>OPS   — submit/track field actions</t><br/>" +
        "<t size='0.85' color='#DDDDDD'>INTEL — leads, briefs, EPW</t><br/>" +
        "<t size='0.85' color='#DDDDDD'>BOARDS — TOC queue / orders / SITREP</t><br/>" +
        "<t size='0.85' color='#DDDDDD'>HANDOFF — EPW / evidence process</t><br/>" +
        "<t size='0.85' color='#DDDDDD'>CMD   — incident command cycle</t><br/>" +
        "<t size='0.85' color='#DDDDDD'>AIR   — airbase / tower controls</t><br/>" +
        "<t size='0.85' color='#DDDDDD'>HQ    — admin / S1 personnel</t><br/>" +
        "<br/><t size='0.8' color='#808080'>LCTRL+LSHIFT+T to open console.</t>";

    _ctrlDetails ctrlSetStructuredText parseText _rTxt;

    private _dashDefaultPos = uiNamespace getVariable ["ARC_console_dashDetailsDefaultPos", []];
    if (!(_dashDefaultPos isEqualType []) || { (count _dashDefaultPos) < 4 }) then
    {
        _dashDefaultPos = ctrlPosition _ctrlDetails;
        uiNamespace setVariable ["ARC_console_dashDetailsDefaultPos", +_dashDefaultPos];
    };
    [_ctrlDetails] call BIS_fnc_ctrlFitToTextHeight;
    private _dashGrp = _display displayCtrl 78016;
    private _dashMinH = if (!isNull _dashGrp) then { (ctrlPosition _dashGrp) select 3 } else { 0.74 };
    private _dashP = ctrlPosition _ctrlDetails;
    _dashP set [0, _dashDefaultPos select 0];
    _dashP set [1, _dashDefaultPos select 1];
    _dashP set [2, _dashDefaultPos select 2];
    _dashP set [3, (_dashP select 3) max _dashMinH];
    _ctrlDetails ctrlSetPosition _dashP;
    _ctrlDetails ctrlCommit 0;
};

true

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

// Active incident summary
private _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""]; if (!(_taskId isEqualType "")) then { _taskId = ""; };
private _hasIncident = (_taskId != "");
private _incDisp = missionNamespace getVariable ["ARC_activeIncidentDisplayName", "(none)"]; if (!(_incDisp isEqualType "")) then { _incDisp = "(none)"; };
private _incType = missionNamespace getVariable ["ARC_activeIncidentType", ""]; if (!(_incType isEqualType "")) then { _incType = ""; };
private _incPos  = missionNamespace getVariable ["ARC_activeIncidentPos", []]; if (!(_incPos isEqualType [])) then { _incPos = []; };
private _incGrid = if (_incPos isEqualType [] && { (count _incPos) >= 2 }) then { mapGridPosition _incPos } else { "" };
private _acc = missionNamespace getVariable ["ARC_activeIncidentAccepted", false]; if (!(_acc isEqualType true) && !(_acc isEqualType false)) then { _acc = false; };
private _accBy = missionNamespace getVariable ["ARC_activeIncidentAcceptedByGroup", ""]; if (!(_accBy isEqualType "")) then { _accBy = ""; };
private _closeReady = missionNamespace getVariable ["ARC_activeIncidentCloseReady", false]; if (!(_closeReady isEqualType true) && !(_closeReady isEqualType false)) then { _closeReady = false; };
private _sitrepSent = missionNamespace getVariable ["ARC_activeIncidentSitrepSent", false]; if (!(_sitrepSent isEqualType true) && !(_sitrepSent isEqualType false)) then { _sitrepSent = false; };

// Follow-on (from field SITREP flow) and/or system-queued follow-on lead
private _foSummary = missionNamespace getVariable ["ARC_activeIncidentFollowOnSummary", ""];
if (!(_foSummary isEqualType "")) then { _foSummary = ""; };
_foSummary = [_foSummary] call _trimFn;
private _foLeadName = missionNamespace getVariable ["ARC_activeIncidentFollowOnLeadName", ""];
if (!(_foLeadName isEqualType "")) then { _foLeadName = ""; };
_foLeadName = [_foLeadName] call _trimFn;
private _foLeadGrid = missionNamespace getVariable ["ARC_activeIncidentFollowOnLeadGrid", ""];
if (!(_foLeadGrid isEqualType "")) then { _foLeadGrid = ""; };
_foLeadGrid = [_foLeadGrid] call _trimFn;

private _incLine = if (!_hasIncident) then
{
    "<t color='#FFFFFF'>No active incident.</t>"
}
else
{
    format [
        "<t color='%1'>%2</t>%3%4<br/>%5",
        if (_closeReady && !_sitrepSent) then {"#FFFFA0"} else {"#DDDDDD"},
        _incDisp,
        if (_incType isEqualTo "") then {""} else { format [" <t color='#AAAAAA'>(%1)</t>", toUpper _incType] },
        if (_incGrid isEqualTo "") then {""} else { format [" <t color='#AAAAAA'>@ %1</t>", _incGrid] },
        format ["<t color='#AAAAAA'>Accepted:</t> <t color='%1'>%2</t> <t color='#AAAAAA'>| Unit:</t> <t color='#DDDDDD'>%3</t><br/><t color='#AAAAAA'>Close-ready:</t> <t color='#DDDDDD'>%4</t> <t color='#AAAAAA'>| SITREP:</t> <t color='%5'>%6</t>",
            if (_acc) then {"#9FE870"} else {"#FF7A7A"},
            if (_acc) then {"YES"} else {"NO"},
            if (_accBy isEqualTo "") then {"UNASSIGNED"} else {_accBy},
            if (_closeReady) then {"YES"} else {"NO"},
            if (_sitrepSent) then {"#9FE870"} else {"#FFD166"},
            if (_sitrepSent) then {"SENT"} else {"NOT SENT"}
        ]
    ]
};

// Group orders summary
private _orders = missionNamespace getVariable ["ARC_pub_orders", []];
if (!(_orders isEqualType [])) then { _orders = []; };
if ((count _orders) > _rxMaxItems) then { _orders = _orders select [0, _rxMaxItems]; };
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
private _leadPool = missionNamespace getVariable ["ARC_leadPoolPublic", []];
if (!(_leadPool isEqualType [])) then { _leadPool = []; };
if ((count _leadPool) > _rxMaxItems) then { _leadPool = _leadPool select [0, _rxMaxItems]; };
private _intelLog = missionNamespace getVariable ["ARC_pub_intelLog", []];
if (!(_intelLog isEqualType [])) then { _intelLog = []; };
if ((count _intelLog) > _rxMaxItems) then { _intelLog = _intelLog select [((count _intelLog) - _rxMaxItems) max 0, _rxMaxItems]; };

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
private _qPendingArr = missionNamespace getVariable ["ARC_pub_queuePending", []];
if (!(_qPendingArr isEqualType [])) then { _qPendingArr = []; };
if ((count _qPendingArr) > _rxMaxItems) then { _qPendingArr = _qPendingArr select [0, _rxMaxItems]; };
private _qPendingCnt = count _qPendingArr;
private _qPendingColor = "#FFFFFF";
if (_qPendingCnt >= 5) then { _qPendingColor = "#FF7A7A"; } else {
    if (_qPendingCnt >= 3) then { _qPendingColor = "#FFD166"; };
};
private _qPending = format ["<t color='%1'>%2</t>", _qPendingColor, _qPendingCnt];
private _statusRows = missionNamespace getVariable ["ARC_pub_unitStatuses", []];
if (!(_statusRows isEqualType [])) then { _statusRows = []; };
if ((count _statusRows) > _rxMaxItems) then { _statusRows = _statusRows select [0, _rxMaxItems]; };

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
    "<t size='1.15' font='PuristaMedium' color='#B89B6B'>COP / Dashboard</t><br/>" +
    "<t size='0.9'><t color='#B89B6B'>Role:</t> <t color='#FFFFFF'>%1</t> <t color='#B89B6B'>| Group:</t> <t color='#FFFFFF'>%2</t> <t color='#B89B6B'>| Tag:</t> <t color='#FFFFFF'>%3</t></t><br/>" +
    "<t size='0.85' color='#AAAAAA'>Your grid: %4 | Station: %5</t><br/>",
    _roleCat,
    if (_gid isEqualTo "") then {"(none)"} else {_gid},
    _tag,
    _grid,
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
private _secIntel    = format [
    "<t size='1.0' font='PuristaMedium' color='#B89B6B'>Intel / Leads</t><br/>" +
    "<t color='#DDDDDD'>Lead pool:</t> %1<br/>" +
    "<t color='#DDDDDD'>Queue pending:</t> %2<br/>" +
    "<t color='#DDDDDD'>Latest intel:</t> %3<br/><br/>",
    count _leadPool,
    _qPending,
    _lastIntel
];
private _secUnits = "<t size='1.0' font='PuristaMedium' color='#B89B6B'>Unit Availability</t><br/>" + _unitsBlock + "<br/><br/>";

// Next Actions: workflow coaching / blocker visibility
private _secNext = "";
	private _nextArr = [];
	// Defensive: allow this painter to run even if CfgFunctions is stale.
	// If the helper function isn't registered, lazy-load it from file.
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
        _sections pushBack _secIntel;
        _sections pushBack _secIncident;
        _sections pushBack _secOrders;
        _sections pushBack _secUnits;
    };
    case "TOC-S3":
    {
        _sections pushBack _secIncident;
        _sections pushBack _secOrders;
        _sections pushBack _secUnits;
        _sections pushBack _secIntel;
    };
    case "TOC-S2":
    {
        _sections pushBack _secIntel;
        _sections pushBack _secIncident;
        _sections pushBack _secUnits;
    };
    case "FIELD":
    {
        _sections pushBack _secIncident;
        _sections pushBack _secOrders;
        _sections pushBack _secUnits;
        _sections pushBack _secIntel;
    };
    default
    {
        _sections pushBack _secIncident;
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

// Auto-fit + clamp to viewport; pin width to parent group before fitting to prevent horizontal overflow.
private _mainGrp = _display displayCtrl 78015;
private _minH  = if (!isNull _mainGrp) then { (ctrlPosition _mainGrp) select 3 } else { 0.74 };
private _grpW  = if (!isNull _mainGrp) then { (ctrlPosition _mainGrp) select 2 } else { 1.4 };
private _safeW = _grpW - 0.025;
private _pPre  = ctrlPosition _ctrlMain;
_pPre set [2, _safeW];
_ctrlMain ctrlSetPosition _pPre;
_ctrlMain ctrlCommit 0;
[_ctrlMain] call BIS_fnc_ctrlFitToTextHeight;
private _p = ctrlPosition _ctrlMain;
_p set [2, _safeW];
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
        "<t size='1.0' font='PuristaMedium' color='#B89B6B'>Quick Status</t><br/>" +
        format ["<t size='0.9' color='#BDBDBD'>Incident:</t> <t size='0.9' color='%1'>%2</t><br/>", _incStatusColor, _incStatusText] +
        format ["<t size='0.9' color='#BDBDBD'>Queue pending:</t> <t size='0.9' color='%1'>%2</t><br/>", _qColor, _qPendingCnt] +
        format ["<t size='0.9' color='#BDBDBD'>Unit reports:</t> <t size='0.9'>%1</t><br/>", count _statusRows] +
        format ["<t size='0.9' color='#BDBDBD'>Intel leads:</t> <t size='0.9'>%1</t><br/>", count _leadPool] +
        "<br/><t size='1.0' font='PuristaMedium' color='#B89B6B'>Quick Reference</t><br/>" +
        "<t size='0.85' color='#DDDDDD'>OPS — submit/track field actions</t><br/>" +
        "<t size='0.85' color='#DDDDDD'>INTEL — leads, briefs, EPW</t><br/>" +
        "<t size='0.85' color='#DDDDDD'>CMD — incident command cycle</t><br/>" +
        "<t size='0.85' color='#DDDDDD'>AIR — airbase/tower controls</t><br/>" +
        "<br/><t size='0.8' color='#808080'>LCTRL+LSHIFT+T to open console.</t>";

    _ctrlDetails ctrlSetStructuredText parseText _rTxt;

    private _dashGrp = _display displayCtrl 78016;
    private _dashMinH = if (!isNull _dashGrp) then { (ctrlPosition _dashGrp) select 3 } else { 0.74 };
    private _dashGrpW = if (!isNull _dashGrp) then { (ctrlPosition _dashGrp) select 2 } else { 0.47 };
    private _dashDefaultPos = uiNamespace getVariable ["ARC_console_dashDetailsDefaultPos", []];
    if (!(_dashDefaultPos isEqualType []) || { (count _dashDefaultPos) < 4 }) then
    {
        _dashDefaultPos = ctrlPosition _ctrlDetails;
        _dashDefaultPos set [2, _dashGrpW - 0.01];
        uiNamespace setVariable ["ARC_console_dashDetailsDefaultPos", +_dashDefaultPos];
    };
    private _dashPPre = ctrlPosition _ctrlDetails;
    _dashPPre set [2, _dashDefaultPos select 2];
    _ctrlDetails ctrlSetPosition _dashPPre;
    _ctrlDetails ctrlCommit 0;
    [_ctrlDetails] call BIS_fnc_ctrlFitToTextHeight;
    private _dashP = ctrlPosition _ctrlDetails;
    _dashP set [0, _dashDefaultPos select 0];
    _dashP set [1, _dashDefaultPos select 1];
    _dashP set [2, _dashDefaultPos select 2];
    _dashP set [3, (_dashP select 3) max _dashMinH];
    _ctrlDetails ctrlSetPosition _dashP;
    _ctrlDetails ctrlCommit 0;
};

true

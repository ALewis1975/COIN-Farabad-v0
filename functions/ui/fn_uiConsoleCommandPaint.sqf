/*
    ARC_fnc_uiConsoleCommandPaint

    UI09: paint Command (TOC) tab.

    Focus:
      - TOC queue + incident command cycle
      - Closeout guidance

    Buttons (set by refresh):
      Primary   - Queue Manager
      Secondary - Context action (Closeout / Approve / Generate)

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

// sqflint 0.3.2 compat: wrap trim via compile so the linter does not error on unknown operator.
private _trimFn = compile "params ['_s']; trim _s";

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
private _b2 = _display displayCtrl 78022;
private _ctrlDetailsGrp = _display displayCtrl 78016;
private _ctrlDetails    = _display displayCtrl 78012;

// OMNI override (playtesting)
private _omniTokens = missionNamespace getVariable ["ARC_consoleOmniTokens", ["OMNI"]];
if (!(_omniTokens isEqualType [])) then { _omniTokens = ["OMNI"]; };
private _isOmni = false;
{
    if (_x isEqualType "" && { [player, _x] call ARC_fnc_rolesHasGroupIdToken }) exitWith { _isOmni = true; };
} forEach _omniTokens;

private _canApprove = [player] call ARC_fnc_rolesCanApproveQueue;
private _isAuth = [player] call ARC_fnc_rolesIsAuthorized;
private _statusFmt = {
    params ["_statusRaw", ["_reasonRaw", ""]];
    private _s = if (_statusRaw isEqualType "") then { toUpper ([_statusRaw] call _trimFn) } else { "OFFLINE" };
    private _reason = if (_reasonRaw isEqualType "") then { [_reasonRaw] call _trimFn } else { "" };
    if ((_reason isEqualTo "") && { (_s find ":") > -1 }) then
    {
        private _p = _s splitString ":";
        if ((count _p) >= 2) then
        {
            _s = toUpper ([_p select 0] call _trimFn);
            _reason = [(_p select [1, (count _p) - 1]) joinString ":"] call _trimFn;
        };
    };
    if (_s isEqualTo "OFFLINE") then { _s = "UNAVAILABLE"; };
    private _c = "#FFD166";
    if (_s in ["AVAILABLE", "ON SCENE"]) then { _c = "#9FE870"; };
    if (_s in ["UNAVAILABLE", "FAILED"]) then { _c = "#FF7A7A"; };
    [if (_s isEqualTo "") then {"UNAVAILABLE"} else {_s}, _c, _reason]
};

private _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""];
private _dispName = missionNamespace getVariable ["ARC_activeIncidentDisplayName", "(none)"];
private _typ = missionNamespace getVariable ["ARC_activeIncidentType", ""];
private _pos = missionNamespace getVariable ["ARC_activeIncidentPos", []];
private _grid = if (_pos isEqualType [] && { (count _pos) >= 2 }) then { mapGridPosition _pos } else { "????" };

private _accepted = missionNamespace getVariable ["ARC_activeIncidentAccepted", false];
private _acceptedBy = missionNamespace getVariable ["ARC_activeIncidentAcceptedByGroup", ""];
private _closeReady = missionNamespace getVariable ["ARC_activeIncidentCloseReady", false];
private _sitrepSent = missionNamespace getVariable ["ARC_activeIncidentSitrepSent", false];
private _holdMain = missionNamespace getVariable ["ARC_activeIncidentHoldMain", false];
private _foSummary = missionNamespace getVariable ["ARC_activeIncidentFollowOnSummary", ""];
if (!(_foSummary isEqualType "")) then { _foSummary = ""; };
_foSummary = [_foSummary] call _trimFn;
_foSummary = [_foSummary, ""] call _trimText;

private _sysFoLeadName = missionNamespace getVariable ["ARC_activeIncidentFollowOnLeadName", ""];
if (!(_sysFoLeadName isEqualType "")) then { _sysFoLeadName = ""; };
_sysFoLeadName = [_sysFoLeadName] call _trimFn;
_sysFoLeadName = [_sysFoLeadName, ""] call _trimText;

private _sysFoLeadPos = missionNamespace getVariable ["ARC_activeIncidentFollowOnLeadPos", []];


// Queue stats
private _qTail = missionNamespace getVariable ["ARC_pub_queueTail", []];
if (!(_qTail isEqualType [])) then { _qTail = []; };
if ((count _qTail) > _rxMaxItems) then { _qTail = _qTail select [((count _qTail) - _rxMaxItems) max 0, _rxMaxItems]; };

private _items = _qTail select { (_x isEqualType []) && { (count _x) >= 12 } };
private _pending = _items select { (toUpper (_x param [2, "", [""]])) isEqualTo "PENDING" };

private _pendingInc = _pending select { (toUpper (_x param [3, "", [""]])) isEqualTo "INCIDENT" };
private _pendingLead = _pending select { (toUpper (_x param [3, "", [""]])) isEqualTo "LEAD" };
private _pendingOther = (count _pending) - (count _pendingInc) - (count _pendingLead);

// Decide what the secondary button SHOULD say / whether it should be enabled.
private _secText = "ACTION";
private _secEnable = false;

if (!(_taskId isEqualTo "")) then
{
    if (_closeReady) then
    {
        _secText = "CLOSEOUT / FOLLOW-ON";
        _secEnable = true;
    }
    else
    {
        _secText = "CLOSEOUT / FOLLOW-ON";
        _secEnable = false;
    };
}
else
{
    // Pending INCIDENT queue items require explicit approval via TOC QUEUE mode.
    // The secondary button always generates the next incident from the pool/backlog;
    // use the primary "TOC QUEUE" button to approve specific queue items.
    _secText = "GENERATE INCIDENT";
    _secEnable = true;
};

if (!isNull _b2) then
{
    _b2 ctrlSetText _secText;
    _b2 ctrlEnable _secEnable;
};

private _role = if (_isOmni) then {"OMNI"} else { if (_canApprove) then {"TOC APPROVER"} else { if (_isAuth) then {"AUTHORIZED"} else {"LIMITED"} } };

private _lines = [];
_lines pushBack "<t size='1.2' font='PuristaMedium' color='#B89B6B'>TOC / CMD</t>";
_lines pushBack format ["<t size='0.95' color='#BDBDBD'>Access:</t> <t size='0.95'>%1</t>", _role];
_lines pushBack "<br/>";

_lines pushBack "<t size='1.05' font='PuristaMedium' color='#B89B6B'>Active Incident</t>";
_lines pushBack "";
if (_taskId isEqualTo "") then
{
    _lines pushBack "<t color='#BBBBBB' size='0.95'>No active incident.</t>";
}
else
{
    _lines pushBack format ["<t size='0.95'>%1</t>", _dispName];
    if !(_typ isEqualTo "") then { _lines pushBack format ["<t size='0.9' color='#BDBDBD'>Type:</t> <t size='0.9'>%1</t>", _typ]; };
    _lines pushBack format ["<t size='0.9' color='#BDBDBD'>Grid:</t> <t size='0.9'>%1</t>", _grid];
    _lines pushBack format ["<t size='0.9' color='#BDBDBD'>Accepted:</t> <t size='0.9'>%1</t>", if (_accepted) then {"YES"} else {"NO"}];
    if (_accepted && !(_acceptedBy isEqualTo "")) then
    {
        _lines pushBack format ["<t size='0.9' color='#BDBDBD'>Accepted by:</t> <t size='0.9'>%1</t>", _acceptedBy];
    };
    _lines pushBack format ["<t size='0.9' color='#BDBDBD'>Closeout Ready:</t> <t size='0.9'>%1</t>", if (_closeReady) then {"YES"} else {"NO"}];
    _lines pushBack format ["<t size='0.9' color='#BDBDBD'>SITREP:</t> <t size='0.9'>%1</t>", if (_sitrepSent) then {"SENT"} else {"NOT SENT"}];
    _lines pushBack "<br/>";
    private _nextStep = if (!_accepted) then {"AWAITING: INCIDENT ACCEPTANCE"} else { if (!_sitrepSent) then {"AWAITING: FIELD SITREP"} else { if (!_closeReady) then {"AWAITING: CLOSEOUT CONDITIONS"} else {"READY: ISSUE CLOSEOUT + FOLLOW-ON"} } };
    private _nextColor = if ((_nextStep find "READY:") isEqualTo 0) then {"#9FE870"} else { if ((_nextStep find "CLOSEOUT CONDITIONS") > -1) then {"#FF7A7A"} else {"#FFD166"} };
    _lines pushBack format ["<t size='0.92' color='%1' font='PuristaMedium'>%2</t>", _nextColor, _nextStep];

    // Field follow-on request (captured via SITREP wizard)
    if (_foSummary != "") then
    {
        _lines pushBack format ["<t size='0.9' color='#BDBDBD'>Field follow-on:</t> <t size='0.9'>%1</t>", _foSummary];
    };

    // Current TOC order state for the accepted unit (if any)
    private _ordLine = "";
    if (_acceptedBy != "") then
    {
        private _orders = missionNamespace getVariable ["ARC_pub_orders", []];
        if (!(_orders isEqualType [])) then { _orders = []; };
        if ((count _orders) > _rxMaxItems) then { _orders = _orders select [((count _orders) - _rxMaxItems) max 0, _rxMaxItems]; };
        if (_orders isEqualType []) then
        {
            for "_i" from ((count _orders) - 1) to 0 step -1 do
            {
                private _o = _orders select _i;
                if (!(_o isEqualType []) || { (count _o) < 7 }) then { continue; };
                private _st = _o select 2;
                private _ot = _o select 3;
                private _tg = _o select 4;
                if (!(_tg isEqualTo _acceptedBy)) then { continue; };
                private _stU = toUpper _st;
                if (_stU in ["ISSUED","ACCEPTED","COMPLETED","FAILED"]) exitWith
                {
                    private _stColor = "#FFFFFF";
                    if (_stU isEqualTo "ISSUED") then { _stColor = "#FFD166"; };
                    if (_stU isEqualTo "ACCEPTED") then { _stColor = "#9FE870"; };
                    if (_stU isEqualTo "COMPLETED") then { _stColor = "#AAAAAA"; };
                    if (_stU isEqualTo "FAILED") then { _stColor = "#FF7A7A"; };
                    _ordLine = format ["%1 (<t color='%2'>%3</t>)", _ot, _stColor, _stU];
                };
            };
        };
    };
    if (_ordLine != "") then
    {
        _lines pushBack format ["<t size='0.9' color='#BDBDBD'>Current order:</t> <t size='0.9'>%1</t>", _ordLine];
    };

    // System follow-on lead suggestion (pre-queued by incident systems)
    if (_sysFoLeadName != "") then
    {
        private _sysGrid = if (_sysFoLeadPos isEqualType [] && { (count _sysFoLeadPos) >= 2 }) then { mapGridPosition _sysFoLeadPos } else { "" };
        private _tail = if (_sysGrid isEqualTo "") then { "" } else { format [" (%1)", _sysGrid] };
        _lines pushBack format ["<t size='0.9' color='#BDBDBD'>System follow-on lead:</t> <t size='0.9'>%1%2</t>", _sysFoLeadName, _tail];
    };

    if (_holdMain) then
    {
        _lines pushBack "<t size='0.9' color='#FFD166'>Main position hold is active. Resolve the hold (or issue follow-on) before generating the next incident.</t>";
    };
};

_lines pushBack "<br/>";
_lines pushBack "<t size='1.05' font='PuristaMedium' color='#B89B6B'>Unit Status Board</t>";
_lines pushBack "";
private _statusRows = missionNamespace getVariable ["ARC_pub_unitStatuses", []];
if (!(_statusRows isEqualType [])) then { _statusRows = []; };
if ((count _statusRows) > _rxMaxItems) then { _statusRows = _statusRows select [0, _rxMaxItems]; };
if ((count _statusRows) isEqualTo 0) then
{
    _lines pushBack "<t size='0.95' color='#BBBBBB'>No unit status reports.</t>";
}
else
{
    private _support = [];
    {
        if (!(_x isEqualType []) || { (count _x) < 2 }) then { continue; };
        private _gid = _x select 0;
        private _stRaw = _x select 1;
        private _reason = if ((count _x) >= 5 && { (_x select 4) isEqualType "" }) then { [(_x select 4), ""] call _trimText } else { "" };
        private _fmt = [_stRaw, _reason] call _statusFmt;
        private _st = _fmt select 0;
        private _stColor = _fmt select 1;
        private _why = _fmt select 2;
        if (_acceptedBy != "" && { _gid != _acceptedBy } && { _st in ["IN TRANSIT", "ON SCENE"] }) then { _support pushBack _gid; };
        _lines pushBack format ["<t size='0.9' color='#BDBDBD'>%1:</t> <t size='0.9' color='%2'>%3</t>%4",
            if (_gid isEqualTo "") then {"(UNKNOWN)"} else {_gid},
            _stColor,
            _st,
            if (_why isEqualTo "") then {""} else { format [" <t size='0.85' color='#AAAAAA'>(%1)</t>", _why] }
        ];
    } forEach _statusRows;
    if ((count _support) > 0) then
    {
        _lines pushBack format ["<t size='0.9' color='#FFD166'>Supporting Units:</t> <t size='0.9'>%1</t>", _support joinString ", "];
    };
};

_lines pushBack "<br/>";
_lines pushBack "<t size='1.05' font='PuristaMedium' color='#B89B6B'>TOC Queue</t>";
_lines pushBack "";
private _pendingCnt = count _pending;
_lines pushBack format ["<t size='0.95'>Pending:</t> <t size='0.95'>%1</t>  <t size='0.9' color='#BDBDBD'>(INC %2 | LEAD %3 | OTHER %4)</t>", _pendingCnt, count _pendingInc, count _pendingLead, _pendingOther max 0];

// Per-item list: show up to 5 oldest pending items with type + age
if (_pendingCnt > 0) then
{
    _lines pushBack "";
    private _shownItems = 0;
    {
        if (_shownItems >= 5) exitWith {};
        if (!(_x isEqualType []) || { (count _x) < 12 }) then { continue; }; // Needs at least 12 fields: [id(0), createdAt(1), status(2), kind(3), from(4), fromGrp(5), fromUid(6), pos(7), summary(8), ...]
        private _qKindItem = toUpper (_x param [3, "?", [""]]);
        private _qCreated  = _x param [1, -1, [0]];
        private _qFromGrpItem = _x param [5, "", [""]];
        private _qSumItem  = _x param [8, "", [""]]; // Queue item fields: [id(0), createdAt(1), status(2), kind(3), from(4), fromGrp(5), fromUid(6), pos(7), summary(8), details(9), payload(10), meta(11), decision(12)]
        if (!(_qSumItem isEqualType "")) then { _qSumItem = ""; };        private _ageS = if (_qCreated > 0) then { round (serverTime - _qCreated) } else { -1 };
        private _ageFmt = if (_ageS < 0) then { "" } else { if (_ageS < 60) then { format [" %1s ago", _ageS] } else { format [" %1m ago", floor (_ageS / 60)] } };
        private _fromFmt = if (_qFromGrpItem isEqualTo "") then { "" } else { format [" <t color='#AAAAAA'>(%1)</t>", _qFromGrpItem] };
        private _sumFmt = if (_qSumItem isEqualTo "") then { "" } else { format [" — %1", _qSumItem select [0, (30 min (count _qSumItem))]] };
        _lines pushBack format ["<t size='0.85'><t color='#B89B6B'>%1</t><t color='#AAAAAA'>%2%3</t>%4</t>", _qKindItem, _ageFmt, _fromFmt, _sumFmt];
        _shownItems = _shownItems + 1;
    } forEach _pending;
    if (_pendingCnt > 5) then
    {
        _lines pushBack format ["<t size='0.85' color='#AAAAAA'>… and %1 more. Open TOC QUEUE to review all.</t>", _pendingCnt - 5];
    };
};

private _allowDuringRtb = missionNamespace getVariable ["ARC_allowIncidentDuringAcceptedRtb", false];
private _policyText = if (_allowDuringRtb) then
{
    "Policy: Incident generation is allowed even while accepted RTB is active."
}
else
{
    "Policy: Incident generation is blocked while the last tasked group has accepted RTB or pending order acceptance."
};
_lines pushBack format ["<t size='0.9' color='#BDBDBD'>%1</t>", _policyText];

private _deny = missionNamespace getVariable ["ARC_pub_nextIncidentLastDenied", []];
if (_deny isEqualType [] && { (count _deny) >= 3 }) then
{
    _deny params ["_denyStamp", "_denyCode", "_denyDetail"];
    private _stampOk = _denyStamp isEqualType 0;
    if (_stampOk && { (diag_tickTime - _denyStamp) <= 120 }) then
    {
        private _detail = if (_denyDetail isEqualType "") then { [_denyDetail] call _trimFn } else { "" };
        private _code = if (_denyCode isEqualType "") then { toUpper ([_denyCode] call _trimFn) } else { "UNKNOWN" };
        private _line = if (_detail isEqualTo "") then
        {
            format ["Latest generation denial: %1", _code]
        }
        else
        {
            format ["Latest generation denial: %1 — %2", _code, _detail]
        };
        _lines pushBack format ["<t size='0.9' color='#FF7A7A'>%1</t>", _line];
    };
};

_lines pushBack "<br/>";
_lines pushBack "<t size='0.95' color='#BDBDBD'>Use TOC QUEUE to review/approve items. Use CLOSEOUT to finalize an incident once close-ready.</t>";

_ctrlMain ctrlSetStructuredText parseText (_lines joinString "<br/>");

// Auto-fit + clamp to viewport so the controls group can scroll when needed.
[_ctrlMain] call BIS_fnc_ctrlFitToTextHeight;
private _mainGrp = _display displayCtrl 78015;
private _minH = if (!isNull _mainGrp) then { (ctrlPosition _mainGrp) select 3 } else { 0.74 };
private _p = ctrlPosition _ctrlMain;
_p set [3, (_p select 3) max _minH];
_ctrlMain ctrlSetPosition _p;
_ctrlMain ctrlCommit 0;

// Right panel: time-on-incident, per-group order state, next unlock condition.
if (!isNull _ctrlDetailsGrp && { !isNull _ctrlDetails }) then
{
    _ctrlDetailsGrp ctrlShow true;
    _ctrlDetails ctrlShow true;

    // Time-on-incident (from acceptance timestamp)
    private _accAtRaw = missionNamespace getVariable ["ARC_activeIncidentAcceptedAt", -1];
    if (!(_accAtRaw isEqualType 0)) then { _accAtRaw = -1; };
    private _timeOnLine = if (!(_taskId isEqualTo "") && { _accepted } && { _accAtRaw > 0 }) then
    {
        private _elapsedS = round (serverTime - _accAtRaw);
        private _elapsedFmt = if (_elapsedS < 60) then { format ["%1s", _elapsedS] } else { format ["%1m %2s", floor (_elapsedS / 60), _elapsedS mod 60] };
        format ["<t size='0.9' color='#BDBDBD'>Time on incident:</t> <t size='0.9' color='#FFD166'>%1</t>", _elapsedFmt]
    } else {
        "<t size='0.9' color='#AAAAAA'>Time on incident: — </t>"
    };

    // Per-group order state breakdown (all groups)
    private _ordersR = missionNamespace getVariable ["ARC_pub_orders", []];
    if (!(_ordersR isEqualType [])) then { _ordersR = []; };
    private _grpOrderLines = [];
    {
        if (!(_x isEqualType []) || { (count _x) < 7 }) then { continue; };
        private _stO = toUpper (_x select 2);
        if (!(_stO in ["ISSUED","ACCEPTED","COMPLETED","FAILED"])) then { continue; };
        private _tgO = _x select 4;
        private _tyO = _x select 3;
        private _stColor = "#FFFFFF";
        if (_stO isEqualTo "ISSUED")    then { _stColor = "#FFD166"; };
        if (_stO isEqualTo "ACCEPTED")  then { _stColor = "#9FE870"; };
        if (_stO isEqualTo "COMPLETED") then { _stColor = "#AAAAAA"; };
        if (_stO isEqualTo "FAILED")    then { _stColor = "#FF7A7A"; };
        _grpOrderLines pushBack format ["<t size='0.85' color='#BDBDBD'>%1:</t> <t size='0.85'>%2</t> <t size='0.85' color='%3'>(%4)</t>", _tgO, _tyO, _stColor, _stO];
        if ((count _grpOrderLines) >= 8) exitWith {};
    } forEach _ordersR;
    private _ordersSection = if ((count _grpOrderLines) > 0) then
    {
        "<t size='1.0' font='PuristaMedium' color='#B89B6B'>Unit Orders</t><br/>" + (_grpOrderLines joinString "<br/>") + "<br/>"
    } else {
        "<t size='1.0' font='PuristaMedium' color='#B89B6B'>Unit Orders</t><br/><t size='0.9' color='#AAAAAA'>No active orders.</t><br/>"
    };

    // Next workflow unlock condition
    private _nextUnlock = if (_taskId isEqualTo "") then
    {
        "<t size='0.9' color='#AAAAAA'>Waiting for next incident.</t>"
    } else {
        if (!_accepted) then {
            "<t size='0.9' color='#FFD166'>Unlock: Unit must ACCEPT ORDER (OPS tab).</t>"
        } else {
            if (!_sitrepSent) then {
                "<t size='0.9' color='#FFD166'>Unlock: Field unit must submit SITREP (close-ready required).</t>"
            } else {
                if (!_closeReady) then {
                    "<t size='0.9' color='#FF7A7A'>Unlock: Closeout conditions not yet met.</t>"
                } else {
                    "<t size='0.9' color='#9FE870'>Ready: Issue CLOSEOUT + FOLLOW-ON order now.</t>"
                };
            };
        };
    };

    private _rTxt =
        "<t size='1.0' font='PuristaMedium' color='#B89B6B'>Incident Timeline</t><br/>" +
        _timeOnLine + "<br/><br/>" +
        _ordersSection + "<br/>" +
        "<t size='1.0' font='PuristaMedium' color='#B89B6B'>Next Unlock</t><br/>" +
        _nextUnlock;

    _ctrlDetails ctrlSetStructuredText parseText _rTxt;

    private _cmdRpDefaultPos = uiNamespace getVariable ["ARC_console_cmdRpDefaultPos", []];
    if (!(_cmdRpDefaultPos isEqualType []) || { (count _cmdRpDefaultPos) < 4 }) then
    {
        _cmdRpDefaultPos = ctrlPosition _ctrlDetails;
        uiNamespace setVariable ["ARC_console_cmdRpDefaultPos", +_cmdRpDefaultPos];
    };
    [_ctrlDetails] call BIS_fnc_ctrlFitToTextHeight;
    private _cmdGrp = _display displayCtrl 78016;
    private _cmdMinH = if (!isNull _cmdGrp) then { (ctrlPosition _cmdGrp) select 3 } else { 0.74 };
    private _cmdP = ctrlPosition _ctrlDetails;
    _cmdP set [0, _cmdRpDefaultPos select 0];
    _cmdP set [1, _cmdRpDefaultPos select 1];
    _cmdP set [2, _cmdRpDefaultPos select 2];
    _cmdP set [3, (_cmdP select 3) max _cmdMinH];
    _ctrlDetails ctrlSetPosition _cmdP;
    _ctrlDetails ctrlCommit 0;
};

true

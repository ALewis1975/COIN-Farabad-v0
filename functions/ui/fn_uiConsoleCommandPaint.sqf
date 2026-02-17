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

private _ctrlMain = _display displayCtrl 78010;
private _b2 = _display displayCtrl 78022;

// OMNI override (playtesting)
private _omniTokens = missionNamespace getVariable ["ARC_consoleOmniTokens", ["OMNI"]];
if (!(_omniTokens isEqualType [])) then { _omniTokens = ["OMNI"]; };
private _isOmni = false;
{
    if (_x isEqualType "" && { [player, _x] call ARC_fnc_rolesHasGroupIdToken }) exitWith { _isOmni = true; };
} forEach _omniTokens;

private _canApprove = [player] call ARC_fnc_rolesCanApproveQueue;
private _isAuth = [player] call ARC_fnc_rolesIsAuthorized;

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
_foSummary = trim _foSummary;

private _sysFoLeadName = missionNamespace getVariable ["ARC_activeIncidentFollowOnLeadName", ""];
if (!(_sysFoLeadName isEqualType "")) then { _sysFoLeadName = ""; };
_sysFoLeadName = trim _sysFoLeadName;

private _sysFoLeadPos = missionNamespace getVariable ["ARC_activeIncidentFollowOnLeadPos", []];


// Queue stats
private _qTail = missionNamespace getVariable ["ARC_pub_queueTail", []];
if (!(_qTail isEqualType [])) then { _qTail = []; };

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
        _secText = "CLOSEOUT";
        _secEnable = true;
    }
    else
    {
        _secText = "ACTION";
        _secEnable = false;
    };
}
else
{
    if ((count _pendingInc) > 0 && (_canApprove || _isOmni)) then
    {
		_secText = "APPROVE NEXT (QUEUE)";
        _secEnable = true;
    }
    else
    {
		_secText = "GENERATE INCIDENT";
        _secEnable = true;
    };
};

if (!isNull _b2) then
{
    _b2 ctrlSetText _secText;
    _b2 ctrlEnable _secEnable;
};

private _role = if (_isOmni) then {"OMNI"} else { if (_canApprove) then {"TOC APPROVER"} else { if (_isAuth) then {"AUTHORIZED"} else {"LIMITED"} } };

private _lines = [];
_lines pushBack "<t size='1.2' font='PuristaMedium'>TOC / CMD</t>";
_lines pushBack format ["<t size='0.95' color='#BDBDBD'>Access:</t> <t size='0.95'>%1</t>", _role];
_lines pushBack "<br/>";

_lines pushBack "<t size='1.05' font='PuristaMedium'>Active Incident</t>";
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

    // Field follow-on request (captured via SITREP wizard)
    if (_foSummary isNotEqualTo "") then
    {
        _lines pushBack format ["<t size='0.9' color='#BDBDBD'>Field follow-on:</t> <t size='0.9'>%1</t>", _foSummary];
    };

    // Current TOC order state for the accepted unit (if any)
    private _ordLine = "";
    if (_acceptedBy isNotEqualTo "") then
    {
        private _orders = missionNamespace getVariable ["ARC_pub_orders", []];
        if (_orders isEqualType []) then
        {
            for "_i" from ((count _orders) - 1) to 0 step -1 do
            {
                private _o = _orders # _i;
                if (!(_o isEqualType []) || { (count _o) < 7 }) then { continue; };
                _o params ["_oid","_iat","_st","_ot","_tg","_data","_meta"];
                if (!(_tg isEqualTo _acceptedBy)) then { continue; };
                private _stU = toUpper _st;
                if (_stU in ["ISSUED","ACCEPTED"]) exitWith
                {
                    _ordLine = format ["%1 (%2)", _ot, _stU];
                };
            };
        };
    };
    if (_ordLine isNotEqualTo "") then
    {
        _lines pushBack format ["<t size='0.9' color='#BDBDBD'>Current order:</t> <t size='0.9'>%1</t>", _ordLine];
    };

    // System follow-on lead suggestion (pre-queued by incident systems)
    if (_sysFoLeadName isNotEqualTo "") then
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
_lines pushBack "<t size='1.05' font='PuristaMedium'>TOC Queue</t>";
_lines pushBack format ["<t size='0.95'>Pending:</t> <t size='0.95'>%1</t>", count _pending];
_lines pushBack format ["<t size='0.9' color='#BDBDBD'>Incidents:</t> <t size='0.9'>%1</t>  <t size='0.9' color='#BDBDBD'>Leads:</t> <t size='0.9'>%2</t>  <t size='0.9' color='#BDBDBD'>Other:</t> <t size='0.9'>%3</t>", count _pendingInc, count _pendingLead, _pendingOther max 0];

_lines pushBack "<br/>";
_lines pushBack "<t size='0.95' color='#BDBDBD'>Use TOC QUEUE to review/approve items. Use CLOSEOUT to finalize an incident once close-ready.</t>";

_ctrlMain ctrlSetStructuredText parseText (_lines joinString "<br/>");

// Auto-fit + clamp to viewport so the controls group can scroll when needed.
[_ctrlMain] call BIS_fnc_ctrlFitToTextHeight;
private _mainGrp = _display displayCtrl 78015;
private _minH = if (!isNull _mainGrp) then { (ctrlPosition _mainGrp) # 3 } else { 0.74 };
private _p = ctrlPosition _ctrlMain;
_p set [3, (_p # 3) max _minH];
_ctrlMain ctrlSetPosition _p;
_ctrlMain ctrlCommit 0;
true
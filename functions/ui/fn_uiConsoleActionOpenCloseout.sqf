/*
    ARC_fnc_uiConsoleActionOpenCloseout

    Client: open an incident closeout prompt for TOC approvers.

    Behavior:
      - Presents a minimal dialog to choose SUCCEEDED or FAILED.
      - Confirms the choice.
      - RemoteExecs the decision to the server (ARC_fnc_tocRequestCloseIncident).

    Design rules:
      - Server remains authoritative (will enforce any forced-fail rules).
      - UI provides clear context so players don't guess.

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

// UI event handlers are unscheduled; dialogs/prompts require scheduled context.
if (!canSuspend) exitWith { _this spawn ARC_fnc_uiConsoleActionOpenCloseout; false };

// OMNI override (playtesting)
private _omniTokens = missionNamespace getVariable ["ARC_consoleOmniTokens", ["OMNI"]];
if (!(_omniTokens isEqualType [])) then { _omniTokens = ["OMNI"]; };
private _isOmni = false;
{
    if (_x isEqualType "" && { [player, _x] call ARC_fnc_rolesHasGroupIdToken }) exitWith { _isOmni = true; };
} forEach _omniTokens;

private _canApprove = _isOmni || { [player] call ARC_fnc_rolesCanApproveQueue };
if (!_canApprove) exitWith
{
    ["TOC Ops", "Closeout is restricted to S3/Command (or OMNI)."] call ARC_fnc_clientToast;
    false
};

private _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""]; 
if (!(_taskId isEqualType "")) then { _taskId = ""; };
if (_taskId isEqualTo "") exitWith
{
    ["TOC Ops", "No active incident to close."] call ARC_fnc_clientToast;
    false
};

private _acc = missionNamespace getVariable ["ARC_activeIncidentAccepted", false];
if (!(_acc isEqualType true) && !(_acc isEqualType false)) then { _acc = false; };
if (!_acc) exitWith
{
    ["TOC Ops", "Active incident is not accepted yet. Accept it before closeout."] call ARC_fnc_clientToast;
    false
};

private _closeReady = missionNamespace getVariable ["ARC_activeIncidentCloseReady", false];
if (!(_closeReady isEqualType true) && !(_closeReady isEqualType false)) then { _closeReady = false; };

private _disp = missionNamespace getVariable ["ARC_activeIncidentDisplayName", "Incident"]; 
if (!(_disp isEqualType "")) then { _disp = "Incident"; };

private _type = missionNamespace getVariable ["ARC_activeIncidentType", ""]; 
if (!(_type isEqualType "")) then { _type = ""; };
private _typeU = toUpper _type;

private _pos = missionNamespace getVariable ["ARC_activeIncidentPos", []];
if (!(_pos isEqualType [])) then { _pos = []; };
private _grid = if (_pos isEqualType [] && { (count _pos) >= 2 }) then { mapGridPosition _pos } else { "" };

private _suggest = missionNamespace getVariable ["ARC_activeIncidentSuggestedResult", ""]; 
if (!(_suggest isEqualType "")) then { _suggest = ""; };
private _suggestU = toUpper _suggest;

private _reason = missionNamespace getVariable ["ARC_activeIncidentCloseReason", ""]; 
if (!(_reason isEqualType "")) then { _reason = ""; };
private _reasonU = toUpper _reason;

private _sitrepSent = missionNamespace getVariable ["ARC_activeIncidentSitrepSent", false];
if (!(_sitrepSent isEqualType true) && !(_sitrepSent isEqualType false)) then { _sitrepSent = false; };

if (!_sitrepSent) exitWith {
    ["Closeout", "SITREP has not been sent. Send SITREP before initiating closeout."] call ARC_fnc_clientToast;
    false
};

private _sitrepFrom = missionNamespace getVariable ["ARC_activeIncidentSitrepFrom", ""]; 
if (!(_sitrepFrom isEqualType "")) then { _sitrepFrom = ""; };
private _sitrepSum = missionNamespace getVariable ["ARC_activeIncidentSitrepSummary", ""]; 
if (!(_sitrepSum isEqualType "")) then { _sitrepSum = ""; };

private _forceTag = if (_closeReady) then { "" } else { "<t color='#FFB0B0'>(FORCE)</t> " };

private _body = "";
_body = _body + format ["<t size='1.1' font='PuristaMedium'>%1Closeout</t><br/>", _forceTag];
_body = _body + format ["<t size='0.95' color='#DDDDDD'>%1 (%2)</t><br/>", _disp, if (_typeU isEqualTo "") then {"UNKNOWN"} else {_typeU}];
if (_grid isNotEqualTo "") then { _body = _body + format ["<t size='0.9' color='#CCCCCC'>Grid: %1</t><br/>", _grid]; };

_body = _body + "<br/>";
_body = _body + format ["<t size='0.9'>Close-ready: %1</t><br/>", if (_closeReady) then {"YES"} else {"NO"}];
if (_suggestU isNotEqualTo "") then { _body = _body + format ["<t size='0.9'>Suggested: %1</t><br/>", _suggestU]; };
if (_reasonU isNotEqualTo "") then { _body = _body + format ["<t size='0.9'>Reason: %1</t><br/>", _reasonU]; };

_body = _body + "<br/>";
_body = _body + format ["<t size='0.9'>SITREP: %1</t><br/>", if (_sitrepSent) then {"SENT"} else {"PENDING"}];
if (_sitrepSent && { _sitrepSum isNotEqualTo "" }) then
{
    _body = _body + format ["<t size='0.85' color='#CCCCCC'>From: %1</t><br/>", if (_sitrepFrom isEqualTo "") then {"(unknown)"} else {_sitrepFrom}];
    _body = _body + format ["<t size='0.85' color='#CCCCCC'>%1</t><br/>", _sitrepSum];
};

// Default selection tries to follow the suggested result (if provided).
private _defaultSel = 1; // FAILED
if (_suggestU isEqualTo "SUCCEEDED") then { _defaultSel = 0; };
if (_suggestU isEqualTo "FAILED") then { _defaultSel = 1; };

uiNamespace setVariable ["ARC_closeout_body", _body];
uiNamespace setVariable ["ARC_closeout_defaultSel", _defaultSel];
uiNamespace setVariable ["ARC_closeout_result", nil];

private _consoleWasOpen = !isNull (findDisplay 78000);

// Open dialog (defined in config/CfgDialogs.hpp)
createDialog "ARC_CloseoutDialog";

waitUntil {
    uiSleep 0.05;
    (!isNil { uiNamespace getVariable "ARC_closeout_result" }) || { isNull (findDisplay 78200) }
};

private _res = uiNamespace getVariable ["ARC_closeout_result", [false, -1]];
uiNamespace setVariable ["ARC_closeout_result", nil];

_res params ["_ok", "_idx"]; 
if (!(_ok isEqualType true)) then { _ok = false; };
if (!(_idx isEqualType 0)) then { _idx = -1; };

// Re-open console if the dialog stack closed it.
if (_consoleWasOpen && { isNull (findDisplay 78000) }) then
{
    [] call ARC_fnc_uiConsoleOpen;
};

if (!_ok || { _idx < 0 }) exitWith {false};

private _result = if (_idx isEqualTo 0) then {"SUCCEEDED"} else {"FAILED"};

// Next: issue a follow-on order as part of the closeout flow.
// Pull any field-submitted follow-on request (from the SITREP flow) so TOC can approve or override.
private _foArr = missionNamespace getVariable ["ARC_activeIncidentFollowOnRequest", []];
if (!(_foArr isEqualType [])) then { _foArr = []; };
private _foSummary = missionNamespace getVariable ["ARC_activeIncidentFollowOnSummary", ""]; 
if (!(_foSummary isEqualType "")) then { _foSummary = ""; };

private _sysLeadId = missionNamespace getVariable ["ARC_activeIncidentFollowOnLeadId", ""]; 
if (!(_sysLeadId isEqualType "")) then { _sysLeadId = ""; };
_sysLeadId = trim _sysLeadId;
private _sysLeadName = missionNamespace getVariable ["ARC_activeIncidentFollowOnLeadName", ""]; 
if (!(_sysLeadName isEqualType "")) then { _sysLeadName = ""; };
_sysLeadName = trim _sysLeadName;

private _tgtGrp = missionNamespace getVariable ["ARC_activeIncidentAcceptedByGroup", ""]; 
if (!(_tgtGrp isEqualType "")) then { _tgtGrp = ""; };
_tgtGrp = trim _tgtGrp;
if (_tgtGrp isEqualTo "") then { _tgtGrp = "(unknown group)"; };

private _getPair = {
    params ["_arr", "_k", "_d"];
    private _i = _arr findIf { _x isEqualType [] && { (count _x) == 2 } && { (_x # 0) isEqualTo _k } };
    if (_i >= 0) exitWith { _arr # _i # 1 };
    _d
};

// TOC defaults
private _dReq = "HOLD";
private _dPurpose = "REFIT";
private _dHoldIntent = "SECURITY";
private _dHoldMin = 30;
private _dProceedIntent = "NEXT TASK";

// If field requested a follow-on, use it as default.
private _fReq = toUpper (trim ([_foArr, "request", ""] call _getPair));
private _fPurpose = toUpper (trim ([_foArr, "purpose", ""] call _getPair));
private _fHoldIntent = toUpper (trim ([_foArr, "holdIntent", ""] call _getPair));
private _fHoldMin = [_foArr, "holdMinutes", -1] call _getPair;
private _fProceedIntent = toUpper (trim ([_foArr, "proceedIntent", ""] call _getPair));

if (_fReq in ["RTB","HOLD","PROCEED"]) then { _dReq = _fReq; };
if (_fPurpose in ["REFIT","INTEL","EPW"]) then { _dPurpose = _fPurpose; };
if (_fHoldIntent isNotEqualTo "") then { _dHoldIntent = _fHoldIntent; };
if (_fHoldMin isEqualType 0 && { _fHoldMin > 0 }) then { _dHoldMin = _fHoldMin; };
if (_fProceedIntent isNotEqualTo "") then { _dProceedIntent = _fProceedIntent; };

// If a system follow-on lead exists (IED detonation response, etc.), bias toward PROCEED.
if (_sysLeadId isNotEqualTo "") then { _dReq = "PROCEED"; };

// Custom header for TOC issue flow
private _hdr = format [
    "<t size='1.05' font='PuristaMedium'>ISSUE FOLLOW-ON ORDER</t><br/><t size='0.9' color='#CCCCCC'>To: %1 | After: %2</t>",
    _tgtGrp,
    _disp
];
if (_grid isNotEqualTo "") then { _hdr = _hdr + format ["<br/><t size='0.85' color='#AAAAAA'>Last known grid: %1</t>", _grid]; };
if (_sitrepSent && { _sitrepSum isNotEqualTo "" }) then { _hdr = _hdr + format ["<br/><t size='0.85' color='#AAAAAA'>SITREP: %1</t>", _sitrepSum]; };
if (_foSummary isNotEqualTo "") then { _hdr = _hdr + format ["<br/><t size='0.85' color='#AAAAAA'>Field follow-on request: %1</t>", _foSummary]; };
if (_sysLeadName isNotEqualTo "") then { _hdr = _hdr + format ["<br/><t size='0.85' color='#AAAAAA'>System follow-on lead queued: %1</t>", _sysLeadName]; };

uiNamespace setVariable ["ARC_followOn_title", "ISSUE FOLLOW-ON ORDER"]; 
uiNamespace setVariable ["ARC_followOn_headerOverride", _hdr];
uiNamespace setVariable ["ARC_followOn_defaultRequest", _dReq];
uiNamespace setVariable ["ARC_followOn_defaultPurpose", _dPurpose];
uiNamespace setVariable ["ARC_followOn_defaultHoldIntent", _dHoldIntent];
uiNamespace setVariable ["ARC_followOn_defaultHoldMinutes", _dHoldMin];
uiNamespace setVariable ["ARC_followOn_defaultProceedIntent", _dProceedIntent];

private _foRes = [] call ARC_fnc_uiFollowOnPrompt;
// Clear overrides so the next use (field) is clean.
uiNamespace setVariable ["ARC_followOn_title", nil];
uiNamespace setVariable ["ARC_followOn_headerOverride", nil];
uiNamespace setVariable ["ARC_followOn_defaultRequest", nil];
uiNamespace setVariable ["ARC_followOn_defaultPurpose", nil];
uiNamespace setVariable ["ARC_followOn_defaultHoldIntent", nil];
uiNamespace setVariable ["ARC_followOn_defaultHoldMinutes", nil];
uiNamespace setVariable ["ARC_followOn_defaultProceedIntent", nil];

if (!(_foRes isEqualType []) || { (count _foRes) < 10 }) exitWith {false};
_foRes params ["_okFo", "_req", "_purpose", "_rat", "_con", "_sup", "_notes", "_hIntent", "_hMin", "_pIntent"];
if (!_okFo) exitWith {false};

// Final confirmation (closeout + order)
private _orderLine = if (toUpper _req isEqualTo "RTB") then { format ["%1 (%2)", toUpper _req, toUpper _purpose] } else { toUpper _req };
private _prompt = format ["Close %1 as %2%3 and issue %4?", _disp, _result, if (_closeReady) then {""} else {" (FORCE)"}, _orderLine];
private _confirm = [_prompt, "TOC Ops", true, true] call BIS_fnc_guiMessage;
if (!_confirm) exitWith {false};

[_result, _req, _purpose, _rat, _con, _sup, _notes, _hIntent, _hMin, _pIntent, player] remoteExec ["ARC_fnc_tocRequestCloseoutAndOrder", 2];
["TOC Ops", format ["Closeout submitted: %1. Awaiting server confirmation. Follow-on: %2", _result, _orderLine]] call ARC_fnc_clientToast;

true
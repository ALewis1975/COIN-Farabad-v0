/*
    ARC_fnc_uiConsoleOpsPaint

    UI09: paint Operations (S3) tab.

    Requirements satisfied:
      - Workboard includes incidents, leads, AND orders
      - Incidents / Orders / Leads displayed in their own frames
      - Details pane shows context and recommended next action

    Params:
      0: DISPLAY
      1: BOOL - rebuild lists (default true)

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

params [
    ["_display", displayNull, [displayNull]],
    ["_rebuild", true, [true]]
];

if (isNull _display) exitWith {false};

private _ctrlMain = _display displayCtrl 78010;
private _ctrlList = _display displayCtrl 78011;
private _ctrlDetails = _display displayCtrl 78012;

private _b1 = _display displayCtrl 78021;
private _b2 = _display displayCtrl 78022;

// Ops frame controls
private _cIncBg = _display displayCtrl 78030;
private _cIncLbl = _display displayCtrl 78031;
private _cInc = _display displayCtrl 78032;
private _cOrdBg = _display displayCtrl 78033;
private _cOrdLbl = _display displayCtrl 78034;
private _cOrd = _display displayCtrl 78035;
private _cLeadBg = _display displayCtrl 78036;
private _cLeadLbl = _display displayCtrl 78037;
private _cLead = _display displayCtrl 78038;

// Visibility (override the base state from uiConsoleRefresh)
if (!isNull _ctrlMain) then { _ctrlMain ctrlShow false; };
if (!isNull _ctrlList) then { _ctrlList ctrlShow false; };
if (!isNull _ctrlDetails) then { _ctrlDetails ctrlShow true; };

{
    if (!isNull _x) then { _x ctrlShow true; };
} forEach [_cIncBg,_cIncLbl,_cInc,_cOrdBg,_cOrdLbl,_cOrd,_cLeadBg,_cLeadLbl,_cLead];

// Helpers
private _safeStr = {
    params ["_s", ["_fallback", "N/A"]];
    if (!(_s isEqualType "")) exitWith {_fallback};
    _s = trim _s;
    if (_s isEqualTo "") then {_fallback} else {_s};
};

private _pairGet = {
    params ["_pairs", "_key", ["_def", ""]];
    if (!(_pairs isEqualType [])) exitWith {_def};
    private _idx = _pairs findIf { _x isEqualType [] && { (count _x) >= 2 } && { (_x#0) isEqualTo _key } };
    if (_idx < 0) exitWith {_def};
    private _v = (_pairs # _idx) # 1;
    if (isNil "_v") exitWith {_def};
    _v
};

// Persist selection + focus across rebuilds
private _selIncData = uiNamespace getVariable ["ARC_console_opsSel_inc", ""]; if (!(_selIncData isEqualType "")) then { _selIncData = ""; };
private _selOrdData = uiNamespace getVariable ["ARC_console_opsSel_ord", ""]; if (!(_selOrdData isEqualType "")) then { _selOrdData = ""; };
private _selLeadData = uiNamespace getVariable ["ARC_console_opsSel_lead", ""]; if (!(_selLeadData isEqualType "")) then { _selLeadData = ""; };

private _focus = uiNamespace getVariable ["ARC_console_opsFocus", "INCIDENT"]; if (!(_focus isEqualType "")) then { _focus = "INCIDENT"; };
_focus = toUpper (trim _focus);

if (_rebuild) then
{
    // -------------------------------
    // Incidents
    // -------------------------------
    lbClear _cInc;
    private _activeId = missionNamespace getVariable ["ARC_activeTaskId", ""]; if (!(_activeId isEqualType "")) then { _activeId = ""; };
    _activeId = trim _activeId;
    if (_activeId isEqualTo "") then
    {
        private _i = _cInc lbAdd "(No active incident)";
        _cInc lbSetData [_i, "NONE"];
    }
    else
    {
        private _dispName = missionNamespace getVariable ["ARC_activeIncidentDisplayName", "Incident"]; if (!(_dispName isEqualType "")) then { _dispName = "Incident"; };
        private _typ = missionNamespace getVariable ["ARC_activeIncidentType", ""]; if (!(_typ isEqualType "")) then { _typ = ""; };
        private _accepted = missionNamespace getVariable ["ARC_activeIncidentAccepted", false]; if (!(_accepted isEqualType true) && !(_accepted isEqualType false)) then { _accepted = false; };
        private _tag = if (_accepted) then {"ACTIVE"} else {"PENDING"};
        private _label = format ["[%1] %2", _tag, _dispName];
        if ((trim _typ) != "") then { _label = _label + format [" (%1)", toUpper (trim _typ)]; };
        private _i = _cInc lbAdd _label;
        _cInc lbSetData [_i, format ["INCIDENT|%1", _activeId]];
    };

    // Restore selection (incident)
    private _restoreSel = {
        params ["_ctrl", "_wantedData"];
        if (isNull _ctrl) exitWith {};
        if (_wantedData isEqualTo "") exitWith {};
        private _n = lbSize _ctrl;
        for "_i" from 0 to (_n - 1) do
        {
            if ((_ctrl lbData _i) isEqualTo _wantedData) exitWith { _ctrl lbSetCurSel _i; };
        };
    };
    [_cInc, _selIncData] call _restoreSel;

    // -------------------------------
    // Orders
    // -------------------------------
    lbClear _cOrd;
    private _orders = missionNamespace getVariable ["ARC_pub_orders", []];
    if (!(_orders isEqualType [])) then { _orders = []; };
    private _gid = groupId group player;
    private _mine = _orders select {
        _x isEqualType [] && { (count _x) >= 5 } && { (_x # 4) isEqualTo _gid }
    };

    if ((count _mine) isEqualTo 0) then
    {
        private _o = _cOrd lbAdd "(No orders for your group)";
        _cOrd lbSetData [_o, "NONE"];
    }
    else
    {
        {
            private _order = _x;
            private _id = _order # 0;
            private _status = toUpper (trim (_order # 2));
            private _otype = toUpper (trim (_order # 3));
            private _pairs = _order # 5;
            private _purpose = [_pairs, "purpose", ""] call _pairGet;
            if (!(_purpose isEqualType "")) then { _purpose = ""; };
            _purpose = trim _purpose;

            private _label = format ["[%1] %2", _status, _otype];
            if (_purpose != "") then { _label = _label + format [" - %1", _purpose]; };
            private _idx = _cOrd lbAdd _label;
            _cOrd lbSetData [_idx, format ["ORDER|%1", _id]];
        } forEach _mine;
    };
    [_cOrd, _selOrdData] call _restoreSel;

    // -------------------------------
    // Leads
    // -------------------------------
    lbClear _cLead;
    private _leads = missionNamespace getVariable ["ARC_leadPoolPublic", []];
    if (!(_leads isEqualType [])) then { _leads = []; };

    if ((count _leads) isEqualTo 0) then
    {
        private _l = _cLead lbAdd "(No leads available)";
        _cLead lbSetData [_l, "NONE"];
    }
    else
    {
        {
            private _lead = _x;
            if (!(_lead isEqualType []) || { (count _lead) < 4 }) then { continue };
            private _id = _lead # 0;
            private _typ = toUpper (trim (_lead # 1));
            private _name = _lead # 2;
            if (!(_name isEqualType "")) then { _name = "Lead"; };
            private _label = format ["[%1] %2", _typ, _name];
            private _idx = _cLead lbAdd _label;
            _cLead lbSetData [_idx, format ["LEAD|%1", _id]];
        } forEach _leads;
    };
    [_cLead, _selLeadData] call _restoreSel;
};

// Determine focus if current focus has no valid selection
private _selInc = lbCurSel _cInc;
private _selOrd = lbCurSel _cOrd;
private _selLead = lbCurSel _cLead;

private _hasSelInc = (_selInc >= 0) && { (_cInc lbData _selInc) != "" } && { (_cInc lbData _selInc) != "NONE" };
private _hasSelOrd = (_selOrd >= 0) && { (_cOrd lbData _selOrd) != "" } && { (_cOrd lbData _selOrd) != "NONE" };
private _hasSelLead = (_selLead >= 0) && { (_cLead lbData _selLead) != "" } && { (_cLead lbData _selLead) != "NONE" };

if (_focus isEqualTo "INCIDENT" && !_hasSelInc) then { _focus = "ORDER"; };
if (_focus isEqualTo "ORDER" && !_hasSelOrd) then { _focus = "LEAD"; };
if (_focus isEqualTo "LEAD" && !_hasSelLead) then { _focus = "INCIDENT"; };

uiNamespace setVariable ["ARC_console_opsFocus", _focus];

// Resolve focused selection data
private _focusData = "";
switch (_focus) do
{
    case "INCIDENT": { if (_hasSelInc) then { _focusData = _cInc lbData _selInc; }; };
    case "ORDER":    { if (_hasSelOrd) then { _focusData = _cOrd lbData _selOrd; }; };
    case "LEAD":     { if (_hasSelLead) then { _focusData = _cLead lbData _selLead; }; };
};

// Store per-list selections (for rebuild preservation)
if (_hasSelInc) then { uiNamespace setVariable ["ARC_console_opsSel_inc", _cInc lbData _selInc]; };
if (_hasSelOrd) then { uiNamespace setVariable ["ARC_console_opsSel_ord", _cOrd lbData _selOrd]; };
if (_hasSelLead) then { uiNamespace setVariable ["ARC_console_opsSel_lead", _cLead lbData _selLead]; };

// Details + recommended next action
private _details = "";
private _primaryLabel = "ACTION";
private _primaryEnabled = false;

private _followOnViaSitrepLabel = "FOLLOW-ON (SITREP)";
private _secondaryLabel = _followOnViaSitrepLabel;
private _secondaryEnabled = false; // Follow-on requests are part of the SITREP wizard; no standalone button.

private _isAuth = [player] call ARC_fnc_rolesIsAuthorized;

if (_focusData isEqualTo "") then
{
    _details = "<t size='1.1' font='PuristaMedium'>Operations</t><br/><br/>" +
               "Select an incident, an order, or a lead to view details." +
               "<br/><br/><t size='0.9' color='#BDBDBD'>Follow-on requests are captured inside the SITREP flow.</t>";
}
else
{
    private _parts = _focusData splitString "|";
    private _kind = toUpper (trim (_parts # 0));
    private _id = if ((count _parts) > 1) then { _parts # 1 } else { "" };

    switch (_kind) do
    {
        case "INCIDENT":
        {
            private _dispName = missionNamespace getVariable ["ARC_activeIncidentDisplayName", "Incident"]; if (!(_dispName isEqualType "")) then { _dispName = "Incident"; };
            private _typ = missionNamespace getVariable ["ARC_activeIncidentType", ""]; if (!(_typ isEqualType "")) then { _typ = ""; };
            private _pos = missionNamespace getVariable ["ARC_activeIncidentPos", [0,0,0]]; if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = [0,0,0]; };
            private _grid = mapGridPosition _pos;
            private _accepted = missionNamespace getVariable ["ARC_activeIncidentAccepted", false]; if (!(_accepted isEqualType true) && !(_accepted isEqualType false)) then { _accepted = false; };
            private _acceptedBy = missionNamespace getVariable ["ARC_activeIncidentAcceptedByGroup", ""]; if (!(_acceptedBy isEqualType "")) then { _acceptedBy = ""; };
            private _closeReady = missionNamespace getVariable ["ARC_activeIncidentCloseReady", false]; if (!(_closeReady isEqualType true) && !(_closeReady isEqualType false)) then { _closeReady = false; };
            private _sitrepSent = missionNamespace getVariable ["ARC_activeIncidentSitrepSent", false]; if (!(_sitrepSent isEqualType true) && !(_sitrepSent isEqualType false)) then { _sitrepSent = false; };
            private _sitrepDetails = missionNamespace getVariable ["ARC_activeIncidentSitrepDetails", ""]; if (!(_sitrepDetails isEqualType "")) then { _sitrepDetails = ""; };

            _details = format ["<t size='1.2' font='PuristaMedium'>%1</t><br/>", _dispName];
            if ((trim _typ) != "") then { _details = _details + format ["<t color='#A0A0A0'>Type:</t> %1<br/>", toUpper (trim _typ)]; };
            _details = _details + format ["<t color='#A0A0A0'>Grid:</t> %1<br/>", _grid];
            _details = _details + format ["<t color='#A0A0A0'>Accepted:</t> %1", if (_accepted) then {"YES"} else {"NO"}];
            if (_acceptedBy != "") then { _details = _details + format [" (by %1)", _acceptedBy]; };
            _details = _details + "<br/>";
            _details = _details + format ["<t color='#A0A0A0'>Close-ready:</t> %1<br/>", if (_closeReady) then {"YES"} else {"NO"}];
            _details = _details + format ["<t color='#A0A0A0'>SITREP sent:</t> %1<br/><br/>", if (_sitrepSent) then {"YES"} else {"NO"}];

            if (!_accepted) then
            {
                _primaryLabel = "Accept Incident";
                _primaryEnabled = _isAuth;
                _details = _details + "Next: accept the incident to start execution.";
            }
            else
            {
                // Next actions: keep SITREP as the primary reporting step until sent.
                private _typU = toUpper (trim _typ);
                private _canSit = [player] call ARC_fnc_clientCanSendSitrep;

                if (_sitrepSent) then
                {
                    // Prevent duplicate SITREPs; display the submitted report inline for transparency.
                    _primaryLabel = "SITREP SENT";
                    _primaryEnabled = false;
                    _details = _details + "SITREP already submitted. Await TOC follow-on / closeout guidance.";

                    if (_sitrepDetails isNotEqualTo "") then
                    {
                        private _sitHtml = (_sitrepDetails splitString "\n") joinString "<br/>";
                        _details = _details + "<br/><br/><t size='1.0' font='PuristaMedium'>Last SITREP (full)</t><br/>" +
                                   "<t size='0.85' color='#DDDDDD'>" + _sitHtml + "</t>";
                    };
                }
                else
                {
                    // Primary: SITREP (enabled if allowed)
                    _primaryLabel = "Send SITREP";
                    _primaryEnabled = _canSit;

                    if (_canSit) then
                    {
                        _details = _details + "Next: send SITREP to trigger TOC follow-on.";
                    }
                    else
                    {
                        _details = _details + "Next: send SITREP (not available yet). Ensure you are within range and the incident is accepted.";
                    };

                    // Secondary: EOD disposition request (IED incidents only, pre-closeout)
                    if (_typU isEqualTo "IED") then
                    {
                        _secondaryLabel = "EOD DISPO";
                        _secondaryEnabled = _isAuth;
                    };
                };

            };
        };

        case "ORDER":
        {
            private _orders = missionNamespace getVariable ["ARC_pub_orders", []]; if (!(_orders isEqualType [])) then { _orders = []; };
            private _o = _orders findIf { _x isEqualType [] && { (count _x) >= 1 } && { (_x # 0) isEqualTo _id } };
            if (_o < 0) then
            {
                _details = "<t size='1.1' font='PuristaMedium'>Order</t><br/><br/>Order not found (stale UI).";
            }
            else
            {
                private _order = _orders # _o;
                private _status = toUpper (trim (_order # 2));
                private _otype = toUpper (trim (_order # 3));
                private _pairs = _order # 5;
                private _meta = _order # 6;

                private _purpose = [_pairs, "purpose", ""] call _pairGet;
                if (!(_purpose isEqualType "")) then { _purpose = ""; };
                _purpose = trim _purpose;

                private _note = [_meta, "note", ""] call _pairGet;
                if (!(_note isEqualType "")) then { _note = ""; };
                _note = trim _note;

                _details = format ["<t size='1.2' font='PuristaMedium'>%1</t><br/>", _otype];
                _details = _details + format ["<t color='#A0A0A0'>Status:</t> %1<br/>", _status];
                if (_purpose != "") then { _details = _details + format ["<t color='#A0A0A0'>Purpose:</t> %1<br/>", _purpose]; };
                if (_note != "") then { _details = _details + format ["<t color='#A0A0A0'>Note:</t> %1<br/>", _note]; };
                _details = _details + "<br/>";

                if (_status isEqualTo "ISSUED") then
                {
                    _primaryLabel = "Accept Order";
                    _primaryEnabled = _isAuth;
                    _details = _details + "Next: accept the order to proceed.";
                }
                else
                {
                    _primaryLabel = "ACTION";
                    _primaryEnabled = false;
                    _details = _details + "No action available for this order in UI09 (view only).";
                };
            };
        };

        case "LEAD":
        {
            private _leads = missionNamespace getVariable ["ARC_leadPoolPublic", []]; if (!(_leads isEqualType [])) then { _leads = []; };
            private _idx = _leads findIf { _x isEqualType [] && { (count _x) >= 1 } && { (_x # 0) isEqualTo _id } };
            if (_idx < 0) then
            {
                _details = "<t size='1.1' font='PuristaMedium'>Lead</t><br/><br/>Lead not found (stale UI).";
            }
            else
            {
                private _lead = _leads # _idx;
                private _typ = toUpper (trim (_lead # 1));
                private _name = _lead # 2; if (!(_name isEqualType "")) then { _name = "Lead"; };
                private _pos = _lead # 3; if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = [0,0,0]; };
                private _grid = mapGridPosition _pos;
                private _tag = if ((count _lead) > 10) then { _lead # 10 } else { "" };
                if (!(_tag isEqualType "")) then { _tag = ""; };
                _tag = trim _tag;

                _details = format ["<t size='1.2' font='PuristaMedium'>%1</t><br/>", _name];
                _details = _details + format ["<t color='#A0A0A0'>Type:</t> %1<br/>", _typ];
                _details = _details + format ["<t color='#A0A0A0'>Grid:</t> %1<br/>", _grid];
                if (_tag != "") then { _details = _details + format ["<t color='#A0A0A0'>Tag:</t> %1<br/>", _tag]; };
                _details = _details + "<br/>Leads are intelligence-derived opportunities. TOC/S2 can convert them into tasks/orders.";
                _primaryLabel = "ACTION";
                _primaryEnabled = false;
            };
        };
    };
};

if (!isNull _ctrlDetails) then
{
    _ctrlDetails ctrlSetStructuredText parseText _details;

    // Auto-fit + clamp to viewport so the controls group can scroll when needed.
    [_ctrlDetails] call BIS_fnc_ctrlFitToTextHeight;
    private _grp = _display displayCtrl 78016;
    private _minH = if (!isNull _grp) then { (ctrlPosition _grp) # 3 } else { 0.74 };
    private _p = ctrlPosition _ctrlDetails;
    _p set [3, (_p # 3) max _minH];
    _ctrlDetails ctrlSetPosition _p;
    _ctrlDetails ctrlCommit 0;
};

// Button state
if (!isNull _b1) then { _b1 ctrlSetText _primaryLabel; _b1 ctrlEnable _primaryEnabled; };
if (!isNull _b2) then { _b2 ctrlSetText _secondaryLabel; _b2 ctrlEnable _secondaryEnabled; };

true

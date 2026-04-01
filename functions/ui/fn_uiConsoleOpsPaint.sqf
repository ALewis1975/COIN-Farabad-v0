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

private _rxMaxItems = missionNamespace getVariable ["ARC_consoleRxMaxItems", 80];
if (!(_rxMaxItems isEqualType 0) || { _rxMaxItems < 10 }) then { _rxMaxItems = 80; };
_rxMaxItems = (_rxMaxItems min 160) max 10;

private _rxMaxText = missionNamespace getVariable ["ARC_consoleRxMaxTextLen", 220];
if (!(_rxMaxText isEqualType 0) || { _rxMaxText < 40 }) then { _rxMaxText = 220; };
_rxMaxText = (_rxMaxText min 500) max 40;

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
    if ((count _s) > _rxMaxText) then { _s = _s select [0, _rxMaxText]; };
    if (_s isEqualTo "") then {_fallback} else {_s};
};

private _pairGet = {
    params ["_pairs", "_key", ["_def", ""]];
    if (!(_pairs isEqualType [])) exitWith {_def};
    private _idx = -1;
    { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x#0) isEqualTo _key }) exitWith { _idx = _forEachIndex; }; } forEach _pairs;
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

// ── Console VM v1 shadow-mode (Item 9: Ops tab migration) ──────────────────
// When ARC_console_ops_v2 is true, the Ops paint reads shared lists from the
// VM payload instead of raw missionNamespace. The flag is off by default; enable
// after parity validation on a dedicated server session. Tabs that use ARC_pub_*
// reads inside deeply nested conditional blocks override those reads locally.
private _opsUseVm = missionNamespace getVariable ["ARC_console_ops_v2", false];
if (!(_opsUseVm isEqualType true) && !(_opsUseVm isEqualType false)) then { _opsUseVm = false; };

// Pre-read shared VM data when flag is on (provides cached values for use
// inside the conditional blocks below without changing their structure).
private _vm_orders   = if (_opsUseVm && { !isNil "ARC_fnc_consoleVmAdapterV1" }) then { ["ops", "orders",       []] call ARC_fnc_consoleVmAdapterV1 } else { [] };
private _vm_leads    = if (_opsUseVm && { !isNil "ARC_fnc_consoleVmAdapterV1" }) then { ["ops", "lead_pool",    []] call ARC_fnc_consoleVmAdapterV1 } else { [] };
private _vm_intelLog = if (_opsUseVm && { !isNil "ARC_fnc_consoleVmAdapterV1" }) then { ["ops", "intel_log",   []] call ARC_fnc_consoleVmAdapterV1 } else { [] };
private _vm_queue    = if (_opsUseVm && { !isNil "ARC_fnc_consoleVmAdapterV1" }) then { ["ops", "queue_pending",[]] call ARC_fnc_consoleVmAdapterV1 } else { [] };
if (!(_vm_orders   isEqualType [])) then { _vm_orders   = []; };
if (!(_vm_leads    isEqualType [])) then { _vm_leads    = []; };
if (!(_vm_intelLog isEqualType [])) then { _vm_intelLog = []; };
if (!(_vm_queue    isEqualType [])) then { _vm_queue    = []; };

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
    private _orders = if (_opsUseVm && { (count _vm_orders) > 0 }) then { _vm_orders } else { missionNamespace getVariable ["ARC_pub_orders", []] };
    if (!(_orders isEqualType [])) then { _orders = []; };
    if ((count _orders) > _rxMaxItems) then { _orders = _orders select [((count _orders) - _rxMaxItems) max 0, _rxMaxItems]; };
    private _gid = groupId group player;
    // Show ALL outstanding orders (ISSUED/ACCEPTED) so TOC/S3 staff can track follow-ons
    // issued to any field unit, not just their own group.  The ACCEPT action is gated
    // separately in the details panel to only allow own-group acceptance.
    private _allOrders = _orders select { _x isEqualType [] && { (count _x) >= 5 } };

    if ((count _allOrders) isEqualTo 0) then
    {
        private _o = _cOrd lbAdd "(No outstanding orders)";
        _cOrd lbSetData [_o, "NONE"];
    }
    else
    {
        {
            private _order = _x;
            private _id = _order # 0;
            private _status = toUpper (trim (_order # 2));
            private _otype = toUpper (trim (_order # 3));
            private _tgtGrp = if ((count _order) >= 5) then { _order # 4 } else { "" };
            if (!(_tgtGrp isEqualType "")) then { _tgtGrp = ""; };
            _tgtGrp = trim _tgtGrp;
            private _pairs = if ((count _order) >= 6) then { _order # 5 } else { [] };
            private _purpose = [_pairs, "purpose", ""] call _pairGet;
            if (!(_purpose isEqualType "")) then { _purpose = ""; };
            _purpose = trim _purpose;

            private _label = format ["[%1] %2", _status, _otype];
            if (_purpose != "") then { _label = _label + format [" - %1", _purpose]; };
            // Append the target group name when it differs from the viewing player's group
            // so S3/TOC staff can see which unit the order is for.
            if (_tgtGrp != "" && { _tgtGrp != _gid }) then { _label = _label + format [" → %1", _tgtGrp]; };
            private _idx = _cOrd lbAdd _label;
            _cOrd lbSetData [_idx, format ["ORDER|%1", _id]];
        } forEach _allOrders;
    };
    [_cOrd, _selOrdData] call _restoreSel;

    // -------------------------------
    // Leads
    // -------------------------------
    lbClear _cLead;
    private _leads = if (_opsUseVm && { (count _vm_leads) > 0 }) then { _vm_leads } else { missionNamespace getVariable ["ARC_leadPoolPublic", []] };
    if (!(_leads isEqualType [])) then { _leads = []; };
    if ((count _leads) > _rxMaxItems) then { _leads = _leads select [0, _rxMaxItems]; };

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
private _gidSelf = groupId (group player);
private _statusRows = missionNamespace getVariable ["ARC_pub_unitStatuses", []];
if (!(_statusRows isEqualType [])) then { _statusRows = []; };
if ((count _statusRows) > _rxMaxItems) then { _statusRows = _statusRows select [0, _rxMaxItems]; };
private _statusIdx = -1;
{ if (_x isEqualType [] && { (count _x) >= 2 } && { (_x # 0) isEqualTo _gidSelf }) exitWith { _statusIdx = _forEachIndex; }; } forEach _statusRows;
private _unitStatus = if (_statusIdx < 0) then { "OFFLINE" } else { toUpper (trim ((_statusRows # _statusIdx) # 1)) };

private _allowDuringRtb = missionNamespace getVariable ["ARC_allowIncidentDuringAcceptedRtb", false];
private _policyText = if (_allowDuringRtb) then
{
    "Generation policy: Allowed during accepted RTB."
}
else
{
    "Generation policy: Blocked while pending acceptance or accepted RTB is active for the last tasked group."
};

private _denialText = "";
private _deny = missionNamespace getVariable ["ARC_pub_nextIncidentLastDenied", []];
if (_deny isEqualType [] && { (count _deny) >= 3 }) then
{
    _deny params ["_denyStamp", "_denyCode", "_denyDetail"];
    if (_denyStamp isEqualType 0 && { (diag_tickTime - _denyStamp) <= 120 }) then
    {
        private _code = if (_denyCode isEqualType "") then { toUpper (trim _denyCode) } else { "UNKNOWN" };
        private _detail = if (_denyDetail isEqualType "") then { trim _denyDetail } else { "" };
        _denialText = if (_detail isEqualTo "") then
        {
            format ["Latest generation denial: %1", _code]
        }
        else
        {
            format ["Latest generation denial: %1 - %2", _code, _detail]
        };
    };
};

private _genInfo = format ["<br/><br/><t size='0.9' color='#BDBDBD'>%1</t>%2",
    _policyText,
    if (_denialText isEqualTo "") then { "" } else { format ["<br/><t size='0.9' color='#FF7A7A'>%1</t>", _denialText] }
];

if (_focusData isEqualTo "") then
{
    _details = "<t align='left' size='1.1' font='PuristaMedium'>Operations</t><br/><br/>" +
               "Select an incident, an order, or a lead to view details." +
               "<br/><br/><t align='left' size='0.9' color='#BDBDBD'>Follow-on requests are captured inside the SITREP flow.</t>" + _genInfo;
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
            _sitrepDetails = [_sitrepDetails, ""] call _safeStr;

            _details = format ["<t size='1.2' font='PuristaMedium'>%1</t><br/>", _dispName];
            if ((trim _typ) != "") then { _details = _details + format ["<t color='#A0A0A0'>Type:</t> %1<br/>", toUpper (trim _typ)]; };
            _details = _details + format ["<t color='#A0A0A0'>Grid:</t> %1<br/>", _grid];
            _details = _details + format ["<t color='#A0A0A0'>Accepted:</t> %1", if (_accepted) then {"YES"} else {"NO"}];
            if (_acceptedBy != "") then { _details = _details + format [" (by %1)", _acceptedBy]; };
            _details = _details + "<br/>";
            _details = _details + format ["<t color='#A0A0A0'>Unit status (%1):</t> %2<br/>", if (_gidSelf isEqualTo "") then {"NO-CALLSIGN"} else {_gidSelf}, _unitStatus];
            _details = _details + format ["<t color='#A0A0A0'>Close-ready:</t> %1<br/>", if (_closeReady) then {"YES"} else {"NO"}];
            _details = _details + format ["<t color='#A0A0A0'>SITREP sent:</t> %1<br/><br/>", if (_sitrepSent) then {"YES"} else {"NO"}];

            if (!_accepted) then
            {
                _primaryLabel = "ACCEPT INCIDENT";
                _primaryEnabled = _isAuth && (_unitStatus isEqualTo "AVAILABLE");
                _secondaryLabel = if (_unitStatus isEqualTo "AVAILABLE") then { "SET OFFLINE" } else { "SET AVAILABLE" };
                _secondaryEnabled = _isAuth;
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
                    _details = _details + "SITREP already submitted. Await TOC follow-on order and closeout instructions.";

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
                    _primaryLabel = "SEND SITREP";
                    _primaryEnabled = _canSit;

                    // Secondary: REQUEST CAS for all accepted incidents except IED
                    // (IED overrides to EOD DISPOSITION below). CAS request requires JTAC
                    // authorization or queue-approver role and CASREQ subsystem enabled.
                    private _casreqSysEnabled = missionNamespace getVariable ["casreq_v1_enabled", true];
                    if (!(_casreqSysEnabled isEqualType true) && !(_casreqSysEnabled isEqualType false)) then { _casreqSysEnabled = true; };
                    private _canCasreq = _casreqSysEnabled && { _isAuth || { [player] call ARC_fnc_rolesCanApproveQueue } };
                    _secondaryLabel = "REQUEST CAS";
                    _secondaryEnabled = _canCasreq;

                    if (_canSit) then
                    {
                        _details = _details + "Next: submit SITREP to TOC for follow-on.";
                    }
                    else
                    {
                        _details = _details + "Next: submit SITREP (not yet available). Ensure you are within range and the incident is accepted.";
                    };

                    // Override secondary for IED incidents: EOD disposition takes priority.
                    if (_typU isEqualTo "IED") then
                    {
                        _secondaryLabel = "EOD DISPOSITION";
                        _secondaryEnabled = _isAuth;
                    };
                };

            };

            // ── Incident OPORD ─────────────────────────────────────────────
            // Abbreviated five-paragraph OPORD for quick leader reference.
            private _typU_ord = toUpper (trim _typ);
            private _missionStmt = switch (_typU_ord) do {
                case "IED":        { "Investigate and clear reported IED threat. EOD disposition required before close." };
                case "VBIED":      { "Intercept and neutralize reported VBIED before it reaches its target." };
                case "CONTACT":    { "Respond to reported enemy contact. Neutralize threat. Report KIA/WIA and equipment." };
                case "PATROL":     { "Conduct area patrol to designated grid. Report all significant activities (SALUTE format)." };
                case "DEFEND":     { "Occupy and defend designated position. Maintain security until relieved or task closed." };
                case "RAID":       { "Conduct deliberate raid on designated objective. Detain HVTs, collect evidence, and clear site." };
                case "RECON":      { "Conduct route/area reconnaissance to designated grid. Report findings via SITREP." };
                case "QRF":        { "Respond immediately to designated grid. Assess situation, support in-contact elements, and report." };
                case "CHECKPOINT": { "Establish and man vehicle checkpoint at designated position. Search personnel and vehicles IAW ROE." };
                case "ESCORT":     { "Escort designated convoy/VIP along planned route. Maintain security throughout movement." };
                case "LOGISTICS":  { "Conduct logistics task at designated grid. Coordinate resupply/delivery and report status to TOC." };
                case "CIVIL":      { "Respond to civil situation. Assess, stabilize, and report IAW COIN TTPs." };
                case "CASEVAC":    { "Respond to CASEVAC request. Extract and treat all casualties. Report status to TOC." };
                default            { format ["Execute %1 task at designated grid. Report all significant activities.", if (_typU_ord isEqualTo "") then {"ASSIGNED"} else {_typU_ord}] };
            };
            _details = _details
                + "<br/><t size='1.0' font='PuristaMedium'>INCIDENT OPORD</t><br/>"
                + "<t color='#A0A0A0'>1. SITUATION</t><br/>"
                + format ["   Type: %1 | Grid: %2<br/>", if (_typU_ord isEqualTo "") then {"UNSPECIFIED"} else {_typU_ord}, _grid]
                + "<t color='#A0A0A0'>2. MISSION</t><br/>"
                + format ["   %1<br/>", _missionStmt]
                + "<t color='#A0A0A0'>3. EXECUTION</t><br/>"
                + "   Accept incident, execute assigned task, submit SITREP to TOC upon completion.<br/>"
                + "   ROE: Card Alpha applies. Report all civilian casualties to TOC immediately.<br/>"
                + "<t color='#A0A0A0'>4. SUSTAINMENT</t><br/>"
                + "   Request CASEVAC and resupply via TOC queue as required.<br/>"
                + "<t color='#A0A0A0'>5. COMMAND AND SIGNAL</t><br/>"
                + "   Report: TOC via SITREP on task completion.";
            // ── end OPORD ───────────────────────────────────────────────────
        };

        case "ORDER":
        {
            private _orders = missionNamespace getVariable ["ARC_pub_orders", []]; if (!(_orders isEqualType [])) then { _orders = []; };
            if ((count _orders) > _rxMaxItems) then { _orders = _orders select [((count _orders) - _rxMaxItems) max 0, _rxMaxItems]; };
            private _o = -1;
            { if (_x isEqualType [] && { (count _x) >= 1 } && { (_x # 0) isEqualTo _id }) exitWith { _o = _forEachIndex; }; } forEach _orders;
            if (_o < 0) then
            {
                _details = "<t align='left' size='1.1' font='PuristaMedium'>Order</t><br/><br/>Order not found (stale UI).";
            }
            else
            {
                private _order = _orders # _o;
                private _status = toUpper (trim (_order # 2));
                private _otype = toUpper (trim (_order # 3));
                private _orderTgtGrp = if ((count _order) >= 5) then { _order # 4 } else { "" };
                if (!(_orderTgtGrp isEqualType "")) then { _orderTgtGrp = ""; };
                _orderTgtGrp = trim _orderTgtGrp;
                private _isOwnOrder = (_orderTgtGrp isEqualTo "") || { _orderTgtGrp isEqualTo _gidSelf };
                private _pairs = if ((count _order) >= 6) then { _order # 5 } else { [] };
                private _meta  = if ((count _order) >= 7) then { _order # 6 } else { [] };

                private _purpose = [_pairs, "purpose", ""] call _pairGet;
                if (!(_purpose isEqualType "")) then { _purpose = ""; };
                _purpose = trim _purpose;

                private _note = [_meta, "note", ""] call _pairGet;
                if (!(_note isEqualType "")) then { _note = ""; };
                _note = trim _note;

                _details = format ["<t size='1.2' font='PuristaMedium'>%1</t><br/>", _otype];
                _details = _details + format ["<t color='#A0A0A0'>Status:</t> %1<br/>", _status];
                if (_orderTgtGrp != "") then { _details = _details + format ["<t color='#A0A0A0'>Tasked unit:</t> %1<br/>", _orderTgtGrp]; };
                if (_purpose != "") then { _details = _details + format ["<t color='#A0A0A0'>Purpose:</t> %1<br/>", _purpose]; };
                if (_note != "") then { _details = _details + format ["<t color='#A0A0A0'>Note:</t> %1<br/>", _note]; };
                _details = _details + "<br/>";

                if (_status isEqualTo "ISSUED") then
                {
                    if (_isOwnOrder) then
                    {
                        _primaryLabel = "ACCEPT ORDER";
                        _primaryEnabled = _isAuth;
                        _details = _details + "Next: accept the order to proceed.";
                    }
                    else
                    {
                        _primaryLabel = "ACTION";
                        _primaryEnabled = false;
                        private _orderTgtLabel = if (_orderTgtGrp isEqualTo "") then {"(unknown group)"} else {_orderTgtGrp};
                        _details = _details + format ["Order issued to %1. They must accept it from their console.", _orderTgtLabel];
                    };
                }
                else
                {
                    _primaryLabel = "ACTION";
                    _primaryEnabled = false;
                    _details = _details + "No action available for this order (view only).";
                };
            };

            _details = _details + _genInfo;
        };

        case "LEAD":
        {
            private _leads = missionNamespace getVariable ["ARC_leadPoolPublic", []]; if (!(_leads isEqualType [])) then { _leads = []; };
            if ((count _leads) > _rxMaxItems) then { _leads = _leads select [0, _rxMaxItems]; };
            private _idx = -1;
            { if (_x isEqualType [] && { (count _x) >= 1 } && { (_x # 0) isEqualTo _id }) exitWith { _idx = _forEachIndex; }; } forEach _leads;
            if (_idx < 0) then
            {
                _details = "<t align='left' size='1.1' font='PuristaMedium'>Lead</t><br/><br/>Lead not found (stale UI).";
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
                _details = _details + "<br/>Leads are intelligence-derived opportunities.<br/>";
                if (_isAuth) then
                {
                    _primaryLabel = "SUBMIT TO TOC QUEUE";
                    _primaryEnabled = true;
                    _details = _details + "SUBMIT TO TOC QUEUE: send this lead to the TOC for review and approval before a PROCEED order is issued.";
                }
                else
                {
                    _primaryLabel = "ACTION";
                    _primaryEnabled = false;
                    _details = _details + "Authorized S3/TOC staff can submit this lead to the TOC queue for review.";
                };
            };
        };
    };
};

if (!isNull _ctrlDetails) then
{
    _ctrlDetails ctrlSetStructuredText parseText _details;

    // Auto-fit + clamp to viewport so the controls group can scroll when needed.
    // Keep x/y/w pinned to the designed inset; BIS_fnc_ctrlFitToTextHeight can
    // inherit stretched width from prior states, which causes horizontal overflow
    // and makes S3 right-panel text render off-screen.
    private _defaultPos = uiNamespace getVariable ["ARC_console_opsDetailsDefaultPos", []];
    if (!(_defaultPos isEqualType []) || { (count _defaultPos) < 4 }) then
    {
        _defaultPos = ctrlPosition _ctrlDetails;
        uiNamespace setVariable ["ARC_console_opsDetailsDefaultPos", +_defaultPos];
    };

    [_ctrlDetails] call BIS_fnc_ctrlFitToTextHeight;
    private _grp = _display displayCtrl 78016;
    private _minH = if (!isNull _grp) then { (ctrlPosition _grp) # 3 } else { 0.74 };
    private _p = ctrlPosition _ctrlDetails;
    _p set [0, _defaultPos # 0];
    _p set [1, _defaultPos # 1];
    _p set [2, _defaultPos # 2];
    _p set [3, (_p # 3) max _minH];
    _ctrlDetails ctrlSetPosition _p;
    _ctrlDetails ctrlCommit 0;
};

// Button state
if (!isNull _b1) then { _b1 ctrlSetText _primaryLabel; _b1 ctrlEnable _primaryEnabled; };
if (!isNull _b2) then { _b2 ctrlSetText _secondaryLabel; _b2 ctrlEnable _secondaryEnabled; };

true

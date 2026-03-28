/*
    ARC_fnc_intelUiQueueManagerUpdateDetails

    Client UI: update the right-hand details pane based on the selected queue item.
*/

params [ ["_lb", controlNull, [controlNull]], ["_idx", -1, [0]] ];
if (isNull _lb || { _idx < 0 }) exitWith {false};

private _disp = ctrlParent _lb;
if (isNull _disp) exitWith {false};

private _detailsCtrl = _disp displayCtrl 61002;
private _btnApprove = _disp displayCtrl 61011;
private _btnReject  = _disp displayCtrl 61012;

private _qid = _lb lbData _idx;
if (_qid isEqualTo "") exitWith {false};

private _getPair = {
    private _pairs = _this param [0, [], [[]]];
private _trimFn = compile "params ['_s']; trim _s";

    private _k = _this param [1, "", [""]];
    private _d = _this param [2, nil];

    if (!(_pairs isEqualType [])) exitWith { _d };
    if (_k isEqualTo "") exitWith { _d };

    private _j = -1;
    { if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo _k }) exitWith { _j = _forEachIndex; }; } forEach _pairs;
    if (_j < 0) exitWith { _d };
    (_pairs select _j) select 1
};

// Prefer queue tail so decided items can still be viewed.
private _q = missionNamespace getVariable ["ARC_pub_queueTail", []];
if (!(_q isEqualType [])) then { _q = []; };
if (_q isEqualTo []) then
{
    _q = missionNamespace getVariable ["ARC_pub_queue", []];
    if (!(_q isEqualType [])) then { _q = []; };
};

private _it = [];
{
    if (_x isEqualType [] && { (count _x) >= 12 } && { (_x param [0, "", [""]]) isEqualTo _qid }) exitWith { _it = _x; };
} forEach _q;

if (_it isEqualTo []) exitWith
{
    _detailsCtrl ctrlSetStructuredText parseText format ["<t size='1.1'>%1</t><br/><t size='0.9'>Queue item not found in client snapshot (out of range / old).</t>", _qid];
    _btnApprove ctrlEnable false;
    _btnReject ctrlEnable false;
    false
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

private _zone = [_meta, "zone", "Unzoned"] call _getPair;
if (!(_zone isEqualType "")) then { _zone = "Unzoned"; };

private _grid = [_meta, "grid", ""] call _getPair;
if (!(_grid isEqualType "")) then { _grid = ""; };
if (_grid isEqualTo "") then
{
    if (_posATL isEqualType [] && { (count _posATL) >= 2 } && { (_posATL select 0) isEqualType 0 } && { (_posATL select 1) isEqualType 0 }) then
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

// Enable approve/reject only for authorized users AND pending items.
private _canDecide = [player] call ARC_fnc_rolesCanApproveQueue;
private _isPending = (_stU isEqualTo "PENDING");
_btnApprove ctrlEnable (_canDecide && _isPending);
_btnReject ctrlEnable (_canDecide && _isPending);

// Parse payload into a compact, human-readable block.
private _payloadTxt = "";
private _statusTxt = "";

private _kindU = toUpper _kind;
switch (_kindU) do
{
    case "LEAD_REQUEST":
    {
        private _leadType = [_payload, "leadType", "RECON"] call _getPair;
        private _dispName = [_payload, "displayName", _sum] call _getPair;
        private _lp       = [_payload, "pos", []] call _getPair;
        private _pri      = [_payload, "priority", 3] call _getPair;
        private _tag      = [_payload, "tag", "S2_REQUEST"] call _getPair;

        if (!(_leadType isEqualType "")) then { _leadType = "RECON"; };
        _leadType = toUpper ([_leadType] call _trimFn);

        if (!(_dispName isEqualType "")) then { _dispName = _sum; };
        _dispName = [_dispName] call _trimFn;

        private _pGrid = _grid;
        if (_lp isEqualType [] && { (count _lp) >= 2 } && { (_lp select 0) isEqualType 0 } && { (_lp select 1) isEqualType 0 }) then
        {
            _pGrid = mapGridPosition _lp;
        };

        if (!(_pri isEqualType 0)) then { _pri = 3; };
        _pri = (_pri max 1) min 5;

        if (!(_tag isEqualType "")) then { _tag = "S2_REQUEST"; };
        _tag = [_tag] call _trimFn;

        _payloadTxt = format ["Lead Request: <t color='#FFD700'>%1</t> (P%2)<br/>Grid: %3 | Zone: %4<br/>Tag: %5<br/>Title: %6", _leadType, _pri, _pGrid, _zone, _tag, _dispName];

        // If approved, try to resolve the downstream lead status.
        if (_stU isEqualTo "APPROVED") then
        {
            private _leadId = [_meta, "leadId", ""] call _getPair;
            if (!(_leadId isEqualType "")) then { _leadId = ""; };

            private _pool = missionNamespace getVariable ["ARC_leadPoolPublic", []];
            if (!(_pool isEqualType [])) then { _pool = []; };

            private _lead = [];
            {
                if (_x isEqualType [] && { (count _x) >= 10 }) then
                {
                    private _lid = _x select 0;
                    private _srcTask = _x select 7;
                    private _srcInc  = _x select 8;

                    if (_leadId != "" && { _lid isEqualTo _leadId }) exitWith { _lead = _x; };
                    if (_leadId isEqualTo "" && { _srcTask isEqualTo _qid } && { toUpper _srcInc isEqualTo "QUEUE" }) exitWith { _lead = _x; };
                };
            } forEach _pool;

            private _activeLeadId = missionNamespace getVariable ["ARC_activeLeadId", ""];
            if (!(_activeLeadId isEqualType "")) then { _activeLeadId = ""; };

            private _lastConsumed = missionNamespace getVariable ["ARC_lastLeadConsumedPublic", []];
            if (!(_lastConsumed isEqualType [])) then { _lastConsumed = []; };

            // Check for an outstanding LEAD order for this queue item.
            private _orders = missionNamespace getVariable ["ARC_pub_orders", []];
            if (!(_orders isEqualType [])) then { _orders = []; };

            private _leadOrder = [];
            {
                if (_x isEqualType [] && { (count _x) >= 7 }) then
                {
                    private _otype = _x param [3, "", [""]];
                    if ((toUpper _otype) isEqualTo "LEAD") then
                    {
                        private _data = _x param [5, [], [[]]];
                        private _meta2 = _x param [6, [], [[]]];

                        private _ol = [_data, "leadId", ""] call _getPair;
                        if (!(_ol isEqualType "")) then { _ol = ""; };

                        private _src = [_meta2, "sourceQid", ""] call _getPair;
                        if (!(_src isEqualType "")) then { _src = ""; };

                        if ((_leadId != "" && { _ol isEqualTo _leadId }) || (_leadId isEqualTo "" && { _src isEqualTo _qid })) exitWith
                        {
                            _leadOrder = _x;
                        };
                    };
                };
            } forEach _orders;

            // Status priority: AVAILABLE -> ORDER ISSUED/ACCEPTED -> ACTIVE -> CONSUMED -> UNKNOWN
            if (!(_lead isEqualTo [])) then
            {
                private _expiresAt = _lead param [6, -1, [0]];
                private _minsLeft = 0;
                if (_expiresAt isEqualType 0) then
                {
                    _minsLeft = floor ((_expiresAt - serverTime) / 60);
                    if (_minsLeft < 0) then { _minsLeft = 0; };
                };

                private _lid2 = _lead param [0, "", [""]];
                if (_leadId isEqualTo "" && { _lid2 != "" }) then { _leadId = _lid2; };

                _statusTxt = format ["Lead Status: <t color='#55FF55'>AVAILABLE</t> (Lead Pool)<br/>LeadId: %1 | TTL: %2m", _leadId, _minsLeft];
            }
            else
            {
                if (!(_leadOrder isEqualTo [])) then
                {
                    private _oid = _leadOrder param [0, "", [""]];
                    private _ost = toUpper (_leadOrder param [2, "", [""]]);
                    private _tgt = _leadOrder param [4, "", [""]];

                    // Try to recover leadId from the order if we don't have it.
                    private _odata = _leadOrder param [5, [], [[]]];
                    private _oidLead = [_odata, "leadId", ""] call _getPair;
                    if (_leadId isEqualTo "" && { _oidLead isEqualType "" && { _oidLead != "" } }) then { _leadId = _oidLead; };

                    _statusTxt = format ["Lead Status: <t color='#FFD700'>ORDER %1</t><br/>%2 to %3<br/>LeadId: %4", _ost, _oid, _tgt, _leadId];
                }
                else
                {
                    if (_leadId != "" && { _activeLeadId isEqualTo _leadId }) then
                    {
                        _statusTxt = format ["Lead Status: <t color='#FFD700'>ACTIVE</t> (Current Incident)<br/>LeadId: %1", _leadId];
                    }
                    else
                    {
                        // If we don't have leadId, try to match last-consumed by sourceTaskId.
                        private _lcMatch = false;
                        if (_leadId != "" && { _lastConsumed isEqualType [] } && { (count _lastConsumed) >= 10 } && { (_lastConsumed select 0) isEqualTo _leadId }) then { _lcMatch = true; };
                        if (_leadId isEqualTo "" && { _lastConsumed isEqualType [] } && { (count _lastConsumed) >= 10 } && { (_lastConsumed select 7) isEqualTo _qid } && { toUpper (_lastConsumed select 8) isEqualTo "QUEUE" }) then { _lcMatch = true; };

                        if (_lcMatch) then
                        {
                            private _lcId = _lastConsumed select 0;
                            _statusTxt = format ["Lead Status: <t color='#FFD700'>CONSUMED</t><br/>LeadId: %1", _lcId];
                        }
                        else
                        {
                            _statusTxt = "Lead Status: <t color='#FFAAAA'>UNKNOWN</t> (not in lead pool / no active order)";
                        };
                    };
                };
            };
        };
    };

    
case "FOLLOWON_PACKAGE":
{
    private _srcTask = [_payload, "sourceTaskId", ""] call _getPair;
    private _incType = [_payload, "sourceIncidentType", ""] call _getPair;
    private _res     = [_payload, "result", ""] call _getPair;
    private _rec     = [_payload, "recommendation", ""] call _getPair;
    private _purpose = [_payload, "purpose", ""] call _getPair;
    private _leadIds = [_payload, "leadIds", []] call _getPair;
    private _sitSum  = [_payload, "sitrepSummary", ""] call _getPair;

    if (!(_srcTask isEqualType "")) then { _srcTask = ""; };
    if (!(_incType isEqualType "")) then { _incType = ""; };
    if (!(_res isEqualType "")) then { _res = ""; };
    if (!(_rec isEqualType "")) then { _rec = ""; };
    if (!(_purpose isEqualType "")) then { _purpose = ""; };
    if (!(_sitSum isEqualType "")) then { _sitSum = ""; };
    if (!(_leadIds isEqualType [])) then { _leadIds = []; };

    _incType = toUpper ([_incType] call _trimFn);
    _res = toUpper ([_res] call _trimFn);
    _rec = toUpper ([_rec] call _trimFn);
    _purpose = toUpper ([_purpose] call _trimFn);

    private _n = count _leadIds;
    private _leadTxt = if (_n > 0) then { _leadIds joinString ", " } else { "None" };

    _payloadTxt = format [
        "Follow-on Package (post-closeout)<br/>TaskId: %1 | Type: %2 | Result: <t color='#FFD700'>%3</t><br/>Recommendation: %4 %5<br/>Leads (%6): %7<br/><br/>SITREP Summary:<br/>%8",
        _srcTask, _incType, _res, _rec, _purpose, _n, _leadTxt, _sitSum
    ];

    // Status text + actions depend on whether the item is still pending.
    if (_isPending) then
    {
        _statusTxt = "Approve will triage these lead(s) for TOC follow-on (no orders are issued).";
    }
    else
    {
        switch (_stU) do
        {
            case "APPROVED": { _statusTxt = "This follow-on package is already APPROVED. (Nothing to do here.)"; };
            case "REJECTED": { _statusTxt = "This follow-on package is REJECTED."; };
            default { _statusTxt = format ["This follow-on package is %1 (not pending).", _stU]; };
        };
    };

    // Allow approve/reject only while pending; avoid misleading enabled buttons on decided items.
    _btnApprove ctrlEnable (_canDecide && _isPending && (_n > 0));
    _btnReject  ctrlEnable (_canDecide && _isPending);
};

case "FOLLOWON_REQUEST":
    {
        private _req = [_payload, "request", "RTB"] call _getPair;
        private _purpose = [_payload, "purpose", "REFIT"] call _getPair;
        private _reqGroup = [_payload, "requestorGroup", _fromGroup] call _getPair;
        private _reqRole  = [_payload, "requestorRole", ""] call _getPair;

        if (!(_req isEqualType "")) then { _req = "RTB"; };
        _req = toUpper ([_req] call _trimFn);

        if (!(_purpose isEqualType "")) then { _purpose = "REFIT"; };
        _purpose = toUpper ([_purpose] call _trimFn);

        if (!(_reqGroup isEqualType "")) then { _reqGroup = _fromGroup; };

        _payloadTxt = format ["Follow-on Request: <t color='#FFD700'>%1</t><br/>Purpose: %2<br/>Requestor: %3 %4", _req, _purpose, _reqGroup, _reqRole];

        private _rat = [_payload, "rationale", ""] call _getPair;
        private _con = [_payload, "constraints", ""] call _getPair;
        private _sup = [_payload, "support", ""] call _getPair;
        private _holdIntent = [_payload, "holdIntent", ""] call _getPair;
        private _holdMin = [_payload, "holdMinutes", 0] call _getPair;
        private _proceedIntent = [_payload, "proceedIntent", ""] call _getPair;

        if (!(_rat isEqualType "")) then { _rat = ""; };
        if (!(_con isEqualType "")) then { _con = ""; };
        if (!(_sup isEqualType "")) then { _sup = ""; };
        if (!(_holdIntent isEqualType "")) then { _holdIntent = ""; };
        if (!(_proceedIntent isEqualType "")) then { _proceedIntent = ""; };
        if (!(_holdMin isEqualType 0)) then { _holdMin = 0; };

        private _extra = [];

        if (_req isEqualTo "HOLD") then
        {
            if (trim !(_holdIntent isEqualTo "")) then { _extra pushBack format ["Hold intent: %1", [_holdIntent] call _trimFn]; };
            if (_holdMin > 0) then { _extra pushBack format ["Hold duration: %1 min", _holdMin]; };
        };

        if (_req isEqualTo "PROCEED") then
        {
            if (trim !(_proceedIntent isEqualTo "")) then { _extra pushBack format ["Proceed intent: %1", [_proceedIntent] call _trimFn]; };
        };

        if (trim !(_rat isEqualTo "")) then { _extra pushBack format ["Rationale: %1", [_rat] call _trimFn]; };
        if (trim !(_con isEqualTo "")) then { _extra pushBack format ["Constraints: %1", [_con] call _trimFn]; };
        if (trim !(_sup isEqualTo "")) then { _extra pushBack format ["Support: %1", [_sup] call _trimFn]; };

        if ((count _extra) > 0) then
        {
            _payloadTxt = _payloadTxt + "<br/>" + (_extra joinString "<br/>");
        };

        if (_stU isEqualTo "APPROVED") then
        {
            private _orders = missionNamespace getVariable ["ARC_pub_orders", []];
            if (!(_orders isEqualType [])) then { _orders = []; };

            private _ordTxt = "Order: (not yet visible / already completed)";
            {
                if (_x isEqualType [] && { (count _x) >= 7 }) then
                {
                    private _oid = _x select 0;
                    private _ost = _x select 2;
                    private _otype = _x select 3;
                    private _tgt = _x select 4;
                    private _meta2 = _x select 6;

                    private _src = [_meta2, "sourceQid", ""] call _getPair;
                    if (_src isEqualType "" && { _src isEqualTo _qid }) exitWith
                    {
                        _ordTxt = format ["Order: %1 (%2) Type: %3 Target: %4", _oid, toUpper _ost, toUpper _otype, _tgt];
                    };
                };
            } forEach _orders;

            _statusTxt = _ordTxt;
        };
    };

    default
    {
        _payloadTxt = "";
    };
};

// Decision text (if any).
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
    _decNote = [_decNote] call _trimFn;
    if (_decNote isEqualTo "") then { _decNote = "(no note)"; };

    _decTxt = format ["Decision: <t color='#FFD700'>%1</t> by %2 (%3m ago)<br/>Note: %4", _d, _decBy, _decAge, _decNote];
};

if (_payloadTxt isEqualTo "") then
{
    _payloadTxt = "(No payload details)";
};

private _who = if (_fromGroup isEqualType "" && { _fromGroup != "" }) then { _fromGroup } else { _from };
if (!(_who isEqualType "")) then { _who = ""; };

private _hdr = format ["<t size='1.15'>%1</t><br/><t size='0.95'>Status: %2 | Kind: %3 | Age: %4m</t><br/><t size='0.9'>From: %5</t><br/><t size='0.9'>Grid: %6 | Zone: %7</t>", _qid, _stU, toUpper _kind, _ageMin, _who, _grid, _zone];

private _body = format ["<br/><t size='1.0'>%1</t><br/><t size='0.9'>%2</t>", _sum, _det];

private _extra = "";
if (_decTxt != "") then { _extra = format ["<br/><t size='0.95'>%1</t>", _decTxt]; };
if (_statusTxt != "") then { _extra = format ["%1<br/><t size='0.95'>%2</t>", _extra, _statusTxt]; };

_detailsCtrl ctrlSetStructuredText parseText (_hdr + _body + "<br/><t size='0.95'>" + _payloadTxt + "</t>" + _extra);

true

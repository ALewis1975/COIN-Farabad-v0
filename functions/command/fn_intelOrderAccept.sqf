/*
    ARC_fnc_intelOrderAccept

    Server: accept an ISSUED TOC order (player acknowledgement).

    Params:
      0: OBJECT acceptor
      1: STRING orderId

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\\core\\fn_rpcValidateSender.sqf"; };

params [
    ["_acceptor", objNull],
    ["_orderId", ""]
];

if (!([_acceptor, "ARC_fnc_intelOrderAccept", "Order acceptance rejected: sender verification failed.", "TOC_ORDER_ACCEPT_REJECTED"] call ARC_fnc_rpcValidateSender)) exitWith {false};

if (isNull _acceptor) exitWith {false};
_orderId = trim _orderId;
if (_orderId isEqualTo "") exitWith {false};

private _gid = groupId (group _acceptor);
if (!(_gid isEqualType "") || { _gid isEqualTo "" }) exitWith {false};

// Helpers
private _getPair = {
    params ["_pairs", "_k", "_d"];
    if (!(_pairs isEqualType [])) exitWith { _d };
    private _idx = _pairs findIf { (_x isEqualType []) && { (count _x) >= 2 } && { (_x # 0) isEqualTo _k } };
    if (_idx < 0) exitWith { _d };
    (_pairs # _idx) # 1
};

private _setPair = {
    params ["_pairs", "_k", "_v"];
    if (!(_pairs isEqualType [])) then { _pairs = []; };
    private _idx = _pairs findIf { (_x isEqualType []) && { (count _x) >= 2 } && { (_x # 0) isEqualTo _k } };
    if (_idx < 0) then {
        _pairs pushBack [_k, _v];
    } else {
        _pairs set [_idx, [_k, _v]];
    };
    _pairs
};

private _orders = ["tocOrders", []] call ARC_fnc_stateGet;
if (!(_orders isEqualType [])) then { _orders = []; };

private _idx = _orders findIf { (_x isEqualType []) && { (count _x) >= 7 } && { (_x # 0) isEqualTo _orderId } };
if (_idx < 0) exitWith {false};

private _ord = _orders # _idx;
private _status = toUpper (_ord # 2);
private _type   = toUpper (_ord # 3);
private _target = _ord # 4;
private _data   = _ord # 5;
private _meta   = _ord # 6;

if (!(_target isEqualTo _gid)) exitWith
{
    ["OPS", format ["ORDER: %1 attempted to accept %2, but target group is %3.", [_acceptor] call ARC_fnc_rolesFormatUnit, _orderId, _target], [0,0,0],
        [
            ["event", "TOC_ORDER_ACCEPT_DENIED"],
            ["orderId", _orderId],
            ["targetGroup", _target],
            ["attemptGroup", _gid]
        ]
    ] call ARC_fnc_intelLog;
    false
};

if (!(_status isEqualTo "ISSUED")) exitWith {false};

// Mark accepted
_meta = [_meta, "acceptedAt", serverTime] call _setPair;
_meta = [_meta, "acceptedBy", [_acceptor] call ARC_fnc_rolesFormatUnit] call _setPair;
_meta = [_meta, "acceptedByUID", getPlayerUID _acceptor] call _setPair;

_ord set [2, "ACCEPTED"];
_ord set [6, _meta];

// Side effects by order type
switch (_type) do
{
    case "RTB":
    {
        // If the unit already accepted a LEAD order, RTB acceptance fails that lead.
        // If the lead was only issued (not accepted), cancel it and return the lead to the pool.
        private _leadPool = ["leadPool", []] call ARC_fnc_stateGet;
        if (!(_leadPool isEqualType [])) then { _leadPool = []; };

        {
            if (!(_x isEqualType []) || { (count _x) < 7 }) then { continue; };

            private _oId = _x # 0;
            private _oSt = toUpper (_x # 2);
            private _oTy = toUpper (_x # 3);
            private _oTg = _x # 4;
            private _oDa = _x # 5;
            private _oMe = _x # 6;

            if (!(_oTy isEqualTo "LEAD") || { !(_oTg isEqualTo _gid) }) then { continue; };

            // NOTE: LEAD orders store the full lead entry under key "lead".
            private _leadRec = [_oDa, "lead", []] call _getPair;

            private _leadId = "";
            if (_leadRec isEqualType [] && { (count _leadRec) > 0 }) then
            {
                private _tmp = _leadRec # 0;
                if (_tmp isEqualType "" && { _tmp isNotEqualTo "" }) then { _leadId = _tmp; };
            };

            if (_oSt isEqualTo "ACCEPTED") then
            {
                // Fail the lead (unit had accepted it)
                if (_leadId isEqualType "" && { _leadId != "" }) then
                {
                    private _lz = "";
                    private _pos = _leadRec # 3;
                    if (_pos isEqualType [] && { (count _pos) >= 2 }) then
                    {
                        _lz = [_pos] call ARC_fnc_worldGetZoneForPos;
                    };

                    private _lt = _leadRec # 1;
                    private _th = _leadRec # 9;

                    private _leadHist = ["leadHistory", []] call ARC_fnc_stateGet;
                    if (!(_leadHist isEqualType [])) then { _leadHist = []; };
                    _leadHist pushBack [_leadId, "FAILED", serverTime, "", _lt, _lz, _th];
                    ["leadHistory", _leadHist] call ARC_fnc_stateSet;

                    ["OPS", format ["LEAD FAILED: %1 abandoned accepted lead %2 due to RTB.", _gid, _leadId], [0,0,0],
                        [
                            ["event", "LEAD_FAILED_RTB"],
                            ["leadId", _leadId],
                            ["group", _gid]
                        ]
                    ] call ARC_fnc_intelLog;
                };

                _oMe = [_oMe, "failedAt", serverTime] call _setPair;
                _oMe = [_oMe, "failedReason", "RTB_ACCEPTED"] call _setPair;

                _x set [2, "FAILED"];
                _x set [6, _oMe];
            }
            else
            {
                if (_oSt isEqualTo "ISSUED") then
                {
                    // Return the lead to the pool
                    if ((_leadRec isEqualType []) && { (count _leadRec) > 0 }) then
                    {
                        private _existing = _leadPool findIf { (_x isEqualType []) && { (count _x) > 0 } && { (_x # 0) isEqualTo (_leadRec # 0) } };
                        if (_existing < 0) then { _leadPool pushBack _leadRec; };
                    };

                    _oMe = [_oMe, "canceledAt", serverTime] call _setPair;
                    _oMe = [_oMe, "canceledReason", "RTB_ACCEPTED"] call _setPair;

                    _x set [2, "CANCELED"];
                    _x set [6, _oMe];
                };
            };
        } forEach _orders;

        ["leadPool", _leadPool] call ARC_fnc_stateSet;
        [] call ARC_fnc_leadBroadcast;

        // Task creation
        private _purpose = [_data, "purpose", "REFIT"] call _getPair;
        private _destPos = [_data, "destPos", []] call _getPair;
        private _destLbl = [_data, "destLabel", "Base"] call _getPair;
        private _destRad = [_data, "destRadius", 30] call _getPair;

        if (!(_destPos isEqualType []) || { (count _destPos) < 2 }) then
        {
            private _res = [_purpose] call ARC_fnc_intelResolveRtbDestination;
            _destPos = _res # 0;
            _destLbl = _res # 1;
            _destRad = _res # 2;
        };

        _destPos resize 3;
        if (!(_destRad isEqualType 0)) then { _destRad = 30; };

        private _taskId = format ["%1_task", _orderId];

        private _issuer = [_meta, "issuedBy", "TOC"] call _getPair;
        private _note   = [_meta, "note", ""] call _getPair;

        private _title = format ["RTB: %1 (%2)", _destLbl, _purpose];

        private _extra = if (toUpper _purpose isEqualTo "INTEL") then
        {
            "\n\nOn arrival, use the Intel Debrief station to submit your debrief and complete the order."
        }
        else
        {
            ""
        };

        private _desc = format [
            "Return to %1 to %2.%3%4%5", 
            _destLbl,
            _purpose,
            if (_note isEqualTo "") then { "" } else { format ["\n\nTOC Note: %1", _note] },
            "\n\nTip: If you only need ammo/fuel/medical, consider requesting resupply in-place via support modules/vehicles instead of RTB.",
            _extra
        ];

        [group _acceptor, _taskId, [[_desc], _title, ""], _destPos, "ASSIGNED", 1, true, "MOVE", false] call BIS_fnc_taskCreate;

        // Ensure the group UI focuses the newly assigned RTB task (Assigned Task helper).
        {
            if (isPlayer _x) then
            {
                [_taskId, [["kind","ORDER"],["title",_title],["pos",_destPos]]] remoteExec ["ARC_fnc_clientSetCurrentTask", _x];
            };
        } forEach (units (group _acceptor));


        _data = [_data, "taskId", _taskId] call _setPair;
        _data = [_data, "destPos", _destPos] call _setPair;
        _data = [_data, "destLabel", _destLbl] call _setPair;
        _data = [_data, "destRadius", _destRad] call _setPair;

        _ord set [5, _data];

        // Notify target group
        {
            if (isPlayer _x) then
            {
                private _m = format ["ORDER ACCEPTED: %1. Move to %2.", _title, _destLbl];
                [_m] remoteExec ["ARC_fnc_intelClientNotify", _x];
                ["Order Accepted", _m, 6] remoteExec ["ARC_fnc_clientToast", _x];
            };
        } forEach (units (group _acceptor));
    };

    case "HOLD":
    {
        private _issuer = [_meta, "issuedBy", "TOC"] call _getPair;
        private _note   = [_meta, "note", ""] call _getPair;

        private _holdPos = getPosATL _acceptor;
        private _holdRad = 40;
        private _taskId = format ["%1_task", _orderId];

        private _title = "HOLD: Maintain Position";
        private _desc = format [
            "Hold at current position until further notice.%1",
            if (_note isEqualTo "") then { "" } else { format ["\n\nTOC Note: %1", _note] }
        ];

        [group _acceptor, _taskId, [[_desc], _title, ""], _holdPos, "ASSIGNED", 1, true, "HOLD", false] call BIS_fnc_taskCreate;

        // Ensure the group UI focuses the newly assigned HOLD task (Assigned Task helper).
        {
            if (isPlayer _x) then
            {
                [_taskId, [["kind","ORDER"],["title",_title],["pos",_holdPos]]] remoteExec ["ARC_fnc_clientSetCurrentTask", _x];
            };
        } forEach (units (group _acceptor));


        _data = [_data, "taskId", _taskId] call _setPair;
        _data = [_data, "holdPos", _holdPos] call _setPair;
        _data = [_data, "holdRadius", _holdRad] call _setPair;

        _ord set [5, _data];

        {
            if (isPlayer _x) then
            {
                private _m = "ORDER ACCEPTED: HOLD.";
                [_m] remoteExec ["ARC_fnc_intelClientNotify", _x];
                ["Order Accepted", _m, 6] remoteExec ["ARC_fnc_clientToast", _x];
            };
        } forEach (units (group _acceptor));
    };

    case "LEAD":
    {
        // LEAD: create a focused task at the lead position so the ATH/HUD can display it.
        private _leadRec = [_data, "lead", []] call _getPair;

        private _leadPos = [];
        private _leadName = "Investigate Lead";
        if (_leadRec isEqualType [] && { (count _leadRec) >= 4 }) then
        {
            private _dn = _leadRec # 2;
            if (_dn isEqualType "" && { _dn isNotEqualTo "" }) then { _leadName = _dn; };

            private _p = _leadRec # 3;
            if (_p isEqualType [] && { (count _p) >= 2 }) then { _leadPos = _p; };
        };

        if !(_leadPos isEqualType [] && { (count _leadPos) >= 2 }) then
        {
            _leadPos = getPosATL _acceptor;
        };
        _leadPos = +_leadPos; _leadPos resize 3;

        private _taskId = format ["%1_task", _orderId];
        private _note = [_meta, "note", ""] call _getPair;

        private _title = format ["LEAD: %1", _leadName];
        private _desc = format [
            "Investigate the lead location and report findings.%1",
            if (_note isEqualTo "") then { "" } else { format ["\n\nTOC Note: %1", _note] }
        ];

        [group _acceptor, _taskId, [[_desc], _title, ""], _leadPos, "ASSIGNED", 1, true, "MOVE", false] call BIS_fnc_taskCreate;

        {
            if (isPlayer _x) then
            {
                [_taskId, [["kind","LEAD"],["title",_title],["pos",_leadPos]]] remoteExec ["ARC_fnc_clientSetCurrentTask", _x];

                private _m = format ["ORDER ACCEPTED: %1.", _title];
                [_m] remoteExec ["ARC_fnc_intelClientNotify", _x];
                ["Order Accepted", _m, 6] remoteExec ["ARC_fnc_clientToast", _x];
            };
        } forEach (units (group _acceptor));

        _data = [_data, "taskId", _taskId] call _setPair;
        _ord set [5, _data];
    };

    default
    {
        // STANDBY / other: acceptance is acknowledgement only
        {
            if (isPlayer _x) then
            {
                private _m = format ["ORDER ACCEPTED: %1.", _type];
                [_m] remoteExec ["ARC_fnc_intelClientNotify", _x];
                ["Order Accepted", _m, 6] remoteExec ["ARC_fnc_clientToast", _x];
            };
        } forEach (units (group _acceptor));
    };
};

// Save back
_orders set [_idx, _ord];
["tocOrders", _orders] call ARC_fnc_stateSet;

[] call ARC_fnc_intelOrderBroadcast;
[] call ARC_fnc_publicBroadcastState;

["OPS", format ["ORDER ACCEPTED: %1 accepted %2 (%3)", [_acceptor] call ARC_fnc_rolesFormatUnit, _orderId, _type], [0,0,0],
    [
        ["event", "TOC_ORDER_ACCEPTED"],
        ["orderId", _orderId],
        ["orderType", _type],
        ["targetGroup", _gid]
    ]
] call ARC_fnc_intelLog;

// -------------------------------------------------------------------------
// Closeout pending hook:
// If TOC staged a closeout that is awaiting unit acceptance, and this
// acceptance matches the staged follow-on order, close the incident now.
// -------------------------------------------------------------------------
private _pend = ["activeIncidentClosePending", false] call ARC_fnc_stateGet;
if (!(_pend isEqualType true)) then { _pend = false; };

if (_pend) then
{
    private _pendOrderId = ["activeIncidentClosePendingOrderId", ""] call ARC_fnc_stateGet;
    if (!(_pendOrderId isEqualType "")) then { _pendOrderId = ""; };
    _pendOrderId = trim _pendOrderId;

    private _pendGroup = ["activeIncidentClosePendingGroup", ""] call ARC_fnc_stateGet;
    if (!(_pendGroup isEqualType "")) then { _pendGroup = ""; };
    _pendGroup = trim _pendGroup;

    private _matchGroup = (_pendGroup isEqualTo "") || { _pendGroup isEqualTo _gid };
    private _matchOrder = (_pendOrderId isEqualTo "") || { _pendOrderId isEqualTo _orderId };

    if (_matchGroup && _matchOrder) then
    {
        private _res = ["activeIncidentClosePendingResult", "SUCCEEDED"] call ARC_fnc_stateGet;
        if (!(_res isEqualType "")) then { _res = "SUCCEEDED"; };
        _res = toUpper (trim _res);
        if !(_res in ["SUCCEEDED", "FAILED", "CANCELED"]) then { _res = "SUCCEEDED"; };

        // Defensive: enforce forced-fail for IED CIV KIA at close time.
        private _itype = ["activeIncidentType", ""] call ARC_fnc_stateGet;
        if (!(_itype isEqualType "")) then { _itype = ""; };
        _itype = toUpper (trim _itype);

        if (_res isEqualTo "SUCCEEDED" && { _itype isEqualTo "IED" }) then
        {
            private _civKia = ["activeIedCivKia", 0] call ARC_fnc_stateGet;
            if (!(_civKia isEqualType 0)) then { _civKia = 0; };
            if (_civKia > 0) then { _res = "FAILED"; };
        };

        diag_log format ["[ARC][TOC] Closeout acceptance trigger: group=%1 order=%2 result=%3", _gid, _orderId, _res];
        [_res] call ARC_fnc_incidentClose;
    };
};

true

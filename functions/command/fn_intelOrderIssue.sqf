/*
    ARC_fnc_intelOrderIssue

    Server: issue a TOC order to a target group.

    Order format stored in ARC_state (tocOrders):
      [
        0: STRING orderId (ARC_ord_#)
        1: NUMBER issuedAt (serverTime)
        2: STRING status (ISSUED|ACCEPTED|COMPLETED|CANCELED|FAILED)
        3: STRING orderType (RTB|HOLD|LEAD|STANDBY)
        4: STRING targetGroup (groupId)
        5: ARRAY  dataPairs [[k,v],...]
        6: ARRAY  metaPairs [[k,v],...]
      ]

    Params:
      0: STRING orderType (RTB|HOLD|LEAD|STANDBY)
      1: STRING targetGroupId
      2: ARRAY  dataPairsSeed (optional)
      3: OBJECT issuer (optional)
      4: STRING note (optional)
      5: STRING sourceQueueId (optional)

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_orderType", ""],
    ["_targetGroupId", ""],
    ["_dataSeed", []],
    ["_issuer", objNull],
    ["_note", ""],
    ["_sourceQid", ""]
];

if (!(_orderType isEqualType "")) then { _orderType = ""; };
_orderType = toUpper (trim _orderType);

if (_orderType in ["PROCEED"]) then { _orderType = "LEAD"; };
if (_orderType isEqualTo "") exitWith {false};

if (!(_targetGroupId isEqualType "")) then { _targetGroupId = ""; };
_targetGroupId = trim _targetGroupId;
if (_targetGroupId isEqualTo "") exitWith {false};

if (!(_dataSeed isEqualType [])) then { _dataSeed = []; };
if (!(_note isEqualType "")) then { _note = ""; };
if (!(_sourceQid isEqualType "")) then { _sourceQid = ""; };

private _issuerStr = "SYSTEM";
private _issuerUID = "";
if (!isNull _issuer) then
{
    _issuerStr = [_issuer] call ARC_fnc_rolesFormatUnit;
    _issuerUID = getPlayerUID _issuer;
};

// Helper: set a [k,v] pair in an array of pairs
private _setPair = {
    params ["_pairs", "_k", "_v"];
    if (!(_pairs isEqualType [])) exitWith { [[_k,_v]] };
    private _found = false;
    for "_i" from 0 to ((count _pairs) - 1) do
    {
        private _p = _pairs # _i;
        if (_p isEqualType [] && { (count _p) >= 2 } && { (_p # 0) isEqualTo _k }) exitWith
        {
            _pairs set [_i, [_k, _v]];
            _found = true;
        };
    };
    if (!_found) then { _pairs pushBack [_k, _v]; };
    _pairs
};

// Helper: get a [k,v] pair
private _getPair = {
    params ["_pairs", "_k", "_d"];
    if (!(_pairs isEqualType [])) exitWith { _d };
    private _out = _d;
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { (_x # 0) isEqualTo _k }) exitWith
        {
            _out = _x # 1;
        };
    } forEach _pairs;
    _out
};

// Prevent stacking multiple ISSUED orders for the same group (keeps UX clean)
private _orders = ["tocOrders", []] call ARC_fnc_stateGet;
if (!(_orders isEqualType [])) then { _orders = []; };

private _hasIssued = false;
{
    if (_x isEqualType [] && { (count _x) >= 7 }) then
    {
        private _st = toUpper (_x # 2);
        private _tg = _x # 4;
        if (_st isEqualTo "ISSUED" && { _tg isEqualTo _targetGroupId }) exitWith { _hasIssued = true; };
    };
} forEach _orders;

if (_hasIssued) exitWith
{
    ["OPS", format ["ORDER: %1 attempted to issue %2 to %3, but an ISSUED order already exists.", _issuerStr, _orderType, _targetGroupId], [0,0,0],
        [
            ["event", "TOC_ORDER_BLOCKED"],
            ["orderType", _orderType],
            ["targetGroup", _targetGroupId]
        ]
    ] call ARC_fnc_intelLog;
    false
};



// Build data pairs based on order type
private _data = +_dataSeed;

switch (_orderType) do
{
    case "RTB":
    {
        private _purpose = [_dataSeed, "purpose", "REFIT"] call _getPair;
        if (!(_purpose isEqualType "")) then { _purpose = "REFIT"; };
        _purpose = toUpper (trim _purpose);

        private _dest = [_purpose] call ARC_fnc_intelResolveRtbDestination;
        _dest params ["_destPos", "_destLabel", "_destRad"];

        _data = [_data, "purpose", _purpose] call _setPair;
        _data = [_data, "destPos", _destPos] call _setPair;
        _data = [_data, "destLabel", _destLabel] call _setPair;
        _data = [_data, "destRadius", _destRad] call _setPair;
    };

    case "LEAD":
    {
        // Assign a lead from the pool (consumes it from leadPool).
        // If the caller provided a specific leadId in the seed, try to consume that lead first.
        private _seedLeadId = [_data, "leadId", ""] call _getPair;
        if (!(_seedLeadId isEqualType "")) then { _seedLeadId = ""; };
        _seedLeadId = trim _seedLeadId;

        private _lead = [];
        if (_seedLeadId != "") then
        {
            _lead = [_seedLeadId] call ARC_fnc_leadConsumeById;
        };
        if (_lead isEqualTo []) then
        {
            _lead = [] call ARC_fnc_leadConsumeNext;
        };
        if (!(_lead isEqualType []) || { (count _lead) == 0 }) then
        {
            _orderType = "STANDBY";
        }
        else
        {
            private _leadId = _lead # 0;
            private _leadType = _lead # 1;
            private _leadName = _lead # 2;
            private _leadPos  = _lead # 3;

            private _zone = [_leadPos] call ARC_fnc_worldGetZoneForPos;

            _data = [_data, "lead", _lead] call _setPair;
            _data = [_data, "leadId", _leadId] call _setPair;
            _data = [_data, "leadType", _leadType] call _setPair;
            _data = [_data, "leadName", _leadName] call _setPair;
            _data = [_data, "leadPos", _leadPos] call _setPair;
            _data = [_data, "zone", _zone] call _setPair;
        };
    };

    default { };
};

private _ctr = ["orderCounter", 0] call ARC_fnc_stateGet;
if (!(_ctr isEqualType 0)) then { _ctr = 0; };
_ctr = _ctr + 1;
["orderCounter", _ctr] call ARC_fnc_stateSet;

private _orderId = format ["ARC_ord_%1", _ctr];

private _meta = [];
_meta = [_meta, "issuedBy", _issuerStr] call _setPair;
_meta = [_meta, "issuedByUID", _issuerUID] call _setPair;
_meta = [_meta, "note", trim _note] call _setPair;
_meta = [_meta, "sourceQid", trim _sourceQid] call _setPair;

private _rec = [_orderId, serverTime, "ISSUED", _orderType, _targetGroupId, _data, _meta];

_orders pushBack _rec;

private _cap = missionNamespace getVariable ["ARC_tocOrderCap", 30];
if (!(_cap isEqualType 0)) then { _cap = 30; };
_cap = (_cap max 10) min 100;
while { (count _orders) > _cap } do { _orders deleteAt 0; };

["tocOrders", _orders] call ARC_fnc_stateSet;

// Publish orders snapshot
[] call ARC_fnc_intelOrderBroadcast;

// Quietly log issuance
["OPS", format ["ORDER: %1 issued %2 (%3) to %4.", _issuerStr, _orderId, _orderType, _targetGroupId], [0,0,0],
    [
        ["event", "TOC_ORDER_ISSUED"],
        ["orderId", _orderId],
        ["orderType", _orderType],
        ["targetGroup", _targetGroupId],
        ["sourceQid", trim _sourceQid]
    ]
] call ARC_fnc_intelLog;

// Notify target group (player-side) if possible
private _targetGroup = grpNull;
{
    if (groupId _x isEqualTo _targetGroupId) exitWith { _targetGroup = _x; };
} forEach allGroups;

if (!isNull _targetGroup) then
{
    private _msg = "";
    private _toastTitle = "TOC Order Pending Acceptance";
    private _toastBody = "";
    switch (_orderType) do
    {
        case "RTB":
        {
            private _purpose = [_data, "purpose", "REFIT"] call _getPair;
            private _destLabel = [_data, "destLabel", "Base"] call _getPair;
            _msg = format ["TOC ORDER: RTB (%1) to %2. Use [Player] Actions to accept.", _purpose, _destLabel];
            _toastBody = format ["RTB (%1) to %2. Accept the order.", _purpose, _destLabel];
        };
        case "HOLD": { _msg = "TOC ORDER: HOLD. Use [Player] Actions to accept."; };
        case "LEAD":
        {
            private _leadName = [_data, "leadName", "Lead"] call _getPair;
            _msg = format ["TOC ORDER: PROCEED on %1. Use [Player] Actions to accept.", _leadName];
            _toastBody = format ["PROCEED on %1. Accept the order.", _leadName];
        };
        default { _msg = format ["TOC ORDER: %1. Use [Player] Actions to accept.", _orderType]; };
    };

    if (_toastBody isEqualTo "") then
    {
        _toastBody = _msg;
    };

    {
        if (isPlayer _x) then
        {
            [_toastTitle, _toastBody, 6] remoteExec ["ARC_fnc_clientToast", _x];
        };
    } forEach (units _targetGroup);
};

true

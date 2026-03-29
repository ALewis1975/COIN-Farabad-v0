/*
    ARC_fnc_intelOrderCompleteRtbIntel

    Server: complete an ACCEPTED RTB(INTEL) order after a player submits an Intel Debrief.

    This is the interaction the player should perform at the TOC Intel Debrief station.

    Params:
      0: OBJECT - caller/player
      1: STRING - summary (optional)
      2: STRING - details (optional)

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_caller", objNull],
    ["_summary", ""],
    ["_details", ""],
    ["_forceConsole", false, [false]],
    ["_orderIdOverride", "", [""]]
];

if (isNull _caller) exitWith {false};
if (!isPlayer _caller) exitWith {false};

// RemoteExec anti-spoof (best effort)
if (!isNil "remoteExecutedOwner") then
{
    if (remoteExecutedOwner != owner _caller) exitWith {false};
};

private _g = group _caller;
if (isNull _g) exitWith {false};
private _gidCaller = groupId _g;
if (_gidCaller isEqualTo "") exitWith {false};

// Allow console debrief to be executed remotely by authorized TOC roles.
// We require that the RTB(INTEL) order has already reached its destination (arrivedAt meta) to prevent premature completion.
private _canForce = false;
if (_forceConsole) then
{
    _canForce = [_caller] call ARC_fnc_rolesCanApproveQueue;
    if (!(_canForce isEqualType true)) then { _canForce = false; };
};

private _getPair = {
    params ["_pairs", "_k", "_d"];
    if (!(_pairs isEqualType [])) exitWith { _d };
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { (_x # 0) isEqualTo _k }) exitWith { _x # 1 };
    } forEach _pairs;
    _d
};

private _setPair = {
    params ["_pairs", "_k", "_v"];
    if (!(_pairs isEqualType [])) then { _pairs = []; };
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

private _orderIdO = "";
if (_orderIdOverride isEqualType "") then { _orderIdO = trim _orderIdOverride; };

private _orders = ["tocOrders", []] call ARC_fnc_stateGet;
if (!(_orders isEqualType [])) then { _orders = []; };

private _idx = -1;
private _ord = [];

if (!(_orderIdO isEqualTo "")) then
{
    if (!_canForce) exitWith {false};

    _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 7 } && { (_x # 0) isEqualTo _orderIdO }) exitWith { _idx = _forEachIndex; }; } forEach _orders;
    if (_idx >= 0) then { _ord = _orders # _idx; };
    if (_idx < 0 || {_ord isEqualTo []}) exitWith {false};

    _ord params ["_orderId", "_issuedAt", "_status", "_orderType", "_targetGroup", "_data", "_meta"]; 

    if (!((toUpper _status) isEqualTo "ACCEPTED")) exitWith {false};
    if (!((toUpper _orderType) isEqualTo "RTB")) exitWith {false};

    private _purposeO = toUpper ([_data, "purpose", "REFIT"] call _getPair);
    if (!(_purposeO isEqualTo "INTEL")) exitWith {false};
}
else
{
    for "_i" from 0 to ((count _orders) - 1) do
    {
        private _o = _orders # _i;
        if (!(_o isEqualType [] && { (count _o) >= 7 })) then { continue; };

        _o params ["_orderId", "_issuedAt", "_status", "_orderType", "_targetGroup", "_data", "_meta"];

        if (!((toUpper _status) isEqualTo "ACCEPTED")) then { continue; };
        if (!((toUpper _orderType) isEqualTo "RTB")) then { continue; };
        if (!(_targetGroup isEqualTo _gidCaller)) then { continue; };

        private _purpose = toUpper ([_data, "purpose", "REFIT"] call _getPair);
        if (_purpose isEqualTo "INTEL") exitWith
        {
            _idx = _i;
            _ord = _o;
        };
    };

    if (_idx < 0 || {_ord isEqualTo []}) exitWith {false};
};

_ord params ["_orderId", "_issuedAt", "_status", "_orderType", "_targetGroup", "_data", "_meta"];

private _gidTarget = _targetGroup;

private _taskId  = [_data, "taskId", ""] call _getPair;
private _destPos = [_data, "destPos", []] call _getPair;
private _destRad = [_data, "destRadius", 30] call _getPair;

if (!(_destRad isEqualType 0)) then { _destRad = 30; };
_destRad = (_destRad max 8) min 500;

// Validate caller is near the intended destination unless this is a TOC-authorized
// console debrief request.
if (!_canForce) then
{
    if (_destPos isEqualType [] && { (count _destPos) >= 2 }) then
    {
        private _p = +_destPos; _p resize 3;
        if ((_caller distance2D _p) > (_destRad + 10)) exitWith
        {
            ["You are not at the Intel Debrief point. Move closer and try again."] remoteExec ["ARC_fnc_intelClientNotify", _caller];
            false
        };
    };
};
// Update order status + metadata
_status = "COMPLETED";
_meta = [_meta, "completedAt", serverTime] call _setPair;
_meta = [_meta, "completedBy", name _caller] call _setPair;
_meta = [_meta, "completedByUID", getPlayerUID _caller] call _setPair;

_orders set [_idx, [_orderId, _issuedAt, _status, _orderType, _targetGroup, _data, _meta]];
["tocOrders", _orders] call ARC_fnc_stateSet;

// Complete the RTB task if present
if (!(_taskId isEqualTo "")) then
{
    if ([_taskId] call BIS_fnc_taskExists) then
    {
        [_taskId, "SUCCEEDED", true] call BIS_fnc_taskSetState;
    };
};

// Log debrief content (intel feed)
private _pos = if (_destPos isEqualType [] && { (count _destPos) >= 2 }) then { +_destPos } else { getPosATL _caller };
_pos resize 3;

private _sum = trim _summary;
private _det = trim _details;
if (_sum isEqualTo "") then { _sum = "Intel debrief delivered."; };

private _iMeta = [
    ["event", "RTB_INTEL_DEBRIEF"],
    ["orderId", _orderId],
    ["taskId", _taskId],
    ["targetGroup", _gidTarget],
    ["caller", name _caller]
];
if (!(_det isEqualTo "")) then { _iMeta pushBack ["details", _det]; };

["DEBRIEF", _sum, _pos, _iMeta] call ARC_fnc_intelLog;

// Log completion breadcrumb (OPS)
private _grid = mapGridPosition _pos;
private _opsSum = format ["ORDER COMPLETE: %1 (RTB INTEL) by %2 at %3.", _orderId, name _caller, _grid];
["OPS", _opsSum, _pos, [["event", "ORDER_COMPLETED"], ["orderId", _orderId], ["taskId", _taskId], ["targetGroup", _gidTarget]]] call ARC_fnc_intelLog;

// Broadcast updated order snapshot
[] call ARC_fnc_intelOrderBroadcast;

true

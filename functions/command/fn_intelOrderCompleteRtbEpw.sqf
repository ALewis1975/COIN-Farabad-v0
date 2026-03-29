/*
    ARC_fnc_intelOrderCompleteRtbEpw

    Server: complete an ACCEPTED RTB(EPW) order after a player processes EPWs.

    This is the interaction the player should perform at the SHERIFF handling / EPW processing station.

    On completion:
      - RTB(EPW) order is marked COMPLETED
      - RTB task (if present) is set SUCCEEDED
      - Nearby detainees are moved to the EPW holding area
      - Detainees are scheduled for virtual transfer to Division after a delay

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

// Allow console processing to be executed remotely by authorized TOC roles.
// This bypasses the caller proximity check, but EPW presence near the processing point is still required.
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
        if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _k }) exitWith { _x select 1 };
    } forEach _pairs;
    _d
};

private _setPair = {
    params ["_pairs", "_k", "_v"];
    if (!(_pairs isEqualType [])) then { _pairs = []; };
    private _found = false;
    for "_i" from 0 to ((count _pairs) - 1) do
    {
        private _p = _pairs select _i;
        if (_p isEqualType [] && { (count _p) >= 2 } && { (_p select 0) isEqualTo _k }) exitWith
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

// Find the ACCEPTED RTB(EPW) order.
// - Default: group-scoped (targetGroup == caller groupId)
// - TOC override: by orderId (requires forceConsole + TOC auth)
private _orders = ["tocOrders", []] call ARC_fnc_stateGet;
if (!(_orders isEqualType [])) then { _orders = []; };

private _idx = -1;
private _ord = [];

if (!(_orderIdO isEqualTo "")) then
{
    if (!_canForce) exitWith {false};

    _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 7 } && { (_x select 0) isEqualTo _orderIdO }) exitWith { _idx = _forEachIndex; }; } forEach _orders;
    if (_idx >= 0) then { _ord = _orders select _idx; };
    if (_idx < 0 || {_ord isEqualTo []}) exitWith {false};

    _ord params ["_orderId", "_issuedAt", "_status", "_orderType", "_targetGroup", "_data", "_meta"];

    if (!((toUpper _status) isEqualTo "ACCEPTED")) exitWith {false};
    if (!((toUpper _orderType) isEqualTo "RTB")) exitWith {false};

    private _purposeO = toUpper ([_data, "purpose", "REFIT"] call _getPair);
    if (!(_purposeO isEqualTo "EPW")) exitWith {false};
}
else
{
    for "_i" from 0 to ((count _orders) - 1) do
    {
        private _o = _orders select _i;
        if (!(_o isEqualType [] && { (count _o) >= 7 })) then { continue; };

        _o params ["_orderId", "_issuedAt", "_status", "_orderType", "_targetGroup", "_data", "_meta"]; 

        if (!((toUpper _status) isEqualTo "ACCEPTED")) then { continue; };
        if (!((toUpper _orderType) isEqualTo "RTB")) then { continue; };
        if (!(_targetGroup isEqualTo _gidCaller)) then { continue; };

        private _purpose = toUpper ([_data, "purpose", "REFIT"] call _getPair);
        if (_purpose isEqualTo "EPW") exitWith
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
// console processing request. (We still require detainees at the processing point below.)
if (!_canForce) then
{
    if (_destPos isEqualType [] && { (count _destPos) >= 2 }) then
    {
        private _p = +_destPos; _p resize 3;
        if ((_caller distance2D _p) > (_destRad + 10)) exitWith
        {
            ["You are not at the EPW processing point. Move closer and try again."] remoteExec ["ARC_fnc_intelClientNotify", _caller];
            false
        };
    };
}
else
{
    // If someone attempts to force console processing without TOC rights, fall back to normal checks.
    // (Defensive; _canForce already encodes auth.)
};

// Resolve EPW holding location
private _resolveHolding = {
    private _mHold = "";
    {
        private _cand = [_x] call ARC_fnc_worldResolveMarker;
        if (!((markerType _cand) isEqualTo "")) exitWith { _mHold = _cand; };
    } forEach ["epw_holding", "mkr_SHERIFF_HOLDING"];

    if (!(_mHold isEqualTo "")) exitWith
    {
        private _hp = getMarkerPos _mHold; _hp resize 3;
        private _hl = markerText _mHold;
        if (_hl isEqualTo "") then { _hl = "EPW Holding"; };
        [_hp, _hl, 35]
    };

    // Fallback: base center
    private _m = missionNamespace getVariable ["ARC_mkr_airbaseCenter", "mkr_airbaseCenter"];
    _m = [_m] call ARC_fnc_worldResolveMarker;
    private _bp = getMarkerPos _m; _bp resize 3;
    if ((markerType _m) isEqualTo "") then { _bp = getPosATL _caller; };
    [_bp, "Base", 60]
};

private _hold = call _resolveHolding;
_hold params ["_holdPos", "_holdLabel", "_holdRad"]; 

// Find nearby detainees to transfer
private _searchRad = missionNamespace getVariable ["ARC_epwProcessSearchRadius", 45];
if (!(_searchRad isEqualType 0)) then { _searchRad = 45; };
_searchRad = (_searchRad max 10) min 200;

private _detained = [];
{
    private _u = _x;

    if (isPlayer _u) then { continue; };
    if (!alive _u) then { continue; };

    if (_destPos isEqualType [] && { (count _destPos) >= 2 }) then
    {
        if ((_u distance2D _destPos) > _searchRad) then { continue; };
    }
    else
    {
        if ((_u distance2D _caller) > _searchRad) then { continue; };
    };

    // Best-effort: ACE captives sets captive/handcuffed state.
    private _hc = _u getVariable ["ace_captives_isHandcuffed", false];
    if (!(_hc isEqualType true)) then { _hc = false; };
    private _hc2 = _u getVariable ["ACE_captives_isHandcuffed", false];
    if (!(_hc2 isEqualType true)) then { _hc2 = false; };

    private _isDetained = (captive _u) || { _hc } || { _hc2 };
    if (!_isDetained) then { continue; };

    _detained pushBackUnique _u;
} forEach allUnits;

// Require at least one detainee so the order cannot be "completed" accidentally.
if ((count _detained) isEqualTo 0) exitWith
{
    [format ["No detained EPWs found within %1m of processing. Bring detainee(s) close to the processing point and try again.", _searchRad]] remoteExec ["ARC_fnc_intelClientNotify", _caller];
    false
};

private _moved = 0;

// Transfer detainees to holding
{
    private _u = _x;
    if (isNull _u || {!alive _u}) then { continue; };

    _moved = _moved + 1;

    // Small scatter around holding marker
    private _offX = (random 10) - 5;
    private _offY = (random 10) - 5;
    private _hp = [(_holdPos select 0) + _offX, (_holdPos select 1) + _offY, 0];

    // Move out of vehicle if needed, then place
    [_u, _hp] spawn {
        params ["_u", "_hp"];
        if (isNull _u) exitWith {};

        if (vehicle _u != _u) then
        {
            unassignVehicle _u;
            moveOut _u;
            sleep 0.2;
        };

        // Keep them detained/contained
        _u setCaptive true;
        _u setPosATL _hp;
        _u disableAI "PATH";
        _u disableAI "MOVE";
        _u setVariable ["ARC_epw_inHolding", true, true];
        _u setVariable ["ARC_epw_processedAt", serverTime, true];

        // Virtual transfer to Division after a delay
        private _delay = missionNamespace getVariable ["ARC_epwTransferToDivisionAfterSec", 1800];
        if (!(_delay isEqualType 0)) then { _delay = 1800; };
        _delay = (_delay max 60) min 21600;

        [_u, _delay] spawn {
            params ["_u", "_delay"];
            sleep _delay;
            if (isNull _u) exitWith {};
            if (!alive _u) exitWith {};
            if (!(_u getVariable ["ARC_epw_inHolding", false])) exitWith {};

            private _pos = getPosATL _u;
            ["OPS", format ["EPW transferred to Division (%1).", name _u], _pos,
                [
                    ["event", "EPW_TRANSFERRED_TO_DIV"],
                    ["unit", name _u]
                ]
            ] call ARC_fnc_intelLog;

            deleteVehicle _u;
        };
    };
} forEach _detained;

// Update order status + metadata
_status = "COMPLETED";
_meta = [_meta, "completedAt", serverTime] call _setPair;
_meta = [_meta, "completedBy", name _caller] call _setPair;
_meta = [_meta, "completedByUID", getPlayerUID _caller] call _setPair;
_meta = [_meta, "epwMovedToHolding", _moved] call _setPair;
_meta = [_meta, "holdingLabel", _holdLabel] call _setPair;

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

// Update basic metrics (optional)
private _tot = ["epwProcessedTotal", 0] call ARC_fnc_stateGet;
if (!(_tot isEqualType 0)) then { _tot = 0; };
_tot = _tot + _moved;
["epwProcessedTotal", _tot] call ARC_fnc_stateSet;

private _pos = if (_destPos isEqualType [] && { (count _destPos) >= 2 }) then { +_destPos } else { getPosATL _caller };
_pos resize 3;

private _sum = trim _summary;
private _det = trim _details;
if (_sum isEqualTo "") then
{
    _sum = format ["EPW processed: %1 transferred to holding (%2).", _moved, _holdLabel];
};

private _iMeta = [
    ["event", "RTB_EPW_PROCESSED"],
    ["orderId", _orderId],
    ["taskId", _taskId],
    ["targetGroup", _gidTarget],
    ["caller", name _caller],
    ["moved", _moved],
    ["holding", _holdLabel]
];
if (!(_det isEqualTo "")) then { _iMeta pushBack ["details", _det]; };

["EPW", _sum, _pos, _iMeta] call ARC_fnc_intelLog;

private _grid = mapGridPosition _pos;
private _opsSum = format ["ORDER COMPLETE: %1 (RTB EPW) by %2 at %3. EPWs moved: %4. Target: %5.", _orderId, name _caller, _grid, _moved, _gidTarget];
["OPS", _opsSum, _pos,
    [
        ["event", "ORDER_COMPLETED"],
        ["orderId", _orderId],
        ["taskId", _taskId],
        ["targetGroup", _gidTarget],
        ["moved", _moved]
    ]
] call ARC_fnc_intelLog;

// Notify caller (client-side)
[format ["EPW processed. Moved %1 detainee(s) to %2.", _moved, _holdLabel]] remoteExec ["ARC_fnc_intelClientNotify", _caller];

// Broadcast updated order snapshot
[] call ARC_fnc_intelOrderBroadcast;

true

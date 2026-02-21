/*
    ARC_fnc_intelOrderBroadcast

    Server: publish a JIP-safe snapshot of outstanding TOC orders for clients.

    Published vars:
      ARC_pub_orders          = [order,...]
      ARC_pub_ordersUpdatedAt = serverTime

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

// sqflint-compat helpers
private _trimFn     = compile "params ['_s']; trim _s";

private _maxOrders = missionNamespace getVariable ["ARC_pubOrdersMax", 60];
if (!(_maxOrders isEqualType 0) || { _maxOrders < 10 }) then { _maxOrders = 60; };
_maxOrders = (_maxOrders min 120) max 10;

private _maxTextLen = missionNamespace getVariable ["ARC_pubOrdersTextMaxLen", 180];
if (!(_maxTextLen isEqualType 0) || { _maxTextLen < 40 }) then { _maxTextLen = 180; };
_maxTextLen = (_maxTextLen min 400) max 40;

private _maxPairs = missionNamespace getVariable ["ARC_pubOrdersPairsMax", 14];
if (!(_maxPairs isEqualType 0) || { _maxPairs < 0 }) then { _maxPairs = 14; };
_maxPairs = (_maxPairs min 40) max 0;

private _sanitizePairs = {
    params ["_pairs"];
    private _in = if (_pairs isEqualType []) then { +_pairs } else { [] };
    private _truncated = false;
    if ((count _in) > _maxPairs) then { _in = _in select [0, _maxPairs]; _truncated = true; };
    private _out = [];
    {
        if !(_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualType "" }) then { _truncated = true; continue; };
        private _k = [(_x select 0)] call _trimFn;
        if (_k isEqualTo "") then { _truncated = true; continue; };
        private _v = _x select 1;
        if (_v isEqualType "") then {
            _v = [_v] call _trimFn;
            if ((count _v) > _maxTextLen) then { _v = _v select [0, _maxTextLen]; _truncated = true; };
        };
        _out pushBack [_k, _v];
    } forEach _in;
    if (_truncated) then { _out pushBack ["truncated", true]; };
    _out
};

private _sanitizeOrder = {
    params ["_order"];
    if !(_order isEqualType [] && { (count _order) >= 7 }) exitWith { [] };
    private _id = _order select 0;
    private _createdAt = _order select 1;
    private _status = _order select 2;
    private _kind = _order select 3;
    private _targetGroup = _order select 4;
    private _data = _order select 5;
    private _meta = _order select 6;
    private _tr = false;

    if !(_id isEqualType "") then { _id = ""; _tr = true; };
    if !(_createdAt isEqualType 0) then { _createdAt = 0; _tr = true; };
    if !(_status isEqualType "") then { _status = "ISSUED"; _tr = true; };
    if !(_kind isEqualType "") then { _kind = "UNKNOWN"; _tr = true; };
    if !(_targetGroup isEqualType "") then { _targetGroup = ""; _tr = true; };
    private _dataSafe = [_data] call _sanitizePairs;
    private _metaSafe = [_meta] call _sanitizePairs;
    if (_tr) then { _metaSafe pushBack ["entryTruncated", true]; };
    [_id, _createdAt, toUpper _status, toUpper _kind, _targetGroup, _dataSafe, _metaSafe]
};

private _o = ["tocOrders", []] call ARC_fnc_stateGet;
if (!(_o isEqualType [])) then { _o = []; };

private _out = [];
{
    if (_x isEqualType [] && { (count _x) >= 7 }) then
    {
        private _st = _x select 2;
        if (_st isEqualType "") then
        {
            private _su = toUpper _st;
            if (_su in ["ISSUED", "ACCEPTED"]) then
            {
                _out pushBack _x;
            };
        };
    };
} forEach _o;

private _allCount = count _out;
if (_allCount > _maxOrders) then
{
    _out = _out select [(_allCount - _maxOrders) max 0, _maxOrders];
};

private _safe = _out apply { [_x] call _sanitizeOrder };

missionNamespace setVariable ["ARC_pub_orders", _safe, true];
missionNamespace setVariable ["ARC_pub_ordersUpdatedAt", serverTime, true];
missionNamespace setVariable ["ARC_pub_ordersMeta", [
    ["maxOrders", _maxOrders],
    ["textMaxLen", _maxTextLen],
    ["pairsMax", _maxPairs],
    ["truncated", _allCount > _maxOrders]
], true];

true

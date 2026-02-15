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

private _o = ["tocOrders", []] call ARC_fnc_stateGet;
if (!(_o isEqualType [])) then { _o = []; };

private _out = [];
{
    if (_x isEqualType [] && { (count _x) >= 7 }) then
    {
        private _st = _x # 2;
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

missionNamespace setVariable ["ARC_pub_orders", _out, true];
missionNamespace setVariable ["ARC_pub_ordersUpdatedAt", serverTime, true];

true

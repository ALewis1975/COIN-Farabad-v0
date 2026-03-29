/*
    ARC_fnc_intelClientHasAcceptedRtbIntel

    Client: returns true if the unit's group currently has an ACCEPTED RTB order
    with purpose INTEL.

    Params:
      0: OBJECT - unit (default: player)

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

params [["_unit", player]];
if (isNull _unit) exitWith {false};

private _g = group _unit;
if (isNull _g) exitWith {false};
private _gid = groupId _g;
if (_gid isEqualTo "") exitWith {false};

private _orders = missionNamespace getVariable ["ARC_pub_orders", []];
if (!(_orders isEqualType [])) then { _orders = []; };

private _getPair = {
    params ["_pairs", "_k", "_d"];
    if (!(_pairs isEqualType [])) exitWith { _d };
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _k }) exitWith { _x select 1 };
    } forEach _pairs;
    _d
};

private _has = false;

{
    if (!(_x isEqualType [] && { (count _x) >= 7 })) then { continue; };

    _x params ["_orderId", "_issuedAt", "_status", "_orderType", "_targetGroup", "_data", "_meta"];

    if (!((toUpper _status) isEqualTo "ACCEPTED")) then { continue; };
    if (!((toUpper _orderType) isEqualTo "RTB")) then { continue; };
    if (!(_targetGroup isEqualTo _gid)) then { continue; };

    private _purpose = toUpper ([_data, "purpose", "REFIT"] call _getPair);
    if (_purpose isEqualTo "INTEL") exitWith { _has = true; };
} forEach _orders;

_has

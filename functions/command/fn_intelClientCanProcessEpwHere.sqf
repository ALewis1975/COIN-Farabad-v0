/*
    ARC_fnc_intelClientCanProcessEpwHere

    Client: returns true if the unit:
      - has an ACCEPTED RTB order with purpose EPW
      - is near the resolved RTB destination position

    This is used for the fallback self-action that allows EPW processing even
    if the station object variable is not available on the client.

    Params:
      0: OBJECT - unit (default: player)

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

params [ ["_unit", player] ];
if (isNull _unit) exitWith {false};

// Must have an accepted RTB(EPW) first
if (!([_unit] call ARC_fnc_intelClientHasAcceptedRtbEpw)) exitWith {false};

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
        if (_x isEqualType [] && { (count _x) >= 2 } && { (_x # 0) isEqualTo _k }) exitWith { _x # 1 };
    } forEach _pairs;
    _d
};

private _destPos = [];
private _destRad = 30;

{
    if (!(_x isEqualType [] && { (count _x) >= 7 })) then { continue; };

    _x params ["_orderId", "_issuedAt", "_status", "_orderType", "_targetGroup", "_data", "_meta"];

    if ((toUpper _status) isNotEqualTo "ACCEPTED") then { continue; };
    if ((toUpper _orderType) isNotEqualTo "RTB") then { continue; };
    if (_targetGroup isNotEqualTo _gid) then { continue; };

    private _purpose = toUpper ([_data, "purpose", "REFIT"] call _getPair);
    if (_purpose isNotEqualTo "EPW") then { continue; };

    _destPos = [_data, "destPos", []] call _getPair;
    _destRad = [_data, "destRadius", 30] call _getPair;
    break;
} forEach _orders;

if (!(_destRad isEqualType 0)) then { _destRad = 30; };

// Fallback if order didn't include a usable destPos
if (!(_destPos isEqualType [] && { (count _destPos) >= 2 })) then
{
    private _m = "";
    {
        private _cand = [_x] call ARC_fnc_worldResolveMarker;
        if (!((markerType _cand) isEqualTo "")) exitWith { _m = _cand; };
    } forEach ["epw_processing", "epw_holding", "mkr_SHERIFF_HOLDING"];

    if (_m isNotEqualTo "") then
    {
        _destPos = getMarkerPos _m;
        _destRad = 30;
    }
    else
    {
        // Last resort: allow within a small radius of the player (should not normally happen)
        _destPos = getPosATL _unit;
        _destRad = 10;
    };
};

// Use the server-provided destination radius whenever possible.
// IMPORTANT: keep this in sync with server arrival detection (ARC_fnc_intelOrderTick)
// so players don't get an "arrived" prompt while the client-side fallback action is still hidden.
//
// Upper bound prevents the action from showing "across base" if a mission maker sets an absurd radius.
private _useRad = (_destRad max 12) min 60;

(_unit distance2D _destPos) <= _useRad

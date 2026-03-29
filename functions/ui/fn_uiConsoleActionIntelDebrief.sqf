/*
    ARC_fnc_uiConsoleActionIntelDebrief

    Client: invoked from the console "ACTION" button on HANDOFF tab.

    Fix:
    - Capture _orderId explicitly (do not rely on inner-scope params variables)
    - Support TOC override by reading selected orderId from uiNamespace (set by HandoffPaint)
*/

if (!hasInterface) exitWith {false};

private _gidSelf = groupId (group player);
if (_gidSelf isEqualTo "") exitWith {false};

private _isToc = [player] call ARC_fnc_rolesCanApproveQueue;
if (!(_isToc isEqualType true)) then { _isToc = false; };

// Try to use the order selected by the HANDOFF paint (TOC focus / best candidate)
private _orderId = "";
private _orderTg = "";

if (_isToc) then {
    _orderId = ["ARC_console_handoff_intelOrderId", ""] call ARC_fnc_uiNsGetString;
    _orderTg = ["ARC_console_handoff_intelTargetGroup", ""] call ARC_fnc_uiNsGetString;
    if (!(_orderId isEqualType "")) then { _orderId = ""; };
    if (!(_orderTg isEqualType "")) then { _orderTg = ""; };
    _orderId = trim _orderId;
    _orderTg = trim _orderTg;
};

// Fallback: find accepted RTB(INTEL) for your own group
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

private _hasAccepted = false;
private _destPos = [];
private _destRad = 30;

// If no selected orderId, locate the self-group order (purpose INTEL)
if (_orderId isEqualTo "") then
{
    {
        if (_x isEqualType [] && { (count _x) >= 7 }) then
        {
            _x params ["_oid", "_iat", "_st", "_ot", "_tg", "_data", "_meta"];
            if ((toUpper _st) isEqualTo "ACCEPTED" && { (toUpper _ot) isEqualTo "RTB" } && { _tg isEqualTo _gidSelf }) then
            {
                private _purpose = toUpper ([_data, "purpose", "REFIT"] call _getPair);
                if (_purpose isEqualTo "INTEL") exitWith
                {
                    _hasAccepted = true;
                    _orderId = _oid;
                    _orderTg = _tg;
                    _destPos = [_data, "destPos", []] call _getPair;
                    _destRad = [_data, "destRadius", 30] call _getPair;
                    if (!(_destRad isEqualType 0)) then { _destRad = 30; };
                    _destRad = _destRad max 30;
                };
            };
        };
    } forEach _orders;
}
else
{
    // We have a selected orderId. Validate its dest so we can decide if "near" (optional).
    {
        if (_x isEqualType [] && { (count _x) >= 7 }) then
        {
            _x params ["_oid", "_iat", "_st", "_ot", "_tg", "_data", "_meta"];
            if (_oid isEqualTo _orderId) exitWith
            {
                if (!((toUpper _st) isEqualTo "ACCEPTED")) exitWith {};
                if (!((toUpper _ot) isEqualTo "RTB")) exitWith {};
                private _purpose = toUpper ([_data, "purpose", "REFIT"] call _getPair);
                if (!(_purpose isEqualTo "INTEL")) exitWith {};
                _hasAccepted = true;
                _orderTg = _tg;
                _destPos = [_data, "destPos", []] call _getPair;
                _destRad = [_data, "destRadius", 30] call _getPair;
                if (!(_destRad isEqualType 0)) then { _destRad = 30; };
            };
        };
    } forEach _orders;
};

if (!_hasAccepted) exitWith {
    ["Handoff", "No accepted RTB (INTEL) found (focused or self)."] call ARC_fnc_clientToast;
    false
};

// Decide forceConsole
private _near = false;
if (_destPos isEqualType [] && { (count _destPos) >= 2 }) then {
    private _p = +_destPos;
    _p resize 3;
    _near = (player distance2D _p) <= (_destRad + 10);
};

// If the order belongs to another group, console override must be true
private _force = !_near;
if (_isToc && { !(_orderTg isEqualTo "") } && { !(_orderTg isEqualTo _gidSelf) }) then {
    _force = true;
};

// Always pass orderId when we have one (enables TOC cross-group processing).
[objNull, player, _force, _orderId] call ARC_fnc_intelClientDebriefIntel;

true

/*
    ARC_fnc_uiConsoleActionEpwProcess

    Client: invoked from the console "ACTION" button on HANDOFF tab.

    Fix:
    - Capture _orderId explicitly
    - Use uiNamespace-selected order for TOC
    - Keep arrival requirement (arrivedAt/awaitingEpwProcessing OR player at dest)
*/

if (!hasInterface) exitWith {false};

private _gidSelf = groupId (group player);
if (_gidSelf isEqualTo "") exitWith {false};

private _isToc = [player] call ARC_fnc_rolesCanApproveQueue;
if (!(_isToc isEqualType true)) then { _isToc = false; };

private _orderId = "";
private _orderTg = "";

if (_isToc) then {
    _orderId = ["ARC_console_handoff_epwOrderId", ""] call ARC_fnc_uiNsGetString;
    _orderTg = ["ARC_console_handoff_epwTargetGroup", ""] call ARC_fnc_uiNsGetString;
    if (!(_orderId isEqualType "")) then { _orderId = ""; };
    if (!(_orderTg isEqualType "")) then { _orderTg = ""; };
    _orderId = trim _orderId;
    _orderTg = trim _orderTg;
};

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
private _arrived = false;
private _destPos = [];
private _destRad = 30;

private _consumeOrder = {
    params ["_oid", "_tg", "_data", "_meta"];

    _hasAccepted = true;
    _orderId = _oid;
    _orderTg = _tg;

    _destPos = [_data, "destPos", []] call _getPair;
    _destRad = [_data, "destRadius", 30] call _getPair;
    if (!(_destRad isEqualType 0)) then { _destRad = 30; };

    private _arrivedAt = [_meta, "arrivedAt", -1] call _getPair;
    if (!(_arrivedAt isEqualType 0)) then { _arrivedAt = -1; };

    if (_arrivedAt >= 0) exitWith { _arrived = true; };

    private _awaiting = [_meta, "awaitingEpwProcessing", false] call _getPair;
    if (!(_awaiting isEqualType true)) then { _awaiting = false; };
    _arrived = _awaiting;
};

// If no selected orderId, locate the self-group order (purpose EPW)
if (_orderId isEqualTo "") then
{
    {
        if (_x isEqualType [] && { (count _x) >= 7 }) then
        {
            _x params ["_oid", "_iat", "_st", "_ot", "_tg", "_data", "_meta"];
            if ((toUpper _st) isEqualTo "ACCEPTED" && { (toUpper _ot) isEqualTo "RTB" } && { _tg isEqualTo _gidSelf }) then
            {
                private _purpose = toUpper ([_data, "purpose", "REFIT"] call _getPair);
                if (_purpose isEqualTo "EPW") exitWith {
                    [_oid, _tg, _data, _meta] call _consumeOrder;
                };
            };
        };
    } forEach _orders;
}
else
{
    // We have a selected orderId. Validate it.
    {
        if (_x isEqualType [] && { (count _x) >= 7 }) then
        {
            _x params ["_oid", "_iat", "_st", "_ot", "_tg", "_data", "_meta"];
            if (_oid isEqualTo _orderId) exitWith
            {
                if (!((toUpper _st) isEqualTo "ACCEPTED")) exitWith {};
                if (!((toUpper _ot) isEqualTo "RTB")) exitWith {};
                private _purpose = toUpper ([_data, "purpose", "REFIT"] call _getPair);
                if (!(_purpose isEqualTo "EPW")) exitWith {};
                [_oid, _tg, _data, _meta] call _consumeOrder;
            };
        };
    } forEach _orders;
};

if (!_hasAccepted) exitWith {
    ["Handoff", "No accepted RTB (EPW) found (focused or self)."] call ARC_fnc_clientToast;
    false
};

// Allow immediate processing if physically at destination even before the 60s order tick marks ARRIVED.
private _near = false;
if (_destPos isEqualType [] && { (count _destPos) >= 2 }) then {
    private _p = +_destPos;
    _p resize 3;
    _near = (player distance2D _p) <= (_destRad + 10);
};

// Extra robustness: if a detained AI is already inside the processing zone, treat as arrived even when
// the local player is not standing at the destination (avoids waiting on server tick).
if (!_arrived && {!_near}) then {
    private _found = false;
    if (_destPos isEqualType [] && { (count _destPos) >= 2 }) then {
        private _searchRad = missionNamespace getVariable ["ARC_epwProcessSearchRadius", 45];
        if (!(_searchRad isEqualType 0)) then { _searchRad = 45; };
        _searchRad = (_searchRad max 10) min 200;

        {
            private _u = _x;
            if (isPlayer _u) then { continue; };
            if (!alive _u) then { continue; };
            if ((_u distance2D _destPos) > _searchRad) then { continue; };
            private _hc = _u getVariable ["ace_captives_isHandcuffed", false];
            if (!(_hc isEqualType true)) then { _hc = false; };
            private _hc2 = _u getVariable ["ACE_captives_isHandcuffed", false];
            if (!(_hc2 isEqualType true)) then { _hc2 = false; };
            private _isDetained = (captive _u) || { _hc } || { _hc2 };
            if (!_isDetained) then { continue; };
            _found = true;
        } forEach allUnits;
    };
    if (_found) then { _arrived = true; };
};


if (!_arrived && {!_near}) exitWith {
    ["Handoff", "RTB (EPW) has not arrived at the processing destination yet."] call ARC_fnc_clientToast;
    false
};

// Force only when not physically at the point, or when TOC is processing another unit
private _force = (!_near);
if (_isToc && { !(_orderTg isEqualTo "") } && { !(_orderTg isEqualTo _gidSelf) }) then {
    _force = true;
};

[objNull, player, _force, _orderId] call ARC_fnc_intelClientProcessEpw;

true

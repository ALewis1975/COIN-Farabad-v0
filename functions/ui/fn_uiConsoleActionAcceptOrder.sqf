/*
    ARC_fnc_uiConsoleActionAcceptOrder

    Client: invoked from the console "Accept Order" button.

    Purpose:
      - Removes reliance on addAction / ACE self-actions for accepting TOC orders.
      - Provides a predictable, UI-driven acceptance workflow.

    Rules:
      - Accepts the next ISSUED order for the player's group.
      - Requires an authorized leader OR OMNI token (playtest override).

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

// UI button handlers run in an unscheduled environment. This action uses BIS_fnc_guiMessage,
// which internally suspends (waitUntil), so force scheduled execution.
if (!canSuspend) exitWith { _this spawn ARC_fnc_uiConsoleActionAcceptOrder; false };

private _g = group player;
if (isNull _g) exitWith {false};
private _gid = groupId _g;
if (!(_gid isEqualType "") || { _gid isEqualTo "" }) exitWith
{
    ["Orders", "Your group has no callsign; cannot resolve orders."] call ARC_fnc_clientToast;
    false
};

// OMNI override (playtesting)
private _omniTokens = missionNamespace getVariable ["ARC_consoleOmniTokens", ["OMNI"]];
if (!(_omniTokens isEqualType [])) then { _omniTokens = ["OMNI"]; };
private _isOmni = false;
{
    if (_x isEqualType "" && { [player, _x] call ARC_fnc_rolesHasGroupIdToken }) exitWith { _isOmni = true; };
} forEach _omniTokens;

private _isLeader = ([player] call ARC_fnc_rolesIsAuthorized) || _isOmni;
if (!_isLeader) exitWith
{
    ["Orders", "A leader (or OMNI) must accept TOC orders for your group."] call ARC_fnc_clientToast;
    false
};

private _orders = missionNamespace getVariable ["ARC_pub_orders", []];
if (!(_orders isEqualType [])) then { _orders = []; };

private _ord = [];
{
    if (!(_x isEqualType [] && { (count _x) >= 7 })) then { continue; };
    private _st = toUpper (_x select 2);
    private _tg = _x select 4;
    if (_st isEqualTo "ISSUED" && { _tg isEqualTo _gid }) exitWith { _ord = _x; };
} forEach _orders;

if (_ord isEqualTo []) exitWith
{
    ["Orders", "No TOC order pending acceptance for your group."] call ARC_fnc_clientToast;
    false
};

_ord params ["_orderId", "_issuedAt", "_status", "_orderType", "_targetGroup", "_data", "_meta"];
_orderType = toUpper (trim _orderType);

private _getPair = {
    params ["_pairs", "_k", "_d"];
    if (!(_pairs isEqualType [])) exitWith { _d };
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _k }) exitWith { _x select 1 };
    } forEach _pairs;
    _d
};

private _issuer = [_meta, "issuedBy", "TOC"] call _getPair;
private _note   = [_meta, "note", ""] call _getPair;

private _lines = [];
_lines pushBack format ["Order ID: %1", _orderId];
_lines pushBack format ["Type: %1", _orderType];
_lines pushBack format ["Issued By: %1", _issuer];

switch (_orderType) do
{
    case "RTB":
    {
        private _purpose = toUpper ([_data, "purpose", "REFIT"] call _getPair);
        private _destLabel = [_data, "destLabel", "Return Point"] call _getPair;
        private _destPos = [_data, "destPos", []] call _getPair;
        private _grid = if (_destPos isEqualType [] && { (count _destPos) >= 2 }) then { mapGridPosition _destPos } else { "" };

        _lines pushBack format ["Purpose: %1", _purpose];
        _lines pushBack format ["Destination: %1%2", _destLabel, if (_grid isEqualTo "") then {""} else {format [" (@ %1)", _grid]}];
    };

    case "LEAD":
    {
        private _leadName = [_data, "leadName", "Lead"] call _getPair;
        private _leadPos  = [_data, "leadPos", []] call _getPair;
        private _grid = if (_leadPos isEqualType [] && { (count _leadPos) >= 2 }) then { mapGridPosition _leadPos } else { "" };

        _lines pushBack format ["Lead: %1", _leadName];
        if (!(_grid isEqualTo "")) then { _lines pushBack format ["Lead Location: %1", _grid]; };
    };

    default { };
};

if (!(_note isEqualTo "")) then
{
    _lines pushBack "";
    _lines pushBack "TOC Note:";
    _lines pushBack _note;
};

private _msg = _lines joinString "\n";
private _ok = [_msg, "Accept TOC Order", true, true] call BIS_fnc_guiMessage;
if (!_ok) exitWith { false };

["ORDER_ACCEPT", "SUBMITTING", format ["Order %1", _orderId], 8] call ARC_fnc_uiConsoleOpsActionStatus;
[player, _orderId] remoteExec ["ARC_fnc_intelOrderAccept", 2];
true

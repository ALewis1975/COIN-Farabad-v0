/*
    ARC_fnc_intelClientAcceptOrder

    Client: accept the next ISSUED TOC order for the player's group.

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

// This function uses BIS_fnc_guiMessage (suspends via waitUntil). Ensure we run scheduled.
if (!canSuspend) exitWith { _this spawn ARC_fnc_intelClientAcceptOrder; false };

if (!([] call ARC_fnc_intelClientCanAcceptOrder)) exitWith
{
    hint "No TOC order pending acceptance.";
    false
};

private _gid = groupId (group player);
private _orders = missionNamespace getVariable ["ARC_pub_orders", []];
if (!(_orders isEqualType [])) then { _orders = []; };

private _o = [];
{
    if (_x isEqualType [] && { (count _x) >= 7 }) then
    {
        private _st = toUpper (_x # 2);
        private _tg = _x # 4;
        if (_st isEqualTo "ISSUED" && { _tg isEqualTo _gid }) exitWith { _o = _x; };
    };
} forEach _orders;

if (_o isEqualTo []) exitWith { hint "No TOC order found."; false };

_o params ["_orderId", "_issuedAt", "_status", "_orderType", "_targetGroup", "_data", "_meta"];
_orderType = toUpper _orderType;

private _getPair = {
    params ["_pairs", "_k", "_d"];
    if (!(_pairs isEqualType [])) exitWith { _d };
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { (_x # 0) isEqualTo _k }) exitWith { _x # 1 };
    } forEach _pairs;
    _d
};

private _issuer = [_meta, "issuedBy", "TOC"] call _getPair;
private _note = [_meta, "note", ""] call _getPair;

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
        _lines pushBack format ["Destination: %1 %2", _destLabel, if (_grid isEqualTo "") then { "" } else { format ["(@ %1)", _grid] }];
    };

    case "LEAD":
    {
        // NOTE: order payload uses key "leadName" (not "leadDisplayName")
        private _leadName = [_data, "leadName", "Lead" ] call _getPair;
        private _leadPos = [_data, "leadPos", []] call _getPair;
        private _grid = if (_leadPos isEqualType [] && { (count _leadPos) >= 2 }) then { mapGridPosition _leadPos } else { "" };
        _lines pushBack format ["Lead: %1", _leadName];
        if (_grid isNotEqualTo "") then { _lines pushBack format ["Lead Location: %1", _grid]; };
    };

    default { };
};

if (_note isNotEqualTo "") then
{
    _lines pushBack "";
    _lines pushBack "TOC Note:";
    _lines pushBack _note;
};

private _msg = _lines joinString "\n";
private _ok = [_msg, "Accept TOC Order", true, true] call BIS_fnc_guiMessage;
if (!_ok) exitWith { false };

[player, _orderId] remoteExec ["ARC_fnc_intelOrderAccept", 2];

hint format ["Order accepted: %1", _orderId];
true

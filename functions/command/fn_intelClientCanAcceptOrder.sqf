/*
    ARC_fnc_intelClientCanAcceptOrder

    Client: gate for accepting an outstanding TOC order.

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

if (!([player] call ARC_fnc_rolesIsAuthorized)) exitWith {false};

private _gid = groupId (group player);
if (_gid isEqualTo "") exitWith {false};

private _availRows = missionNamespace getVariable ["ARC_pub_groupTaskingAvailability", []];
if (!(_availRows isEqualType [])) then { _availRows = []; };
private _idxAvail = _availRows findIf {
    (_x isEqualType []) && { (count _x) >= 2 } &&
    { ((_x # 0) isEqualType "") && { (toUpper (_x # 0)) isEqualTo (toUpper _gid) } }
};
if (_idxAvail >= 0 && { !((_availRows # _idxAvail) param [1, true]) }) exitWith {false};

private _orders = missionNamespace getVariable ["ARC_pub_orders", []];
if (!(_orders isEqualType [])) then { _orders = []; };

private _hasIssued = false;
{
    if (_x isEqualType [] && { (count _x) >= 5 }) then
    {
        private _st = toUpper (_x # 2);
        private _tg = _x # 4;
        if (_st isEqualTo "ISSUED" && { _tg isEqualTo _gid }) exitWith { _hasIssued = true; };
    };
} forEach _orders;

_hasIssued

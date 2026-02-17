/*
    ARC_fnc_intelSetGroupTaskingAvailability

    Server: set the requesting caller's group availability for TOC tasking.

    Params:
      0: OBJECT caller
      1: BOOL available
*/

if (!isServer) exitWith {false};

params [
    ["_caller", objNull, [objNull]],
    ["_available", true, [true]]
];

if !([_caller, "ARC_fnc_intelSetGroupTaskingAvailability", "Tasking availability update denied.", "TASKING_AVAIL_REJECTED"] call ARC_fnc_rpcValidateSender) exitWith {false};
if (isNull _caller || {!isPlayer _caller}) exitWith {false};
if !([_caller] call ARC_fnc_rolesIsAuthorized) exitWith {false};

private _gid = groupId (group _caller);
if (_gid isEqualTo "") exitWith {false};

private _rows = missionNamespace getVariable ["ARC_pub_groupTaskingAvailability", []];
if (!(_rows isEqualType [])) then { _rows = []; };

private _idx = _rows findIf {
    (_x isEqualType []) && { (count _x) >= 2 } &&
    { ((_x # 0) isEqualType "") && { (toUpper (_x # 0)) isEqualTo (toUpper _gid) } }
};

if (_idx < 0) then
{
    _rows pushBack [_gid, _available];
}
else
{
    private _row = _rows # _idx;
    _row set [1, _available];
    _rows set [_idx, _row];
};

missionNamespace setVariable ["ARC_pub_groupTaskingAvailability", _rows, true];
true

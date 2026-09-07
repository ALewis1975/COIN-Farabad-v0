/*
    ARC_fnc_intelTocIssueOrder

    Server: helper for TOC staff to issue a follow-on order without going through
    the request queue.

    Params:
      0: OBJECT issuer
      1: STRING order (RTB|HOLD|PROCEED)
      2: STRING purpose (for RTB: REFIT|INTEL|EPW)
      3: STRING note

    Target group selection:
      - activeIncidentAcceptedByGroup (if available)
      - lastTaskingGroup
      - issuer's own group

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

private _compatTrimFn = compile "params ['_s']; trim _s";

params [
    ["_issuer", objNull],
    ["_order", ""],
    ["_purpose", "REFIT"],
    ["_note", ""]
];

if (isNull _issuer) exitWith {false};

// Dedicated MP hardening: validate sender identity.
private _reoOwner = remoteExecutedOwner;
if (!([_issuer, "ARC_fnc_intelTocIssueOrder", "Request rejected: sender verification failed.", "INTELTOCISSUEORDER_SECURITY_DENIED", false, _reoOwner] call ARC_fnc_rpcValidateSender)) exitWith {false};

_order = toUpper (([_order] call _compatTrimFn));
_purpose = toUpper (([_purpose] call _compatTrimFn));

private _targetGroup = ["activeIncidentAcceptedByGroup", ""] call ARC_fnc_stateGet;
if (!(_targetGroup isEqualType "") || { _targetGroup isEqualTo "" }) then
{
    _targetGroup = ["lastTaskingGroup", ""] call ARC_fnc_stateGet;
};
if (!(_targetGroup isEqualType "") || { _targetGroup isEqualTo "" }) then
{
    _targetGroup = groupId (group _issuer);
};


private _orderType = "STANDBY";
private _payload = [];

switch (_order) do
{
    case "RTB":
    {
        _orderType = "RTB";
        _payload = [["purpose", _purpose]];
    };
    case "HOLD":
    {
        _orderType = "HOLD";
        _payload = [];
    };
    case "PROCEED":
    {
        // PROCEED becomes a lead assignment if a lead exists, otherwise STANDBY.
        _orderType = "LEAD";
        _payload = [];
    };
    default
    {
        _orderType = "STANDBY";
        _payload = [];
    };
};

[_orderType, _targetGroup, _payload, _issuer, _note, ""] call ARC_fnc_intelOrderIssue

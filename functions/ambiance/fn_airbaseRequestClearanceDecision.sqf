/*
    Server RPC: tower decision for clearance request.
    Params: [OBJECT caller, STRING requestId, BOOL approve, STRING reason]
*/
if (!isServer) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\\core\\fn_rpcValidateSender.sqf"; };
if (isNil "ARC_fnc_airbaseTowerAuthorize") then { ARC_fnc_airbaseTowerAuthorize = compile preprocessFileLineNumbers "functions\\core\\fn_airbaseTowerAuthorize.sqf"; };

params [
    ["_caller", objNull, [objNull]],
    ["_requestId", "", [""]],
    ["_approve", true, [true]],
    ["_reason", "", [""]]
];

if (!([_caller, "ARC_fnc_airbaseRequestClearanceDecision", "Airbase clearance decision rejected: sender verification failed.", "AIRBASE_CLEARANCE_DECISION_SECURITY_DENIED"] call ARC_fnc_rpcValidateSender)) exitWith {false};

if (!(_requestId isEqualType "")) then { _requestId = ""; };
_requestId = trim _requestId;
if (_requestId isEqualTo "") exitWith {false};

if (!(_approve isEqualType true) && !(_approve isEqualType false)) then { _approve = false; };
if (!(_reason isEqualType "")) then { _reason = ""; };
_reason = trim _reason;
if (_reason isEqualTo "") then { _reason = if (_approve) then {"TOWER_APPROVE"} else {"TOWER_DENY"}; };

private _actionToken = if (_approve) then {"APPROVE"} else {"DENY"};
private _auth = [_caller, _actionToken] call ARC_fnc_airbaseTowerAuthorize;
private _ok = _auth param [0, false];
if (!_ok) then {
    private _override = [_caller, "OVERRIDE"] call ARC_fnc_airbaseTowerAuthorize;
    _ok = _override param [0, false];
};
if (!_ok) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { [format ["Airbase %1 decision denied: tower authorization required.", toLower _actionToken]] remoteExec ["ARC_fnc_clientHint", _owner]; };
    false
};

private _requests = ["airbase_v1_clearanceRequests", []] call ARC_fnc_stateGet;
if (!(_requests isEqualType [])) then { _requests = []; };

private _history = ["airbase_v1_clearanceHistory", []] call ARC_fnc_stateGet;
if (!(_history isEqualType [])) then { _history = []; };

private _idx = _requests findIf { ((_x param [0, ""]) isEqualTo _requestId) };
if (_idx < 0) exitWith {false};

private _rec = _requests # _idx;
private _status = toUpperANSI (_rec param [6, ""]);
if !(_status in ["PENDING", "AWAITING_TOWER_DECISION"]) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { ["Clearance request is no longer pending decision."] remoteExec ["ARC_fnc_clientHint", _owner]; };
    false
};

private _now = serverTime;
private _uid = getPlayerUID _caller;
private _name = name _caller;

_rec set [6, if (_approve) then {"APPROVED"} else {"DENIED"}];
_rec set [8, _now];
_rec set [9, [_name, _uid, _now, _actionToken, _reason]];

private _meta = _rec param [10, []];
if (!(_meta isEqualType [])) then { _meta = []; };
_meta pushBack ["decidedBy", _name];
_meta pushBack ["decidedByUid", _uid];
_meta pushBack ["decisionAction", _actionToken];
_meta pushBack ["decisionReason", _reason];
_rec set [10, _meta];

_requests set [_idx, _rec];

private _hIdx = _history findIf { ((_x param [0, ""]) isEqualTo _requestId) };
if (_hIdx >= 0) then { _history set [_hIdx, _rec]; } else { _history pushBack _rec; };

["airbase_v1_clearanceRequests", _requests] call ARC_fnc_stateSet;
["airbase_v1_clearanceHistory", _history] call ARC_fnc_stateSet;

["OPS", format ["AIRBASE CLEARANCE: %1 %2 by %3", _requestId, toLower _actionToken, _name], getPosATL _caller, [
    ["event", "AIRBASE_CLEARANCE_TOWER_DECISION"],
    ["requestId", _requestId],
    ["action", _actionToken],
    ["decisionBy", _name],
    ["uid", _uid],
    ["reason", _reason]
]] call ARC_fnc_intelLog;

true

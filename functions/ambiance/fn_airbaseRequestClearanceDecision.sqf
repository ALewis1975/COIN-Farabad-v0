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


private _callerCheck = [_caller, "OBJECT_NOT_NULL", "caller", [objNull]] call ARC_fnc_paramAssert;
if !(_callerCheck param [0, false]) exitWith {
    ["AIRBASE", format ["clearance decision guard: code=%1 msg=%2", _callerCheck param [2, "ARC_ASSERT_UNKNOWN"], _callerCheck param [3, "caller invalid"]], [["code", _callerCheck param [2, "ARC_ASSERT_UNKNOWN"]], ["rpc", "ARC_fnc_airbaseRequestClearanceDecision"]]] call ARC_fnc_farabadWarn;
    false
};

private _requestIdCheck = [_requestId, "NON_EMPTY_STRING", "requestId", [""]] call ARC_fnc_paramAssert;
_requestId = _requestIdCheck param [1, ""];
if !(_requestIdCheck param [0, false]) exitWith {
    ["AIRBASE", format ["clearance decision guard: code=%1 msg=%2", _requestIdCheck param [2, "ARC_ASSERT_UNKNOWN"], _requestIdCheck param [3, "requestId invalid"]], [["code", _requestIdCheck param [2, "ARC_ASSERT_UNKNOWN"]], ["rpc", "ARC_fnc_airbaseRequestClearanceDecision"]]] call ARC_fnc_farabadWarn;
    false
};

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
private _reqCheck = [_requests, "ARRAY_SHAPE", "airbase_v1_clearanceRequests", [[], 0, -1, false]] call ARC_fnc_paramAssert;
_requests = _reqCheck param [1, []];
if !(_reqCheck param [0, false]) then {
    ["AIRBASE", format ["clearance decision guard: code=%1 msg=%2", _reqCheck param [2, "ARC_ASSERT_UNKNOWN"], _reqCheck param [3, "requests invalid"]], [["code", _reqCheck param [2, "ARC_ASSERT_UNKNOWN"]], ["stateKey", "airbase_v1_clearanceRequests"]]] call ARC_fnc_farabadWarn;
};

private _history = ["airbase_v1_clearanceHistory", []] call ARC_fnc_stateGet;
private _histCheck = [_history, "ARRAY_SHAPE", "airbase_v1_clearanceHistory", [[], 0, -1, false]] call ARC_fnc_paramAssert;
_history = _histCheck param [1, []];
if !(_histCheck param [0, false]) then {
    ["AIRBASE", format ["clearance decision guard: code=%1 msg=%2", _histCheck param [2, "ARC_ASSERT_UNKNOWN"], _histCheck param [3, "history invalid"]], [["code", _histCheck param [2, "ARC_ASSERT_UNKNOWN"]], ["stateKey", "airbase_v1_clearanceHistory"]]] call ARC_fnc_farabadWarn;
};

private _events = ["airbase_v1_events", []] call ARC_fnc_stateGet;
private _eventsCheck = [_events, "ARRAY_SHAPE", "airbase_v1_events", [[], 0, -1, false]] call ARC_fnc_paramAssert;
_events = _eventsCheck param [1, []];
if !(_eventsCheck param [0, false]) then {
    ["AIRBASE", format ["clearance decision guard: code=%1 msg=%2", _eventsCheck param [2, "ARC_ASSERT_UNKNOWN"], _eventsCheck param [3, "events invalid"]], [["code", _eventsCheck param [2, "ARC_ASSERT_UNKNOWN"]], ["stateKey", "airbase_v1_events"]]] call ARC_fnc_farabadWarn;
};
private _eventsMax = missionNamespace getVariable ["airbase_v1_eventsMax", 60];
if (!(_eventsMax isEqualType 0) || { _eventsMax < 10 }) then { _eventsMax = 60; };

private _idx = _requests findIf { ((_x param [0, ""]) isEqualTo _requestId) };
if (_idx < 0) exitWith {false};

private _rec = _requests # _idx;
private _requesterUid = _rec param [2, ""];
private _requesterOwner = -1;
if (_requesterUid isNotEqualTo "") then {
    {
        if ((getPlayerUID _x) isEqualTo _requesterUid) exitWith { _requesterOwner = owner _x; };
    } forEach allPlayers;
};
private _status = toUpperANSI (_rec param [6, ""]);
if !(_status in ["QUEUED", "PENDING", "AWAITING_TOWER_DECISION"]) exitWith {
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
if (_approve) then {
    _meta pushBack ["lifecycle_approved_at", _now];
} else {
    _meta pushBack ["lifecycle_denied_at", _now];
};
_rec set [10, _meta];

_requests set [_idx, _rec];

private _hIdx = _history findIf { ((_x param [0, ""]) isEqualTo _requestId) };
if (_hIdx >= 0) then { _history set [_hIdx, _rec]; } else { _history pushBack _rec; };


_events pushBack [
    _now,
    _actionToken,
    _requestId,
    _uid,
    _requesterUid,
    [_reason]
];
if ((count _events) > _eventsMax) then {
    _events deleteRange [0, (count _events) - _eventsMax];
};

_requests = [_requests] call ARC_fnc_airbaseClearanceSortRequests;

["airbase_v1_clearanceRequests", _requests] call ARC_fnc_stateSet;
["airbase_v1_clearanceHistory", _history] call ARC_fnc_stateSet;
["airbase_v1_events", _events] call ARC_fnc_stateSet;


private _decisionWord = if (_approve) then {"approved"} else {"denied"};
if (_requesterOwner > 0) then {
    ["Airbase Clearance", format ["%1 %2 by %3", _requestId, _decisionWord, _name], 6] remoteExec ["ARC_fnc_clientToast", _requesterOwner];
};
private _controllerOwner = owner _caller;
if (_controllerOwner > 0) then {
    [format ["Decision recorded: %1", _requestId]] remoteExec ["ARC_fnc_clientHint", _controllerOwner];
};

["OPS", format ["AIRBASE CLEARANCE: %1 %2 by %3", _requestId, toLower _actionToken, _name], getPosATL _caller, [
    ["event", "AIRBASE_CLEARANCE_TOWER_DECISION"],
    ["requestId", _requestId],
    ["action", _actionToken],
    ["decisionBy", _name],
    ["uid", _uid],
    ["reason", _reason]
]] call ARC_fnc_intelLog;

true

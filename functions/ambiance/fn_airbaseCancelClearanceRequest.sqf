/*
    Server RPC: cancel a pending airbase clearance request.
    Params: [OBJECT caller, STRING requestId]
*/
if (!isServer) exitWith {false};
if !(["airbaseCancelClearanceRequest"] call ARC_fnc_airbaseRuntimeEnabled) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\\core\\fn_rpcValidateSender.sqf"; };
if (isNil "ARC_fnc_airbaseTowerAuthorize") then { ARC_fnc_airbaseTowerAuthorize = compile preprocessFileLineNumbers "functions\\core\\fn_airbaseTowerAuthorize.sqf"; };

params [
    ["_caller", objNull, [objNull]],
    ["_requestId", "", [""]]
];

if (!([_caller, "ARC_fnc_airbaseCancelClearanceRequest", "Airbase clearance cancel rejected: sender verification failed.", "AIRBASE_CLEARANCE_CANCEL_SECURITY_DENIED"] call ARC_fnc_rpcValidateSender)) exitWith {false};

if (!(_requestId isEqualType "")) then { _requestId = ""; };
_requestId = trim _requestId;
if (_requestId isEqualTo "") exitWith {false};

private _requests = ["airbase_v1_clearanceRequests", []] call ARC_fnc_stateGet;
if (!(_requests isEqualType [])) then { _requests = []; };

private _history = ["airbase_v1_clearanceHistory", []] call ARC_fnc_stateGet;
if (!(_history isEqualType [])) then { _history = []; };


private _events = ["airbase_v1_events", []] call ARC_fnc_stateGet;
if (!(_events isEqualType [])) then { _events = []; };
private _eventsMax = missionNamespace getVariable ["airbase_v1_eventsMax", 60];
if (!(_eventsMax isEqualType 0) || { _eventsMax < 10 }) then { _eventsMax = 60; };

private _idx = -1;
{ if ((_x param [0, ""]) isEqualTo _requestId) exitWith { _idx = _forEachIndex; }; } forEach _requests;
if (_idx < 0) exitWith {false};

private _rec = _requests # _idx;
private _status = toUpper (_rec param [6, ""]);
private _uid = _rec param [2, ""];
private _requesterOwner = -1;
if (!(_uid isEqualTo "")) then {
    {
        if ((getPlayerUID _x) isEqualTo _uid) exitWith { _requesterOwner = owner _x; };
    } forEach allPlayers;
};
private _callerUid = getPlayerUID _caller;

if !(_status in ["QUEUED", "PENDING", "AWAITING_TOWER_DECISION"]) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { ["Clearance request cannot be canceled in current state."] remoteExec ["ARC_fnc_clientHint", _owner]; };
    false
};

private _overrideAuth = [_caller, "OVERRIDE"] call ARC_fnc_airbaseTowerAuthorize;
private _hasOverride = _overrideAuth param [0, false];

if ((!(_uid isEqualTo _callerUid)) && {!_hasOverride}) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { ["Only the requesting pilot or tower override can cancel this request."] remoteExec ["ARC_fnc_clientHint", _owner]; };
    false
};

_rec set [6, "CANCELED"];
_rec set [8, serverTime];
_rec set [9, [name _caller, _callerUid, serverTime, "CANCEL", "PILOT_CANCEL"]];

private _meta = _rec param [10, []];
if (!(_meta isEqualType [])) then { _meta = []; };
_meta pushBack ["cancelledBy", name _caller];
_meta pushBack ["cancelledByUid", _callerUid];
_meta pushBack ["lifecycle_complete_at", serverTime];
_rec set [10, _meta];

_requests set [_idx, _rec];

private _hIdx = -1;
{ if ((_x param [0, ""]) isEqualTo _requestId) exitWith { _hIdx = _forEachIndex; }; } forEach _history;
if (_hIdx >= 0) then { _history set [_hIdx, _rec]; } else { _history pushBack _rec; };


_events pushBack [
    serverTime,
    "CANCEL",
    _requestId,
    _callerUid,
    _uid,
    []
];
if ((count _events) > _eventsMax) then {
    _events deleteRange [0, (count _events) - _eventsMax];
};

_requests = [_requests] call ARC_fnc_airbaseClearanceSortRequests;

["airbase_v1_clearanceRequests", _requests] call ARC_fnc_stateSet;
["airbase_v1_clearanceHistory", _history] call ARC_fnc_stateSet;
["airbase_v1_events", _events] call ARC_fnc_stateSet;


private _controllerOwner = owner _caller;
if (_requesterOwner > 0) then {
    ["Airbase Clearance", format ["Request canceled: %1", _requestId], 5] remoteExec ["ARC_fnc_clientToast", _requesterOwner];
};
if (_controllerOwner > 0 && { _controllerOwner != _requesterOwner }) then {
    [format ["Cancellation recorded: %1", _requestId]] remoteExec ["ARC_fnc_clientHint", _controllerOwner];
};

["OPS", format ["AIRBASE CLEARANCE: %1 canceled by %2", _requestId, name _caller], getPosATL _caller, [
    ["event", "AIRBASE_CLEARANCE_CANCELED"],
    ["requestId", _requestId],
    ["caller", name _caller],
    ["uid", _callerUid]
]] call ARC_fnc_intelLog;

true

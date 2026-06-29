/*
    ARC_fnc_airbaseRequestQueueParkedAsset

    Server RPC: manually queue a specific parked asset for departure.
    Called by ARC_fnc_airbaseClientQueueParkedAsset on client → server (target = 2).

    Params:
      0: OBJECT  _caller  — the unit submitting the request (must be a player)
      1: STRING  _assetId — the airbase asset ID to queue (e.g. "FW-A10-WARTHOG11")

    Returns: BOOL — true on success, false on any rejection
*/

if (!isServer) exitWith {
    diag_log "[ARC][AIRBASE][RAMP] GUARD FAIL airbaseRequestQueueParkedAsset not_server";
    false
};
if !(["airbaseRequestQueueParkedAsset"] call ARC_fnc_airbaseRuntimeEnabled) exitWith {
    diag_log "[ARC][AIRBASE][RAMP] GUARD FAIL airbase runtime disabled (airbaseRequestQueueParkedAsset)";
    false
};

// Capture remoteExecutedOwner at the TOP frame — nested call frames see nil on dedicated.
private _reoOwner = if (!isNil "remoteExecutedOwner") then { remoteExecutedOwner } else { -1 };

if (isNil "ARC_fnc_rpcValidateSender") then {
    ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\\core\\fn_rpcValidateSender.sqf";
};
if (isNil "ARC_fnc_airbaseTowerAuthorize") then {
    ARC_fnc_airbaseTowerAuthorize = compile preprocessFileLineNumbers "functions\\core\\fn_airbaseTowerAuthorize.sqf";
};

params [
    ["_caller", objNull, [objNull]],
    ["_assetId", "", [""]]
];

private _trimFn = compile "params ['_s']; trim _s";
private _fnHmGet = compile "params ['_m', '_k', '_d']; private _v = _m get _k; if (isNil '_v') then { _d } else { _v }";

// Sender validation (security: confirm caller owns the unit they claim to be).
if (!([_caller, "ARC_fnc_airbaseRequestQueueParkedAsset", "Airbase ramp queue request rejected: sender verification failed.", "AIRBASE_RAMP_QUEUE_SECURITY_DENIED", true, _reoOwner] call ARC_fnc_rpcValidateSender)) exitWith { false };

// Tower authorization: require APPROVE-level (CCIC/BnCmd tier).
private _auth = [_caller, "APPROVE"] call ARC_fnc_airbaseTowerAuthorize;
_auth params ["_ok", "_level", "_reason"];
if (!_ok) exitWith {
    private _callerOwner = owner _caller;
    if (_callerOwner > 0) then {
        ["Ramp queue request denied: tower authorization required."] remoteExec ["ARC_fnc_clientHint", _callerOwner];
    };
    ["OPS", format ["AIRBASE CONTROL DENIED: RAMP QUEUE by %1 (%2)", name _caller, _reason], getPosATL _caller, 0, [
        ["event", "AIRBASE_RAMP_QUEUE_AUTH_DENIED"],
        ["caller", name _caller],
        ["uid", getPlayerUID _caller],
        ["level", _level],
        ["reason", _reason],
        ["assetId", _assetId]
    ]] call ARC_fnc_intelLog;
    false
};

// Validate asset ID.
if (!(_assetId isEqualType "")) then { _assetId = ""; };
_assetId = [_assetId] call _trimFn;
if (_assetId isEqualTo "") exitWith {
    private _callerOwner = owner _caller;
    if (_callerOwner > 0) then {
        ["Ramp queue request rejected: no asset ID provided."] remoteExec ["ARC_fnc_clientHint", _callerOwner];
    };
    false
};

// Look up asset in the airbase runtime.
private _rt = missionNamespace getVariable ["airbase_v1_rt", createHashMap];
private _assets = [_rt, "assets", []] call _fnHmGet;
if (!(_assets isEqualType [])) then { _assets = []; };

private _assetIdx = -1;
{
    if (([_x, "id", ""] call _fnHmGet) isEqualTo _assetId) exitWith { _assetIdx = _forEachIndex; };
} forEach _assets;

if (_assetIdx < 0) exitWith {
    private _callerOwner = owner _caller;
    if (_callerOwner > 0) then {
        [format ["Ramp queue request rejected: asset %1 not found.", _assetId]] remoteExec ["ARC_fnc_clientHint", _callerOwner];
    };
    diag_log format ["[ARC][AIRBASE][RAMP][WARN] ARC_fnc_airbaseRequestQueueParkedAsset: asset not found aid=%1 caller=%2", _assetId, name _caller];
    false
};

private _asset = _assets select _assetIdx;
private _state = [_asset, "state", "DISABLED"] call _fnHmGet;
if (!(_state isEqualTo "PARKED")) exitWith {
    private _callerOwner = owner _caller;
    if (_callerOwner > 0) then {
        [format ["Ramp queue request rejected: %1 is not currently parked (state: %2).", _assetId, _state]] remoteExec ["ARC_fnc_clientHint", _callerOwner];
    };
    diag_log format ["[ARC][AIRBASE][RAMP][WARN] ARC_fnc_airbaseRequestQueueParkedAsset: asset not PARKED aid=%1 state=%2", _assetId, _state];
    false
};

// Verify asset is not already in the departure queue.
private _queue = ["airbase_v1_queue", []] call ARC_fnc_stateGet;
if (!(_queue isEqualType [])) then { _queue = []; };

private _alreadyQueued = false;
{
    if (!(_x isEqualType [])) then { continue; };
    if ((_x param [2, ""]) isEqualTo _assetId) exitWith { _alreadyQueued = true; };
} forEach _queue;

if (_alreadyQueued) exitWith {
    private _callerOwner = owner _caller;
    if (_callerOwner > 0) then {
        [format ["%1 is already in the departure queue.", _assetId]] remoteExec ["ARC_fnc_clientHint", _callerOwner];
    };
    false
};

// Allocate a new flight ID.
private _seq = ["airbase_v1_seq", 0] call ARC_fnc_stateGet;
if (!(_seq isEqualType 0)) then { _seq = 0; };
_seq = _seq + 1;
["airbase_v1_seq", _seq] call ARC_fnc_stateSet;
private _fid = format ["FLT-%1", _seq];
private _nowTs = serverTime;

private _cat = [_asset, "category", "FW"] call _fnHmGet;
private _vehType = [_asset, "startVehType", ""] call _fnHmGet;

// Build departure record (same shape as ambient scheduler records).
private _recs = ["airbase_v1_records", []] call ARC_fnc_stateGet;
if (!(_recs isEqualType [])) then { _recs = []; };
private _rec = [
    _fid, _nowTs,
    "DEP", _cat,
    _assetId,
    "QUEUED",
    _nowTs,
    [
        ["mode", "DEPART"],
        ["assetId", _assetId],
        ["vehType", _vehType],
        ["source", "MANUAL_ATC"],
        ["manualOverride", true],
        ["manualBy", name _caller],
        ["manualByUid", getPlayerUID _caller],
        ["queuedAt", _nowTs]
    ]
];
_recs pushBack _rec;

// Validate route before committing to queue.
private _routeDecision = ["DEP", "MANUAL_ATC", _fid] call ARC_fnc_airbaseBuildRouteDecision;
private _routeOk = _routeDecision param [0, false];
private _routeMeta = _routeDecision param [1, []];
private _routeReason = _routeDecision param [2, "ROUTE_DECISION_FAILED"];

if (!_routeOk) exitWith {
    _recs deleteAt ((count _recs) - 1);
    ["airbase_v1_records", _recs] call ARC_fnc_stateSet;
    private _callerOwner = owner _caller;
    if (_callerOwner > 0) then {
        [format ["Ramp queue rejected: route unavailable for %1 (%2).", _assetId, _routeReason]] remoteExec ["ARC_fnc_clientHint", _callerOwner];
    };
    diag_log format ["[ARC][AIRBASE][RAMP][WARN] ARC_fnc_airbaseRequestQueueParkedAsset: route failed fid=%1 aid=%2 reason=%3", _fid, _assetId, _routeReason];
    false
};

// Commit: push to records and queue.
["airbase_v1_records", _recs] call ARC_fnc_stateSet;
_queue pushBack [_fid, "DEP", _assetId, _routeMeta];
["airbase_v1_queue", _queue] call ARC_fnc_stateSet;

// Ops log.
["OPS", format ["AIRBASE CONTROL: ramp queue %1 (%2) by %3", _fid, _assetId, name _caller], getPosATL _caller, 0, [
    ["event", "AIRBASE_RAMP_QUEUE_SET"],
    ["caller", name _caller],
    ["uid", getPlayerUID _caller],
    ["authLevel", _level],
    ["flightId", _fid],
    ["assetId", _assetId],
    ["queueLen", count _queue]
]] call ARC_fnc_intelLog;

// Notify requesting player.
private _callerOwner = owner _caller;
if (_callerOwner > 0) then {
    ["Airbase Tower", format ["Ramp queue accepted: %1 (%2) — flight %3", _assetId, _cat, _fid], 5] remoteExec ["ARC_fnc_clientToast", _callerOwner];
};

diag_log format ["[ARC][AIRBASE][RAMP][INFO] ARC_fnc_airbaseRequestQueueParkedAsset: queued fid=%1 aid=%2 by=%3 level=%4 queueLen=%5", _fid, _assetId, name _caller, _level, count _queue];
true

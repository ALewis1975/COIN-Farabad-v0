/*
    Server RPC: escalate pending clearance request to emergency priority.
    Params: [OBJECT caller, STRING requestId]
*/
if (!isServer) exitWith {false};
if !(["airbaseMarkClearanceEmergency"] call ARC_fnc_airbaseRuntimeEnabled) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\\core\\fn_rpcValidateSender.sqf"; };
if (isNil "ARC_fnc_airbaseTowerAuthorize") then { ARC_fnc_airbaseTowerAuthorize = compile preprocessFileLineNumbers "functions\\core\\fn_airbaseTowerAuthorize.sqf"; };

params [
    ["_caller", objNull, [objNull]],
    ["_requestId", "", [""]]
];

if (!([_caller, "ARC_fnc_airbaseMarkClearanceEmergency", "Airbase emergency escalation rejected: sender verification failed.", "AIRBASE_CLEARANCE_EMERGENCY_SECURITY_DENIED"] call ARC_fnc_rpcValidateSender)) exitWith {false};

if (!(_requestId isEqualType "")) then { _requestId = ""; };
_requestId = trim _requestId;
if (_requestId isEqualTo "") exitWith {false};

private _requests = ["airbase_v1_clearanceRequests", []] call ARC_fnc_stateGet;
if (!(_requests isEqualType [])) then { _requests = []; };

private _history = ["airbase_v1_clearanceHistory", []] call ARC_fnc_stateGet;
if (!(_history isEqualType [])) then { _history = []; };

private _idx = _requests findIf { ((_x param [0, ""]) isEqualTo _requestId) };
if (_idx < 0) exitWith {false};

private _rec = _requests # _idx;
private _status = toUpperANSI (_rec param [6, ""]);
private _uid = _rec param [2, ""];
private _callerUid = getPlayerUID _caller;

if !(_status in ["QUEUED", "PENDING", "AWAITING_TOWER_DECISION"]) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { ["Only pending clearance requests can be escalated."] remoteExec ["ARC_fnc_clientHint", _owner]; };
    false
};

private _overrideAuth = [_caller, "OVERRIDE"] call ARC_fnc_airbaseTowerAuthorize;
private _hasOverride = _overrideAuth param [0, false];

if ((_uid isNotEqualTo _callerUid) && {!_hasOverride}) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { ["Only the requesting pilot or tower override can mark emergency."] remoteExec ["ARC_fnc_clientHint", _owner]; };
    false
};

_rec set [5, 100];
_rec set [8, serverTime];
_rec set [9, [name _caller, _callerUid, serverTime, "OVERRIDE", "EMERGENCY_ESCALATION"]];

private _meta = _rec param [10, []];
if (!(_meta isEqualType [])) then { _meta = []; };
_meta pushBack ["emergency", true];
_meta pushBack ["escalatedBy", name _caller];
_meta pushBack ["escalatedByUid", _callerUid];
_meta pushBack ["priorityClass", "PRIORITY"];
_meta pushBack ["lane", "ARRIVAL"];
_rec set [10, _meta];

_requests set [_idx, _rec];

private _hIdx = _history findIf { ((_x param [0, ""]) isEqualTo _requestId) };
if (_hIdx >= 0) then { _history set [_hIdx, _rec]; } else { _history pushBack _rec; };

_requests = [_requests] call ARC_fnc_airbaseClearanceSortRequests;

["airbase_v1_clearanceRequests", _requests] call ARC_fnc_stateSet;
["airbase_v1_clearanceHistory", _history] call ARC_fnc_stateSet;

["OPS", format ["AIRBASE CLEARANCE: %1 marked emergency by %2", _requestId, name _caller], getPosATL _caller, [
    ["event", "AIRBASE_CLEARANCE_EMERGENCY"],
    ["requestId", _requestId],
    ["caller", name _caller],
    ["uid", _callerUid]
]] call ARC_fnc_intelLog;

true

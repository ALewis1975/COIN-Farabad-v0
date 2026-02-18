/*
    Server RPC: submit an airbase clearance request.
    Params: [OBJECT caller, STRING requestType, OBJECT aircraft, NUMBER priority]

    Record shape:
    [
        requestId, type, callerUid, callerName,
        aircraftNetId, priority, status,
        createdAt, updatedAt,
        [decisionBy, decisionByUid, decisionAt, decisionAction, decisionReason],
        [meta pairs]
    ]
*/
if (!isServer) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\\core\\fn_rpcValidateSender.sqf"; };

params [
    ["_caller", objNull, [objNull]],
    ["_requestType", "", [""]],
    ["_aircraft", objNull, [objNull]],
    ["_priority", 0, [0]]
];

if (!([_caller, "ARC_fnc_airbaseSubmitClearanceRequest", "Airbase clearance request rejected: sender verification failed.", "AIRBASE_CLEARANCE_SUBMIT_SECURITY_DENIED"] call ARC_fnc_rpcValidateSender)) exitWith {false};

if (isNull _aircraft) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { ["Clearance request rejected: invalid aircraft."] remoteExec ["ARC_fnc_clientHint", _owner]; };
    false
};

private _vehOwner = owner _aircraft;
private _callerOwner = owner _caller;
if ((_vehOwner > 0) && { _vehOwner != _callerOwner }) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { ["Clearance request rejected: aircraft ownership mismatch."] remoteExec ["ARC_fnc_clientHint", _owner]; };

    ["OPS", format ["AIRBASE CLEARANCE DENIED: submit owner mismatch by %1", name _caller], getPosATL _caller, [
        ["event", "AIRBASE_CLEARANCE_SUBMIT_OWNER_MISMATCH"],
        ["caller", name _caller],
        ["uid", getPlayerUID _caller],
        ["aircraftOwner", _vehOwner],
        ["callerOwner", _callerOwner]
    ]] call ARC_fnc_intelLog;

    false
};

if (!(_requestType isEqualType "")) then { _requestType = ""; };
_requestType = toUpperANSI (trim _requestType);
if !(_requestType in ["TAKEOFF", "LANDING", "TAXI", "RUNWAY_CROSS", "PARKING"]) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { ["Clearance request rejected: unsupported request type."] remoteExec ["ARC_fnc_clientHint", _owner]; };
    false
};

if (!(_priority isEqualType 0)) then { _priority = 0; };
if (_priority < 0) then { _priority = 0; };
if (_priority > 100) then { _priority = 100; };

private _requests = ["airbase_v1_clearanceRequests", []] call ARC_fnc_stateGet;
if (!(_requests isEqualType [])) then { _requests = []; };

private _history = ["airbase_v1_clearanceHistory", []] call ARC_fnc_stateGet;
if (!(_history isEqualType [])) then { _history = []; };

private _seq = ["airbase_v1_clearanceSeq", 0] call ARC_fnc_stateGet;
if (!(_seq isEqualType 0)) then { _seq = 0; };
_seq = _seq + 1;

private _requestId = format ["CLR-%1", _seq];
private _nowTs = serverTime;
private _callerUid = getPlayerUID _caller;
private _callerName = name _caller;
private _aircraftNetId = netId _aircraft;
if (!(_aircraftNetId isEqualType "")) then { _aircraftNetId = ""; };

private _record = [
    _requestId,
    _requestType,
    _callerUid,
    _callerName,
    _aircraftNetId,
    _priority,
    "PENDING",
    _nowTs,
    _nowTs,
    ["", "", -1, "", ""],
    [
        ["callerOwner", _callerOwner],
        ["aircraftType", typeOf _aircraft],
        ["submittedAt", _nowTs]
    ]
];

_requests pushBack _record;
_history pushBack _record;

private _historyMax = missionNamespace getVariable ["airbase_v1_clearanceHistoryMax", 100];
if (!(_historyMax isEqualType 0) || { _historyMax < 10 }) then { _historyMax = 100; };
if ((count _history) > _historyMax) then {
    _history deleteRange [0, (count _history) - _historyMax];
};

["airbase_v1_clearanceSeq", _seq] call ARC_fnc_stateSet;
["airbase_v1_clearanceRequests", _requests] call ARC_fnc_stateSet;
["airbase_v1_clearanceHistory", _history] call ARC_fnc_stateSet;

["OPS", format ["AIRBASE CLEARANCE: %1 submitted by %2", _requestId, _callerName], getPosATL _caller, [
    ["event", "AIRBASE_CLEARANCE_SUBMITTED"],
    ["requestId", _requestId],
    ["requestType", _requestType],
    ["caller", _callerName],
    ["uid", _callerUid],
    ["aircraftNetId", _aircraftNetId],
    ["priority", _priority]
]] call ARC_fnc_intelLog;

true

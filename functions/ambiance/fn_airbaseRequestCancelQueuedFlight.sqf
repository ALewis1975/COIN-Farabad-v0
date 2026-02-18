/*
    Server RPC: cancel a queued flight ID.
    Params: [OBJECT caller, STRING flightId]
*/

if (!isServer) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\\core\\fn_rpcValidateSender.sqf"; };
if (isNil "ARC_fnc_airbaseTowerAuthorize") then { ARC_fnc_airbaseTowerAuthorize = compile preprocessFileLineNumbers "functions\\core\\fn_airbaseTowerAuthorize.sqf"; };

params [
    ["_caller", objNull, [objNull]],
    ["_flightId", "", [""]]
];

if (!([_caller, "ARC_fnc_airbaseRequestCancelQueuedFlight", "Airbase cancel request rejected: sender verification failed.", "AIRBASE_CANCEL_SECURITY_DENIED"] call ARC_fnc_rpcValidateSender)) exitWith {false};

private _auth = [_caller, "CANCEL"] call ARC_fnc_airbaseTowerAuthorize;
_auth params ["_ok", "_level", "_reason"];
if (!_ok) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { ["Airbase cancel request denied: tower authorization required."] remoteExec ["ARC_fnc_clientHint", _owner]; };

    ["OPS", format ["AIRBASE CONTROL DENIED: CANCEL by %1 (%2)", name _caller, _reason], getPosATL _caller, 0, [
        ["event", "AIRBASE_CANCEL_AUTH_DENIED"],
        ["caller", name _caller],
        ["uid", getPlayerUID _caller],
        ["level", _level],
        ["reason", _reason],
        ["flightId", _flightId]
    ]] call ARC_fnc_intelLog;
    false
};

if (!(_flightId isEqualType "")) then { _flightId = ""; };
_flightId = trim _flightId;
if (_flightId isEqualTo "") exitWith {false};

private _queue = ["airbase_v1_queue", []] call ARC_fnc_stateGet;
if (!(_queue isEqualType [])) then { _queue = []; };

private _idx = _queue findIf { ((_x param [0, ""]) isEqualTo _flightId) };
if (_idx < 0) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { [format ["Flight %1 is not currently queued.", _flightId]] remoteExec ["ARC_fnc_clientHint", _owner]; };
    false
};

private _removed = [_queue, _flightId] call ARC_fnc_airbaseQueueRemoveByFid;
_queue = _removed param [0, []];

private _recs = ["airbase_v1_records", []] call ARC_fnc_stateGet;
if (!(_recs isEqualType [])) then { _recs = []; };
private _updated = [_recs, _flightId, "CANCELED", [["cancelledBy", name _caller], ["cancelledByUid", getPlayerUID _caller]]] call ARC_fnc_airbaseRecordSetQueuedStatus;
_recs = _updated param [0, []];

["airbase_v1_queue", _queue] call ARC_fnc_stateSet;
["airbase_v1_records", _recs] call ARC_fnc_stateSet;

private _manualPriority = ["airbase_v1_manualPriority", []] call ARC_fnc_stateGet;
if (!(_manualPriority isEqualType [])) then { _manualPriority = []; };
_manualPriority = _manualPriority select { _x isEqualType "" && { _x isNotEqualTo _flightId } };
["airbase_v1_manualPriority", _manualPriority] call ARC_fnc_stateSet;

["OPS", format ["AIRBASE CONTROL: cancelled flight %1 by %2", _flightId, name _caller], getPosATL _caller, 0, [
    ["event", "AIRBASE_QUEUE_CANCEL"],
    ["caller", name _caller],
    ["uid", getPlayerUID _caller],
    ["authLevel", _level],
    ["flightId", _flightId],
    ["queueLen", count _queue]
]] call ARC_fnc_intelLog;

true

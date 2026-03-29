/*
    Server RPC: claim/release ATC lane staffing ownership.
    Params: [OBJECT caller, STRING laneId, BOOL claim]
*/

if (!isServer) exitWith {false};
if !(["airbaseRequestSetLaneStaffing"] call ARC_fnc_airbaseRuntimeEnabled) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\\core\\fn_rpcValidateSender.sqf"; };
if (isNil "ARC_fnc_airbaseTowerAuthorize") then { ARC_fnc_airbaseTowerAuthorize = compile preprocessFileLineNumbers "functions\\core\\fn_airbaseTowerAuthorize.sqf"; };

params [
    ["_caller", objNull, [objNull]],
    ["_laneId", "", [""]],
    ["_claim", true, [true]]
];

if (!([_caller, "ARC_fnc_airbaseRequestSetLaneStaffing", "Airbase lane staffing request rejected: sender verification failed.", "AIRBASE_STAFFING_SECURITY_DENIED"] call ARC_fnc_rpcValidateSender)) exitWith {false};

private _auth = [_caller, "STAFF"] call ARC_fnc_airbaseTowerAuthorize;
_auth params ["_ok", "_level", "_reason"];
if (!_ok) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { ["Airbase staffing request denied: tower authorization required."] remoteExec ["ARC_fnc_clientHint", _owner]; };

    ["OPS", format ["AIRBASE STAFFING DENIED: %1 by %2 (%3)", if (_claim) then {"CLAIM"} else {"RELEASE"}, name _caller, _reason], getPosATL _caller, 0, [
        ["event", "AIRBASE_STAFFING_AUTH_DENIED"],
        ["caller", name _caller],
        ["uid", getPlayerUID _caller],
        ["level", _level],
        ["reason", _reason],
        ["lane", _laneId],
        ["claim", _claim]
    ]] call ARC_fnc_intelLog;
    false
};

if (!(_laneId isEqualType "")) then { _laneId = ""; };
_laneId = toLower (trim _laneId);
if !(_laneId in ["tower", "ground", "arrival"]) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { [format ["Invalid lane '%1'.", _laneId]] remoteExec ["ARC_fnc_clientHint", _owner]; };
    false
};

if (!(_claim isEqualType true) && !(_claim isEqualType false)) then { _claim = true; };

private _staffing = ["airbase_v1_towerStaffing", []] call ARC_fnc_stateGet;
if (!(_staffing isEqualType [])) then { _staffing = []; };

private _findLane = {
    params ["_rows", "_lane"];
    private _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 5 } && { ((_x param [0, ""]) isEqualTo _lane) }) exitWith { _idx = _forEachIndex; }; } forEach _rows;
    _idx
};

private _idx = [_staffing, _laneId] call _findLane;
if (_idx < 0) then {
    _staffing pushBack [_laneId, "AUTO", "", "", -1];
    _idx = [_staffing, _laneId] call _findLane;
};

if (_idx < 0) exitWith {false};

private _rec = _staffing # _idx;
private _now = serverTime;
private _name = name _caller;
private _uid = getPlayerUID _caller;
private _event = "";

private _queue = ["airbase_v1_clearanceRequests", []] call ARC_fnc_stateGet;
if (!(_queue isEqualType [])) then { _queue = []; };
private _laneReqTypes = switch (_laneId) do {
    case "arrival": { ["REQ_INBOUND", "REQ_LAND", "REQ_EMERGENCY"] };
    case "ground": { ["REQ_TAXI"] };
    default { ["REQ_TAKEOFF"] };
};
private _lanePending = count (_queue select {
    private _rtype = toUpper (_x param [1, ""]);
    private _st = toUpper (_x param [6, ""]);
    (_rtype in _laneReqTypes) && { _st in ["QUEUED", "PENDING", "AWAITING_TOWER_DECISION"] }
});

if (_claim) then {    _rec set [1, "MANNED"];
    _rec set [2, _name];
    _rec set [3, _uid];
    _rec set [4, _now];
    _event = "AIRBASE_STAFFING_CLAIM";
} else {
    _rec set [1, "AUTO"];
    _rec set [2, ""];
    _rec set [3, ""];
    _rec set [4, _now];
    _event = "AIRBASE_STAFFING_RELEASE";
};

_staffing set [_idx, _rec];
["airbase_v1_towerStaffing", _staffing] call ARC_fnc_stateSet;

private _owner = owner _caller;
if (_owner > 0) then {
    [format ["%1 lane %2 set to %3 (pending handoff queue: %4).", toUpper _laneId, if (_claim) then {"staffing"} else {"AUTO"}, if (_claim) then {_name} else {"AUTO"}, _lanePending]] remoteExec ["ARC_fnc_clientHint", _owner];
};

["OPS", format ["AIRBASE STAFFING: %1 lane %2 by %3", if (_claim) then {"claimed"} else {"released"}, toUpper _laneId, _name], getPosATL _caller, 0, [
    ["event", _event],
    ["caller", _name],
    ["uid", _uid],
    ["authLevel", _level],
    ["lane", _laneId],
    ["claim", _claim],
    ["status", _rec param [1, "AUTO"]],
    ["operator", _rec param [2, ""]],
    ["operatorUid", _rec param [3, ""]],
    ["pendingQueueHandoff", _lanePending]
]] call ARC_fnc_intelLog;

true

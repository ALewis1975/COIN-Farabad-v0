/*
    File: functions/ambiance/fn_airbaseAdminResetControlState.sqf
    Author: ARC / Ambient Airbase Subsystem
    Description:
      Server-side AIRSUB control reset used by admin tooling.
      Clears runway lock ownership and pending control requests while optionally preserving history.

    Params:
      0: BOOL preserveHistory (default: true)
      1: OBJECT actor (optional; for ops log context)
*/

if (!isServer) exitWith {false};
private _runtimeEnabled = ["airbaseAdminResetControlState"] call ARC_fnc_airbaseRuntimeEnabled;

params [
    ["_preserveHistory", true, [true]],
    ["_actor", objNull, [objNull]]
];

if (!(_preserveHistory isEqualType true) && !(_preserveHistory isEqualType false)) then { _preserveHistory = true; };

private _requests = ["airbase_v1_clearanceRequests", []] call ARC_fnc_stateGet;
if (!(_requests isEqualType [])) then { _requests = []; };
private _pendingBefore = count (_requests select {
    _x isEqualType [] && { (count _x) > 6 } && { (_x select 6) in ["QUEUED", "PENDING", "AWAITING_TOWER_DECISION"] }
});

private _queue = ["airbase_v1_queue", []] call ARC_fnc_stateGet;
if (!(_queue isEqualType [])) then { _queue = []; };
private _queueBefore = count _queue;

private _manualPriority = ["airbase_v1_manualPriority", []] call ARC_fnc_stateGet;
if (!(_manualPriority isEqualType [])) then { _manualPriority = []; };
private _priorityBefore = count _manualPriority;

private _history = ["airbase_v1_clearanceHistory", []] call ARC_fnc_stateGet;
if (!(_history isEqualType [])) then { _history = []; };
private _historyBefore = count _history;

["airbase_v1_clearanceRequests", []] call ARC_fnc_stateSet;
["airbase_v1_queue", []] call ARC_fnc_stateSet;
["airbase_v1_manualPriority", []] call ARC_fnc_stateSet;
["airbase_v1_holdDepartures", false] call ARC_fnc_stateSet;
["airbase_v1_towerStaffing", [
    ["tower", "AUTO", "", "", -1],
    ["ground", "AUTO", "", "", -1],
    ["arrival", "AUTO", "", "", -1]
]] call ARC_fnc_stateSet;

// Reset runtime scheduling state so the tick triggers a forced re-seed:
//   - firstDepartureDone = false: re-enables the forced-first-departure path
//   - lastDepartTs / lastArriveTs = -1e9: departure and arrival cooldowns are
//     immediately satisfied, so the next probability roll that succeeds will
//     schedule a flight without any extra wait.
private _rt = missionNamespace getVariable ["airbase_v1_rt", createHashMap];
if (_rt isEqualType createHashMap) then {
    _rt set ["firstDepartureDone", false];
    _rt set ["lastDepartTs", -1e9];
    _rt set ["lastArriveTs", -1e9];
    missionNamespace setVariable ["airbase_v1_rt", _rt, true];
};

if (!_preserveHistory) then {
    ["airbase_v1_clearanceHistory", []] call ARC_fnc_stateSet;
    ["airbase_v1_events", []] call ARC_fnc_stateSet;
};

missionNamespace setVariable ["airbase_v1_notifyState", createHashMap, false];
missionNamespace setVariable ["airbase_v1_runwayState", "OPEN", true];
missionNamespace setVariable ["airbase_v1_runwayOwner", "", true];
missionNamespace setVariable ["airbase_v1_runwayUntil", -1, true];

private _ops = missionNamespace getVariable ["airbase_v1_opsLogEnabled", true];
if (!(_ops isEqualType true) && !(_ops isEqualType false)) then { _ops = true; };
private _dbgOps = missionNamespace getVariable ["airbase_v1_debugOpsLog", false];

if (_ops || _dbgOps) then {
    private _rt = missionNamespace getVariable ["airbase_v1_rt", createHashMap];
    private _center = _rt get "bubbleCenter";
    if (isNil "_center") then { _center = getMarkerPos "mkr_airbaseCenter"; };

    private _actorName = if (isNull _actor) then { "<server>" } else { name _actor };
    private _actorUid = if (isNull _actor) then { "" } else { getPlayerUID _actor };

    ["OPS", format ["AIRBASE CONTROL RESET: runway/queue/clearances reset by %1", _actorName], _center, 0, [
        ["event", "AIRBASE_CONTROL_RESET"],
        ["actor", _actorName],
        ["actorUid", _actorUid],
        ["runtimeEnabled", _runtimeEnabled],
        ["preserveHistory", _preserveHistory],
        ["pendingRequestsCleared", _pendingBefore],
        ["queueCleared", _queueBefore],
        ["manualPriorityCleared", _priorityBefore],
        ["historyBefore", _historyBefore]
    ]] call ARC_fnc_intelLog;
};

true

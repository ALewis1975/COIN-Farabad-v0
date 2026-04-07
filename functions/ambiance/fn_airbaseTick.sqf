/*
    File: functions/ambiance/fn_airbaseTick.sqf
    Author: ARC / Ambient Airbase Subsystem
    Description:
      Main tick loop. Schedules departures/arrivals, processes queue, handles player bubble simulation gating,
      and queues "return arrivals" for departed aircraft once their turnaround timer expires.
*/

if (!isServer) exitWith {};

if (!(["airbaseTick"] call ARC_fnc_airbaseRuntimeEnabled)) exitWith {false};

private _rt = missionNamespace getVariable ["airbase_v1_rt", createHashMap];

// sqflint-compat: compiled string hides `get` from the parser (see SQFLINT_COMPAT_GUIDE §3)
private _fnHmGet = compile "params ['_hm','_key','_fallback']; if (!(_hm isEqualType createHashMap)) exitWith {_fallback}; private _value = _hm get _key; if (isNil '_value') exitWith {_fallback}; _value";
if (!(_fnHmGet isEqualType {})) exitWith {};

if (!([_rt, "initialized", false] call _fnHmGet)) exitWith {};

// Fail-safe runway cleanup in case previous movement aborted or lock metadata went stale.
["tick", false] call ARC_fnc_airbaseRunwayLockSweep;

private _nowTs = serverTime;
// Phase 5: publish last tick time for snapshot freshness computation.
missionNamespace setVariable ["airbase_v1_lastTickAt", _nowTs, true];
private _tickS = missionNamespace getVariable ["airbase_v1_tick_s", 2];

private _center = [_rt, "bubbleCenter", getMarkerPos "mkr_airbaseCenter"] call _fnHmGet;
private _radius = [_rt, "bubbleRadius", 2500] call _fnHmGet;

// Player bubble check
private _bubbleActive = false;
{
    if (isPlayer _x && { alive _x } && { (_x distance2D _center) < _radius }) exitWith { _bubbleActive = true; };
} forEach allPlayers;

private _wasActive = [_rt, "bubbleActive", false] call _fnHmGet;
_rt set ["bubbleActive", _bubbleActive];
missionNamespace setVariable ["airbase_v1_bubble_active", _bubbleActive, true];

// Toggle simulation for parked assets when bubble changes
if (!(_bubbleActive isEqualTo _wasActive)) then {
    private _assetsT = [_rt, "assets", []] call _fnHmGet;
    {
        private _state = [_x, "state", "PARKED"] call _fnHmGet;
        if (_state == "PARKED") then {
            private _veh = [_x, "veh", objNull] call _fnHmGet;
            if (!isNull _veh) then { _veh enableSimulationGlobal _bubbleActive; };
        };
    } forEach _assetsT;

    // NOTE: We no longer clear the exec lock on bubble deactivation.
    // If a departure is in progress while players leave the bubble, clearing the
    // lock can cause concurrent departures. If we ever need a watchdog, add a
    // time-based safety release instead.

    // OPS observability: bubble toggles are important to understand why the airbase is "frozen".
    private _ops = missionNamespace getVariable ["airbase_v1_opsLogEnabled", true];
    if (!(_ops isEqualType true) && !(_ops isEqualType false)) then { _ops = true; };
    private _dbgOps = missionNamespace getVariable ["airbase_v1_debugOpsLog", false];
    if ((_ops || _dbgOps)) then {
        ["OPS", format ["AIRBASE: bubble %1", if (_bubbleActive) then {"ACTIVE"} else {"INACTIVE"}], _center, 0, [
            ["radius_m", _radius]
        ]] call ARC_fnc_intelLog;
    };
};

// If bubble is inactive, freeze parked assets.
// IMPORTANT: we still keep scheduling/execution running so airbase operations continue
// even when no players are nearby (Ops Log remains active).
if (!_bubbleActive) then {
    private _assetsF = [_rt, "assets", []] call _fnHmGet;
    {
        private _state = [_x, "state", "PARKED"] call _fnHmGet;
        if (_state == "PARKED") then {
            private _veh = [_x, "veh", objNull] call _fnHmGet;
            if (!isNull _veh) then { _veh enableSimulationGlobal false; };
        };
    } forEach _assetsF;

    missionNamespace setVariable ["airbase_v1_rt", _rt, true];
};

// Load state store
private _queue = ["airbase_v1_queue", []] call ARC_fnc_stateGet;
private _recs  = ["airbase_v1_records", []] call ARC_fnc_stateGet;
private _seq   = ["airbase_v1_seq", 0] call ARC_fnc_stateGet;
private _holdDepartures = ["airbase_v1_holdDepartures", false] call ARC_fnc_stateGet;
if (!(_holdDepartures isEqualType true) && !(_holdDepartures isEqualType false)) then { _holdDepartures = false; };

private _fn_nextId = {
    _seq = _seq + 1;
    ["airbase_v1_seq", _seq] call ARC_fnc_stateSet;

    // Local pad routine (keeps this subsystem independent of optional helper functions)
    private _s = str _seq;
    while { (count _s) < 4 } do { _s = "0" + _s; };
    format ["FLT-%1", _s];
};


private _debugOps = missionNamespace getVariable ["airbase_v1_debugOpsLog", false];

private _opsLogEnabled = missionNamespace getVariable ["airbase_v1_opsLogEnabled", true];
if (!(_opsLogEnabled isEqualType true) && !(_opsLogEnabled isEqualType false)) then { _opsLogEnabled = true; };

private _opsStatusInterval = missionNamespace getVariable ["airbase_v1_opsStatusInterval_s", 120];
if (!(_opsStatusInterval isEqualType 0) || { _opsStatusInterval < 30 }) then { _opsStatusInterval = 120; };

private _controllerTimeoutS = missionNamespace getVariable ["airbase_v1_controller_timeout_s", 90];
if (!(_controllerTimeoutS isEqualType 0) || { _controllerTimeoutS < 5 }) then { _controllerTimeoutS = 90; };

private _controllerTimeoutTowerS = missionNamespace getVariable ["airbase_v1_controller_timeout_tower_s", _controllerTimeoutS];
if (!(_controllerTimeoutTowerS isEqualType 0) || { _controllerTimeoutTowerS < 5 }) then { _controllerTimeoutTowerS = _controllerTimeoutS; };
private _controllerTimeoutGroundS = missionNamespace getVariable ["airbase_v1_controller_timeout_ground_s", _controllerTimeoutS];
if (!(_controllerTimeoutGroundS isEqualType 0) || { _controllerTimeoutGroundS < 5 }) then { _controllerTimeoutGroundS = _controllerTimeoutS; };
private _controllerTimeoutArrivalS = missionNamespace getVariable ["airbase_v1_controller_timeout_arrival_s", _controllerTimeoutS];
if (!(_controllerTimeoutArrivalS isEqualType 0) || { _controllerTimeoutArrivalS < 5 }) then { _controllerTimeoutArrivalS = _controllerTimeoutS; };

private _autoDelayTowerS = missionNamespace getVariable ["airbase_v1_automation_delay_tower_s", 8];
if (!(_autoDelayTowerS isEqualType 0) || { _autoDelayTowerS < 1 }) then { _autoDelayTowerS = 8; };
private _autoDelayGroundS = missionNamespace getVariable ["airbase_v1_automation_delay_ground_s", 10];
if (!(_autoDelayGroundS isEqualType 0) || { _autoDelayGroundS < 1 }) then { _autoDelayGroundS = 10; };
private _autoDelayArrivalS = missionNamespace getVariable ["airbase_v1_automation_delay_arrival_s", 6];
if (!(_autoDelayArrivalS isEqualType 0) || { _autoDelayArrivalS < 1 }) then { _autoDelayArrivalS = 6; };

private _controllerFallbackEnabled = missionNamespace getVariable ["airbase_v1_controller_fallback_enabled", true];
if (!(_controllerFallbackEnabled isEqualType true) && !(_controllerFallbackEnabled isEqualType false)) then { _controllerFallbackEnabled = true; };

private _forceAiOnly = missionNamespace getVariable ["airbase_v1_debug_forceAiOnly", false];
if (!(_forceAiOnly isEqualType true) && !(_forceAiOnly isEqualType false)) then { _forceAiOnly = false; };

private _clearanceRequests = ["airbase_v1_clearanceRequests", []] call ARC_fnc_stateGet;
if (!(_clearanceRequests isEqualType [])) then { _clearanceRequests = []; };

private _clearanceHistory = ["airbase_v1_clearanceHistory", []] call ARC_fnc_stateGet;
if (!(_clearanceHistory isEqualType [])) then { _clearanceHistory = []; };

private _events = ["airbase_v1_events", []] call ARC_fnc_stateGet;
if (!(_events isEqualType [])) then { _events = []; };
private _eventsMax = missionNamespace getVariable ["airbase_v1_eventsMax", 60];
if (!(_eventsMax isEqualType 0) || { _eventsMax < 10 }) then { _eventsMax = 60; };
private _eventsDirty = false;

private _notifyThrottleS = missionNamespace getVariable ["airbase_v1_notifyThrottle_s", 8];
if (!(_notifyThrottleS isEqualType 0) || { _notifyThrottleS < 1 }) then { _notifyThrottleS = 8; };
private _notifyState = missionNamespace getVariable ["airbase_v1_notifyState", createHashMap];
if !(_notifyState isEqualType createHashMap) then { _notifyState = createHashMap; };
private _notifyDirty = false;

private _metaGet = {
    params ["_rows", "_k", "_def"];
    private _v = _def;
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { ((_x select 0)) isEqualTo _k }) exitWith { _v = _x select 1; };
    } forEach _rows;
    _v
};

private _metaSet = {
    params ["_rows", "_k", "_v"];
    private _idx = -1;
    { if (_x isEqualType [] && { (count _x) >= 2 } && { ((_x select 0)) isEqualTo _k }) exitWith { _idx = _forEachIndex; }; } forEach _rows;
    if (_idx < 0) then { _rows pushBack [_k, _v]; } else { _rows set [_idx, [_k, _v]]; };
    _rows
};

private _fnEventPush = {
    params ["_kind", "_rid", "_actorUid", "_targetUid", ["_meta", []]];
    _events pushBack [_nowTs, _kind, _rid, _actorUid, _targetUid, _meta];
    if ((count _events) > _eventsMax) then {
        _events deleteRange [0, (count _events) - _eventsMax];
    };
    _eventsDirty = true;
};

private _fnNotifyMaybe = {
    params ["_owner", "_method", "_title", "_body", "_dedupeKey"];
    if (_owner <= 0) exitWith {};
    if (!(_dedupeKey isEqualType "")) then { _dedupeKey = str _dedupeKey; };
    private _lastAt = [_notifyState, _dedupeKey, -1000] call _fnHmGet;
    if ((_nowTs - _lastAt) < _notifyThrottleS) exitWith {};
    _notifyState set [_dedupeKey, _nowTs];
    _notifyDirty = true;

    if (_method isEqualTo "HINT") then {
        [_body] remoteExec ["ARC_fnc_clientHint", _owner];
    } else {
        [_title, _body, 5] remoteExec ["ARC_fnc_clientToast", _owner];
    };
};

// UID → owner cache: built once per tick, replaces 4 inline allPlayers scans
private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";
private _uidOwnerPairs = [];
{ _uidOwnerPairs pushBack [getPlayerUID _x, owner _x]; } forEach allPlayers;
private _uidOwnerCache = [_uidOwnerPairs] call _hmCreate;
private _hgOwner = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _towerControllers = [];
if (!_forceAiOnly) then {
    {
        if !(isPlayer _x) then { continue; };
        if !(alive _x) then { continue; };

        private _authApprove = [_x, "APPROVE"] call ARC_fnc_airbaseTowerAuthorize;
        private _okApprove = _authApprove param [0, false];
        private _level = _authApprove param [1, ""];

        if (!_okApprove) then {
            private _authFallback = [_x, "PRIORITIZE"] call ARC_fnc_airbaseTowerAuthorize;
            private _okFallback = _authFallback param [0, false];
            if (_okFallback) then { _level = _authFallback param [1, ""]; };
            if (_okFallback && (_level isEqualTo "")) then { _level = "LC"; };
            if (!_okFallback) then { continue; };
        };

        _towerControllers pushBack [name _x, getPlayerUID _x, _level];
    } forEach allPlayers;
};

private _towerStaffing = ["airbase_v1_towerStaffing", []] call ARC_fnc_stateGet;
if (!(_towerStaffing isEqualType [])) then { _towerStaffing = []; };

private _staffLaneRec = {
    params ["_rows", "_lane"];
    private _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 5 } && { ((_x param [0, ""]) isEqualTo _lane) }) exitWith { _idx = _forEachIndex; }; } forEach _rows;
    if (_idx < 0) exitWith { [_lane, "AUTO", "", "", -1] };
    _rows select _idx
};

private _laneControllerCount = {
    params ["_lane"];
    private _rec = [_towerStaffing, _lane] call _staffLaneRec;
    private _status = toUpper (_rec param [1, "AUTO"]);
    if (_status isEqualTo "MANNED") then { 1 } else { 0 }
};

private _laneForRequest = {
    params ["_reqType"];
    private _rt = toUpper _reqType;
    if (_rt in ["REQ_INBOUND", "REQ_LAND", "REQ_EMERGENCY"]) exitWith { "arrival" };
    if (_rt isEqualTo "REQ_TAXI") exitWith { "ground" };
    "tower"
};

private _laneTimeoutFor = {
    params ["_lane"];
    switch (toLower _lane) do {
        case "arrival": { _controllerTimeoutArrivalS };
        case "ground": { _controllerTimeoutGroundS };
        default { _controllerTimeoutTowerS };
    }
};

private _laneAutoDelayFor = {
    params ["_lane"];
    switch (toLower _lane) do {
        case "arrival": { _autoDelayArrivalS };
        case "ground": { _autoDelayGroundS };
        default { _autoDelayTowerS };
    }
};

private _clearanceStateDirty = false;

for "_iClr" from 0 to ((count _clearanceRequests) - 1) do {
    private _rec = _clearanceRequests select _iClr;
    if !(_rec isEqualType []) then { continue; };

    private _status = toUpper (_rec param [6, ""]);
    if (_status in ["APPROVED", "DENIED", "CANCELED", "COMPLETE"]) then { continue; };

    private _createdAt = _rec param [7, _nowTs];
    if (!(_createdAt isEqualType 0)) then { _createdAt = _nowTs; };

    private _ageS = _nowTs - _createdAt;

    private _meta = _rec param [10, []];
    if (!(_meta isEqualType [])) then { _meta = []; };

    private _warnGateAdv = missionNamespace getVariable ["airbase_v1_arrival_warn_advisory_m", 7000];
    private _warnGateCau = missionNamespace getVariable ["airbase_v1_arrival_warn_caution_m", 4500];
    private _warnGateUrg = missionNamespace getVariable ["airbase_v1_arrival_warn_urgent_m", 2600];
    private _landGateM = missionNamespace getVariable ["airbase_v1_arrival_land_gate_m", 2200];
    private _staleEscalateS = missionNamespace getVariable ["airbase_v1_inbound_stale_escalate_s", 45];

    private _distM = -1;
    private _rtypeNow = toUpper (_rec param [1, ""]);
    if (_rtypeNow in ["REQ_INBOUND", "REQ_LAND"]) then {
        private _airNid = _rec param [4, ""];
        private _veh = objectFromNetId _airNid;
        if (!isNull _veh) then {
            private _runwayMarker = missionNamespace getVariable ["airbase_v1_arrival_runway_marker", "AEON_Right_270_Outbound"];
            private _runwayPos = getMarkerPos _runwayMarker;
            if ((_runwayPos select 0) != 0 || {(_runwayPos select 1) != 0}) then {
                _distM = _veh distance2D _runwayPos;
            };
        };

        private _warnLevel = "NONE";
        if (_distM >= 0) then {
            if (_distM <= _warnGateUrg) then { _warnLevel = "URGENT"; } else {
                if (_distM <= _warnGateCau) then { _warnLevel = "CAUTION"; } else {
                    if (_distM <= _warnGateAdv) then { _warnLevel = "ADVISORY"; };
                };
            };
        };

        _meta = [_meta, "arrivalDistanceM", _distM] call _metaSet;
        _meta = [_meta, "arrivalWarnLevel", _warnLevel] call _metaSet;
        _meta = [_meta, "arrivalWarnAdvisoryM", _warnGateAdv] call _metaSet;
        _meta = [_meta, "arrivalWarnCautionM", _warnGateCau] call _metaSet;
        _meta = [_meta, "arrivalWarnUrgentM", _warnGateUrg] call _metaSet;

        if (_rtypeNow isEqualTo "REQ_INBOUND" && { _distM >= 0 } && { _distM <= _landGateM }) then {
            _rec set [1, "REQ_LAND"];
            _meta = [_meta, "lifecycle_land_gate_at", _nowTs] call _metaSet;
            _meta = [_meta, "lifecycle_auto_land", true] call _metaSet;
            _clearanceStateDirty = true;
            ["LIFECYCLE_LAND_GATE", _rec param [0, ""], "SYSTEM", _rec param [2, ""], [_distM, _landGateM]] call _fnEventPush;
        };

        if (_rtypeNow isEqualTo "REQ_INBOUND" && { _status in ["QUEUED", "PENDING", "AWAITING_TOWER_DECISION"] } && { _distM >= 0 } && { _distM <= _warnGateUrg } && { _ageS >= _staleEscalateS }) then {
            _rec set [6, "AWAITING_TOWER_DECISION"];
            _rec set [8, _nowTs];
            _rec set [9, ["SYSTEM", "SYSTEM", _nowTs, "ESCALATE", "STALE_INBOUND_NEAR_RUNWAY"]];
            _meta = [_meta, "staleInboundEscalated", true] call _metaSet;
            _meta = [_meta, "staleInboundEscalatedAt", _nowTs] call _metaSet;
            _meta = [_meta, "staleInboundEscalateAfterS", _staleEscalateS] call _metaSet;
            _clearanceStateDirty = true;
            ["ESCALATE", _rec param [0, ""], "SYSTEM", _rec param [2, ""], ["STALE_INBOUND_NEAR_RUNWAY", _distM, _ageS]] call _fnEventPush;
        };
    };

    _rec set [10, _meta];
    _clearanceRequests set [_iClr, _rec];

    private _laneId = [_rec param [1, ""]] call _laneForRequest;
    _meta = [_meta, "decisionLane", _laneId] call _metaSet;

    private _laneControllers = [_laneId] call _laneControllerCount;
    private _laneTimeoutS = [_laneId] call _laneTimeoutFor;
    private _laneAutoDelayS = [_laneId] call _laneAutoDelayFor;

    private _isAwaiting = _status isEqualTo "AWAITING_TOWER_DECISION";
    private _autoDecisionAtExisting = [_meta, "automationDecisionAt", -1] call _metaGet;
    if (!(_autoDecisionAtExisting isEqualType 0)) then { _autoDecisionAtExisting = -1; };
    private _autoInProgress = (_autoDecisionAtExisting >= 0) && { _nowTs < _autoDecisionAtExisting };

    if (_laneControllers > 0) then {
        if (_autoInProgress) then {
            _meta = [_meta, "automationStatus", format ["AUTO decision in progress (%1 lane). ETA %2s", toUpper _laneId, (_autoDecisionAtExisting - _nowTs) max 0]] call _metaSet;
            _meta = [_meta, "automationEtaS", (_autoDecisionAtExisting - _nowTs) max 0] call _metaSet;
            _meta = [_meta, "automationSource", "AUTO_IN_PROGRESS_LOCKED"] call _metaSet;
            _rec set [10, _meta];
            _clearanceRequests set [_iClr, _rec];
            continue;
        };

        if (_status in ["QUEUED", "PENDING"]) then {
            _rec set [6, "AWAITING_TOWER_DECISION"];
            _rec set [8, _nowTs];
            _rec set [9, ["", "", -1, "", "AWAITING_TOWER"]];
            _meta = [_meta, "awaitingTowerDecision", true] call _metaSet;
            _meta = [_meta, "towerControllersPresent", _laneControllers] call _metaSet;
            _meta = [_meta, "automationStatus", format ["Awaiting %1 controller decision", toUpper _laneId]] call _metaSet;
            _meta = [_meta, "automationEtaS", -1] call _metaSet;
            _meta = [_meta, "automationDecisionAt", -1] call _metaSet;
            _meta = [_meta, "automationSource", "MANNED_LANE"] call _metaSet;

            _rec set [10, _meta];
            _clearanceRequests set [_iClr, _rec];
            _clearanceStateDirty = true;

            private _ridAwait = _rec param [0, ""];
            private _requesterUidAwait = _rec param [2, ""];
            ["LOCK_ACQUIRE", _ridAwait, "SYSTEM", _requesterUidAwait, [_laneId, _laneControllers]] call _fnEventPush;

            private _requesterOwnerAwait = [_uidOwnerCache, _requesterUidAwait, -1] call _hgOwner;
            [_requesterOwnerAwait, "TOAST", "Airbase Clearance", format ["Request queued: %1 awaiting %2 controller", _ridAwait, toUpper _laneId], format ["AIR_REQ_AWAIT:%1", _ridAwait]] call _fnNotifyMaybe;
            {
                private _towUid = _x param [1, ""];
                private _towOwner = [_uidOwnerCache, _towUid, -1] call _hgOwner;
                [_towOwner, "TOAST", "Airbase Tower", format ["Decision required (%1): %2", toUpper _laneId, _ridAwait], format ["AIR_CTRL_PENDING:%1:%2", _ridAwait, _towUid]] call _fnNotifyMaybe;
            } forEach _towerControllers;

            if (_opsLogEnabled || _debugOps) then {
                ["OPS", format ["AIRBASE CLEARANCE: %1 moved to awaiting %2 controller", _rec param [0, ""], _laneId], _center, 0, [
                    ["event", "AIRBASE_CLEARANCE_AWAITING_TOWER"],
                    ["requestId", _rec param [0, ""]],
                    ["lane", _laneId],
                    ["controllers", _laneControllers]
                ]] call ARC_fnc_intelLog;
            };
        };

        continue;
    };

    if (!_controllerFallbackEnabled) then { continue; };

    if !(_status in ["QUEUED", "PENDING", "AWAITING_TOWER_DECISION"]) then { continue; };

    private _autoDecisionAt = [_meta, "automationDecisionAt", -1] call _metaGet;
    if (!(_autoDecisionAt isEqualType 0)) then { _autoDecisionAt = -1; };

    if (_autoDecisionAt < 0) then {
        private _autoDueAt = _createdAt + _laneTimeoutS + _laneAutoDelayS;
        _meta = [_meta, "automationTimeoutS", _laneTimeoutS] call _metaSet;
        _meta = [_meta, "automationDelayS", _laneAutoDelayS] call _metaSet;
        _meta = [_meta, "automationDecisionAt", _autoDueAt] call _metaSet;
        _meta = [_meta, "automationStatus", format ["AUTO queue active (%1 lane). ETA %2s", toUpper _laneId, _laneTimeoutS + _laneAutoDelayS]] call _metaSet;
        _meta = [_meta, "automationEtaS", (_autoDueAt - _nowTs) max 0] call _metaSet;
        _meta = [_meta, "automationSource", "UNMANNED_LANE"] call _metaSet;

        if (_isAwaiting) then {
            _rec set [6, "QUEUED"];
            _rec set [8, _nowTs];
            _rec set [9, ["SYSTEM", "SYSTEM", _nowTs, "AUTO_HANDOFF", "LANE_UNMANNED"]];
        };

        _rec set [10, _meta];
        _clearanceRequests set [_iClr, _rec];
        _clearanceStateDirty = true;

        private _ridAutoQueue = _rec param [0, ""];
        private _requesterUidAutoQueue = _rec param [2, ""];
        ["AUTO_QUEUE", _ridAutoQueue, "SYSTEM", _requesterUidAutoQueue, [_laneId, _autoDueAt]] call _fnEventPush;

        private _requesterOwnerAutoQueue = [_uidOwnerCache, _requesterUidAutoQueue, -1] call _hgOwner;
        [_requesterOwnerAutoQueue, "TOAST", "Airbase Clearance", format ["%1 in AUTO queue (%2). ETA %3s", _ridAutoQueue, toUpper _laneId, (_autoDueAt - _nowTs) max 0], format ["AIR_REQ_AUTOQ:%1", _ridAutoQueue]] call _fnNotifyMaybe;
        continue;
    };

    _meta = [_meta, "automationEtaS", (_autoDecisionAt - _nowTs) max 0] call _metaSet;
    _meta = [_meta, "automationStatus", format ["AUTO decision pending (%1 lane). ETA %2s", toUpper _laneId, (_autoDecisionAt - _nowTs) max 0]] call _metaSet;
    _rec set [10, _meta];
    _clearanceRequests set [_iClr, _rec];

    if (_nowTs < _autoDecisionAt) then { continue; };

    _rec set [6, "APPROVED"];
    _rec set [8, _nowTs];
    _rec set [9, ["AI", "AI", _nowTs, "APPROVE", "AUTO_DECIDED"]];

    _meta = [_meta, "decidedBy", "AI"] call _metaSet;
    _meta = [_meta, "reason", "auto_decided_unmanned_lane"] call _metaSet;
    _meta = [_meta, "timedOutAfterS", _ageS] call _metaSet;
    _meta = [_meta, "forceAiOnly", _forceAiOnly] call _metaSet;
    _meta = [_meta, "decisionMeta", "AUTO DECIDED"] call _metaSet;
    _meta = [_meta, "autoDecided", true] call _metaSet;
    _meta = [_meta, "autoDecidedLane", _laneId] call _metaSet;
    _meta = [_meta, "autoDecidedAt", _nowTs] call _metaSet;
    _meta = [_meta, "automationEtaS", 0] call _metaSet;
    _meta = [_meta, "automationStatus", format ["AUTO DECIDED by %1 lane automation", toUpper _laneId]] call _metaSet;
    _rec set [10, _meta];

    _clearanceRequests set [_iClr, _rec];
    _clearanceStateDirty = true;

    private _ridAi = _rec param [0, ""];
    private _requesterUidAi = _rec param [2, ""];
    ["APPROVE", _ridAi, "AI", _requesterUidAi, ["AUTO_DECIDED", _laneId]] call _fnEventPush;

    private _requesterOwnerAi = [_uidOwnerCache, _requesterUidAi, -1] call _hgOwner;
    [_requesterOwnerAi, "TOAST", "Airbase Clearance", format ["AUTO DECIDED: %1 approved by %2 lane automation", _ridAi, toUpper _laneId], format ["AIR_REQ_APPROVE_AI:%1", _ridAi]] call _fnNotifyMaybe;

    if (_opsLogEnabled || _debugOps) then {
        ["OPS", format ["AIRBASE CLEARANCE: %1 AUTO DECIDED by %2 lane automation", _rec param [0, ""], _laneId], _center, 0, [
            ["event", "AIRBASE_CLEARANCE_AI_TIMEOUT"],
            ["requestId", _rec param [0, ""]],
            ["lane", _laneId],
            ["timeout_s", _laneTimeoutS],
            ["automation_delay_s", _laneAutoDelayS],
            ["age_s", _ageS],
            ["forceAiOnly", _forceAiOnly]
        ]] call ARC_fnc_intelLog;
    };
};

if (_clearanceStateDirty) then {
    _clearanceRequests = [_clearanceRequests] call ARC_fnc_airbaseClearanceSortRequests;
    ["airbase_v1_clearanceRequests", _clearanceRequests] call ARC_fnc_stateSet;

    private _historyById = createHashMap;
    {
        if (_x isEqualType []) then {
            _historyById set [_x param [0, ""], _forEachIndex];
        };
    } forEach _clearanceHistory;

    {
        if !(_x isEqualType []) then { continue; };
        private _rid = _x param [0, ""];
        private _hIdx = [_historyById, _rid, -1] call _fnHmGet;
        if (_hIdx >= 0) then {
            _clearanceHistory set [_hIdx, _x];
        } else {
            _clearanceHistory pushBack _x;
        };
    } forEach _clearanceRequests;

    ["airbase_v1_clearanceHistory", _clearanceHistory] call ARC_fnc_stateSet;
};

if (_eventsDirty) then {
    ["airbase_v1_events", _events] call ARC_fnc_stateSet;
};
if (_notifyDirty) then {
    missionNamespace setVariable ["airbase_v1_notifyState", _notifyState, false];
};

// Return handling for departed assets:
//  - With low probability, queue a RETURN arrival (same tail comes back in on the runway).
//  - Otherwise, restock the parked aircraft off-screen (respawn at its startPos) so the ramp stays populated.
private _pReturn = missionNamespace getVariable ["airbase_v1_p_return", 0.15];
if (!(_pReturn isEqualType 0) || { _pReturn < 0 } || { _pReturn > 1 }) then { _pReturn = 0.15; };

private _assets = [_rt, "assets", []] call _fnHmGet;
{
    private _a = _x;
    private _state = [_a, "state", "PARKED"] call _fnHmGet;

    if (_state == "COOLDOWN") then {
        private _avail = [_a, "availableAt", 0] call _fnHmGet;

        if (_avail > 0 && { _nowTs >= _avail }) then {
            private _aid = [_a, "id", ""] call _fnHmGet;
            private _cat = [_a, "category", "FW"] call _fnHmGet;
            private _vehType = [_a, "startVehType", ""] call _fnHmGet;

            private _doReturn = ((random 1) < _pReturn);

            if (_doReturn) then {
                private _fidA = call _fn_nextId;

                private _recA = [
                    _fidA, _nowTs,
                    "ARR", _cat,
                    _aid,
                    "QUEUED",
                    _nowTs,
                    [
                        ["mode","RETURN"],
                        ["assetId", _aid],
                        ["vehType", _vehType]
                    ]
                ];
                _recs pushBack _recA;
                private _routeDecisionA = ["ARR", "AMBIENT", _fidA] call ARC_fnc_airbaseBuildRouteDecision;
                private _routeOkA = _routeDecisionA param [0, false];
                private _routeMetaA = _routeDecisionA param [1, []];
                private _routeReasonA = _routeDecisionA param [2, "ROUTE_DECISION_FAILED"];
                if (!_routeOkA) then {
                    if (_opsLogEnabled || _debugOps) then {
                        ["OPS", format ["AIRBASE ROUTE: blocked ambient arrival %1 (%2)", _fidA, _routeReasonA], _center, 0, [
                            ["flightId", _fidA],
                            ["reason", _routeReasonA]
                        ]] call ARC_fnc_intelLog;
                    };
                    _recs deleteAt ((count _recs) - 1);
                    continue;
                };
                _queue pushBack [_fidA, "ARR", _aid, _routeMetaA];

                _a set ["state", "RETURN_QUEUED"];
                _a set ["activeFlight", _fidA];
                _a set ["availableAt", 0];

                if (_opsLogEnabled || _debugOps) then {
                    ["OPS", format ["AIRBASE: queued RETURN arrival %1 for %2", _fidA, _aid], _center, 0, [
                        ["category", _cat],
                        ["vehType", _vehType],
                        ["pReturn", _pReturn]
                    ]] call ARC_fnc_intelLog;
                };
            } else {
                private _okRestock = [_a] call ARC_fnc_airbaseRestoreParkedAsset;

                if (_okRestock) then {
                    if (_opsLogEnabled || _debugOps) then {
                        ["OPS", format ["AIRBASE: restocked %1 (no return flight)", _aid], _center, 0, [
                            ["category", _cat],
                            ["vehType", _vehType],
                            ["pReturn", _pReturn]
                        ]] call ARC_fnc_intelLog;
                    };
                } else {
                    // If restock failed, try again shortly.
                    _a set ["availableAt", _nowTs + 60];
                };
            };
        };
    };
} forEach _assets;


// Scheduler: departures + generic arrivals (existing behavior retained)
private _cdDep = missionNamespace getVariable ["airbase_v1_depart_cooldown_s", 900];
private _cdArr = missionNamespace getVariable ["airbase_v1_arrive_cooldown_s", 1200];
private _sinceDep = _nowTs - ([_rt, "lastDepartTs", -1e9] call _fnHmGet);
private _sinceArr = _nowTs - ([_rt, "lastArriveTs", -1e9] call _fnHmGet);
private _canDep = (_sinceDep >= _cdDep);
private _canArr = (_sinceArr >= _cdArr);

private _sinceStart = _nowTs - ([_rt, "startTs", _nowTs] call _fnHmGet);
private _firstDelay = missionNamespace getVariable ["airbase_v1_firstDepartureDelayS", missionNamespace getVariable ["airbase_v1_firstDepartureDelay_s", 300]];
missionNamespace setVariable ["airbase_v1_firstDepartureDelayS", _firstDelay, true];
missionNamespace setVariable ["airbase_v1_firstDepartureDelay_s", _firstDelay, true];
private _forceFirstDeparture = (_sinceStart >= _firstDelay) && { !([_rt, "firstDepartureDone", false] call _fnHmGet) };

// Per-tick rolls
// Defaults raised from 0.25/0.30/0.40/0.45 per-hour to produce roughly 1 departure
// and 1 arrival per hour so the airbase remains active after the seed flights complete.
// All four rates are still configurable via missionNamespace variables set before init.
private _pDepartFW = missionNamespace getVariable ["airbase_v1_p_depart_hour_fw", 1.5];
private _pArriveFW = missionNamespace getVariable ["airbase_v1_p_arrive_hour_fw", 1.5];
private _pDepartRW = missionNamespace getVariable ["airbase_v1_p_depart_hour_rw", 1.0];
private _pArriveRW = missionNamespace getVariable ["airbase_v1_p_arrive_hour_rw", 1.0];

private _pTickDepFW = (_pDepartFW / 3600) * _tickS;
private _pTickDepRW = (_pDepartRW / 3600) * _tickS;
private _pTickArrFW = (_pArriveFW / 3600) * _tickS;
private _pTickArrRW = (_pArriveRW / 3600) * _tickS;

private _pTickDep = _pTickDepFW + _pTickDepRW;
private _pTickArr = _pTickArrFW + _pTickArrRW;

private _rollDep = _forceFirstDeparture || ((_canDep) && ((random 1) < _pTickDep));
private _rollArr = (_canArr) && ((random 1) < _pTickArr);

// Build candidates (include FW + RW, exclude disabled)
private _candidates = _assets select {
    private _st = [_x, "state", "PARKED"] call _fnHmGet;
    (_st == "PARKED")
};

if (!_holdDepartures && { _rollDep } && { (count _candidates) > 0 }) then {
    // Bias: for the very first departure, avoid tow assets + EC-130 (plane7) if possible.
    if (_forceFirstDeparture) then {
        private _prefer = _candidates select {
            !([_x, "requiresTow", false] call _fnHmGet) && { !(([_x, "vehVar", ""] call _fnHmGet) isEqualTo "plane7") }
        };
        if ((count _prefer) > 0) then { _candidates = _prefer; };
    };

    private _asset = selectRandom _candidates;
    private _fid = call _fn_nextId;
    private _cat = [_asset, "category", "FW"] call _fnHmGet;
    private _aid = [_asset, "id", ""] call _fnHmGet;

    private _rec = [
        _fid, _nowTs,
        "DEP", _cat,
        _aid,
        "QUEUED",
        _nowTs,
        [
            ["mode","DEPART"],
            ["assetId", _aid],
            ["vehType", ([_asset, "startVehType", ""] call _fnHmGet)]
        ]
    ];
    _recs pushBack _rec;
    private _routeDecisionDep = ["DEP", "AMBIENT", _fid] call ARC_fnc_airbaseBuildRouteDecision;
    private _routeOkDep = _routeDecisionDep param [0, false];
    private _routeMetaDep = _routeDecisionDep param [1, []];
    private _routeReasonDep = _routeDecisionDep param [2, "ROUTE_DECISION_FAILED"];
    if (!_routeOkDep) then {
        if (_opsLogEnabled || _debugOps) then {
            ["OPS", format ["AIRBASE ROUTE: blocked ambient departure %1 (%2)", _fid, _routeReasonDep], _center, 0, [
                ["flightId", _fid],
                ["assetId", _aid],
                ["reason", _routeReasonDep]
            ]] call ARC_fnc_intelLog;
        };
        _recs deleteAt ((count _recs) - 1);
        _rt set ["lastDepartTs", _nowTs - (_cdDep * 0.8)];
        if (_forceFirstDeparture) then { _rt set ["firstDepartureDone", false]; };
    } else {
        _queue pushBack [_fid, "DEP", _aid, _routeMetaDep];

        _rt set ["lastDepartTs", _nowTs];
        if (_forceFirstDeparture) then { _rt set ["firstDepartureDone", true]; };

        if (_opsLogEnabled || _debugOps) then {
            ["OPS", format ["AIRBASE: queued departure %1 (%2)", _fid, _aid], _center, 0, [
                ["category", _cat],
                ["vehType", ([_asset, "startVehType", ""] call _fnHmGet)]
            ]] call ARC_fnc_intelLog;
        };
    };
};

if (_rollArr) then {
    private _fidA = call _fn_nextId;

    // Choose category for random inbound (FW/RW) based on configured per-hour rates.
    private _catA = "FW";
    private _hasRW = (count (_assets select { ([_x, "category", "FW"] call _fnHmGet) isEqualTo "RW" && { ([_x, "state", "PARKED"] call _fnHmGet) != "DISABLED" } }) ) > 0;
    if (_hasRW && { (random _pTickArr) < _pTickArrRW }) then { _catA = "RW"; };

    private _recA = [_fidA, _nowTs, "ARR", _catA, "INBOUND", "QUEUED", _nowTs, [["mode","RANDOM"]]];
    _recs pushBack _recA;
    private _routeDecisionArr = ["ARR", "AMBIENT", _fidA] call ARC_fnc_airbaseBuildRouteDecision;
    private _routeOkArr = _routeDecisionArr param [0, false];
    private _routeMetaArr = _routeDecisionArr param [1, []];
    private _routeReasonArr = _routeDecisionArr param [2, "ROUTE_DECISION_FAILED"];
    if (_routeOkArr) then {
        _queue pushBack [_fidA, "ARR", "INBOUND", _routeMetaArr];
        _rt set ["lastArriveTs", _nowTs];

        if (_opsLogEnabled || _debugOps) then {
            ["OPS", format ["AIRBASE: queued inbound arrival %1 (%2)", _fidA, _catA], _center, 0, []] call ARC_fnc_intelLog;
        };
    } else {
        _recs deleteAt ((count _recs) - 1);
        _rt set ["lastArriveTs", _nowTs - (_cdArr * 0.8)];
        if (_opsLogEnabled || _debugOps) then {
            ["OPS", format ["AIRBASE ROUTE: blocked ambient inbound %1 (%2)", _fidA, _routeReasonArr], _center, 0, [
                ["flightId", _fidA],
                ["reason", _routeReasonArr]
            ]] call ARC_fnc_intelLog;
        };
    };
};

// Persist queue + records + rt
["airbase_v1_queue", _queue] call ARC_fnc_stateSet;
["airbase_v1_records", _recs] call ARC_fnc_stateSet;
missionNamespace setVariable ["airbase_v1_rt", _rt, true];

// Queue snapshot broadcast (OPS + Diary)
// Purpose: give players a heads-up (pending departures/arrivals) even before a flight starts taxi/takeoff.
private _diaryEnabled = missionNamespace getVariable ["airbase_v1_diaryEnabled", true];
if (!(_diaryEnabled isEqualType true) && !(_diaryEnabled isEqualType false)) then { _diaryEnabled = true; };

private _qDepNow = 0;
private _qArrNow = 0;
{
    private _k = _x param [1, ""];
    if (_k isEqualTo "DEP") then { _qDepNow = _qDepNow + 1; } else { if (_k isEqualTo "ARR") then { _qArrNow = _qArrNow + 1; }; };
} forEach _queue;

private _sigParts = [];
private _nSig = 10 min (count _queue);
for "_i" from 0 to (_nSig - 1) do {
    private _it = _queue select _i;
    _it params ["_sfid","_sk","_sdet"];
    _sigParts pushBack format ["%1/%2/%3", _sfid, _sk, _sdet];
};

private _queueSig = format ["%1|%2|%3|%4", (count _queue), _qDepNow, _qArrNow, (_sigParts joinString ";")];
private _lastSig = [_rt, "queueSig", ""] call _fnHmGet;

if (!(_queueSig isEqualTo _lastSig)) then {
    _rt set ["queueSig", _queueSig];
    missionNamespace setVariable ["airbase_v1_rt", _rt, true];

    private _execNow = missionNamespace getVariable ["airbase_v1_execActive", false];
    private _execFid = missionNamespace getVariable ["airbase_v1_execFid", ""];
    if (!(_execFid isEqualType "")) then { _execFid = ""; };

    // Preview first few items (human-readable)
    private _previewParts = [];
    private _nPrev = 6 min (count _queue);
    for "_i" from 0 to (_nPrev - 1) do {
        private _it = _queue select _i;
        _it params ["_pfid", "_pk", "_pdet"];
        _previewParts pushBack format ["%1 %2 %3", _pfid, _pk, _pdet];
    };

    private _preview = if ((count _previewParts) > 0) then { _previewParts joinString "<br/>" } else { "(empty)" };

    // Diary entry text (structured text)
    private _st = systemTime;
    private _stamp = format ["%1-%2-%3 %4:%5", (_st select 0), (_st select 1), (_st select 2), (_st select 3), (_st select 4)];

    private _diaryText = format [
        "<t size='1.05'>Airbase Queue Snapshot</t><br/>Time: %1<br/>Exec: %2%3<br/>Queued: DEP %4 | ARR %5 | TOTAL %6<br/><br/><t size='0.95'>Next:</t><br/>%7",
        _stamp,
        if (_execNow) then {"ON"} else {"OFF"},
        if (_execFid isEqualTo "") then {""} else { format [" (%1)", _execFid] },
        _qDepNow,
        _qArrNow,
        (count _queue),
        _preview
    ];

    if (_diaryEnabled) then {
        ["Queue Snapshot", _diaryText] remoteExecCall ["ARC_fnc_airbaseDiaryUpdate", 0];
    };

    if (_opsLogEnabled || _debugOps) then {
        ["OPS", format ["AIRBASE: queue update dep=%1 arr=%2 total=%3", _qDepNow, _qArrNow, (count _queue)], _center, 0, [
            ["execActive", _execNow],
            ["execFid", _execFid],
            ["preview", (_previewParts joinString " | ")]
        ]] call ARC_fnc_intelLog;
    };
};



// Periodic status snapshot into OPS log (normal operations + debug)
private _snapEnabled = (_opsLogEnabled || _debugOps);
private _interval = _opsStatusInterval;
if (_debugOps && { _interval > 120 }) then { _interval = 120; };

private _nextSnap = [_rt, "nextOpsStatusTs", ([_rt, "nextDebugOpsTs", 0] call _fnHmGet)] call _fnHmGet;
if (_snapEnabled && { _nowTs >= _nextSnap }) then {
    private _execNow = missionNamespace getVariable ["airbase_v1_execActive", false];
    private _qLen = count _queue;

    private _parked = 0;
    private _active = 0;
    private _cooldown = 0;
    private _returnQueued = 0;
    private _disabled = 0;
    private _soonestReturnAt = 1e9;

    {
        private _st = [_x, "state", "PARKED"] call _fnHmGet;
        switch (_st) do {
            case "PARKED": { _parked = _parked + 1; };
            case "ACTIVE": { _active = _active + 1; };
            case "COOLDOWN": {
                _cooldown = _cooldown + 1;
                private _a = [_x, "availableAt", 0] call _fnHmGet;
                if (_a > 0 && { _a < _soonestReturnAt }) then { _soonestReturnAt = _a; };
            };
            case "RETURN_QUEUED": { _returnQueued = _returnQueued + 1; };
            case "DISABLED": { _disabled = _disabled + 1; };
            default {};
        };
    } forEach _assets;

    private _nextDepAt = ([_rt, "lastDepartTs", -1e9] call _fnHmGet) + (missionNamespace getVariable ["airbase_v1_depart_cooldown_s", 900]);
    private _nextArrAt = ([_rt, "lastArriveTs", -1e9] call _fnHmGet) + (missionNamespace getVariable ["airbase_v1_arrive_cooldown_s", 1200]);

    private _meta = [
        ["bubbleActive", _bubbleActive],
        ["execActive", _execNow],
        ["queueLen", _qLen],
        ["parked", _parked],
        ["active", _active],
        ["cooldown", _cooldown],
        ["returnQueued", _returnQueued],
        ["disabled", _disabled],
        ["nextDepAt", _nextDepAt],
        ["holdDepartures", _holdDepartures],
        ["nextArrAt", _nextArrAt],
        ["soonestReturnAt", if (_soonestReturnAt < 1e9) then { _soonestReturnAt } else { -1 }]
    ];

    private _n = 3 min _qLen;
    for "_i" from 0 to (_n - 1) do {
        private _it = _queue select _i;
        _it params ["_qFid","_qKind","_qDet"];
        _meta pushBack [format ["q%1", _i + 1], format ["%1 %2 %3", _qFid, _qKind, _qDet]];
    };

    // Build a player-visible one-line summary (the console list view primarily shows the summary string).
    private _qDep = 0;
    private _qArr = 0;
    {
        private _k = _x param [1, ""];
        if (_k isEqualTo "DEP") then { _qDep = _qDep + 1; } else { if (_k isEqualTo "ARR") then { _qArr = _qArr + 1; }; };
    } forEach _queue;

    private _nextDepIn = round (_nextDepAt - _nowTs);
    if (_nextDepIn < 0) then { _nextDepIn = 0; };
    private _nextArrIn = round (_nextArrAt - _nowTs);
    if (_nextArrIn < 0) then { _nextArrIn = 0; };

    private _etaReturn = -1;
    if (_soonestReturnAt < 1e9) then {
        _etaReturn = round (_soonestReturnAt - _nowTs);
        if (_etaReturn < 0) then { _etaReturn = 0; };
    };
    private _returnTxt = if (_etaReturn >= 0) then { format ["%1s", _etaReturn] } else { "n/a" };

    private _preview = "";
    private _nP = 3 min _qLen;
    if (_nP > 0) then {
        private _parts = [];
        for "_i" from 0 to (_nP - 1) do {
            private _it = _queue select _i;
            _it params ["_pfid", "_pk", "_pdet"];
            _parts pushBack format ["%1 %2 %3", _pfid, _pk, _pdet];
        };
        _preview = _parts joinString " | ";
    };

    private _msg = format [
        "AIRBASE: status bubble=%1 exec=%2 holdDep=%3 q=%4(dep %5/arr %6) assets P=%7 A=%8 C=%9 RQ=%10 D=%11 cdDep=%12s cdArr=%13s nextReturn=%14%15",
        if (_bubbleActive) then {"ON"} else {"OFF"},
        if (_execNow) then {"ON"} else {"OFF"},
        if (_holdDepartures) then {"ON"} else {"OFF"},
        _qLen, _qDep, _qArr,
        _parked, _active, _cooldown, _returnQueued, _disabled,
        _nextDepIn, _nextArrIn,
        _returnTxt,
        if (_preview isEqualTo "") then {""} else { format [" | %1", _preview] }
    ];

    ["OPS", _msg, _center, 0, _meta] call ARC_fnc_intelLog;
    _rt set ["nextOpsStatusTs", _nowTs + _interval];
    _rt set ["nextDebugOpsTs", _nowTs + _interval];
};

// Execute queue if not busy
private _exec = missionNamespace getVariable ["airbase_v1_execActive", false];
if (_exec) exitWith {};

if ((count _queue) == 0) exitWith {};

private _policyIdx = -1;
private _policyReason = "NO_ELIGIBLE";
private _policyMeta = [];
private _loggedDepHoldSkip = false;

private _runwayState = missionNamespace getVariable ["airbase_v1_runwayState", "OPEN"];
if (!(_runwayState isEqualType "") || !(_runwayState in ["OPEN", "RESERVED", "OCCUPIED"])) then { _runwayState = "OPEN"; };
private _runwayOwner = missionNamespace getVariable ["airbase_v1_runwayOwner", ""];
if (!(_runwayOwner isEqualType "")) then { _runwayOwner = ""; };
private _runwayUntil = missionNamespace getVariable ["airbase_v1_runwayUntil", -1];
if (!(_runwayUntil isEqualType 0)) then { _runwayUntil = -1; };

private _runwayFree = (_runwayState isEqualTo "OPEN") || { (_runwayState isEqualTo "RESERVED") && { _runwayOwner isEqualTo "" } };
if (!_runwayFree) exitWith {
    if (_opsLogEnabled || _debugOps) then {
        ["OPS", format ["AIRBASE POLICY: dequeue blocked by runway lock (%1 owner=%2)", _runwayState, _runwayOwner], _center, 0, [
            ["runwayState", _runwayState],
            ["runwayOwner", _runwayOwner],
            ["runwayUntil", _runwayUntil],
            ["queueLen", count _queue]
        ]] call ARC_fnc_intelLog;
    };
};

for "_i" from 0 to ((count _queue) - 1) do {
    private _qItem = _queue select _i;
    _qItem params ["_qFid", "_qKind"];

    if (_qKind isEqualTo "ARR") exitWith {
        _policyIdx = _i;
        _policyReason = "ALLOW_ARR";
        _policyMeta = [["holdDepartures", _holdDepartures], ["reason", "ARR_EXECUTES_DURING_HOLD"]];
    };

    if (_qKind isEqualTo "DEP") then {
        if (!_holdDepartures) exitWith {
            _policyIdx = _i;
            _policyReason = "ALLOW_DEP_HOLD_OFF";
            _policyMeta = [["holdDepartures", false]];
        };

        private _isOverride = false;
        private _isEmergency = false;
        private _rIdx = -1;
        { if ((_x param [0, ""]) isEqualTo _qFid) exitWith { _rIdx = _forEachIndex; }; } forEach _recs;
        if (_rIdx >= 0) then {
            private _rec = _recs select _rIdx;
            private _meta = _rec param [7, []];
            if (!(_meta isEqualType [])) then { _meta = []; };

            {
                private _k = _x param [0, ""];
                private _v = _x param [1, false];
                if ((_k isEqualTo "overrideHold") && { _v isEqualTo true }) then { _isOverride = true; };
                if ((_k isEqualTo "manualOverride") && { _v isEqualTo true }) then { _isOverride = true; };
                if ((_k isEqualTo "emergency") && { _v isEqualTo true }) then { _isEmergency = true; };
            } forEach _meta;

            if ((_rec param [5, ""]) isEqualTo "PRIORITIZED") then { _isOverride = true; };
        };

        if (_isOverride || _isEmergency) exitWith {
            _policyIdx = _i;
            _policyReason = "ALLOW_DEP_OVERRIDE";
            _policyMeta = [["holdDepartures", true], ["override", _isOverride], ["emergency", _isEmergency]];
        };

        if (!_loggedDepHoldSkip && (_opsLogEnabled || _debugOps)) then {
            _loggedDepHoldSkip = true;
            ["OPS", format ["AIRBASE POLICY: hold blocked departure %1", _qFid], _center, 0, [
                ["holdDepartures", true],
                ["override", false],
                ["emergency", false]
            ]] call ARC_fnc_intelLog;
        };
    };
};

if ((_opsLogEnabled || _debugOps) && { !(_policyReason isEqualTo "NO_ELIGIBLE") }) then {
    private _picked = _queue select _policyIdx;
    _picked params ["_pfid", "_pk", "_pd", ["_prouteMeta", []]];
    if !(_prouteMeta isEqualType []) then { _prouteMeta = []; };
    private _laneDecision = [_prouteMeta, "runwayLaneDecision", "-"] call _metaGet;
    private _runwayMarker = [_prouteMeta, "runwayMarker", "-"] call _metaGet;
    private _policyMetaExt = +_policyMeta;
    _policyMetaExt pushBack ["laneDecision", _laneDecision];
    _policyMetaExt pushBack ["runwayMarker", _runwayMarker];
    ["OPS", format ["AIRBASE POLICY: %1 selected %2 (%3 %4 lane=%5 rwy=%6)", _policyReason, _pfid, _pk, _pd, _laneDecision, _runwayMarker], _center, 0, _policyMetaExt] call ARC_fnc_intelLog;
};

if (_policyIdx < 0) exitWith {
    if (_opsLogEnabled || _debugOps) then {
        private _headKind = (_queue select 0) param [1, ""];
        private _headFid = (_queue select 0) param [0, ""];
        ["OPS", format ["AIRBASE POLICY: dequeue blocked (hold=%1, head=%2 %3)", _holdDepartures, _headFid, _headKind], _center, 0, [
            ["holdDepartures", _holdDepartures],
            ["queueLen", count _queue]
        ]] call ARC_fnc_intelLog;
    };
};

private _item = _queue deleteAt _policyIdx;
_item params ["_fid", "_kind", "_detail", ["_routeMeta", []]];
if !(_routeMeta isEqualType []) then { _routeMeta = []; };

private _reserveS = [_routeMeta, "runwayReserveWindowS", missionNamespace getVariable ["airbase_v1_runwayReserveWindow_s", 120]] call _metaGet;
if (!(_reserveS isEqualType 0) || { _reserveS < 30 }) then { _reserveS = 120; };
private _reserved = [_fid, _kind, _detail, _reserveS, _policyReason] call ARC_fnc_airbaseRunwayLockReserve;
if (_reserved) then {
    ["LOCK_ACQUIRE", _fid, "SYSTEM", "", [_kind, _detail, _policyReason]] call _fnEventPush;
};
if (!_reserved) exitWith {
    // sqflint-compat: `insert` not recognised as binary op; use array splice
    private _qHead = _queue select [0, _policyIdx];
    private _qTail = _queue select [_policyIdx, (count _queue) - _policyIdx];
    _queue = _qHead + [[_fid, _kind, _detail, _routeMeta]] + _qTail;
    ["airbase_v1_queue", _queue] call ARC_fnc_stateSet;
    if (_opsLogEnabled || _debugOps) then {
        ["OPS", format ["AIRBASE POLICY: reserve failed; re-queued %1 (%2 %3)", _fid, _kind, _detail], _center, 0, [
            ["policyReason", _policyReason],
            ["queueLen", count _queue]
        ]] call ARC_fnc_intelLog;
    };
};

private _idxRecActive = -1;
{ if ((_x param [0,""]) isEqualTo _fid) exitWith { _idxRecActive = _forEachIndex; }; } forEach _recs;
if (_idxRecActive >= 0) then {
    private _rActive = _recs select _idxRecActive;
    _rActive set [5, "ACTIVE"];
    _rActive set [6, _nowTs];
    _recs set [_idxRecActive, _rActive];
};

["airbase_v1_queue", _queue] call ARC_fnc_stateSet;
["airbase_v1_records", _recs] call ARC_fnc_stateSet;

[_fid, _kind, _detail, _routeMeta] spawn {
    params ["_fid", "_kind", "_detail", ["_routeMeta", []]];
    if !(_routeMeta isEqualType []) then { _routeMeta = []; };

    // sqflint-compat: compiled string hides `get` from the parser
    private _fnHmGetLocal = compile "params ['_hm','_key','_fallback']; if (!(_hm isEqualType createHashMap)) exitWith {_fallback}; private _value = _hm get _key; if (isNil '_value') exitWith {_fallback}; _value";
    if (!(_fnHmGetLocal isEqualType {})) exitWith {};

    missionNamespace setVariable ["airbase_v1_execActive", true, true];
    missionNamespace setVariable ["airbase_v1_execFid", _fid, true];

    private _evExec = ["airbase_v1_events", []] call ARC_fnc_stateGet;
    if (!(_evExec isEqualType [])) then { _evExec = []; };
    private _evExecMax = missionNamespace getVariable ["airbase_v1_eventsMax", 60];
    if (!(_evExecMax isEqualType 0) || { _evExecMax < 10 }) then { _evExecMax = 60; };
    _evExec pushBack [serverTime, "EXEC_START", _fid, "SYSTEM", "", [_kind, _detail]];
    if ((count _evExec) > _evExecMax) then { _evExec deleteRange [0, (count _evExec) - _evExecMax]; };
    ["airbase_v1_events", _evExec] call ARC_fnc_stateSet;

    private _occupyTimeoutS = [_routeMeta, "runwayOccupyWindowS", missionNamespace getVariable ["airbase_v1_runwayOccupyTimeout_s", 900]] call {
        params ["_rows", "_k", "_def"];
        private _v = _def;
        {
            if (_x isEqualType [] && { (count _x) >= 2 } && { ((_x select 0)) isEqualTo _k }) exitWith { _v = _x select 1; };
        } forEach _rows;
        _v
    };
    if (!(_occupyTimeoutS isEqualType 0) || { _occupyTimeoutS < 60 }) then { _occupyTimeoutS = 900; };
    private _occupied = [_fid, _kind, _detail, _occupyTimeoutS, "EXEC_START"] call ARC_fnc_airbaseRunwayLockOccupy;
    if (!_occupied) exitWith {
        private _recsBlock = ["airbase_v1_records", []] call ARC_fnc_stateGet;
        private _idxBlock = -1;
        { if ((_x param [0,""]) isEqualTo _fid) exitWith { _idxBlock = _forEachIndex; }; } forEach _recsBlock;
        if (_idxBlock >= 0) then {
            private _rBlock = _recsBlock select _idxBlock;
            _rBlock set [5, "FAILED"];
            _rBlock set [6, serverTime];
            _recsBlock set [_idxBlock, _rBlock];
            ["airbase_v1_records", _recsBlock] call ARC_fnc_stateSet;
        };

        ["OPS", format ["AIRBASE: execution aborted, runway occupy denied for %1", _fid], getMarkerPos "mkr_airbaseCenter", 0, [
            ["kind", _kind],
            ["detail", _detail]
        ]] call ARC_fnc_intelLog;

        [_fid, _kind, _detail, "FAILED", true, "EXEC_ABORT_OCCUPY_DENIED"] call ARC_fnc_airbaseRunwayLockRelease;
        missionNamespace setVariable ["airbase_v1_execFid", "", true];
        missionNamespace setVariable ["airbase_v1_execActive", false, true];
    };

    private _rtL = missionNamespace getVariable ["airbase_v1_rt", createHashMap];
    private _assetsL = [_rtL, "assets", []] call _fnHmGetLocal;

    private _ok = false;

    if (_kind isEqualTo "DEP") then {
        private _aIdx = -1;
        { if (([_x, "id", ""] call _fnHmGetLocal) isEqualTo _detail) exitWith { _aIdx = _forEachIndex; }; } forEach _assetsL;
        if (_aIdx >= 0) then {
            private _asset = _assetsL select _aIdx;

            // Skip disabled assets
            if (([_asset, "state", "PARKED"] call _fnHmGetLocal) isEqualTo "DISABLED") exitWith {
                _ok = false;
            };

            _asset set ["state", "ACTIVE"];
            _asset set ["activeFlight", _fid];

            if ([_asset, "requiresTow", false] call _fnHmGetLocal) then {
                _ok = [_fid, _asset] call ARC_fnc_airbaseAttackTowDepart;
            } else {
                _ok = [_fid, _asset] call ARC_fnc_airbasePlaneDepart;
            };

            // Persist runtime changes
            missionNamespace setVariable ["airbase_v1_rt", _rtL, true];
        };
    } else {
        _ok = [_fid] call ARC_fnc_airbaseSpawnArrival;
    };

    // Mark record complete/failed
    private _recs2 = ["airbase_v1_records", []] call ARC_fnc_stateGet;
    private _idx2 = -1;
    { if ((_x param [0,""]) isEqualTo _fid) exitWith { _idx2 = _forEachIndex; }; } forEach _recs2;
    if (_idx2 >= 0) then {
        private _r2 = _recs2 select _idx2;
        _r2 set [5, if (_ok) then { "COMPLETE" } else { "FAILED" }];
        _r2 set [6, serverTime];
        _recs2 set [_idx2, _r2];
        ["airbase_v1_records", _recs2] call ARC_fnc_stateSet;
    };

    missionNamespace setVariable ["airbase_v1_execFid", "", true];

    [_fid, _kind, _detail, if (_ok) then {"COMPLETE"} else {"FAILED"}, false, "EXEC_FINISH"] call ARC_fnc_airbaseRunwayLockRelease;
    ["exec-end", false] call ARC_fnc_airbaseRunwayLockSweep;

    private _evExecEnd = ["airbase_v1_events", []] call ARC_fnc_stateGet;
    if (!(_evExecEnd isEqualType [])) then { _evExecEnd = []; };
    private _evExecEndMax = missionNamespace getVariable ["airbase_v1_eventsMax", 60];
    if (!(_evExecEndMax isEqualType 0) || { _evExecEndMax < 10 }) then { _evExecEndMax = 60; };
    _evExecEnd pushBack [serverTime, "EXEC_END", _fid, "SYSTEM", "", [if (_ok) then {"COMPLETE"} else {"FAILED"}]];
    _evExecEnd pushBack [serverTime, "LOCK_RELEASE", _fid, "SYSTEM", "", [if (_ok) then {"COMPLETE"} else {"FAILED"}]];
    if ((count _evExecEnd) > _evExecEndMax) then { _evExecEnd deleteRange [0, (count _evExecEnd) - _evExecEndMax]; };
    ["airbase_v1_events", _evExecEnd] call ARC_fnc_stateSet;

    missionNamespace setVariable ["airbase_v1_execActive", false, true];
};

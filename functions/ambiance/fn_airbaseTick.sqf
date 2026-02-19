/*
    File: functions/ambiance/fn_airbaseTick.sqf
    Author: ARC / Ambient Airbase Subsystem
    Description:
      Main tick loop. Schedules departures/arrivals, processes queue, handles player bubble simulation gating,
      and queues "return arrivals" for departed aircraft once their turnaround timer expires.
*/

if (!isServer) exitWith {};

private _rt = missionNamespace getVariable ["airbase_v1_rt", createHashMap];

private _fnHmGet = {
    params ["_hm", "_key", "_fallback"];
    if (!(_hm isEqualType createHashMap)) exitWith { _fallback };
    private _value = _hm get _key;
    if (isNil "_value") exitWith { _fallback };
    _value
};

if (!([_rt, "initialized", false] call _fnHmGet)) exitWith {};

// Fail-safe runway cleanup in case previous movement aborted or lock metadata went stale.
["tick", false] call ARC_fnc_airbaseRunwayLockSweep;

private _nowTs = serverTime;
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
if (_bubbleActive isNotEqualTo _wasActive) then {
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


private _debug = missionNamespace getVariable ["airbase_v1_debug", false];
private _debugOps = missionNamespace getVariable ["airbase_v1_debugOpsLog", false];

private _opsLogEnabled = missionNamespace getVariable ["airbase_v1_opsLogEnabled", true];
if (!(_opsLogEnabled isEqualType true) && !(_opsLogEnabled isEqualType false)) then { _opsLogEnabled = true; };

private _opsStatusInterval = missionNamespace getVariable ["airbase_v1_opsStatusInterval_s", 120];
if (!(_opsStatusInterval isEqualType 0) || { _opsStatusInterval < 30 }) then { _opsStatusInterval = 120; };

private _controllerTimeoutS = missionNamespace getVariable ["airbase_v1_controller_timeout_s", 90];
if (!(_controllerTimeoutS isEqualType 0) || { _controllerTimeoutS < 5 }) then { _controllerTimeoutS = 90; };

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
    private _lastAt = _notifyState get _dedupeKey;
    if (isNil "_lastAt") then { _lastAt = -1000; };
    if ((_nowTs - _lastAt) < _notifyThrottleS) exitWith {};
    _notifyState set [_dedupeKey, _nowTs];
    _notifyDirty = true;

    if (_method isEqualTo "HINT") then {
        [_body] remoteExec ["ARC_fnc_clientHint", _owner];
    } else {
        [_title, _body, 5] remoteExec ["ARC_fnc_clientToast", _owner];
    };
};

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

private _hasTowerController = (count _towerControllers) > 0;
private _clearanceStateDirty = false;

for "_iClr" from 0 to ((count _clearanceRequests) - 1) do {
    private _rec = _clearanceRequests # _iClr;
    if !(_rec isEqualType []) then { continue; };

    private _status = toUpperANSI (_rec param [6, ""]);
    if (_status in ["APPROVED", "DENIED", "CANCELED"]) then { continue; };

    private _createdAt = _rec param [7, _nowTs];
    if (!(_createdAt isEqualType 0)) then { _createdAt = _nowTs; };

    private _ageS = _nowTs - _createdAt;

    if (_hasTowerController && {_status isEqualTo "PENDING"}) then {
        _rec set [6, "AWAITING_TOWER_DECISION"];
        _rec set [8, _nowTs];
        _rec set [9, ["", "", -1, "", "AWAITING_TOWER"]];
        private _metaAwait = _rec param [10, []];
        if (!(_metaAwait isEqualType [])) then { _metaAwait = []; };
        _metaAwait pushBack ["awaitingTowerDecision", true];
        _metaAwait pushBack ["towerControllersPresent", count _towerControllers];
        _rec set [10, _metaAwait];
        _clearanceRequests set [_iClr, _rec];
        _clearanceStateDirty = true;

        private _ridAwait = _rec param [0, ""];
        private _requesterUidAwait = _rec param [2, ""];
        ["LOCK_ACQUIRE", _ridAwait, "SYSTEM", _requesterUidAwait, [count _towerControllers]] call _fnEventPush;

        private _requesterOwnerAwait = -1;
        { if ((getPlayerUID _x) isEqualTo _requesterUidAwait) exitWith { _requesterOwnerAwait = owner _x; }; } forEach allPlayers;
        [_requesterOwnerAwait, "TOAST", "Airbase Clearance", format ["%1 awaiting tower decision", _ridAwait], format ["AIR_REQ_AWAIT:%1", _ridAwait]] call _fnNotifyMaybe;
        {
            private _towUid = _x param [1, ""];
            private _towOwner = -1;
            { if ((getPlayerUID _x) isEqualTo _towUid) exitWith { _towOwner = owner _x; }; } forEach allPlayers;
            [_towOwner, "TOAST", "Airbase Tower", format ["Decision required: %1", _ridAwait], format ["AIR_CTRL_PENDING:%1:%2", _ridAwait, _towUid]] call _fnNotifyMaybe;
        } forEach _towerControllers;

        if (_opsLogEnabled || _debugOps) then {
            ["OPS", format ["AIRBASE CLEARANCE: %1 moved to awaiting tower decision", _rec param [0, ""]], _center, 0, [
                ["event", "AIRBASE_CLEARANCE_AWAITING_TOWER"],
                ["requestId", _rec param [0, ""]],
                ["controllers", count _towerControllers]
            ]] call ARC_fnc_intelLog;
        };

        continue;
    };

    if (!_controllerFallbackEnabled) then { continue; };

    if (_status in ["PENDING", "AWAITING_TOWER_DECISION"] && { _ageS >= _controllerTimeoutS }) then {
        _rec set [6, "APPROVED"];
        _rec set [8, _nowTs];
        _rec set [9, ["AI", "AI", _nowTs, "APPROVE", "TIMEOUT"]];

        private _meta = _rec param [10, []];
        if (!(_meta isEqualType [])) then { _meta = []; };
        _meta pushBack ["decidedBy", "AI"];
        _meta pushBack ["reason", "timeout"];
        _meta pushBack ["timedOutAfterS", _ageS];
        _meta pushBack ["forceAiOnly", _forceAiOnly];
        _rec set [10, _meta];

        _clearanceRequests set [_iClr, _rec];
        _clearanceStateDirty = true;

        private _ridAi = _rec param [0, ""];
        private _requesterUidAi = _rec param [2, ""];
        ["APPROVE", _ridAi, "AI", _requesterUidAi, ["TIMEOUT"]] call _fnEventPush;

        private _requesterOwnerAi = -1;
        { if ((getPlayerUID _x) isEqualTo _requesterUidAi) exitWith { _requesterOwnerAi = owner _x; }; } forEach allPlayers;
        [_requesterOwnerAi, "TOAST", "Airbase Clearance", format ["%1 auto-approved (timeout)", _ridAi], format ["AIR_REQ_APPROVE_AI:%1", _ridAi]] call _fnNotifyMaybe;

        if (_opsLogEnabled || _debugOps) then {
            ["OPS", format ["AIRBASE CLEARANCE: %1 auto-approved by AI timeout", _rec param [0, ""]], _center, 0, [
                ["event", "AIRBASE_CLEARANCE_AI_TIMEOUT"],
                ["requestId", _rec param [0, ""]],
                ["timeout_s", _controllerTimeoutS],
                ["age_s", _ageS],
                ["forceAiOnly", _forceAiOnly]
            ]] call ARC_fnc_intelLog;
        };
    };
};

if (_clearanceStateDirty) then {
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
        private _hIdx = _historyById get _rid;
        if (isNil "_hIdx") then { _hIdx = -1; };
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
                _queue pushBack [_fidA, "ARR", _aid];

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
private _pDepartFW = missionNamespace getVariable ["airbase_v1_p_depart_hour_fw", 0.25];
private _pArriveFW = missionNamespace getVariable ["airbase_v1_p_arrive_hour_fw", 0.40];
private _pDepartRW = missionNamespace getVariable ["airbase_v1_p_depart_hour_rw", 0.30];
private _pArriveRW = missionNamespace getVariable ["airbase_v1_p_arrive_hour_rw", 0.45];

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
    _queue pushBack [_fid, "DEP", _aid];

    _rt set ["lastDepartTs", _nowTs];
    if (_forceFirstDeparture) then { _rt set ["firstDepartureDone", true]; };

    if (_opsLogEnabled || _debugOps) then {
        ["OPS", format ["AIRBASE: queued departure %1 (%2)", _fid, _aid], _center, 0, [
            ["category", _cat],
            ["vehType", ([_asset, "startVehType", ""] call _fnHmGet)]
        ]] call ARC_fnc_intelLog;
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
    _queue pushBack [_fidA, "ARR", "INBOUND"];
    _rt set ["lastArriveTs", _nowTs];

    if (_opsLogEnabled || _debugOps) then {
        ["OPS", format ["AIRBASE: queued inbound arrival %1 (%2)", _fidA, _catA], _center, 0, []] call ARC_fnc_intelLog;
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
    private _it = _queue # _i;
    _it params ["_sfid","_sk","_sdet"];
    _sigParts pushBack format ["%1/%2/%3", _sfid, _sk, _sdet];
};

private _queueSig = format ["%1|%2|%3|%4", (count _queue), _qDepNow, _qArrNow, (_sigParts joinString ";")];
private _lastSig = [_rt, "queueSig", ""] call _fnHmGet;

if (_queueSig isNotEqualTo _lastSig) then {
    _rt set ["queueSig", _queueSig];
    missionNamespace setVariable ["airbase_v1_rt", _rt, true];

    private _execNow = missionNamespace getVariable ["airbase_v1_execActive", false];
    private _execFid = missionNamespace getVariable ["airbase_v1_execFid", ""];
    if (!(_execFid isEqualType "")) then { _execFid = ""; };

    // Preview first few items (human-readable)
    private _previewParts = [];
    private _nPrev = 6 min (count _queue);
    for "_i" from 0 to (_nPrev - 1) do {
        private _it = _queue # _i;
        _it params ["_pfid", "_pk", "_pdet"];
        _previewParts pushBack format ["%1 %2 %3", _pfid, _pk, _pdet];
    };

    private _preview = if ((count _previewParts) > 0) then { _previewParts joinString "<br/>" } else { "(empty)" };

    // Diary entry text (structured text)
    private _st = systemTime;
    private _stamp = format ["%1-%2-%3 %4:%5", _st # 0, _st # 1, _st # 2, _st # 3, _st # 4];

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
        private _it = _queue # _i;
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
            private _it = _queue # _i;
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
    private _qItem = _queue # _i;
    _qItem params ["_qFid", "_qKind", "_qDetail"];

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
        private _rIdx = _recs findIf { (_x param [0, ""]) isEqualTo _qFid };
        if (_rIdx >= 0) then {
            private _rec = _recs # _rIdx;
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

if ((_opsLogEnabled || _debugOps) && { _policyReason isNotEqualTo "NO_ELIGIBLE" }) then {
    private _picked = _queue # _policyIdx;
    _picked params ["_pfid", "_pk", "_pd"];
    ["OPS", format ["AIRBASE POLICY: %1 selected %2 (%3 %4)", _policyReason, _pfid, _pk, _pd], _center, 0, _policyMeta] call ARC_fnc_intelLog;
};

if (_policyIdx < 0) exitWith {
    if (_opsLogEnabled || _debugOps) then {
        private _headKind = (_queue # 0) param [1, ""];
        private _headFid = (_queue # 0) param [0, ""];
        ["OPS", format ["AIRBASE POLICY: dequeue blocked (hold=%1, head=%2 %3)", _holdDepartures, _headFid, _headKind], _center, 0, [
            ["holdDepartures", _holdDepartures],
            ["queueLen", count _queue]
        ]] call ARC_fnc_intelLog;
    };
};

private _item = _queue deleteAt _policyIdx;
_item params ["_fid", "_kind", "_detail"];

private _reserveS = missionNamespace getVariable ["airbase_v1_runwayReserveWindow_s", 120];
if (!(_reserveS isEqualType 0) || { _reserveS < 30 }) then { _reserveS = 120; };
private _reserved = [_fid, _kind, _detail, _reserveS, _policyReason] call ARC_fnc_airbaseRunwayLockReserve;
if (_reserved) then {
    ["LOCK_ACQUIRE", _fid, "SYSTEM", "", [_kind, _detail, _policyReason]] call _fnEventPush;
};
if (!_reserved) exitWith {
    _queue insert [_policyIdx, [[_fid, _kind, _detail]]];
    ["airbase_v1_queue", _queue] call ARC_fnc_stateSet;
    if (_opsLogEnabled || _debugOps) then {
        ["OPS", format ["AIRBASE POLICY: reserve failed; re-queued %1 (%2 %3)", _fid, _kind, _detail], _center, 0, [
            ["policyReason", _policyReason],
            ["queueLen", count _queue]
        ]] call ARC_fnc_intelLog;
    };
};

private _idxRecActive = _recs findIf { (_x param [0,""]) isEqualTo _fid };
if (_idxRecActive >= 0) then {
    private _rActive = _recs # _idxRecActive;
    _rActive set [5, "ACTIVE"];
    _rActive set [6, _nowTs];
    _recs set [_idxRecActive, _rActive];
};

["airbase_v1_queue", _queue] call ARC_fnc_stateSet;
["airbase_v1_records", _recs] call ARC_fnc_stateSet;

[_fid, _kind, _detail] spawn {
    params ["_fid", "_kind", "_detail"];

    private _fnHmGetLocal = {
        params ["_hm", "_key", "_fallback"];
        if (!(_hm isEqualType createHashMap)) exitWith { _fallback };
        private _value = _hm get _key;
        if (isNil "_value") exitWith { _fallback };
        _value
    };

    missionNamespace setVariable ["airbase_v1_execActive", true, true];
    missionNamespace setVariable ["airbase_v1_execFid", _fid, true];

    private _evExec = ["airbase_v1_events", []] call ARC_fnc_stateGet;
    if (!(_evExec isEqualType [])) then { _evExec = []; };
    private _evExecMax = missionNamespace getVariable ["airbase_v1_eventsMax", 60];
    if (!(_evExecMax isEqualType 0) || { _evExecMax < 10 }) then { _evExecMax = 60; };
    _evExec pushBack [serverTime, "EXEC_START", _fid, "SYSTEM", "", [_kind, _detail]];
    if ((count _evExec) > _evExecMax) then { _evExec deleteRange [0, (count _evExec) - _evExecMax]; };
    ["airbase_v1_events", _evExec] call ARC_fnc_stateSet;

    private _occupyTimeoutS = missionNamespace getVariable ["airbase_v1_runwayOccupyTimeout_s", 900];
    if (!(_occupyTimeoutS isEqualType 0) || { _occupyTimeoutS < 60 }) then { _occupyTimeoutS = 900; };
    private _occupied = [_fid, _kind, _detail, _occupyTimeoutS, "EXEC_START"] call ARC_fnc_airbaseRunwayLockOccupy;
    if (!_occupied) exitWith {
        private _recsBlock = ["airbase_v1_records", []] call ARC_fnc_stateGet;
        private _idxBlock = _recsBlock findIf { (_x param [0,""]) isEqualTo _fid };
        if (_idxBlock >= 0) then {
            private _rBlock = _recsBlock # _idxBlock;
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
        private _aIdx = _assetsL findIf { ([_x, "id", ""] call _fnHmGetLocal) isEqualTo _detail };
        if (_aIdx >= 0) then {
            private _asset = _assetsL # _aIdx;

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
    private _idx2 = _recs2 findIf { (_x param [0,""]) isEqualTo _fid };
    if (_idx2 >= 0) then {
        private _r2 = _recs2 # _idx2;
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

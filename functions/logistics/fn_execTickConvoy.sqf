/*
    Server: tick logic for CONVOY execution kind.

    Convoy tasks (LOGISTICS / ESCORT) differ from other incidents:
    - The "objective" is a spawned friendly convoy that must reach the destination AO.
    - The convoy holds at 0 fuel until players are near it, then departs.
    - Success: lead vehicle arrives and remains inside the AO for a short dwell.
    - Failure: convoy destroyed (lead vehicle destroyed or all vehicles destroyed) or deadline.

    Params:
        0: NUMBER - now (serverTime)
        1: NUMBER - dt (seconds)

    Returns:
        BOOL
*/

// Notification cooldown keys (ARC_fnc_clientNotifyGate via ARC_fnc_clientHint):
// - ARC_convoy_linkup_detected: link-up/staging detection hint dedupe (12s)
// - ARC_convoy_departing_now: departure hint dedupe (10s)
// - ARC_convoy_autolaunch_now: auto-launch hint dedupe (15s)

private _callerOwner = remoteExecutedOwner;
if (!isServer) exitWith
{
    private _clientOwner = clientOwner;
    private _ownerTxt = if (_clientOwner isEqualType 0) then { str _clientOwner } else {"local"};
    diag_log format ["[ARC][CONVOY][AUTH] Rejected non-server call to execTickConvoy (clientOwner=%1).", _ownerTxt];
    false
};

if (!(_callerOwner isEqualType 0)) then { _callerOwner = -1; };
if (_callerOwner > 2) exitWith
{
    diag_log format ["[ARC][CONVOY][AUTH] Rejected remote client-owner execTickConvoy mutation on server (owner=%1).", _callerOwner];
    false
};

params [
    ["_now", 0],
    ["_dt", 0]
];

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (_taskId isEqualTo "") exitWith {false};

private _destPos = ["activeExecPos", []] call ARC_fnc_stateGet;
private _destRad = ["activeExecRadius", 0] call ARC_fnc_stateGet;
if (!(_destPos isEqualType []) || { (count _destPos) < 2 }) exitWith {true};
_destPos = +_destPos; _destPos resize 3;

// Waypoint target for convoys: snap to a nearby road (computed in execInitActive) to reduce
// cross-country cutting while still evaluating success against the AO center.
private _destWpPos = ["activeConvoyDestWpPos", []] call ARC_fnc_stateGet;
if (!(_destWpPos isEqualType []) || { (count _destWpPos) < 2 }) then { _destWpPos = _destPos; };
_destWpPos = +_destWpPos; _destWpPos resize 3;

// Precomputed road-route points (built in execInitActive). Used for multi-waypoint routing.
private _routePts = ["activeConvoyRoutePoints", []] call ARC_fnc_stateGet;
if (!(_routePts isEqualType []) || { (count _routePts) < 2 }) then { _routePts = []; };

// Optional forced ingress point (e.g., Airbase North Gate).
private _ingressPos = ["activeConvoyIngressPos", []] call ARC_fnc_stateGet;
if (!(_ingressPos isEqualType []) || { (count _ingressPos) < 2 }) then { _ingressPos = []; } else { _ingressPos = +_ingressPos; _ingressPos resize 3; };

// Current convoy spacing (may be tuned by execSpawnConvoy based on convoy length).
private _spacing = ["activeConvoySpacingM", missionNamespace getVariable ["ARC_convoySpacingM", 59]] call ARC_fnc_stateGet;
if (!(_spacing isEqualType 0)) then { _spacing = missionNamespace getVariable ["ARC_convoySpacingM", 59]; };
_spacing = (_spacing max 20) min 150;

// Apply a multi-waypoint road route (reduces bridge issues and end-of-route shortcutting).
// NOTE: Defined early so both the depart block and later watchdog/recovery can use it.
private _fn_applyRouteWps = {
    params [
        "_grp",
        "_routePtsIn",
        "_destWp",
        "_destRad",
        ["_forcedPos", []]
    ];
    if (isNull _grp) exitWith {};

    // Clear any existing waypoints.
    while { (count waypoints _grp) > 0 } do { deleteWaypoint ((waypoints _grp) select 0); };

    private _minWpsUser = missionNamespace getVariable ["ARC_convoyWaypointMin", 8];
    if (!(_minWpsUser isEqualType 0)) then { _minWpsUser = 8; };
    _minWpsUser = (_minWpsUser max 3) min 25;

    private _maxWpsUser = missionNamespace getVariable ["ARC_convoyWaypointMax", 12];
    if (!(_maxWpsUser isEqualType 0)) then { _maxWpsUser = 12; };
    _maxWpsUser = (_maxWpsUser max _minWpsUser) min 25;

    // Waypoint interval is derived from the remaining road-route length so we consistently land
    // in the 8-12 waypoint window (per design). Falls back to a tunable interval if route length is unknown.
    private _interval = missionNamespace getVariable ["ARC_convoyWaypointIntervalM", 450];
    if (!(_interval isEqualType 0)) then { _interval = 450; };
    _interval = (_interval max 150) min 2000;

    private _maxWps = _maxWpsUser;

    private _finalWpRad = missionNamespace getVariable ["ARC_convoyFinalWpRadiusM", 45];
    if (!(_finalWpRad isEqualType 0)) then { _finalWpRad = 45; };
    _finalWpRad = (_finalWpRad max 25) min 150;

    private _wps = [];

    // Find the nearest route index to the current lead position, so we can start sampling forward.
    private _nearIdx = 0;
    if (_routePtsIn isEqualType [] && { (count _routePtsIn) >= 2 }) then
    {
        private _vehL = vehicle (leader _grp);
        private _lp = getPosATL _vehL; _lp resize 3;

        private _bestD = 1e12;
        for "_i" from 0 to ((count _routePtsIn) - 1) do
        {
            private _d = (_routePtsIn # _i) distance2D _lp;
            if (_d < _bestD) then { _bestD = _d; _nearIdx = _i; };
        };
    };

    // Identify a forced index for ingress (closest route point to forcedPos).
    private _forceIdx = -1;
    if (_forcedPos isEqualType [] && { (count _forcedPos) >= 2 } && { _routePtsIn isEqualType [] && { (count _routePtsIn) >= 2 } }) then
    {
        private _bestDg = 1e12;
        for "_i" from 0 to ((count _routePtsIn) - 1) do
        {
            private _d = (_routePtsIn # _i) distance2D _forcedPos;
            if (_d < _bestDg) then { _bestDg = _d; _forceIdx = _i; };
        };
        // If we're already beyond the ingress point, don't force it.
        if (_forceIdx <= _nearIdx) then { _forceIdx = -1; };
    };

    // Compute remaining road-route length from our current position to the end, then
    // derive waypoint count/interval so the convoy commits to the road chain (bridge reliability).
    private _remLen = 0;
    if (_routePtsIn isEqualType [] && { (count _routePtsIn) >= 2 }) then
    {
        for "_j" from (_nearIdx + 1) to ((count _routePtsIn) - 1) do
        {
            _remLen = _remLen + ((_routePtsIn # (_j - 1)) distance2D (_routePtsIn # _j));
        };
    };

    if (_remLen > 0) then
    {
        // Desired total waypoint count (including final): 8-12.
        private _desired = round((_remLen / 700) + 2);
        _desired = (_desired max _minWpsUser) min _maxWpsUser;
        _maxWps = _desired;

        // Interval derived from desired count. Clamp to keep AI from over-steering on short routes.
        _interval = _remLen / ((_maxWps - 1) max 1);
        _interval = (_interval max 180) min 1200;
    };

    // If we have a forced ingress point (gate), tighten waypoint spacing so the AI commits to the road chain.
    if (_forcedPos isEqualType [] && { (count _forcedPos) >= 2 }) then
    {
        _interval = _interval min 420;
    };

    private _forcedAdded = false;

    // Sample forward along the route.
    if (_routePtsIn isEqualType [] && { (count _routePtsIn) >= 2 }) then
    {
        private _acc = 0;
        private _last = _routePtsIn # _nearIdx;
        for "_i" from (_nearIdx + 1) to ((count _routePtsIn) - 1) do
        {
            private _p = _routePtsIn # _i;
            _acc = _acc + (_last distance2D _p);

            // Force-add ingress point when we reach its index.
            if (!_forcedAdded && { _forceIdx >= 0 } && { _i == _forceIdx }) then
            {
                if ((count _wps) isEqualTo 0 || { (_p distance2D (_wps # ((count _wps) - 1))) > 40 }) then
                {
                    _wps pushBack _p;
                };
                _forcedAdded = true;
                _acc = 0;
            };

            if (_acc >= _interval) then
            {
                if ((count _wps) isEqualTo 0 || { (_p distance2D (_wps # ((count _wps) - 1))) > 40 }) then
                {
                    _wps pushBack _p;
                };
                _acc = 0;
                if ((count _wps) >= (_maxWps - 1)) exitWith {};
            };
            _last = _p;
        };
    };

    // Always add the final waypoint (dedupe if already close).
    if ((count _wps) isEqualTo 0 || { ((_wps # ((count _wps) - 1)) distance2D _destWp) > 60 }) then
    {
        _wps pushBack _destWp;
    };

    {
        private _wp = _grp addWaypoint [_x, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "LIMITED";
        _wp setWaypointBehaviour "SAFE";
        _wp setWaypointCombatMode "YELLOW";
        _wp setWaypointFormation "COLUMN";
        _wp setWaypointCompletionRadius 45;

        // Final wp uses a small radius so the lead stays on-road longer.
        if (_forEachIndex isEqualTo ((count _wps) - 1)) then
        {
            _wp setWaypointCompletionRadius _finalWpRad;
        };
    } forEach _wps;

    if ((count waypoints _grp) > 0) then
    {
        _grp setCurrentWaypoint ((waypoints _grp) select 0);
    };
};

// Helper: find nearest route point index to a given position.
// Used for follower recovery (e.g., u-turn deadlocks) without relying on waypoint indices.
private _fn_nearRouteIdx = {
    params [
        ["_pts", []],
        ["_pos", []],
        ["_default", 0]
    ];

    if (!(_pts isEqualType []) || { (count _pts) == 0 }) exitWith { _default };
    if (!(_pos isEqualType []) || { (count _pos) < 2 }) exitWith { _default };

    private _bestI = _default;
    private _bestD = 1e12;

    for "_i" from 0 to ((count _pts) - 1) do
    {
        private _d = (_pts # _i) distance2D _pos;
        if (_d < _bestD) then { _bestD = _d; _bestI = _i; };
    };

    _bestI
};

private _speedKph = ["activeConvoySpeedKph", missionNamespace getVariable ["ARC_convoySpeedKph", 25]] call ARC_fnc_stateGet;
if (!(_speedKph isEqualType 0)) then { _speedKph = missionNamespace getVariable ["ARC_convoySpeedKph", 25]; };
_speedKph = (_speedKph max 10) min 90;
private _kMax = missionNamespace getVariable ["ARC_convoySpeedKphMax", 45];
if (!(_kMax isEqualType 0)) then { _kMax = 45; };
_kMax = (_kMax max 10) min 120;
_speedKph = _speedKph min _kMax;

private _startPos = ["activeConvoyStartPos", []] call ARC_fnc_stateGet;
if (!(_startPos isEqualType []) || { (count _startPos) < 2 }) then { _startPos = _destPos; };
_startPos = +_startPos; _startPos resize 3;

private _startDir = ["activeConvoyStartDir", -1] call ARC_fnc_stateGet;
if (!(_startDir isEqualType 0)) then { _startDir = -1; };

// Optional link-up: edge-start convoys move to a link-up point, hold, then depart once players arrive.
private _linkupPos = ["activeConvoyLinkupPos", []] call ARC_fnc_stateGet;
if (!(_linkupPos isEqualType []) || { (count _linkupPos) < 2 }) then { _linkupPos = []; } else { _linkupPos = +_linkupPos; _linkupPos resize 3; };
private _linkupReached = ["activeConvoyLinkupReached", false] call ARC_fnc_stateGet;
if (!(_linkupReached isEqualType true) && !(_linkupReached isEqualType false)) then { _linkupReached = false; };
private _hasLinkup = ((count _linkupPos) >= 2);


// A "real" link-up leg exists only when the link-up point is meaningfully separated from the spawn/start.
private _useLinkupLeg = (_hasLinkup && { (_startPos distance2D _linkupPos) > 80 });

// Convoy role plan metadata (for startup breadcrumbs / RPT sanity checks).
private _rolePlan = ["activeConvoyRolePlan", []] call ARC_fnc_stateGet;
if (!(_rolePlan isEqualType [])) then { _rolePlan = []; };

private _rolePlanGet = {
    params ["_pairs", "_key", "_default"];
    if !(_pairs isEqualType []) exitWith {_default};
    private _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 2 } && { ((_x # 0) isEqualType "") && { (toLower (_x # 0)) isEqualTo (toLower _key) } }) exitWith { _idx = _forEachIndex; }; } forEach _pairs;
    if (_idx < 0) exitWith {_default};
    (_pairs # _idx) # 1
};

private _roleBundleId = [_rolePlan, "bundleId", ""] call _rolePlanGet;
if (!(_roleBundleId isEqualType "")) then { _roleBundleId = ""; };
_roleBundleId = toUpper _roleBundleId;

// Optional link-up subtask (created in execInitActive for edge-start convoys)
private _linkTaskId = ["activeConvoyLinkupTaskId", ""] call ARC_fnc_stateGet;
if (!(_linkTaskId isEqualType "")) then { _linkTaskId = ""; };

private _linkTaskDone = ["activeConvoyLinkupTaskDone", false] call ARC_fnc_stateGet;
if (!(_linkTaskDone isEqualType true) && !(_linkTaskDone isEqualType false)) then { _linkTaskDone = false; };

private _setLinkupTaskState = {
    params ["_state"];
    if (!_hasLinkup) exitWith {};
    if (_linkTaskId isEqualTo "") exitWith {};
    if (_linkTaskDone) exitWith {};
    if (!([_linkTaskId] call BIS_fnc_taskExists)) exitWith {};
    [_linkTaskId, _state, true] call BIS_fnc_taskSetState;
    ["activeConvoyLinkupTaskDone", true] call ARC_fnc_stateSet;

	    // Current task is local per-client; broadcast the switch back to the parent convoy task.
	    if (_taskId isNotEqualTo "") then
	    {
	        [_taskId] remoteExecCall ["ARC_fnc_clientSetCurrentTask", 0];
	    };
};

private _nids = ["activeConvoyNetIds", []] call ARC_fnc_stateGet;
if (!(_nids isEqualType [])) then { _nids = []; };

// Rehydrate convoy state if netIds were lost (prevents duplicate spawns).
// Vehicles are tagged by execSpawnConvoy (ARC_convoyTaskId / ARC_convoyIndex).
if ((count _nids) isEqualTo 0) then
{
    private _existing = vehicles select {
        alive _x
        && { (_x getVariable ["ARC_isConvoyVeh", false]) }
        && { (_x getVariable ["ARC_convoyTaskId", ""]) isEqualTo _taskId }
    };

    if ((count _existing) > 0) then
    {
        // Keep lead/tail ordering stable using the stored spawn index.
        private _pairs = _existing apply { [ _x getVariable ["ARC_convoyIndex", 999], _x ] };
        _pairs = [_pairs, [], { _x # 0 }, "ASCEND"] call BIS_fnc_sortBy;
        _existing = _pairs apply { _x # 1 };

        private _ids = _existing apply { netId _x };
        ["activeConvoyNetIds", _ids] call ARC_fnc_stateSet;
        missionNamespace setVariable ["ARC_activeConvoyNetIds", _ids, true];
        _nids = _ids;

        diag_log format ["[ARC][CONVOY] Rehydrated convoy vehicles from world (n=%1) for task %2.", count _existing, _taskId];
    };
};

// If convoy doesn't exist yet, start an async spawn thread (with retry/backoff).
if ((count _nids) isEqualTo 0) then
{
    private _spawning = ["activeConvoySpawning", false] call ARC_fnc_stateGet;
    if (!(_spawning isEqualType true) && !(_spawning isEqualType false)) then { _spawning = false; };

    // Hard lock: prevents double convoy spawns even if state gets rebuilt mid-spawn.
    private _lock = missionNamespace getVariable ["ARC_convoySpawnLock", []];
    private _lockTask = "";
    private _lockIdExisting = "";
    private _lockAt = -1;
    if (_lock isEqualType [] && { (count _lock) >= 3 }) then
    {
        _lockTask = _lock # 0;
        _lockIdExisting = _lock # 1;
        _lockAt = _lock # 2;
    };

    private _lockStaleSec = missionNamespace getVariable ["ARC_convoySpawnLockStaleSec", 240];
    if (!(_lockStaleSec isEqualType 0)) then { _lockStaleSec = 240; };
    _lockStaleSec = (_lockStaleSec max 30) min 1800;

    private _lockValid = (_lockTask isEqualTo _taskId) && { (_lockAt isEqualType 0) && { (_now - _lockAt) < _lockStaleSec } };

    if (_lockValid) then
    {
        // Treat as spawning even if the state flag was reset.
        if (!_spawning) then
        {
            ["activeConvoySpawning", true] call ARC_fnc_stateSet;
            ["activeConvoySpawningSince", _lockAt] call ARC_fnc_stateSet;
        };
        _spawning = true;
    }
    else
    {
        // Clear stale lock if it existed.
        if (_lockTask isNotEqualTo "" && { (_lockAt isEqualType 0) } && { (_now - _lockAt) >= _lockStaleSec }) then
        {
            diag_log format ["[ARC][CONVOY] Clearing stale spawn lock (task=%1, age=%2s).", _lockTask, round (_now - _lockAt)];
            missionNamespace setVariable ["ARC_convoySpawnLock", nil];
        };
    };

    if (!_spawning) then
    {
        private _nextTry = ["activeConvoyNextSpawnAttemptAt", -1] call ARC_fnc_stateGet;
        if (!(_nextTry isEqualType 0)) then { _nextTry = -1; };

        if (_nextTry < 0 || { _now >= _nextTry }) then
        {
            // Enforce "one convoy at a time": if any orphan convoy vehicles from a previous
            // incident still exist (common near the airbase due to deferred cleanup), purge them
            // before staging a new convoy. If a player is inside an old convoy vehicle, delay spawn.
            private _okToSpawn = true;

            private _orphans = vehicles select {
                (!isNull _x)
                && { (_x getVariable ["ARC_isConvoyVeh", false]) }
                // Treat anything not tagged to the current task as an orphan.
                && { (_x getVariable ["ARC_convoyTaskId", ""]) isNotEqualTo _taskId }
            };

            if ((count _orphans) > 0) then
            {
                private _deleteVehicleWithCrew = {
                    params ["_veh"];
                    if (isNull _veh) exitWith {};

                    private _crew = crew _veh;
                    private _groups = [];

                    {
                        if (isNull _x) then { continue; };
                        if (isPlayer _x) then { continue; };
                        private _g = group _x;
                        if (!isNull _g) then { _groups pushBackUnique _g; };
                        deleteVehicle _x;
                    } forEach _crew;

                    deleteVehicle _veh;
                    { if (!isNull _x) then { deleteGroup _x; }; } forEach _groups;
                };

                private _deleted = 0;
                private _blocked = false;

                {
                    private _v = _x;
                    if (isNull _v) then { continue; };

                    // Never delete a convoy vehicle if a player is currently in it.
                    private _crew = crew _v;
                    private _crewHasPlayer = false;
                    { if (isPlayer _x) exitWith { _crewHasPlayer = true; }; } forEach _crew;
                    if (_crewHasPlayer) then
                    {
                        _blocked = true;
                    }
                    else
                    {
                        [_v] call _deleteVehicleWithCrew;
                        _deleted = _deleted + 1;
                    };
                } forEach _orphans;

                if (_deleted > 0) then
                {
                    diag_log format ["[ARC][CONVOY] Purged %1 orphan convoy vehicle(s) before staging a new convoy (task=%2).", _deleted, _taskId];
                };

                if (_blocked) then
                {
                    // Previous convoy assets are still in use by a player.
                    // Respect the one-convoy rule and retry later.
                    private _lastNotice = ["activeConvoyOrphanBlockedNoticeAt", -1] call ARC_fnc_stateGet;
                    if (!(_lastNotice isEqualType 0)) then { _lastNotice = -1; };
                    if (_lastNotice < 0 || { (_now - _lastNotice) > 120 }) then
                    {
                        ["OPS", "Convoy staging delayed: previous convoy assets are still occupied by players. Clear them to stage a new convoy.", _startPos, [["taskId", _taskId], ["event", "CONVOY_ORPHAN_BLOCK"]]] call ARC_fnc_intelLog;
                        ["activeConvoyOrphanBlockedNoticeAt", _now] call ARC_fnc_stateSet;
                    };
                    ["activeConvoyNextSpawnAttemptAt", _now + 30] call ARC_fnc_stateSet;
                    _okToSpawn = false;
                };
            };

            if (_okToSpawn) then
            {
                // Acquire a hard lock so only one spawn thread can run per incident/task.
                private _lockId = str (floor (random 1000000000));
                missionNamespace setVariable ["ARC_convoySpawnLock", [_taskId, _lockId, _now]];

                ["activeConvoySpawning", true] call ARC_fnc_stateSet;
                ["activeConvoySpawningSince", _now] call ARC_fnc_stateSet;

                private _type = ["activeIncidentType", "LOGISTICS"] call ARC_fnc_stateGet;

                diag_log format ["[ARC][CONVOY] Starting spawn thread (task=%1, type=%2, lock=%3).", _taskId, _type, _lockId];

                [_taskId, _type, _startPos, _destWpPos, _speedKph, _startDir, _lockId] spawn
                {
                    params ["_taskId", "_type", "_startPos", "_destWpPos", "_speedKph", "_startDir", "_lockId"];

                    private _releaseLock = {
                        params ["_taskId", "_lockId"];
                        private _l = missionNamespace getVariable ["ARC_convoySpawnLock", []];
                        if (_l isEqualType [] && { (count _l) >= 2 } && { (_l # 0) isEqualTo _taskId } && { (_l # 1) isEqualTo _lockId }) then
                        {
                            missionNamespace setVariable ["ARC_convoySpawnLock", nil];
                        };
                    };

                    // Abort cleanly if the spawn lock was stolen/cleared.
                    private _lNow = missionNamespace getVariable ["ARC_convoySpawnLock", []];
                    if !(_lNow isEqualType [] && { (count _lNow) >= 2 } && { (_lNow # 0) isEqualTo _taskId } && { (_lNow # 1) isEqualTo _lockId }) exitWith
                    {
                        diag_log format ["[ARC][CONVOY] Spawn aborted: lock lost before execution (task=%1, lock=%2).", _taskId, _lockId];
                        ["activeConvoySpawning", false] call ARC_fnc_stateSet;
                        ["activeConvoySpawningSince", -1] call ARC_fnc_stateSet;
                        [_taskId, _lockId] call _releaseLock;
                    };

                    // If the incident was closed/replaced while we were queued, abort cleanly.
                    if ((["activeTaskId", ""] call ARC_fnc_stateGet) isNotEqualTo _taskId) exitWith
                    {
                        ["activeConvoySpawning", false] call ARC_fnc_stateSet;
                        ["activeConvoySpawningSince", -1] call ARC_fnc_stateSet;
                        [_taskId, _lockId] call _releaseLock;
                    };

                    private _spawned = [_type, _startPos, _destWpPos, _speedKph, _startDir, _taskId] call ARC_fnc_execSpawnConvoy;

                    if (_spawned isEqualType [] && { (count _spawned) > 0 }) then
                    {
                        ["activeConvoyNetIds", _spawned] call ARC_fnc_stateSet;
                        ["activeConvoySpawnFailCount", 0] call ARC_fnc_stateSet;
                        ["activeConvoyNextSpawnAttemptAt", -1] call ARC_fnc_stateSet;

                        missionNamespace setVariable ["ARC_activeConvoyNetIds", _spawned, true];

                        // Create link-up point child task only after vehicles are staged and moving.
                        private _parentId = ["activeTaskId", ""] call ARC_fnc_stateGet;
                        private _linkPos = ["activeConvoyLinkupPos", []] call ARC_fnc_stateGet;
                        private _existingLinkId = ["activeConvoyLinkupTaskId", ""] call ARC_fnc_stateGet;

                        private _useLink = (_linkPos isEqualType [] && { (count _linkPos) >= 2 } && { (_startPos distance2D _linkPos) > 75 });
                        if (_useLink && { _existingLinkId isEqualTo "" } && { _parentId isNotEqualTo "" }) then
                        {
                            private _linkTaskId = format ["%1_linkup", _parentId];
                            private _title = "Convoy Link-up";
                            private _desc = "Rendezvous with the convoy at the link-up point. Once on-site and ready, the convoy will continue toward its destination.";
                            [true, [_linkTaskId, _parentId], [_desc, _title, ""], _linkPos, "ASSIGNED", 1, true, "MOVE", false] call BIS_fnc_taskCreate;

	                            // Current task is local per-client; broadcast the link-up child task so it doesn't get hidden behind the parent.
	                            [_linkTaskId] remoteExecCall ["ARC_fnc_clientSetCurrentTask", 0];

                            ["activeConvoyLinkupTaskId", _linkTaskId] call ARC_fnc_stateSet;
                            ["activeConvoyLinkupTaskName", _title] call ARC_fnc_stateSet;
                            ["activeConvoyLinkupReached", false] call ARC_fnc_stateSet;
                        };

                        private _grid = mapGridPosition _startPos;
                        ["OPS", format ["Convoy staged at %1. Move to convoy and initiate movement.", _grid], _startPos, [["taskId", _taskId], ["event", "CONVOY_STAGED"]]] call ARC_fnc_intelLog;
                    }
                    else
                    {
                        private _fails = ["activeConvoySpawnFailCount", 0] call ARC_fnc_stateGet;
                        if (!(_fails isEqualType 0)) then { _fails = 0; };
                        _fails = _fails + 1;
                        ["activeConvoySpawnFailCount", _fails] call ARC_fnc_stateSet;

                        // Backoff is tied to spacing so bigger convoys don't hammer spawns.
                        private _spacingTmp = ["activeConvoySpacingM", missionNamespace getVariable ["ARC_convoySpacingPreLinkupM", 25]] call ARC_fnc_stateGet;
                        if (!(_spacingTmp isEqualType 0)) then { _spacingTmp = 25; };
                        _spacingTmp = (_spacingTmp max 20) min 150;
                        private _backoff = (ceil (_spacingTmp / 10)) max 4;
                        _backoff = _backoff + (_fails * 3);
                        ["activeConvoyNextSpawnAttemptAt", serverTime + _backoff] call ARC_fnc_stateSet;

                        ["OPS", format ["Convoy staging delayed (spawn attempt %1). Retrying in ~%2s.", _fails, _backoff], _startPos, [["taskId", _taskId], ["event", "CONVOY_SPAWN_RETRY"], ["attempt", _fails]]] call ARC_fnc_intelLog;

                        // If repeated failures occur, recommend TOC closure (do not auto-close).
                        private _maxFails = missionNamespace getVariable ["ARC_convoySpawnFailMax", 3];
                        if (!(_maxFails isEqualType 0)) then { _maxFails = 3; };
                        _maxFails = (_maxFails max 1) min 10;
                        if (_fails >= _maxFails) then
                        {
                            ["FAILED", "CONVOY_SPAWN_FAILED", format ["Convoy could not stage after %1 attempts. Recommend closing this incident as FAILED.", _fails], _startPos] call ARC_fnc_incidentMarkReadyToClose;
                        };
                    };

                    ["activeConvoySpawning", false] call ARC_fnc_stateSet;
                    ["activeConvoySpawningSince", -1] call ARC_fnc_stateSet;
                    [] call ARC_fnc_publicBroadcastState;
                    [_taskId, _lockId] call _releaseLock;
                };
            };
        };
    };
};

if ((count _nids) isEqualTo 0) exitWith
{
    ["activeConvoyStartupBreadcrumbsLogged", false] call ARC_fnc_stateSet;
    true
}; // nothing to tick yet

private _vehicles = [];
{
    private _v = objectFromNetId _x;
    if (!isNull _v) then { _vehicles pushBack _v; };
} forEach _nids;

// If everything vanished (restart / cleanup), clear netIds and let the async spawner restage.
if ((count _vehicles) isEqualTo 0) exitWith
{
    ["activeConvoyNetIds", []] call ARC_fnc_stateSet;
    missionNamespace setVariable ["ARC_activeConvoyNetIds", [], true];
    ["activeConvoyNextSpawnAttemptAt", -1] call ARC_fnc_stateSet;
    ["activeConvoySpawning", false] call ARC_fnc_stateSet;
    ["activeConvoySpawningSince", -1] call ARC_fnc_stateSet;
    ["activeConvoyStartupBreadcrumbsLogged", false] call ARC_fnc_stateSet;
    true
};

private _lead = _vehicles # 0;
private _aliveVeh = _vehicles select { alive _x };

// T10: MSR threat awareness — check for CONVOY-targeted threat records near the route.
// Rate-limited internally; read-only (no convoy state mutation).
if ((count _routePts) > 0) then
{
    [_lead, _routePts] call ARC_fnc_execMsrThreatCheck;
};

/*
    Bridge zone handling (mission-maker authored):
      - Create area markers named arc_bridge_01, arc_bridge_02, ...
      - While the convoy lead is inside one of these areas, the watchdog:
          * clamps speed (ARC_convoyBridgeSpeedKph)
          * clamps spacing (ARC_convoyBridgeSpacingM)
          * suppresses off-road bypass recovery behaviors
*/
private _bridgeMarkers = missionNamespace getVariable ["ARC_bridgeMarkers", []];
if !(_bridgeMarkers isEqualType []) then { _bridgeMarkers = []; };
private _bridgeMarkersAvailable = ((count _bridgeMarkers) > 0);

private _bridgeSpeedKph = missionNamespace getVariable ["ARC_convoyBridgeSpeedKph", 18];
if !(_bridgeSpeedKph isEqualType 0) then { _bridgeSpeedKph = 18; };
_bridgeSpeedKph = (_bridgeSpeedKph max 5) min 60;

private _bridgeSpacingM = missionNamespace getVariable ["ARC_convoyBridgeSpacingM", 35];
if !(_bridgeSpacingM isEqualType 0) then { _bridgeSpacingM = 35; };
_bridgeSpacingM = (_bridgeSpacingM max 10) min 150;

// Expand bridge zones slightly so approach/deck transitions still count as "bridge mode".
// This is a code-only solution that avoids hand-editing markers for every bridge.
private _bridgeBufM = missionNamespace getVariable ["ARC_convoyBridgeBufferM", 22];
if !(_bridgeBufM isEqualType 0) then { _bridgeBufM = 22; };
_bridgeBufM = (_bridgeBufM max 0) min 80;

// How far beyond the authored marker we place the final "commit" point.
// If unset, default to a sane value derived from the buffer.
private _bridgeOutsideM = missionNamespace getVariable ["ARC_convoyBridgeAssistOutsideM", -1];
if !(_bridgeOutsideM isEqualType 0) then { _bridgeOutsideM = -1; };
if (_bridgeOutsideM < 0) then
{
    _bridgeOutsideM = (_bridgeBufM max 12) min 35;
};
_bridgeOutsideM = (_bridgeOutsideM max 6) min 60;

// Optional: snap assist points to nearby road segments (helps on some mod bridges).
private _bridgeSnapRoadM = missionNamespace getVariable ["ARC_convoyBridgeAssistRoadSnapM", 10];
if !(_bridgeSnapRoadM isEqualType 0) then { _bridgeSnapRoadM = 10; };
_bridgeSnapRoadM = (_bridgeSnapRoadM max 0) min 40;

private _fn_bridgeMarkerAtPos = {
    params [["_pos", []]];
    if ((count _bridgeMarkers) isEqualTo 0) exitWith { "" };
    if (!(_pos isEqualType []) || { (count _pos) < 2 }) exitWith { "" };

    private _p = +_pos; _p resize 3;

    private _idx = -1;
    {
        private _mk = _x;
        private _matched = false;

        if (_bridgeBufM <= 0) then {
            _matched = _p inArea _mk;
        } else {
            if (_mk in allMapMarkers) then {
                private _c = getMarkerPos _mk;
                private _sz = markerSize _mk;
                if ((_sz isEqualType []) && { (count _sz) >= 2 }) then {
                    private _a = (_sz # 0) + _bridgeBufM;
                    private _b = (_sz # 1) + _bridgeBufM;
                    private _dir = markerDir _mk;
                    private _shape = markerShape _mk;
                    if (!(_shape isEqualType "")) then { _shape = "RECTANGLE"; };
                    private _isRect = ((toUpper _shape) isEqualTo "RECTANGLE");
                    _matched = _p inArea [_c, _a, _b, _dir, _isRect];
                };
            };
        };

        if (_matched) exitWith { _idx = _forEachIndex; };
    } forEach _bridgeMarkers;

    if (_idx < 0) exitWith { "" };
    _bridgeMarkers # _idx
};

private _fn_isInBridgeZone = {
    params [["_pos", []]];
    !(([_pos] call _fn_bridgeMarkerAtPos) isEqualTo "")
};

// Fallback chokepoint mode (only used when bridge markers are unavailable).
private _bridgeFallbackEnabled = missionNamespace getVariable ["ARC_convoyBridgeFallbackChokepointEnabled", true];
if (!(_bridgeFallbackEnabled isEqualType true) && !(_bridgeFallbackEnabled isEqualType false)) then { _bridgeFallbackEnabled = true; };

private _bridgeFallbackHoldSec = missionNamespace getVariable ["ARC_convoyBridgeFallbackHoldSec", 70];
if !(_bridgeFallbackHoldSec isEqualType 0) then { _bridgeFallbackHoldSec = 70; };
_bridgeFallbackHoldSec = (_bridgeFallbackHoldSec max 20) min 240;

/*
    Deterministic bridge/chokepoint fallback micro-route from authored road route points.
    Used when marker-based bridge geometry is missing (e.g., fallback_chokepoint mode).

    Returns: ARRAY of 3D positions, forward-biased from lead index.
*/
private _fn_bridgeFallbackRoutePoints = {
    params [
        ["_fromPos", []],
        ["_toPos", []]
    ];

    if (!(_routePts isEqualType []) || { (count _routePts) < 2 }) exitWith { [] };

    private _nearIdx = 0;
    if (_fromPos isEqualType [] && { (count _fromPos) >= 2 }) then
    {
        _nearIdx = [_routePts, _fromPos, 0] call _fn_nearRouteIdx;
    };

    private _exitIdx = ((count _routePts) - 1) min (_nearIdx + 8);
    if (_toPos isEqualType [] && { (count _toPos) >= 2 }) then
    {
        private _toIdx = [_routePts, _toPos, ((count _routePts) - 1)] call _fn_nearRouteIdx;
        _exitIdx = (_toIdx max (_nearIdx + 2)) min ((count _routePts) - 1);
    };

    private _step = missionNamespace getVariable ["ARC_convoyBridgeFallbackStepPts", 2];
    if !(_step isEqualType 0) then { _step = 2; };
    _step = (_step max 1) min 4;

    private _pts = [];
    for "_i" from (_nearIdx + 1) to _exitIdx step _step do
    {
        private _p = +(_routePts # _i);
        _p resize 3;
        if ((count _pts) isEqualTo 0 || { (_p distance2D (_pts # ((count _pts) - 1))) > 18 }) then
        {
            _pts pushBack _p;
        };
    };

    // Guarantee at least one forward target if spacing/step collapsed sampling.
    if ((count _pts) isEqualTo 0) then
    {
        private _fIdx = (_nearIdx + 2) min ((count _routePts) - 1);
        private _pF = +(_routePts # _fIdx);
        _pF resize 3;
        _pts pushBack _pF;
    };

    _pts
};

/*
    Bridge assist helper:
      Some terrain bridges (and mod bridges) produce AI deadlocks even when a road route exists.
      When a convoy vehicle stalls inside/near an arc_bridge_* marker, we can inject a short micro-route
      along the bridge marker centerline to help the vehicle "commit" and clear the chokepoint.

    Returns: ARRAY of 3D positions (ordered toward the likely exit).
*/
private _fn_bridgeAssistPoints = {
    params [
        ["_mk", ""],
        ["_toPos", []],
        ["_fromPos", []]
    ];

    if (!(_mk isEqualType "") || { _mk isEqualTo "" }) exitWith { [] };
    if (_mk isEqualTo "fallback_chokepoint") exitWith
    {
        [_fromPos, _toPos] call _fn_bridgeFallbackRoutePoints
    };
    if !(_mk in allMapMarkers) exitWith { [] };

    private _c = getMarkerPos _mk;
    _c resize 3;

    private _dir = markerDir _mk;
    if (!(_dir isEqualType 0)) then { _dir = 0; };

    private _sz = markerSize _mk;
    if (!(_sz isEqualType []) || { (count _sz) < 2 }) exitWith { [] };

    private _a = (_sz # 0) max 1;
    private _b = (_sz # 1) max 1;

    // Determine the bridge axis (long side of the rectangle marker).
    private _axisDir = _dir;
    private _halfLen = _a;
    if (_b > _a) then
    {
        _axisDir = (_dir + 90) % 360;
        _halfLen = _b;
    };

    // Inside endpoints along the axis.
    private _endInF = _c getPos [_halfLen * 0.92, _axisDir];
    _endInF resize 3;
    private _endInB = _c getPos [_halfLen * 0.92, (_axisDir + 180) % 360];
    _endInB resize 3;

    // Choose an exit endpoint biased toward the destination.
    private _exitIn = _endInF;
    if (_toPos isEqualType [] && { (count _toPos) >= 2 }) then
    {
        _exitIn = if ((_endInF distance2D _toPos) <= (_endInB distance2D _toPos)) then { _endInF } else { _endInB };
    };

    private _dirToExit = _axisDir;
    if (_exitIn isEqualTo _endInB) then { _dirToExit = (_axisDir + 180) % 360; };

    private _entryIn = if (_exitIn isEqualTo _endInF) then { _endInB } else { _endInF };

    // Outside endpoints (slightly beyond the marker) to encourage a "leap of faith".
    private _exitOut  = _c getPos [_halfLen + _bridgeOutsideM, _dirToExit];
    _exitOut resize 3;
    private _entryOut = _c getPos [_halfLen + _bridgeOutsideM, (_dirToExit + 180) % 360];
    _entryOut resize 3;

    // Candidate points along the axis toward the exit.
    private _p1 = _c getPos [_halfLen * 0.20, _dirToExit]; _p1 resize 3;
    private _p2 = _c getPos [_halfLen * 0.55, _dirToExit]; _p2 resize 3;
    private _p3 = _c getPos [_halfLen * 0.88, _dirToExit]; _p3 resize 3;

    private _candidates = [_entryOut, _entryIn, _p1, _p2, _p3, _exitIn, _exitOut];

    // Optional road snap (kept tight to avoid yanking points off the bridge deck).
    if (_bridgeSnapRoadM > 0) then
    {
        private _snapped = [];
        {
            private _p = +_x; _p resize 3;
            private _roads = _p nearRoads _bridgeSnapRoadM;
            if ((count _roads) > 0) then
            {
                private _r = _roads # 0;
                if (!isNull _r) then
                {
                    _p = getPosATL _r;
                    _p resize 3;
                };
            };
            _snapped pushBack _p;
        } forEach _candidates;
        _candidates = _snapped;
    };

    // Order points based on projection along the entry->exit axis.
    private _ls = +_entryOut; _ls resize 3;
    private _le = +_exitOut;  _le resize 3;
    private _ab = _le vectorDiff _ls;
    private _den = _ab vectorDotProduct _ab;
    if (_den < 0.001) exitWith { [] };

    private _tFrom = -1;
    if (_fromPos isEqualType [] && { (count _fromPos) >= 2 }) then
    {
        private _fp = +_fromPos; _fp resize 3;
        private _af = _fp vectorDiff _ls;
        _tFrom = (_af vectorDotProduct _ab) / _den;
    };

    private _pairs = [];
    {
        private _p = +_x; _p resize 3;
        private _ap = _p vectorDiff _ls;
        private _t = (_ap vectorDotProduct _ab) / _den;

        // Keep points that are at/after the vehicle's current progress on the axis (avoid backtracking).
        if (_tFrom < 0 || { _t >= (_tFrom - 0.06) }) then
        {
            _pairs pushBack [_t, _p];
        };
    } forEach _candidates;

    _pairs sort true;

    private _pts = [];
    {
        _x params ["_t", "_p"];
        if ((count _pts) isEqualTo 0 || { (_p distance2D (_pts # ((count _pts) - 1))) > 8 }) then
        {
            _pts pushBack _p;
        };
    } forEach _pairs;

    _pts
};
if (!alive _lead) exitWith
{
    ["FAILED"] call _setLinkupTaskState;
    ["FAILED", "CONVOY_LEAD_KILLED", "Convoy lead vehicle destroyed. Recommend closing this incident as FAILED.", getPosATL _lead] call ARC_fnc_incidentMarkReadyToClose;
    true
};

if ((count _aliveVeh) isEqualTo 0) exitWith
{
    ["FAILED"] call _setLinkupTaskState;
    ["FAILED", "CONVOY_DESTROYED", "Convoy destroyed. Recommend closing this incident as FAILED.", _startPos] call ARC_fnc_incidentMarkReadyToClose;
    true
};

// Normalize convoy groups (critical reliability fix)
// Symptom addressed:
//   - Each vehicle retains its own default group marker
//   - Only the lead group receives waypoints, causing the rest to sit idle
//
// We ensure every convoy vehicle's crew is merged into the lead vehicle's group.
// This makes convoy routing and link-up phase logic deterministic.
private _fn_normalizeConvoyGroups = {
    params ["_vehArr", "_leadVeh"];

    if (!(_vehArr isEqualType []) || { (count _vehArr) == 0 } || { isNull _leadVeh }) exitWith { grpNull };

    // Ensure lead has crew and an accessible commander unit.
    if (isNull (driver _leadVeh)) then { createVehicleCrew _leadVeh; };
    private _ld = driver _leadVeh;
    if (isNull _ld) then { _ld = effectiveCommander _leadVeh; };
    if (isNull _ld) exitWith { grpNull };

    private _gLead = group _ld;
    if (isNull _gLead) exitWith { grpNull };

    {
        private _veh = _x;
        if (!isNull _veh && { alive _veh }) then
        {
            if (isNull (driver _veh)) then { createVehicleCrew _veh; };
            private _d = driver _veh;
            if (isNull _d) then { _d = effectiveCommander _veh; };

            if (!isNull _d) then
            {
                private _g = group _d;
                if (!(_g isEqualTo _gLead)) then
                {
                    private _crew = crew _veh;
                    private _crewAI = _crew select { !isPlayer _x };
                    if ((count _crewAI) > 0) then { _crewAI joinSilent _gLead; };

                    // Clean up empty transient groups to reduce clutter.
                    if (!isNull _g && { !(_g isEqualTo _gLead) } && { (count units _g) == 0 }) then
                    {
                        deleteGroup _g;
                    };
                };
            };
        };
    } forEach _vehArr;

    _gLead
};

private _leadGrp = [_vehicles, _lead] call _fn_normalizeConvoyGroups;

// Start condition: friendly players near convoy start or lead vehicle.
private _startedAt = ["activeConvoyStartedAt", -1] call ARC_fnc_stateGet;
private _started = (_startedAt isEqualType 0 && { _startedAt > 0 });

// If convoy has not started its main route, we either:
//   - (optional) move from edge spawn to link-up point and hold
//   - wait at staging/link-up for players, then depart after a delay
if (!_started) exitWith
{
    private _forceRoad = missionNamespace getVariable ["ARC_convoyForceFollowRoad", true];
    if (!(_forceRoad isEqualType false) && !(_forceRoad isEqualType true)) then { _forceRoad = true; };

    private _spacing = ["activeConvoySpacingM", missionNamespace getVariable ["ARC_convoySpacingPreLinkupM", 25]] call ARC_fnc_stateGet;
    if (!(_spacing isEqualType 0)) then { _spacing = missionNamespace getVariable ["ARC_convoySpacingPreLinkupM", 25]; };
    _spacing = (_spacing max 20) min 150;

    // Bypass window handling also applies while moving to link-up.
    private _bypassUntilP = ["activeConvoyBypassUntil", -1] call ARC_fnc_stateGet;
    if (!(_bypassUntilP isEqualType 0)) then { _bypassUntilP = -1; };
    if (_bypassUntilP > 0 && { _now >= _bypassUntilP }) then
    {
        { private _d = driver _x; if (!isNull _d) then { _d forceFollowRoad true; }; } forEach _vehicles;
        ["activeConvoyBypassUntil", -1] call ARC_fnc_stateSet;
        _bypassUntilP = -1;
    };
    private _bypassActiveP = (_bypassUntilP > 0 && { _now < _bypassUntilP });

    // --- Link-up column slotting -------------------------------------------------
    // When holding at link-up, vehicles should stay in their place in the column.
    // We assign each vehicle a unique slot (lead at link-up, others spaced behind along marker direction)
    // and lock them individually once they arrive. This prevents tail vehicles from "creeping" forward.

    private _fn_nearestRoadPosLocal = {
        params [
            ["_pos", []],
            ["_radius", 60]
        ];

        if (!(_pos isEqualType []) || { (count _pos) < 2 }) exitWith { _pos };
        private _r = (_radius max 20) min 300;
        private _roads = _pos nearRoads _r;
        if ((count _roads) isEqualTo 0) exitWith { _pos };

        private _best = objNull;
        private _bestD = 1e12;
        {
            private _rp = getPosATL _x;
            private _d = _pos distance2D _rp;
            if (_d < _bestD) then { _bestD = _d; _best = _x; };
        } forEach _roads;

        if (isNull _best) exitWith { _pos };
        private _p = getPosATL _best;
        _p resize 3;
        _p
    };

    private _fn_getLinkupHoldDir = {
        params [
            ["_fallbackDir", -1]
        ];

        private _dir = _fallbackDir;

        // Prefer editor-set direction of the preset link-up marker.
        private _mk = ["activeConvoyLinkupMarker", ""] call ARC_fnc_stateGet;
        if (_mk isEqualType "" && { _mk isNotEqualTo "" } && { _mk in allMapMarkers }) then
        {
            _dir = markerDir _mk;
        };

        // Fall back: direction from start to link-up.
        if (!(_dir isEqualType 0) || { _dir < 0 }) then
        {
            _dir = (_startPos getDir _linkupPos);
        };

        (_dir % 360)
    };

    private _fn_enforceLinkupSlots = {
        params [
            ["_vehArr", []],
            ["_linkPos", []],
            ["_spacingM", 25],
            ["_dirOut", 0],
            ["_speedKph", 25],
            ["_forceRoad", true],
            ["_bypassActive", false]
        ];

        if (!(_vehArr isEqualType []) || { (count _vehArr) == 0 }) exitWith {};
        if (!(_linkPos isEqualType []) || { (count _linkPos) < 2 }) exitWith {};

        private _slotRad = missionNamespace getVariable ["ARC_convoyLinkupSlotRadiusM", 12];
        if (!(_slotRad isEqualType 0)) then { _slotRad = 12; };
        _slotRad = (_slotRad max 6) min 25;

        private _snapR = missionNamespace getVariable ["ARC_convoyLinkupSlotSnapM", 40];
        if (!(_snapR isEqualType 0)) then { _snapR = 40; };
        _snapR = (_snapR max 20) min 120;

        private _prevDrv = objNull;

        for "_i" from 0 to ((count _vehArr) - 1) do
        {
            private _v = _vehArr # _i;
            if (isNull _v || { !alive _v }) then { continue; };

            if (isNull (driver _v)) then { createVehicleCrew _v; };
            private _d = driver _v;
            if (isNull _d) then { _d = effectiveCommander _v; };
            if (isNull _d) then { continue; };

            // Slot position: lead at link-up, others spaced behind along OUTBOUND direction.
            private _tgt = _linkPos;
            if (_i > 0) then
            {
                _tgt = _linkPos getPos [_spacingM * _i, ((_dirOut + 180) % 360)];
                _tgt resize 3;
            };

            _tgt = [_tgt, _snapR] call _fn_nearestRoadPosLocal;

            private _dist = _v distance2D _tgt;

            // If a player is driving, never try to hard-stop them.
            private _isP = isPlayer _d;

            if (_dist <= _slotRad) then
            {
                if (!_isP) then
                {
                    _d stop true;
                };
                _v setFuel 0;
                _v limitSpeed 0;
            }
            else
            {
                if (!_isP) then
                {
                    _d stop false;
                };

                _v setFuel 1;
                _v limitSpeed (_speedKph max 10);
                _v setConvoySeparation _spacingM;

                if (_forceRoad && { !_bypassActive }) then
                {
                    _d forceFollowRoad true;
                };

                // Follow the vehicle in front (spawn-clearance + column roll-in).
                if (!isNull _prevDrv && { !_isP }) then
                {
                    _d doFollow _prevDrv;
                };

                _d doMove _tgt;
            };

            _prevDrv = _d;
        };
    };

    // Phase 1: move to link-up point (edge-start convoys only).
    if (_useLinkupLeg && { !_linkupReached }) then
    {
        // Ensure the convoy can move.
        {
            if (!isNull _x && { alive _x }) then
            {
                _x setFuel 1;
                _x limitSpeed _speedKph;
                _x setConvoySeparation _spacing;
            };
        } forEach _vehicles;

        if (_forceRoad && { !_bypassActiveP }) then
        {
            { private _d = driver _x; if (!isNull _d) then { _d forceFollowRoad true; }; } forEach _vehicles;
        };

        // Ensure lead has a valid group.
        if (isNull (driver _lead)) then { createVehicleCrew _lead; };
        private _drvL = driver _lead;
        private _grpL = if (!isNull _drvL) then { group _drvL } else { grpNull };
        if (isNull _grpL) then
        {
            diag_log "[ARC][CONVOY] Linkup: lead has no valid group; creating fallback WEST group.";
            _grpL = createGroup [west, true];
            {
                private _crewAI = (crew _x) select { !isPlayer _x };
                if ((count _crewAI) > 0) then { _crewAI joinSilent _grpL; };
            } forEach _vehicles;
        };

        // Linkup: enforce column formation
        _grpL setFormation "COLUMN";
        _grpL setSpeedMode "NORMAL";
        // Never rename a player group; keep TOC/role gating stable even if a player drives convoy assets.
        private _hasPlayerL = false;
        { if (isPlayer _x) exitWith { _hasPlayerL = true; }; } forEach (units _grpL);
        if (!_hasPlayerL) then { [_grpL, "CONVOY"] call ARC_fnc_groupSetDesignation; };

        // Drive each vehicle into a unique slot at the link-up point.
        // This avoids group waypoint "wait for formation" behavior, and keeps the column clean.
        while { (count waypoints _grpL) > 0 } do { deleteWaypoint ((waypoints _grpL) select 0); };

        private _holdDir = [_startDir] call _fn_getLinkupHoldDir;
        [_vehicles, _linkupPos, _spacing, _holdDir, _speedKph, _forceRoad, _bypassActiveP] call _fn_enforceLinkupSlots;

        // Minimal stuck recovery while moving to link-up.
        // The full watchdog only runs once the convoy starts its main route.
        private _stuckSecL = missionNamespace getVariable ["ARC_convoyStuckSec", 45];
        if (!(_stuckSecL isEqualType 0)) then { _stuckSecL = 45; };
        _stuckSecL = (_stuckSecL max 15) min 300;

        private _lastMoveAtL = ["activeConvoyLastMoveAt", _now] call ARC_fnc_stateGet;
        if (!(_lastMoveAtL isEqualType 0)) then { _lastMoveAtL = _now; };

        private _lastMovePosL = ["activeConvoyLastMovePos", getPosATL _lead] call ARC_fnc_stateGet;
        if (!(_lastMovePosL isEqualType []) || { (count _lastMovePosL) < 2 }) then { _lastMovePosL = getPosATL _lead; };
        _lastMovePosL = +_lastMovePosL; _lastMovePosL resize 3;

        private _curPosL = getPosATL _lead;
        _curPosL = +_curPosL; _curPosL resize 3;
        // Treat the convoy as "moving" if either it has displaced meaningfully, or it
        // is still rolling at speed (tight corners can otherwise look like a stall).
        private _movedL = ((_curPosL distance2D _lastMovePosL) > 8) || { (speed _lead) > 6 };

        if (_movedL) then
        {
            ["activeConvoyLastMoveAt", _now] call ARC_fnc_stateSet;
            ["activeConvoyLastMovePos", _curPosL] call ARC_fnc_stateSet;
        }
        else
        {
            private _stuckForL = _now - _lastMoveAtL;
            private _lastRecL = ["activeConvoyLastRecoveryAt", -1] call ARC_fnc_stateGet;
            if (!(_lastRecL isEqualType 0)) then { _lastRecL = -1; };

            if (_stuckForL >= _stuckSecL && { (_lastRecL < 0) || { (_now - _lastRecL) >= 60 } }) then
            {
                ["activeConvoyLastRecoveryAt", _now] call ARC_fnc_stateSet;

                while { (count waypoints _grpL) > 0 } do { deleteWaypoint ((waypoints _grpL) select 0); };

                private _holdDir = [_startDir] call _fn_getLinkupHoldDir;
                [_vehicles, _linkupPos, _spacing, _holdDir, _speedKph, _forceRoad, _bypassActiveP] call _fn_enforceLinkupSlots;


                // If it's a prolonged stall, briefly allow the lead to go off-road to break deadlocks.
                // Suppress this behavior on marked bridge zones (arc_bridge_*), where off-road attempts often worsen failures.
                private _bridgeHereL = [_curPosL] call _fn_isInBridgeZone;
                if (!_bridgeHereL && { _stuckForL >= (_stuckSecL * 2) }) then
                {
                    private _dBy = driver _lead;
                    if (!isNull _dBy) then { _dBy forceFollowRoad false; };
                    ["activeConvoyBypassUntil", _now + 20] call ARC_fnc_stateSet;
                };

                ["OPS", format ["Convoy link-up recovery executed after %1s stall.", round _stuckForL], _curPosL, [["event", "CONVOY_LINKUP_RECOVER"], ["taskId", _taskId]]] call ARC_fnc_intelLog;
            };
        };

        // When the lead reaches the link-up, transition into a slotted hold.
        // Do NOT freeze the entire convoy at once; allow each vehicle to roll into its slot.
        if ((_lead distance2D _linkupPos) <= 35) then
        {
            ["activeConvoyLinkupReached", true] call ARC_fnc_stateSet;
            ["activeConvoyDetectedAt", -1] call ARC_fnc_stateSet;
            ["activeConvoyDepartAt", -1] call ARC_fnc_stateSet;

            // Clear group waypoints so the AI doesn't attempt to reshuffle the column.
            while { (count waypoints _grpL) > 0 } do { deleteWaypoint ((waypoints _grpL) select 0); };

            // Slot vehicles and lock those that have arrived.
            private _holdDir = [_startDir] call _fn_getLinkupHoldDir;
            [_vehicles, _linkupPos, _spacing, _holdDir, _speedKph, _forceRoad, _bypassActiveP] call _fn_enforceLinkupSlots;

            ["OPS", "Convoy reached link-up point and is holding for escort.", _linkupPos, [["event", "CONVOY_LINKUP_HOLD"], ["taskId", _taskId]]] call ARC_fnc_intelLog;

            if ("ARC_convoy_linkup_active" in allMapMarkers) then
            {
                "ARC_convoy_linkup_active" setMarkerText "Convoy Link-up (Holding)";
                "ARC_convoy_linkup_active" setMarkerAlpha 0.95;
            };
        };

        true;
    };


    // If we are holding at the link-up, keep the column slotted while waiting for players.
    if (_hasLinkup && { _linkupReached }) then
    {
        private _holdDir = [_startDir] call _fn_getLinkupHoldDir;
        [_vehicles, _linkupPos, _spacing, _holdDir, _speedKph, _forceRoad, _bypassActiveP] call _fn_enforceLinkupSlots;
    };

    // Phase 2: staging/link-up hold -> depart after player detection + delay.
    private _players = allPlayers select { alive _x && { side group _x in [west, independent] } };
    if ((count _players) isEqualTo 0) then { _players = allPlayers select { alive _x }; };

    private _detectPos = if (_hasLinkup) then { _linkupPos } else { _startPos };
    private _detectR = missionNamespace getVariable ["ARC_convoyDetectRadiusM", 260];
    if (!(_detectR isEqualType 0)) then { _detectR = 260; };
    _detectR = (_detectR max 120) min 800;

    private _near = false;
    { if ((_x distance2D _detectPos) <= _detectR || { (_x distance2D _lead) <= ((_detectR min 250) max 160) }) exitWith { _near = true; }; } forEach _players;

    // Delay between first player detection and actual departure (gives time to stage).
    private _delay = missionNamespace getVariable ["ARC_convoyDepartDelaySec", 60];
    if (!(_delay isEqualType 0)) then { _delay = 60; };
    _delay = (_delay max 0) min 600;

    private _detectedAt = ["activeConvoyDetectedAt", -1] call ARC_fnc_stateGet;
    private _departAt   = ["activeConvoyDepartAt", -1] call ARC_fnc_stateGet;

    private _detected = (_detectedAt isEqualType 0 && { _detectedAt > 0 });

    // When a player first enters the staging radius, start the departure timer.
    if (_near && { !_detected }) then
    {
        _detectedAt = _now;
        _departAt = _now + _delay;

        ["activeConvoyDetectedAt", _detectedAt] call ARC_fnc_stateSet;
        ["activeConvoyDepartAt", _departAt] call ARC_fnc_stateSet;

        // Link-up task completes when players arrive at the link-up/staging area.
        if (_hasLinkup) then
        {
            ["SUCCEEDED"] call _setLinkupTaskState;
        };

        if (missionNamespace getVariable ["ARC_debugHints", true]) then
        {
            private _targets = _players select {
                (_x distance2D _detectPos) <= _detectR
                || { (_x distance2D _lead) <= ((_detectR min 250) max 160) }
            };

            private _msg = if (_hasLinkup) then
            {
                format ["Convoy link-up confirmed. Departing in %1 seconds.", round _delay]
            }
            else
            {
                format ["Convoy staged. Departing in %1 seconds.", round _delay]
            };

            { [_msg, "ARC_convoy_linkup_detected", 12] remoteExec ["ARC_fnc_clientHint", owner _x]; } forEach _targets;
        };

        private _logPos = _detectPos;
        ["OPS", format ["Convoy detected at staging area. Departure in %1s.", round _delay], _logPos, [["event", "CONVOY_DETECTED"], ["taskId", _taskId]]] call ARC_fnc_intelLog;
    };

    // Auto-launch (safety) only for non-linkup convoys.
    private _createdAt = ["activeIncidentCreatedAt", _now] call ARC_fnc_stateGet;
    if (!(_createdAt isEqualType 0)) then { _createdAt = _now; };
    private _autoLaunch = (!_hasLinkup) && { ((_now - _createdAt) > (8 * 60)) };

    // Start only after the delay has elapsed AND players are still near (unless auto-launched).
    private _ready = _autoLaunch;
    if (!_ready) then
    {
        _ready = (_near && { _departAt isEqualType 0 && { _departAt > 0 } && { _now >= _departAt } });
    };

    if (_ready) then
    {
        // Switch to post-linkup spacing once departing (convoy opens up after link-up).
        private _sepPost = missionNamespace getVariable ["ARC_convoySpacingPostLinkupM", missionNamespace getVariable ["ARC_convoySpacingM", 59]];
        if (!(_sepPost isEqualType 0)) then { _sepPost = missionNamespace getVariable ["ARC_convoySpacingM", 59]; };
        _sepPost = (_sepPost max 20) min 150;
        ["activeConvoySpacingM", _sepPost] call ARC_fnc_stateSet;
        _spacing = _sepPost;

        {
            if (!isNull _x) then
            {
                _x setFuel 1;
                _x limitSpeed _speedKph;
                _x setConvoySeparation _spacing;
            };
        } forEach _vehicles;

        // Clear any link-up hold stops so AI can accept new waypoints.
        {
            private _d = driver _x;
            if (!isNull _d && { !isPlayer _d }) then { _d stop false; };
        } forEach _vehicles;

        ["activeConvoyDetectedAt", -1] call ARC_fnc_stateSet;
        ["activeConvoyDepartAt", -1] call ARC_fnc_stateSet;

        if (isNull (driver _lead)) then { createVehicleCrew _lead; };
        private _drv = driver _lead;
        private _grp = grpNull;
        if (!isNull _drv) then { _grp = group _drv; };

        if (isNull _grp) then
        {
            diag_log "[ARC][CONVOY] Lead vehicle has no valid group; creating fallback WEST group for convoy.";
            _grp = createGroup [west, true];
            {
                private _crewAI = (crew _x) select { !isPlayer _x };
                if ((count _crewAI) > 0) then { _crewAI joinSilent _grp; };
            } forEach _vehicles;
        };

        // Depart: enforce column formation
        _grp setFormation "COLUMN";
        _grp setSpeedMode "LIMITED";
        // Never rename a player group; keep TOC/role gating stable even if a player drives convoy assets.
        private _hasPlayerD = false;
        { if (isPlayer _x) exitWith { _hasPlayerD = true; }; } forEach (units _grp);
        if (!_hasPlayerD) then { [_grp, "CONVOY"] call ARC_fnc_groupSetDesignation; };

        // Keep the convoy on roads.
        if (_forceRoad && { !_bypassActiveP }) then
        {
            { private _d = driver _x; if (!isNull _d) then { _d forceFollowRoad true; }; } forEach _vehicles;
        };

        // Push a multi-waypoint road route.
        [_grp, _routePts, _destWpPos, _destRad, _ingressPos] call _fn_applyRouteWps;

        ["activeConvoyStartedAt", _now] call ARC_fnc_stateSet;
        ["activeConvoyArrivedAt", -1] call ARC_fnc_stateSet;
        ["activeConvoyLastProg", -1] call ARC_fnc_stateSet;

        ["activeConvoyLastMoveAt", _now] call ARC_fnc_stateSet;
        ["activeConvoyLastMovePos", getPosATL _lead] call ARC_fnc_stateSet;
        ["activeConvoyLastRecoveryAt", -1] call ARC_fnc_stateSet;
        ["activeConvoyBypassUntil", -1] call ARC_fnc_stateSet;

        ["activeExecActivated", true] call ARC_fnc_stateSet;
        ["activeExecActivatedAt", _now] call ARC_fnc_stateSet;

        private _gridS = mapGridPosition _detectPos;
        private _gridD = mapGridPosition _destPos;
        ["OPS", format ["Convoy departed %1 en route to %2. Task %3.", _gridS, _gridD, _taskId], _detectPos, [["event", "CONVOY_DEPARTED"], ["speedKph", round _speedKph], ["taskId", _taskId]]] call ARC_fnc_intelLog;

        if (missionNamespace getVariable ["ARC_debugHints", true]) then
        {
            private _hintTargets = if (_near) then
            {
                _players select {
                    (_x distance2D _detectPos) <= _detectR
                    || { (_x distance2D _lead) <= ((_detectR min 250) max 160) }
                }
            }
            else
            {
                +_players
            };

            private _hintMsg = if (_near) then
            {
                format ["Convoy departing now. Speed cap: %1 kph.", round _speedKph]
            }
            else
            {
                format ["Convoy auto-launched (timeout). Speed cap: %1 kph.", round _speedKph]
            };

            {
                private _hintKey = if (_near) then { "ARC_convoy_departing_now" } else { "ARC_convoy_autolaunch_now" };
                private _hintCooldown = if (_near) then { 10 } else { 15 };
                [_hintMsg, _hintKey, _hintCooldown] remoteExec ["ARC_fnc_clientHint", owner _x];
            } forEach _hintTargets;
        };

        if ("ARC_convoy_linkup_active" in allMapMarkers) then
        {
            "ARC_convoy_linkup_active" setMarkerText "Convoy Link-up (Departed)";
            "ARC_convoy_linkup_active" setMarkerAlpha 0.45;
        };
    };

    true;
};

// --- Convoy watchdog ------------------------------------------------------------
// Ensures the convoy always has a valid waypoint (visible in Zeus) and recovers from stalls.
// This specifically targets cases where AI deadlocks on road obstacles (barriers/traffic).
private _bypassUntil = ["activeConvoyBypassUntil", -1] call ARC_fnc_stateGet;
if (!(_bypassUntil isEqualType 0)) then { _bypassUntil = -1; };
if (_bypassUntil > 0 && { _now >= _bypassUntil }) then
{
    // Restore road-following after a bypass window.
    {
        private _d = driver _x;
        if (!isNull _d) then { _d forceFollowRoad true; };
    } forEach _vehicles;

    ["activeConvoyBypassUntil", -1] call ARC_fnc_stateSet;
    _bypassUntil = -1;
};

// Re-assert road following frequently. Certain pathing recoveries or driver swaps can cause
// drivers to ignore the road network even after we originally set forceFollowRoad.
private _forceRoadW = missionNamespace getVariable ["ARC_convoyForceFollowRoad", true];
if (!(_forceRoadW isEqualType false) && !(_forceRoadW isEqualType true)) then { _forceRoadW = true; };
if (_forceRoadW) then
{
    private _globalBypass = (_bypassUntil isEqualType 0 && { _bypassUntil > 0 } && { _now < _bypassUntil });
    {
        private _d = driver _x;
        if (!isNull _d) then
        {
            private _vb = _x getVariable ["ARC_convoyVehBypassUntil", -1];
            if (!(_vb isEqualType 0)) then { _vb = -1; };
            private _vehBypass = (_vb > 0 && { _now < _vb });
            if (!(_globalBypass || _vehBypass)) then { _d forceFollowRoad true; };
        };
    } forEach _vehicles;
};

private _drvW = driver _lead;
if (isNull _drvW) then
{
    createVehicleCrew _lead;
    _drvW = driver _lead;
};

private _grpW = grpNull;
if (!isNull _drvW) then { _grpW = group _drvW; };

if (isNull _grpW) then
{
    diag_log "[ARC][CONVOY] Watchdog: lead has no valid group; creating fallback WEST group.";
    _grpW = createGroup [west, true];
    {
        private _crewAI = (crew _x) select { !isPlayer _x };
        if ((count _crewAI) > 0) then { _crewAI joinSilent _grpW; };
    } forEach _vehicles;
};

// Watchdog: enforce column formation
_grpW setFormation "COLUMN";
_grpW setSpeedMode "LIMITED";
// Never rename a player group; keep TOC/role gating stable even if a player drives convoy assets.
private _hasPlayerW = false;
{ if (isPlayer _x) exitWith { _hasPlayerW = true; }; } forEach (units _grpW);
if (!_hasPlayerW) then { [_grpW, "CONVOY"] call ARC_fnc_groupSetDesignation; };

// Keep the group leader in the lead vehicle when possible (helps formation consistency).
if ((count _aliveVeh) > 0) then
{
    private _drvLead = driver (_aliveVeh # 0);
    if (!isNull _drvLead && { leader _grpW != _drvLead }) then { _grpW selectLeader _drvLead; };

    // Safety: clear any residual STOP locks (e.g., from link-up hold) once the convoy is moving.
    {
        private _d = driver _x;
        if (!isNull _d && { !isPlayer _d }) then { _d stop false; };
    } forEach _aliveVeh;
};



/*
    Bridge zone profile:
      If the mission defines arc_bridge_* area markers, treat them as bridge chokepoints.
      While the lead is inside a bridge marker:
        - enforce forceFollowRoad regardless of bypass windows
        - apply tighter spacing and a lower speed cap (applied later in the speed controller)
        - suppress off-road bypass recoveries (implemented in recovery blocks below)
*/
private _bridgeMarkerLead = "";
private _bridgeLeadMode = false;

private _bridgeMarkerHere = "";
private _bridgeMode = false;
if (_bridgeMarkersAvailable) then
{
    private _pLeadB = getPosATL _lead;
    _pLeadB resize 3;

    _bridgeMarkerLead = [_pLeadB] call _fn_bridgeMarkerAtPos;
    _bridgeLeadMode = !(_bridgeMarkerLead isEqualTo "");

    // Keep bridge mode active until the LAST convoy vehicle exits the bridge marker,
    // so the rear vehicle does not get left behind when the lead clears the chokepoint.
    if (_bridgeLeadMode) then
    {
        _bridgeMarkerHere = _bridgeMarkerLead;
        _bridgeMode = true;
    }
    else
    {
        {
            if (isNull _x || { !alive _x }) then { continue; };
            private _pV = getPosATL _x;
            _pV resize 3;
            private _mk = [_pV] call _fn_bridgeMarkerAtPos;
            if (_mk isNotEqualTo "") exitWith
            {
                _bridgeMarkerHere = _mk;
                _bridgeMode = true;
            };
        } forEach _aliveVeh;
    };
};

if (!_bridgeMarkersAvailable && { _bridgeFallbackEnabled }) then
{
    private _fbUntil = ["activeConvoyBridgeFallbackUntil", -1] call ARC_fnc_stateGet;
    if (!(_fbUntil isEqualType 0)) then { _fbUntil = -1; };

    if (_fbUntil > 0 && { _now < _fbUntil }) then
    {
        _bridgeLeadMode = true;
        _bridgeMode = true;
        _bridgeMarkerLead = "fallback_chokepoint";
        _bridgeMarkerHere = "fallback_chokepoint";
    };
};

private _assistFollowersEnabled = missionNamespace getVariable ["ARC_convoyBridgeAssistFollowersEnabled", true];
if (!(_assistFollowersEnabled isEqualType true) && !(_assistFollowersEnabled isEqualType false)) then { _assistFollowersEnabled = true; };

private _assistLeadEnabled = missionNamespace getVariable ["ARC_convoyBridgeAssistEnabled", true];
if (!(_assistLeadEnabled isEqualType true) && !(_assistLeadEnabled isEqualType false)) then { _assistLeadEnabled = true; };

private _startupBreadcrumbsLogged = ["activeConvoyStartupBreadcrumbsLogged", false] call ARC_fnc_stateGet;
if (!(_startupBreadcrumbsLogged isEqualType true) && !(_startupBreadcrumbsLogged isEqualType false)) then { _startupBreadcrumbsLogged = false; };
if (!_startupBreadcrumbsLogged) then
{
    private _roleBundleLog = if (_roleBundleId isEqualTo "") then {"<none>"} else {_roleBundleId};
    private _classList = _vehicles apply { typeOf _x };

    diag_log format [
        "[ARC][CONVOY][BOOT] task=%1 bundle=%2 classList=%3 bridgeMode=%4 bridgeLeadMode=%5 bridgeFallback=%6 bridgeAssistLead=%7 bridgeAssistFollowers=%8 bridgeMarkersAvailable=%9",
        _taskId,
        _roleBundleLog,
        _classList,
        _bridgeMode,
        _bridgeLeadMode,
        _bridgeFallbackEnabled,
        _assistLeadEnabled,
        _assistFollowersEnabled,
        _bridgeMarkersAvailable
    ];

    ["activeConvoyStartupBreadcrumbsLogged", true] call ARC_fnc_stateSet;
};

private _prevBridgeMarker = missionNamespace getVariable ["ARC_convoy_prevBridgeMarker", ""];
if !(_prevBridgeMarker isEqualType "") then { _prevBridgeMarker = ""; };

if (_bridgeMarkerHere isNotEqualTo _prevBridgeMarker) then
{
    missionNamespace setVariable ["ARC_convoy_prevBridgeMarker", _bridgeMarkerHere];

    if (_bridgeMarkerHere isNotEqualTo "") then
    {
        ["OPS", format ["Convoy entering bridge zone %1. Applying bridge driving profile.", _bridgeMarkerHere], getPosATL _lead, [["event", "CONVOY_BRIDGE_ENTER"], ["marker", _bridgeMarkerHere], ["taskId", _taskId]]] call ARC_fnc_intelLog;
    }
    else
    {
        ["OPS", "Convoy exited bridge zone. Restoring normal convoy profile.", getPosATL _lead, [["event", "CONVOY_BRIDGE_EXIT"], ["taskId", _taskId]]] call ARC_fnc_intelLog;
    };
};

if (_bridgeMode) then
{
    // Prefer road following while in bridge zones, but allow a short per-vehicle bypass window
    // (ARC_convoyVehBypassUntil) for scripted bridge recovery.
    {
        private _d = driver _x;
        if (!isNull _d) then
        {
            private _vb = _x getVariable ["ARC_convoyVehBypassUntil", -1];
            if (!(_vb isEqualType 0)) then { _vb = -1; };
            if (_vb > 0 && { _now < _vb }) then { _d forceFollowRoad false; } else { _d forceFollowRoad true; };
        };
    } forEach _vehicles;
};

private _prevRecoveryStage = ["activeConvoyRecoveryLastStageLogged", -1] call ARC_fnc_stateGet;
if (!(_prevRecoveryStage isEqualType 0)) then { _prevRecoveryStage = -1; };

private _prevBridgeRecoverState = ["activeConvoyBridgeRecoverLogState", ""] call ARC_fnc_stateGet;
if (!(_prevBridgeRecoverState isEqualType "")) then { _prevBridgeRecoverState = ""; };

/*
    Per-vehicle bridge assist queue (followers):
      When follower recovery seeds ARC_convoyBridgeAssistPts/Idx on a vehicle, progress that
      queue each tick until the vehicle exits the bridge marker or the assist TTL expires.
*/
private _assistFQ = _assistFollowersEnabled;

{
    if (isNull _x || { !alive _x }) then { continue; };

    private _pts = _x getVariable ["ARC_convoyBridgeAssistPts", []];
    if (!(_pts isEqualType []) || { (count _pts) == 0 }) then { continue; };

    // If the feature is disabled, clear any queued assists.
    if (!_assistFQ) then
    {
        _x setVariable ["ARC_convoyBridgeAssistPts", nil];
        _x setVariable ["ARC_convoyBridgeAssistIdx", nil];
        _x setVariable ["ARC_convoyBridgeAssistUntil", nil];
        _x setVariable ["ARC_convoyBridgeAssistLastOrderAt", nil];
        continue;
    };

    private _vPosQ = getPosATL _x;
    _vPosQ resize 3;

    // End assist if vehicle is no longer in a bridge marker.
    private _mkQ = [_vPosQ] call _fn_bridgeMarkerAtPos;
    if (_mkQ isEqualTo "") then
    {
        _x setVariable ["ARC_convoyBridgeAssistPts", nil];
        _x setVariable ["ARC_convoyBridgeAssistIdx", nil];
        _x setVariable ["ARC_convoyBridgeAssistUntil", nil];
        _x setVariable ["ARC_convoyBridgeAssistLastOrderAt", nil];
        continue;
    };

    private _untilQ = _x getVariable ["ARC_convoyBridgeAssistUntil", -1];
    if (!(_untilQ isEqualType 0)) then { _untilQ = -1; };
    if (_untilQ > 0 && { _now > _untilQ }) then
    {
        _x setVariable ["ARC_convoyBridgeAssistPts", nil];
        _x setVariable ["ARC_convoyBridgeAssistIdx", nil];
        _x setVariable ["ARC_convoyBridgeAssistUntil", nil];
        _x setVariable ["ARC_convoyBridgeAssistLastOrderAt", nil];
        continue;
    };

    private _idxQ = _x getVariable ["ARC_convoyBridgeAssistIdx", 0];
    if (!(_idxQ isEqualType 0)) then { _idxQ = 0; };

    if (_idxQ >= (count _pts)) then
    {
        _x setVariable ["ARC_convoyBridgeAssistPts", nil];
        _x setVariable ["ARC_convoyBridgeAssistIdx", nil];
        _x setVariable ["ARC_convoyBridgeAssistUntil", nil];
        _x setVariable ["ARC_convoyBridgeAssistLastOrderAt", nil];
        continue;
    };

    private _radQ = missionNamespace getVariable ["ARC_convoyBridgeAssistPointRadiusM", 16];
    if (!(_radQ isEqualType 0)) then { _radQ = 16; };
    _radQ = (_radQ max 8) min 35;

    private _tgtQ = _pts # _idxQ;
    _tgtQ resize 3;

    // Advance when close enough.
    if ((_vPosQ distance2D _tgtQ) <= _radQ) then
    {
        _idxQ = _idxQ + 1;
        _x setVariable ["ARC_convoyBridgeAssistIdx", _idxQ];
        if (_idxQ >= (count _pts)) then
        {
            _x setVariable ["ARC_convoyBridgeAssistPts", nil];
            _x setVariable ["ARC_convoyBridgeAssistIdx", nil];
            _x setVariable ["ARC_convoyBridgeAssistUntil", nil];
            _x setVariable ["ARC_convoyBridgeAssistLastOrderAt", nil];
            continue;
        };
        _tgtQ = _pts # _idxQ;
        _tgtQ resize 3;
    };

    // Throttle doMove re-issues.
    private _lastOrderQ = _x getVariable ["ARC_convoyBridgeAssistLastOrderAt", -1];
    if (!(_lastOrderQ isEqualType 0)) then { _lastOrderQ = -1; };

    private _reissueSecQ = missionNamespace getVariable ["ARC_convoyBridgeFollowerDoMoveReissueSec", 4];
    if (!(_reissueSecQ isEqualType 0)) then { _reissueSecQ = 4; };
    _reissueSecQ = (_reissueSecQ max 1) min 20;

    if (_lastOrderQ < 0 || { (_now - _lastOrderQ) > _reissueSecQ }) then
    {
        private _dQ = driver _x;
        if (!isNull _dQ && { !isPlayer _dQ }) then
        {
            _dQ doMove _tgtQ;
            _x setVariable ["ARC_convoyBridgeAssistLastOrderAt", _now];
        };
    };
} forEach _aliveVeh;



// Waypoint watchdog: if a group loses its waypoints (Zeus, AI glitch), re-apply the stored route.

if ((count waypoints _grpW) isEqualTo 0) then
{
    diag_log "[ARC][CONVOY] Watchdog: convoy group has no waypoints; re-applying route.";
    [_grpW, _routePts, _destWpPos, _destRad, _ingressPos] call _fn_applyRouteWps;
};

// Cohesion controller: if a vehicle falls behind, slow the convoy so it can close distance.
// This reduces "rubber banding" splits and tail vehicles routing independently.
private _catchup = missionNamespace getVariable ["ARC_convoyCatchupEnabled", true];
if (!(_catchup isEqualType true) && !(_catchup isEqualType false)) then { _catchup = true; };

private _capWanted = _speedKph;

if (_catchup && { (count _aliveVeh) >= 2 }
    && { !(_bypassUntil isEqualType 0 && { _bypassUntil > 0 } && { _now < _bypassUntil }) }
) then
{
    private _maxGap = 0;
    for "_i" from 1 to ((count _aliveVeh) - 1) do
    {
        _maxGap = _maxGap max ((_aliveVeh # (_i - 1)) distance2D (_aliveVeh # _i));
    };

    private _slowF = missionNamespace getVariable ["ARC_convoyCatchupGapSlowFactor", 2.2];
    if (!(_slowF isEqualType 0)) then { _slowF = 2.2; };
    _slowF = (_slowF max 1.2) min 6;

    private _holdF = missionNamespace getVariable ["ARC_convoyCatchupGapHoldFactor", 3.4];
    if (!(_holdF isEqualType 0)) then { _holdF = 3.4; };
    _holdF = (_holdF max 1.8) min 8;

    private _gapSlow = ((_spacing max 20) * _slowF) max 120;
    private _gapHold = ((_spacing max 20) * _holdF) max 220;

    private _minKph = missionNamespace getVariable ["ARC_convoyCatchupMinSpeedKph", 12];
    if (!(_minKph isEqualType 0)) then { _minKph = 12; };
    _minKph = (_minKph max 6) min _speedKph;

    private _holdKph = missionNamespace getVariable ["ARC_convoyCatchupHoldSpeedKph", 8];
    if (!(_holdKph isEqualType 0)) then { _holdKph = 8; };
    _holdKph = (_holdKph max 4) min _speedKph;

    private _cap = _speedKph;
    if (_maxGap > _gapHold) then
    {
        _cap = _holdKph;
    }
    else
    {
        if (_maxGap > _gapSlow) then
        {
            _cap = ((_speedKph * 0.60) max _minKph) min _speedKph;
        };
    };

    _capWanted = _cap;

    { if (alive _x) then { _x limitSpeed _cap; }; } forEach _vehicles;
    ["activeConvoySpeedCapKph", _cap] call ARC_fnc_stateSet;
};


// Apply final speed + spacing every tick.
// - catch-up writes into _capWanted (default = _speedKph)
// - bridge zones clamp speed + spacing further
private _capFinal = _capWanted;
if (_bridgeMode) then
{
    _capFinal = _capFinal min _bridgeSpeedKph;
};

private _spacingFinal = if (_bridgeMode) then { (_spacing min _bridgeSpacingM) } else { _spacing };

{
    if (alive _x) then
    {
        _x limitSpeed _capFinal;
        _x setConvoySeparation _spacingFinal;

        if (_bridgeMode) then
        {
            private _d = driver _x;
            if (!isNull _d) then
            {
                private _vb = _x getVariable ["ARC_convoyVehBypassUntil", -1];
                if (!(_vb isEqualType 0)) then { _vb = -1; };
                if (_vb > 0 && { _now < _vb }) then { _d forceFollowRoad false; } else { _d forceFollowRoad true; };
            };
        };
    };
} forEach _vehicles;

["activeConvoySpeedCapKph", _capFinal] call ARC_fnc_stateSet;


// Stuck detection: if the lead hasn't moved for a while, re-issue movement orders.
// (This is common after hitting road barriers or pathfinding deadlocks.)
private _stuckSec = missionNamespace getVariable ["ARC_convoyStuckSec", 45];
if (!(_stuckSec isEqualType 0)) then { _stuckSec = 45; };
_stuckSec = (_stuckSec max 15) min 300;
// In bridge mode, trigger recovery sooner (prevents long stalls on decks/approaches).
if (_bridgeMode) then
{
    private _bStuck = missionNamespace getVariable ["ARC_convoyBridgeStuckSec", 22];
    if (!(_bStuck isEqualType 0)) then { _bStuck = 22; };
    _bStuck = (_bStuck max 8) min 120;
    _stuckSec = _stuckSec min _bStuck;
};


// Follower rejoin order watchdog:
// If a follower was given a rejoin target after a disruption, keep re-issuing doMove for a short
// bounded window so temporary pathing interruptions (not only bridge stalls) do not strand vehicle 3+.
private _rejoinRad = missionNamespace getVariable ["ARC_convoyFollowerRejoinPointRadiusM", 28];
if (!(_rejoinRad isEqualType 0)) then { _rejoinRad = 28; };
_rejoinRad = (_rejoinRad max 8) min 60;

private _rejoinReissueSec = missionNamespace getVariable ["ARC_convoyFollowerDoMoveReissueSec", 6];
if (!(_rejoinReissueSec isEqualType 0)) then { _rejoinReissueSec = 6; };
_rejoinReissueSec = (_rejoinReissueSec max 1) min 20;

{
    if (isNull _x || { !alive _x }) then { continue; };

    private _rTgt = _x getVariable ["ARC_convoyFollowerRejoinTarget", []];
    if (!(_rTgt isEqualType []) || { (count _rTgt) < 2 }) then { continue; };
    _rTgt = +_rTgt; _rTgt resize 3;

    private _rUntil = _x getVariable ["ARC_convoyFollowerRejoinUntil", -1];
    if (!(_rUntil isEqualType 0)) then { _rUntil = -1; };

    private _vPosR = getPosATL _x;
    _vPosR resize 3;

    if ((_rUntil > 0 && { _now >= _rUntil }) || { (_vPosR distance2D _rTgt) <= _rejoinRad }) then
    {
        _x setVariable ["ARC_convoyFollowerRejoinTarget", nil];
        _x setVariable ["ARC_convoyFollowerRejoinUntil", nil];
        _x setVariable ["ARC_convoyFollowerRejoinLastOrderAt", nil];
        continue;
    };

    private _lastOrderR = _x getVariable ["ARC_convoyFollowerRejoinLastOrderAt", -1];
    if (!(_lastOrderR isEqualType 0)) then { _lastOrderR = -1; };

    if (_lastOrderR < 0 || { (_now - _lastOrderR) >= _rejoinReissueSec }) then
    {
        private _dR = driver _x;
        if (!isNull _dR && { !isPlayer _dR }) then
        {
            _dR doMove _rTgt;
            _x setVariable ["ARC_convoyFollowerRejoinLastOrderAt", _now];
        };
    };
} forEach _aliveVeh;

// Follower recovery: if a trailing vehicle is stalled far behind, nudge it to rejoin.
// This targets the common failure mode where the lead continues (slowly) while a follower is deadlocked.
private _fRec = missionNamespace getVariable ["ARC_convoyFollowerRecoveryEnabled", true];
if (!(_fRec isEqualType true) && !(_fRec isEqualType false)) then { _fRec = true; };

if (_fRec && { (count _aliveVeh) >= 2 }
    && { !(_bypassUntil isEqualType 0 && { _bypassUntil > 0 } && { _now < _bypassUntil }) }
) then
{
    private _followerStage = "monitor";
    private _didFollowerRecover = false;
    private _didFollowerBridgeAssist = false;

    private _cooldown = missionNamespace getVariable ["ARC_convoyFollowerRecoveryCooldownSec", 60];
    if (!(_cooldown isEqualType 0)) then { _cooldown = 60; };
    _cooldown = (_cooldown max 30) min 300;

    // Bridge mode follower recovery tunables (kept separate so non-bridge behavior is unchanged).
    if (_bridgeMode) then
    {
        private _bridgeCooldown = missionNamespace getVariable ["ARC_convoyBridgeFollowerRecoveryCooldownSec", 25];
        if (!(_bridgeCooldown isEqualType 0)) then { _bridgeCooldown = 25; };
        _bridgeCooldown = (_bridgeCooldown max 8) min 300;
        _cooldown = _bridgeCooldown;
    };

    private _bypassSecF = missionNamespace getVariable ["ARC_convoyFollowerBypassWindowSec", 12];
    if (!(_bypassSecF isEqualType 0)) then { _bypassSecF = 12; };
    _bypassSecF = (_bypassSecF max 6) min 30;

    private _gapMin = missionNamespace getVariable ["ARC_convoyFollowerGapTriggerMinM", 180];
    if (!(_gapMin isEqualType 0)) then { _gapMin = 180; };
    _gapMin = (_gapMin max 120) min 280;

    private _gapTrigger = ((_spacing max 20) * 3.0) max _gapMin;
    if (_bridgeMode) then
    {
        private _bridgeGapFloor = missionNamespace getVariable ["ARC_convoyBridgeFollowerGapTriggerMinM", 140];
        if (!(_bridgeGapFloor isEqualType 0)) then { _bridgeGapFloor = 140; };
        _bridgeGapFloor = (_bridgeGapFloor max 80) min 219;

        _gapTrigger = ((_spacing max 20) * 3.0) max _bridgeGapFloor;
    };

    private _ldrU = leader _grpW;

    for "_i" from 1 to ((count _aliveVeh) - 1) do
    {
        private _v = _aliveVeh # _i;
        private _prev = _aliveVeh # (_i - 1);
        if (isNull _v || { !alive _v }) then { continue; };

        private _gap = _prev distance2D _v;

        // Only consider vehicles that are materially behind their predecessor and effectively stopped.
        if (_gap < _gapTrigger) then { continue; };
        if ((speed _v) > 2) then { continue; };

        private _vPos = getPosATL _v;
        _vPos resize 3;

        // Movement memory per vehicle.
        private _lmPos = _v getVariable ["ARC_convoyLastMovePos", _vPos];
        if (!(_lmPos isEqualType []) || { (count _lmPos) < 2 }) then { _lmPos = _vPos; };
        _lmPos = +_lmPos; _lmPos resize 3;

        private _lmAt = _v getVariable ["ARC_convoyLastMoveAt", _now];
        if (!(_lmAt isEqualType 0)) then { _lmAt = _now; };

        private _movedV = ((_vPos distance2D _lmPos) > 6) || { (speed _v) > 6 };
        if (_movedV) then
        {
            _v setVariable ["ARC_convoyLastMoveAt", _now];
            _v setVariable ["ARC_convoyLastMovePos", _vPos];
        }
        else
        {
            private _stuckForV = _now - _lmAt;

            private _lastRecV = _v getVariable ["ARC_convoyLastRecoverAt", -1];
            if (!(_lastRecV isEqualType 0)) then { _lastRecV = -1; };

            if (_stuckForV >= _stuckSec && { (_lastRecV < 0) || { (_now - _lastRecV) >= _cooldown } }) then
            {
                _didFollowerRecover = true;
                _v setVariable ["ARC_convoyLastRecoverAt", _now];

                // Ensure it can move.
                _v setFuel 1;
                _v limitSpeed _speedKph;
                _v setConvoySeparation _spacing;

                private _d = driver _v;
                if (!isNull _d) then
                {
                    _d disableAI "AUTOCOMBAT";
                    _d disableAI "TARGET";
                    _d disableAI "AUTOTARGET";

                    // Briefly allow off-road movement to break deadlocks, then reassert roads later.
// Bridge zones: prefer a micro-route across the bridge rather than off-road bypass.
private _didBridgeAssistV = false;
private _bridgeMkV = [_vPos] call _fn_bridgeMarkerAtPos;
private _bridgeHereV = (_bridgeMkV isNotEqualTo "");

if (_bridgeHereV) then
{
    private _assistF = missionNamespace getVariable ["ARC_convoyBridgeAssistFollowersEnabled", true];
    if (!(_assistF isEqualType true) && !(_assistF isEqualType false)) then { _assistF = true; };

    if (_assistF && { _bridgeMkV isNotEqualTo "" }) then
    {
        private _ptsV = [_bridgeMkV, _destWpPos, _vPos] call _fn_bridgeAssistPoints;
        if ((count _ptsV) > 0) then
        {
            _didBridgeAssistV = true;
            _didFollowerBridgeAssist = true;

            _v setVariable ["ARC_convoyBridgeAssistPts", _ptsV];
            _v setVariable ["ARC_convoyBridgeAssistIdx", 0];

            private _ttl = missionNamespace getVariable ["ARC_convoyBridgeAssistFollowerTtlSec", 90];
            if (!(_ttl isEqualType 0)) then { _ttl = 90; };
            _ttl = (_ttl max 25) min 240;
            _v setVariable ["ARC_convoyBridgeAssistUntil", _now + _ttl];
            _v setVariable ["ARC_convoyBridgeAssistLastOrderAt", -1];

            // Allow a brief non-road window to line up on the bridge centerline.
            private _bypassSecBV = missionNamespace getVariable ["ARC_convoyBridgeAssistFollowerBypassSec", 10];
            if (!(_bypassSecBV isEqualType 0)) then { _bypassSecBV = 10; };
            _bypassSecBV = (_bypassSecBV max 6) min 30;

            _v setVariable ["ARC_convoyVehBypassUntil", _now + _bypassSecBV];
            _d forceFollowRoad false;

            _d doMove (_ptsV # 0);

            _v setVariable ["ARC_convoyFollowerRejoinTarget", nil];
            _v setVariable ["ARC_convoyFollowerRejoinUntil", nil];
            _v setVariable ["ARC_convoyFollowerRejoinLastOrderAt", nil];

        };
    };

    if (!_didBridgeAssistV) then
    {
        _v setVariable ["ARC_convoyVehBypassUntil", -1];
        _d forceFollowRoad true;
    };
}
else
{
    if (_bridgeMode) then
    {
        _v setVariable ["ARC_convoyVehBypassUntil", -1];
        _d forceFollowRoad true;
    }
    else
    {
        _v setVariable ["ARC_convoyVehBypassUntil", _now + _bypassSecF];
        _d forceFollowRoad false;
    };
};
                    // Nudge toward a sensible rejoin target.
                    // If the predecessor is behind us along the planned road route (u-turn cases),
                    // push toward a forward route point instead to prevent tail vehicles deadlocking.
                    private _prevPos = getPosATL _prev;
                    _prevPos resize 3;

                    private _target = _prevPos;
                    if (_routePts isEqualType [] && { (count _routePts) >= 2 }) then
                    {
                        private _idxV = [_routePts, _vPos, 0] call _fn_nearRouteIdx;
                        private _idxP = [_routePts, _prevPos, 0] call _fn_nearRouteIdx;

                        // If predecessor is "behind" on the route chain, aim forward instead.
                        if (_idxP < _idxV) then
                        {
                            private _fIdx = (_idxV + 3) min ((count _routePts) - 1);
                            _target = _routePts # _fIdx;
                        };
                    };

                    if (!_didBridgeAssistV) then
                    {
                        _target resize 3;
                        _d doMove _target;

                        private _rejoinTtl = missionNamespace getVariable ["ARC_convoyFollowerRejoinOrderTtlSec", 45];
                        if (!(_rejoinTtl isEqualType 0)) then { _rejoinTtl = 45; };
                        _rejoinTtl = (_rejoinTtl max 10) min 180;

                        _v setVariable ["ARC_convoyFollowerRejoinTarget", _target];
                        _v setVariable ["ARC_convoyFollowerRejoinUntil", _now + _rejoinTtl];
                        _v setVariable ["ARC_convoyFollowerRejoinLastOrderAt", _now];
                    };
                };

            };
        };
    };

    if (_didFollowerRecover) then
    {
        _followerStage = if (_didFollowerBridgeAssist) then { "recover_bridge_assist" } else { "recover" };
    };

    private _prevFollowerStage = ["activeConvoyFollowerRecoverStage", "off"] call ARC_fnc_stateGet;
    if !(_prevFollowerStage isEqualType "") then { _prevFollowerStage = "off"; };

    if (_followerStage isNotEqualTo _prevFollowerStage) then
    {
        ["activeConvoyFollowerRecoverStage", _followerStage] call ARC_fnc_stateSet;

        private _evt = "CONVOY_FOLLOWER_RECOVERY_STAGE";
        private _msg = switch (_followerStage) do
        {
            case "recover_bridge_assist": { "Follower recovery stage: bridge assist active." };
            case "recover": { "Follower recovery stage: recovery active." };
            case "monitor": { "Follower recovery stage: monitoring." };
            default { "Follower recovery stage: off." };
        };

        ["OPS", _msg, getPosATL _lead, [["event", _evt], ["stage", _followerStage], ["taskId", _taskId]]] call ARC_fnc_intelLog;
    };
}
else
{
    private _prevFollowerStage = ["activeConvoyFollowerRecoverStage", "off"] call ARC_fnc_stateGet;
    if !(_prevFollowerStage isEqualType "") then { _prevFollowerStage = "off"; };
    if (_prevFollowerStage isNotEqualTo "off") then
    {
        ["activeConvoyFollowerRecoverStage", "off"] call ARC_fnc_stateSet;
        ["OPS", "Follower recovery stage: off.", getPosATL _lead, [["event", "CONVOY_FOLLOWER_RECOVERY_STAGE"], ["stage", "off"], ["taskId", _taskId]]] call ARC_fnc_intelLog;
    };
};

private _lastMoveAt = ["activeConvoyLastMoveAt", _now] call ARC_fnc_stateGet;
if (!(_lastMoveAt isEqualType 0)) then { _lastMoveAt = _now; };

private _lastMovePos = ["activeConvoyLastMovePos", getPosATL _lead] call ARC_fnc_stateGet;
if (!(_lastMovePos isEqualType []) || { (count _lastMovePos) < 2 }) then { _lastMovePos = getPosATL _lead; };
_lastMovePos = +_lastMovePos; _lastMovePos resize 3;

private _curPos = getPosATL _lead;
_curPos = +_curPos; _curPos resize 3;

private _fn_logBridgeAssistOpsOnce = {
    params ["_eventName", "_msg", "_markerName", "_leadSpeedKph", "_stuckSecs", "_wpCount"];

    private _prev = ["activeConvoyBridgeAssistOpsState", ""] call ARC_fnc_stateGet;
    if !(_prev isEqualType "") then { _prev = ""; };
    if (_prev isEqualTo _eventName) exitWith {};

    ["activeConvoyBridgeAssistOpsState", _eventName] call ARC_fnc_stateSet;
    [
        "OPS",
        _msg,
        _curPos,
        [
            ["event", _eventName],
            ["marker", _markerName],
            ["leadSpeed", round _leadSpeedKph],
            ["stuckDuration", round _stuckSecs],
            ["waypointCount", _wpCount],
            ["taskId", _taskId]
        ]
    ] call ARC_fnc_intelLog;
};

// Treat the convoy as "moving" if it has displaced meaningfully, or it is still rolling.
private _moveDist = if (_bridgeLeadMode) then { 4 } else { 8 };
private _moveSpd  = if (_bridgeLeadMode) then { 2 } else { 6 };
private _moved = ((_curPos distance2D _lastMovePos) > _moveDist) || { (speed _lead) > _moveSpd };

if (_moved) then
{
    ["activeConvoyLastMoveAt", _now] call ARC_fnc_stateSet;
    ["activeConvoyLastMovePos", _curPos] call ARC_fnc_stateSet;
    ["activeConvoyRecoveryLastStageLogged", -1] call ARC_fnc_stateSet;
    ["activeConvoyBridgeRecoverLogState", "off"] call ARC_fnc_stateSet;

    if (_bridgeMode) then
    {
        [
            "ASSIST_SKIPPED_NOT_STUCK",
            "Bridge assist skipped: lead has resumed movement.",
            _bridgeMarkerLead,
            speed _lead,
            0,
            count (waypoints _grpW)
        ] call _fn_logBridgeAssistOpsOnce;
    }
    else
    {
        ["activeConvoyBridgeAssistOpsState", ""] call ARC_fnc_stateSet;
    };
}
else
{
    private _stuckFor = _now - _lastMoveAt;

    if (_bridgeMode && { _stuckFor < _stuckSec }) then
    {
        [
            "ASSIST_SKIPPED_NOT_STUCK",
            "Bridge assist skipped: stall duration has not reached threshold.",
            _bridgeMarkerLead,
            speed _lead,
            _stuckFor,
            count (waypoints _grpW)
        ] call _fn_logBridgeAssistOpsOnce;
    };

    // Fallback bridge/chokepoint mode is only allowed when mission markers are unavailable.
    if (!_bridgeMarkersAvailable && { _bridgeFallbackEnabled } && { _stuckFor >= _stuckSec } && { (speed _lead) < 2.5 }) then
    {
        ["activeConvoyBridgeFallbackUntil", _now + _bridgeFallbackHoldSec] call ARC_fnc_stateSet;
        _bridgeLeadMode = true;
        _bridgeMode = true;
        _bridgeMarkerLead = "fallback_chokepoint";
        _bridgeMarkerHere = "fallback_chokepoint";
    };

    private _lastRec = ["activeConvoyLastRecoveryAt", -1] call ARC_fnc_stateGet;
    if (!(_lastRec isEqualType 0)) then { _lastRec = -1; };

    // Throttle recovery so we don't spam waypoints.
    if (_stuckFor >= _stuckSec && { (_lastRec < 0) || { (_now - _lastRec) >= 60 } }) then
    {
        ["activeConvoyLastRecoveryAt", _now] call ARC_fnc_stateSet;

        // Ensure vehicles are not accidentally refrozen.
        private _spacing = ["activeConvoySpacingM", missionNamespace getVariable ["ARC_convoySpacingM", 59]] call ARC_fnc_stateGet;
        if (!(_spacing isEqualType 0)) then { _spacing = missionNamespace getVariable ["ARC_convoySpacingM", 59]; };
        _spacing = (_spacing max 20) min 150;

        {
            if (!isNull _x && { alive _x }) then
            {
                _x setFuel 1;
                _x limitSpeed _speedKph;
                _x setConvoySeparation _spacing;
            };
        } forEach _vehicles;

        // Stage 1: re-apply the full road route.
        // Stage 2 (longer stall): attempt a short bypass, but keep it road-snapped and disable it near the airbase/destination.
        // Require the lead to be effectively stopped; tight corners can otherwise look like a stall.
        private _stage = if (_stuckFor >= (_stuckSec * 2) && { (speed _lead) < 2 }) then { 2 } else { 1 };

        private _bridgeRecAttempts = ["activeConvoyBridgeRecoverAttempts", 0] call ARC_fnc_stateGet;
        if (!(_bridgeRecAttempts isEqualType 0)) then { _bridgeRecAttempts = 0; };

        private _bridgeRecCooldownUntil = ["activeConvoyBridgeRecoverCooldownUntil", -1] call ARC_fnc_stateGet;
        if (!(_bridgeRecCooldownUntil isEqualType 0)) then { _bridgeRecCooldownUntil = -1; };

        private _bridgeRecMax = missionNamespace getVariable ["ARC_convoyBridgeRecoverMaxAttempts", 3];
        if (!(_bridgeRecMax isEqualType 0)) then { _bridgeRecMax = 3; };
        _bridgeRecMax = (_bridgeRecMax max 1) min 10;

        private _bridgeRecCooldownSec = missionNamespace getVariable ["ARC_convoyBridgeRecoverCooldownSec", 120];
        if (!(_bridgeRecCooldownSec isEqualType 0)) then { _bridgeRecCooldownSec = 120; };
        _bridgeRecCooldownSec = (_bridgeRecCooldownSec max 20) min 600;

        private _allowOffroad = missionNamespace getVariable ["ARC_convoyAllowOffroadRecovery", true];
        if (!(_allowOffroad isEqualType true) && !(_allowOffroad isEqualType false)) then { _allowOffroad = true; };

        private _minDistOffroad = missionNamespace getVariable ["ARC_convoyOffroadRecoveryMinDistToDestM", 1200];
        if (!(_minDistOffroad isEqualType 0)) then { _minDistOffroad = 1200; };
        _minDistOffroad = (_minDistOffroad max 200) min 5000;

        private _distToDestWp = _curPos distance2D _destWpPos;
        private _zone = [_curPos] call ARC_fnc_worldGetZoneForPos;
        private _inAirbase = (_zone isEqualType "" && { (toUpper _zone) isEqualTo "AIRBASE" });

        // Bridge zones (or fallback chokepoint mode): never attempt generic off-road bypass.
        if (_stage isEqualTo 2 && { _bridgeMode }) then
        {
            _stage = 1;
        };

        if (_stage isEqualTo 2 && { (!_allowOffroad) || { _distToDestWp < _minDistOffroad } || { _inAirbase } }) then
        {
            _stage = 1;
        };

        // Clear and rebuild waypoints.
        while { (count waypoints _grpW) > 0 } do { deleteWaypoint ((waypoints _grpW) select 0); };

        if (_stage isEqualTo 1) then
        {
            // If we're stalled in a bridge zone, inject a short micro-route along the bridge centerline
            // before continuing on to ingress/destination.
            private _didBridgeAssist = false;

            if (_bridgeLeadMode && { _bridgeMarkerLead isNotEqualTo "" }) then
            {
                private _assistEn = missionNamespace getVariable ["ARC_convoyBridgeAssistEnabled", true];
                if (!(_assistEn isEqualType true) && !(_assistEn isEqualType false)) then { _assistEn = true; };

                private _bridgeAssistReady = (_bridgeRecCooldownUntil < 0) || { _now >= _bridgeRecCooldownUntil };
                if (_assistEn && { _bridgeAssistReady }) then
                {
                    private _ptsB = [_bridgeMarkerLead, _destWpPos, _curPos] call _fn_bridgeAssistPoints;
                    private _usedFallbackPts = false;
                    if ((count _ptsB) isEqualTo 0) then
                    {
                        [
                            "ASSIST_SKIPPED_NO_POINTS",
                            format ["Bridge assist skipped in %1: no valid assist points generated.", _bridgeMarkerLead],
                            _bridgeMarkerLead,
                            speed _lead,
                            _stuckFor,
                            count (waypoints _grpW)
                        ] call _fn_logBridgeAssistOpsOnce;

                        _ptsB = [_curPos, _destWpPos] call _fn_bridgeFallbackRoutePoints;
                        _usedFallbackPts = ((count _ptsB) > 0);
                    };

                    if ((count _ptsB) > 0) then
                    {
                        _didBridgeAssist = true;
                        _bridgeRecAttempts = _bridgeRecAttempts + 1;
                        ["activeConvoyBridgeRecoverAttempts", _bridgeRecAttempts] call ARC_fnc_stateSet;

                        if (_bridgeRecAttempts >= _bridgeRecMax) then
                        {
                            _bridgeRecAttempts = 0;
                            ["activeConvoyBridgeRecoverAttempts", 0] call ARC_fnc_stateSet;
                            ["activeConvoyBridgeRecoverCooldownUntil", _now + _bridgeRecCooldownSec] call ARC_fnc_stateSet;
                        };

                        // Allow the lead a brief non-road window to line up on awkward bridge geometry.
                        private _bypassSecB = missionNamespace getVariable ["ARC_convoyBridgeAssistBypassSec", 14];
                        if (!(_bypassSecB isEqualType 0)) then { _bypassSecB = 14; };
                        _bypassSecB = (_bypassSecB max 6) min 45;
                        _lead setVariable ["ARC_convoyVehBypassUntil", _now + _bypassSecB];

                        {
                            private _wp = _grpW addWaypoint [_x, 0];
                            _wp setWaypointType "MOVE";
                            _wp setWaypointSpeed "LIMITED";
                            _wp setWaypointBehaviour "SAFE";
                            _wp setWaypointCombatMode "YELLOW";
                            _wp setWaypointFormation "COLUMN";
                            _wp setWaypointCompletionRadius 12;
                        } forEach _ptsB;

                        // Gate wp (Airbase ingress) if defined.
                        if (_ingressPos isEqualType [] && { (count _ingressPos) >= 2 }) then
                        {
                            private _wpG = _grpW addWaypoint [_ingressPos, 0];
                            _wpG setWaypointType "MOVE";
                            _wpG setWaypointSpeed "LIMITED";
                            _wpG setWaypointBehaviour "SAFE";
                            _wpG setWaypointCombatMode "YELLOW";
                            _wpG setWaypointFormation "COLUMN";
                            _wpG setWaypointCompletionRadius 40;
                        };

                        private _wpD = _grpW addWaypoint [_destWpPos, 0];
                        _wpD setWaypointType "MOVE";
                        _wpD setWaypointSpeed "LIMITED";
                        _wpD setWaypointBehaviour "SAFE";
                        _wpD setWaypointCombatMode "YELLOW";
                        _wpD setWaypointFormation "COLUMN";
                        _wpD setWaypointCompletionRadius (_destRad max 40);

                        if ((count waypoints _grpW) > 0) then
                        {
                            _grpW setCurrentWaypoint ((waypoints _grpW) select 0);
                        };

                        [
                            "ASSIST_APPLIED",
                            if (_usedFallbackPts) then
                            {
                                format ["Bridge assist applied in %1; used deterministic route fallback micro-waypoints.", _bridgeMarkerLead]
                            }
                            else
                            {
                                format ["Bridge assist applied in %1; injected micro-waypoints to clear the bridge.", _bridgeMarkerLead]
                            },
                            _bridgeMarkerLead,
                            speed _lead,
                            _stuckFor,
                            count _ptsB
                        ] call _fn_logBridgeAssistOpsOnce;
                    }
                };

                if (_assistEn && { !_bridgeAssistReady }) then
                {
                    [
                        "ASSIST_SKIPPED_COOLDOWN",
                        format ["Bridge assist skipped in %1: recovery cooldown is active.", _bridgeMarkerLead],
                        _bridgeMarkerLead,
                        speed _lead,
                        _stuckFor,
                        count (waypoints _grpW)
                    ] call _fn_logBridgeAssistOpsOnce;
                };
            };

            if (_bridgeMode && { !_didBridgeAssist }) then
            {
                // Bridge mode policy: micro-route + route reapply only; no generic bypass branch.
                _stage = 1;
            };

            if (!_didBridgeAssist) then
            {
                // Re-apply the intended road route.
                [_grpW, _routePts, _destWpPos, _destRad, _ingressPos] call _fn_applyRouteWps;
            };
        }
        else
        {
            // Bypass: pick a point slightly ahead + to the side, but snap it back to a road.
            private _dirTo = _curPos getDir _destWpPos;
            private _side = selectRandom [90, -90];
            private _pFwd = _curPos getPos [80, _dirTo];
            private _pBy  = _pFwd getPos [35, _dirTo + _side];
            _pBy resize 3;

            private _snapM2 = missionNamespace getVariable ["ARC_convoyRoadSnapM", 120];
            if (!(_snapM2 isEqualType 0)) then { _snapM2 = 120; };
            _snapM2 = (_snapM2 max 40) min 400;

            private _roads = _pBy nearRoads _snapM2;
            if ((count _roads) > 0) then
            {
                _pBy = getPosATL (_roads # 0);
                _pBy resize 3;
            }
            else
            {
                // If no road is found, fall back to route re-apply.
                _stage = 1;
            };

            if (_stage isEqualTo 2) then
            {
                private _wpA = _grpW addWaypoint [_pBy, 0];
                _wpA setWaypointType "MOVE";
                _wpA setWaypointSpeed "LIMITED";
                _wpA setWaypointBehaviour "SAFE";
                _wpA setWaypointCompletionRadius 25;

                private _wpB = _grpW addWaypoint [_destWpPos, 0];
                _wpB setWaypointType "MOVE";
                _wpB setWaypointSpeed "LIMITED";
                _wpB setWaypointBehaviour "SAFE";
                _wpB setWaypointCompletionRadius (_destRad max 40);

                _grpW setCurrentWaypoint _wpA;

                // Mark bypass window so other logic (catch-up, road reassert spam) can back off briefly.
                private _bypassSec = missionNamespace getVariable ["ARC_convoyBypassWindowSec", 18];
                if (!(_bypassSec isEqualType 0)) then { _bypassSec = 18; };
                _bypassSec = (_bypassSec max 8) min 40;
                ["activeConvoyBypassUntil", _now + _bypassSec] call ARC_fnc_stateSet;
            }
            else
            {
                [_grpW, _routePts, _destWpPos, _destRad, _ingressPos] call _fn_applyRouteWps;
            };
        };

        // Prefer road-following, but respect any active per-vehicle bypass window (used by bridge assist).
        {
            private _d = driver _x;
            if (!isNull _d) then
            {
                private _vb = _x getVariable ["ARC_convoyVehBypassUntil", -1];
                if (!(_vb isEqualType 0)) then { _vb = -1; };
                if (_vb > 0 && { _now < _vb }) then { _d forceFollowRoad false; } else { _d forceFollowRoad true; };
            };
        } forEach _vehicles;

        _grpW setFormation "COLUMN";
        _grpW setBehaviour "SAFE";
        _grpW setCombatMode "YELLOW";
        _grpW setSpeedMode "LIMITED";

        if (_stage isNotEqualTo _prevRecoveryStage) then
        {
            ["activeConvoyRecoveryLastStageLogged", _stage] call ARC_fnc_stateSet;
            ["OPS", format ["Convoy recovery executed (stage %1) after %2s stall.", _stage, round _stuckFor], _curPos, [["event", "CONVOY_RECOVER"], ["stage", _stage], ["taskId", _taskId]]] call ARC_fnc_intelLog;
        };

        private _bridgeRecoverState = if (_bridgeMode) then
        {
            if (_bridgeRecCooldownUntil > 0 && { _now < _bridgeRecCooldownUntil }) then { "cooldown" } else { "active" }
        }
        else
        {
            "off"
        };

        if (_bridgeRecoverState isNotEqualTo _prevBridgeRecoverState) then
        {
            ["activeConvoyBridgeRecoverLogState", _bridgeRecoverState] call ARC_fnc_stateSet;
            if (_bridgeRecoverState isEqualTo "cooldown") then
            {
                ["OPS", "Bridge recovery cooling down; reapplying planned route only until cooldown expires.", _curPos, [["event", "CONVOY_BRIDGE_RECOVER_COOLDOWN"], ["taskId", _taskId]]] call ARC_fnc_intelLog;
            };
        };
    };
};

// Progress + arrival evaluation.
private _start = if (_hasLinkup) then { _linkupPos } else { _startPos };
private _routeDist = (_start distance2D _destPos) max 1;
private _curDist = (_lead distance2D _destPos) max 0;
private _prog = 1 - (_curDist / _routeDist);
_prog = (_prog max 0) min 1;

// Progress SITREPs at 25/50/75%
private _bucket = floor (_prog * 4);
private _lastBucket = ["activeConvoyLastProg", -1] call ARC_fnc_stateGet;

if (_bucket > _lastBucket && { _bucket in [1,2,3] }) then
{
    ["activeConvoyLastProg", _bucket] call ARC_fnc_stateSet;
    private _pct = _bucket * 25;
    private _grid = mapGridPosition (getPosATL _lead);
    ["OPS", format ["Convoy progress: %1%2 complete (lead at %3).", _pct, "%", _grid], getPosATL _lead, [["taskId", _taskId], ["event", "CONVOY_PROGRESS"], ["pct", _pct]]] call ARC_fnc_intelLog;
};

// Arrival: require a short dwell inside destination AO.
// For larger convoys, require most of the column to be inside the AO before closing the incident.
private _arrivedAt = ["activeConvoyArrivedAt", -1] call ARC_fnc_stateGet;

private _arriveRad = (_destRad max 60);
private _needFrac = missionNamespace getVariable ["ARC_convoyArrivalFraction", 0.75];
if (!(_needFrac isEqualType 0)) then { _needFrac = 0.75; };
_needFrac = (_needFrac max 0.5) min 1;

private _needMin = missionNamespace getVariable ["ARC_convoyArrivalMinVehicles", 2];
if (!(_needMin isEqualType 0)) then { _needMin = 2; };
_needMin = (_needMin max 1) min 999;

private _aliveN = count _aliveVeh;
private _needN = _needMin;
if (_aliveN > 0) then { _needN = (_needMin max (ceil (_aliveN * _needFrac))) min _aliveN; };

private _arrivedN = 0;
{ if ((_x distance2D _destPos) <= _arriveRad) then { _arrivedN = _arrivedN + 1; }; } forEach _aliveVeh;
private _leadArrived = ((_lead distance2D _destPos) <= _arriveRad);

if (_leadArrived && { _arrivedN >= _needN }) then
{
    if (!(_arrivedAt isEqualType 0) || { _arrivedAt < 0 }) then
    {
        ["activeConvoyArrivedAt", _now] call ARC_fnc_stateSet;
        private _gridA = mapGridPosition _destPos;
        ["OPS", format ["Convoy reached destination AO at %1 (%2/%3 vehicles present). Establish local security and complete handoff.", _gridA, _arrivedN, _aliveN], _destPos, [["taskId", _taskId], ["event", "CONVOY_ARRIVED"], ["arrived", _arrivedN], ["alive", _aliveN]]] call ARC_fnc_intelLog;
    }
    else
    {
        if ((_now - _arrivedAt) >= 25) then
        {
            // Freeze convoy at destination so it can be inspected / secured.
            {
                if (!isNull _x) then
                {
                    _x setFuel 0;
                    _x limitSpeed 0;
                };
            } forEach _aliveVeh;

            ["SUCCEEDED"] call _setLinkupTaskState;
            ["SUCCEEDED", "CONVOY_ARRIVED", "Convoy arrived and completed handoff. Recommend closing this incident as SUCCEEDED.", _destPos] call ARC_fnc_incidentMarkReadyToClose;
        };
    };
}
else
{
    // Reset dwell if convoy leaves the AO.
    if (_arrivedAt isEqualType 0 && { _arrivedAt > 0 }) then
    {
        ["activeConvoyArrivedAt", -1] call ARC_fnc_stateSet;
    };
};

true

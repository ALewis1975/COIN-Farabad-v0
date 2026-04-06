/*
    Server: evaluate active incident end-state conditions.

    Called frequently by ARC_fnc_execLoop.

    Responsibilities:
      - enforce deadlines
      - enforce "arrive within X" for ARRIVE_HOLD tasks
      - accumulate HOLD time for HOLD/ARRIVE_HOLD tasks
      - enforce objective-death fail conditions for INTERACT tasks

    Returns:
        BOOL
*/

if (!isServer) exitWith { false };

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (_taskId isEqualTo "") exitWith
{
    // Nothing active; ensure stale execution state doesn't linger.
    if (!((["activeExecTaskId", ""] call ARC_fnc_stateGet) isEqualTo "")) then
    {
        [] call ARC_fnc_execCleanupActive;
    };
    false
};

// Ensure we have a plan for this task
private _execTaskId = ["activeExecTaskId", ""] call ARC_fnc_stateGet;
private _execKind   = ["activeExecKind", ""] call ARC_fnc_stateGet;

if (!(_execTaskId isEqualTo _taskId && { !(_execKind isEqualTo "") })) then
{
    [] call ARC_fnc_execInitActive;
    _execTaskId = ["activeExecTaskId", ""] call ARC_fnc_stateGet;
    _execKind   = ["activeExecKind", ""] call ARC_fnc_stateGet;
};

if (_execKind isEqualTo "") exitWith { true };

// If the incident is already awaiting TOC closure, avoid further automated state changes.
private _closeReady = ["activeIncidentCloseReady", false] call ARC_fnc_stateGet;
if (_closeReady isEqualType true && { _closeReady }) exitWith { true };

// Assignment/acceptance workflow: execution does not progress until TOC acceptance.
private _accepted = ["activeIncidentAccepted", false] call ARC_fnc_stateGet;
if (!(_accepted isEqualType true)) then { _accepted = false; };

// Backward compatibility: older persisted states will have exec timers set but no acceptance flag.
// If execution already started, treat the incident as implicitly accepted.
if (!_accepted) then
{
    private _legacyStartedAt = ["activeExecStartedAt", -1] call ARC_fnc_stateGet;
    if (_legacyStartedAt isEqualType 0 && { _legacyStartedAt >= 0 }) then
    {
        ["activeIncidentAccepted", true] call ARC_fnc_stateSet;
        ["activeIncidentAcceptedAt", _legacyStartedAt] call ARC_fnc_stateSet;
        missionNamespace setVariable ["ARC_activeIncidentAccepted", true, true];
        missionNamespace setVariable ["ARC_activeIncidentAcceptedAt", _legacyStartedAt, true];
        _accepted = true;
    };
};
if (!_accepted) exitWith { true };

private _now  = serverTime;
private _last = missionNamespace getVariable ["ARC_exec_lastTick", _now];
private _dt   = (_now - _last) max 0;
if (_dt > 10) then { _dt = 10; };
missionNamespace setVariable ["ARC_exec_lastTick", _now];

private _deadlineAt = ["activeExecDeadlineAt", -1] call ARC_fnc_stateGet;
if (_deadlineAt isEqualType 0 && { _deadlineAt > 0 } && { _now >= _deadlineAt }) exitWith
{
    ["FAILED", "DEADLINE", "Timing window expired. Recommend closing this incident as FAILED.", ["activeExecPos", []] call ARC_fnc_stateGet] call ARC_fnc_incidentMarkReadyToClose;
    true
};

private _pos        = ["activeExecPos", []] call ARC_fnc_stateGet;
private _radius     = ["activeExecRadius", 0] call ARC_fnc_stateGet;
private _holdReq    = ["activeExecHoldReq", 0] call ARC_fnc_stateGet;
private _holdAccum  = ["activeExecHoldAccum", 0] call ARC_fnc_stateGet;
private _arrivalReq = ["activeExecArrivalReq", 0] call ARC_fnc_stateGet;
private _arrived    = ["activeExecArrived", false] call ARC_fnc_stateGet;
private _startedAt  = ["activeExecStartedAt", -1] call ARC_fnc_stateGet;

if (!(_pos isEqualType []) || { (count _pos) < 2 }) exitWith { true };

// CONVOY logic is self-contained and does not use the normal AO activation rules.
if (_execKind isEqualTo "CONVOY") exitWith
{
    [_now, _dt] call ARC_fnc_execTickConvoy;
};



// ---------------------------------------------------------------------------
// Task helper markers + persistent static compositions
//
// - Meeting/liaison tasks: mark the NPC position (follows movement).
// - IED tasks: mark an approximate search area (not the exact device).
// - Checkpoint tasks: spawn a small static checkpoint prop set that persists in the AO.
// ---------------------------------------------------------------------------

private _mkTask = missionNamespace getVariable ["ARC_taskMarkers_taskId", ""];
if (!(_mkTask isEqualType "")) then { _mkTask = ""; };

if (!(_mkTask isEqualTo _taskId)) then
{
    // New task (or first tick). Clear any prior helper markers.
    if ("ARC_obj_actor_active" in allMapMarkers) then { deleteMarker "ARC_obj_actor_active"; };
    if ("ARC_obj_search_active" in allMapMarkers) then { deleteMarker "ARC_obj_search_active"; };

    missionNamespace setVariable ["ARC_taskMarkers_taskId", _taskId];
    missionNamespace setVariable ["ARC_taskSearchMarkerTaskId", ""];
    missionNamespace setVariable ["ARC_taskSearchMarkerCenter", []];
    missionNamespace setVariable ["ARC_taskSearchMarkerRadiusM", -1];
};

private _incType = ["activeIncidentType", ""] call ARC_fnc_stateGet;
if (!(_incType isEqualType "")) then { _incType = ""; };
private _incTypeU = toUpper _incType;

// IED Phase 1: ensure the active device has a trigger + device record.
if (_incTypeU isEqualTo "IED") then
{
    [] call ARC_fnc_iedSpawnTick;
    // IED Phase 3: VBIED (parked) trigger + record (no-op unless objectiveKind is VBIED_VEHICLE).
    [] call ARC_fnc_vbiedSpawnTick;
    // VBIED Driven: checkpoint/gate rush (no-op unless objectiveKind is VBIED_DRIVEN_*).
    [] call ARC_fnc_vbiedDrivenSpawnTick;
    // Suicide Bomber: approach spawn (no-op unless objectiveKind is SB_*_APPROACH).
    [] call ARC_fnc_suicideBomberSpawnTick;
};

// Objective context (if any)
private _objKind = ["activeObjectiveKind", ""] call ARC_fnc_stateGet;
if (!(_objKind isEqualType "")) then { _objKind = ""; };
private _objNid = ["activeObjectiveNetId", ""] call ARC_fnc_stateGet;
if (!(_objNid isEqualType "")) then { _objNid = ""; };

// 1) Meeting / liaison marker (AI position)
private _meetMkEnabled = missionNamespace getVariable ["ARC_taskMarkerMeetActorEnabled", true];
if (!(_meetMkEnabled isEqualType true) && !(_meetMkEnabled isEqualType false)) then { _meetMkEnabled = true; };

if (_meetMkEnabled && { _objKind isEqualTo "CIV_MEET" } && { !(_objNid isEqualTo "") }) then
{
    private _u = objectFromNetId _objNid;
    if (!isNull _u && { alive _u } && { _u isKindOf "Man" }) then
    {
        private _p = getPosATL _u;
        _p resize 2;

        if !("ARC_obj_actor_active" in allMapMarkers) then
        {
            createMarker ["ARC_obj_actor_active", _p];
            "ARC_obj_actor_active" setMarkerType "mil_dot";
            "ARC_obj_actor_active" setMarkerColor "ColorCIV";
            "ARC_obj_actor_active" setMarkerAlpha 0.85;
            "ARC_obj_actor_active" setMarkerText "Liaison";
            "ARC_obj_actor_active" setMarkerSize [0.8, 0.8];
        }
        else
        {
            "ARC_obj_actor_active" setMarkerPos _p;
        };
    }
    else
    {
        if ("ARC_obj_actor_active" in allMapMarkers) then { deleteMarker "ARC_obj_actor_active"; };
    };
}
else
{
    if ("ARC_obj_actor_active" in allMapMarkers) then { deleteMarker "ARC_obj_actor_active"; };
};

// 2) Suspicious-object / IED approximate search marker (not exact)
private _areaMkEnabled = missionNamespace getVariable ["ARC_taskMarkerSuspiciousAreaEnabled", true];
if (!(_areaMkEnabled isEqualType true) && !(_areaMkEnabled isEqualType false)) then { _areaMkEnabled = true; };

if (_areaMkEnabled && { _incTypeU isEqualTo "IED" }) then
{
    private _rad = missionNamespace getVariable ["ARC_taskObjSearchRadiusM_IED", 125];
    if (!(_rad isEqualType 0) || { _rad <= 0 }) then { _rad = 125; };
    _rad = (_rad max 50) min 400;

    private _jitter = missionNamespace getVariable ["ARC_taskObjSearchJitterM_IED", 60];
    if (!(_jitter isEqualType 0) || { _jitter < 0 }) then { _jitter = 60; };
    _jitter = (_jitter max 0) min 250;

    private _center = missionNamespace getVariable ["ARC_taskSearchMarkerCenter", []];
    private _centerTask = missionNamespace getVariable ["ARC_taskSearchMarkerTaskId", ""];
    if (!(_centerTask isEqualType "")) then { _centerTask = ""; };

    if (!(_centerTask isEqualTo _taskId) || { !(_center isEqualType []) } || { (count _center) < 2 }) then
    {
        // Base: objective position if known; else fall back to exec AO position.
        private _basePos = ["activeObjectivePos", []] call ARC_fnc_stateGet;
        if (!(_basePos isEqualType []) || { (count _basePos) < 2 }) then { _basePos = _pos; };
        _basePos = +_basePos; _basePos resize 3;

        private _offDist = if (_jitter > 0) then { random _jitter } else { 0 };
        private _offDir  = random 360;
        _center = _basePos getPos [_offDist, _offDir];
        _center = +_center; _center resize 3;

        missionNamespace setVariable ["ARC_taskSearchMarkerTaskId", _taskId];
        missionNamespace setVariable ["ARC_taskSearchMarkerCenter", _center];
        missionNamespace setVariable ["ARC_taskSearchMarkerRadiusM", _rad];
    };

    private _p2 = +_center; _p2 resize 2;

    if !("ARC_obj_search_active" in allMapMarkers) then
    {
        createMarker ["ARC_obj_search_active", _p2];
    }
    else
    {
        "ARC_obj_search_active" setMarkerPos _p2;
    };

    "ARC_obj_search_active" setMarkerShape "ELLIPSE";
    "ARC_obj_search_active" setMarkerBrush "SolidBorder";
    "ARC_obj_search_active" setMarkerColor "ColorOrange";
    "ARC_obj_search_active" setMarkerAlpha 0.35;
    "ARC_obj_search_active" setMarkerSize [_rad, _rad];
    "ARC_obj_search_active" setMarkerText "Search Area";
}
else
{
    if ("ARC_obj_search_active" in allMapMarkers) then { deleteMarker "ARC_obj_search_active"; };
};

// 3) CHECKPOINT: spawn a small persistent prop set once (remains in AO)
private _cpEnabled = missionNamespace getVariable ["ARC_checkpointStaticCompsEnabled", true];
if (!(_cpEnabled isEqualType true) && !(_cpEnabled isEqualType false)) then { _cpEnabled = true; };

// Do not spawn extra checkpoint props inside the Airbase zone (gates already have editor-placed assets).
if (_cpEnabled && { _incTypeU isEqualTo "CHECKPOINT" } && { !((toUpper _objKind) isEqualTo "VBIED_VEHICLE") } && { !((toUpper ([_pos] call ARC_fnc_worldGetZoneForPos)) isEqualTo "AIRBASE") }) then
{
    private _sites = missionNamespace getVariable ["ARC_persistentCheckpointSites", []];
    if (!(_sites isEqualType [])) then { _sites = []; };

    // Don't stack multiple checkpoints at the same location.
    private _exists = false;
    { if ((_pos distance2D _x) < 80) exitWith { _exists = true; }; } forEach _sites;

    if (!_exists) then
    {
        private _basePos = +_pos; _basePos resize 3;

        // Snap to nearest road if possible (keeps the prop set sensible).
        private _roads = _basePos nearRoads 60;
        private _road = objNull;

        if ((count _roads) > 0) then
        {
            private _bestD = 1e12;
            {
                private _d = _basePos distance2D _x;
                if (_d < _bestD) then { _bestD = _d; _road = _x; };
            } forEach _roads;

            if (!isNull _road) then
            {
                _basePos = getPosATL _road;
                _basePos resize 3;
            };
        };

        private _dir = random 360;
        if (!isNull _road) then
        {
            private _conn = roadsConnectedTo _road;
            if ((count _conn) > 0) then
            {
                _dir = _road getDir (_conn select 0);
            };
        };

        private _make = {
            params ["_cls", "_posATL", "_dirDeg"];
            private _o = createVehicle [_cls, _posATL, [], 0, "CAN_COLLIDE"];
            _o setDir _dirDeg;
            _o setPosATL _posATL;
            _o allowDamage false;
            _o setVariable ["ARC_persistInAO", true, true];
            _o setVariable ["ARC_staticCompType", "CHECKPOINT", true];
            _o
        };

        // Chicane-style barriers + cones (lightweight, vanilla).
        private _objs = [];

        private _b1Pos = _basePos getPos [4, _dir + 90];
        private _b2Pos = _basePos getPos [4, _dir - 90];
        private _b3Pos = _basePos getPos [9, _dir + 90];
        private _b4Pos = _basePos getPos [9, _dir - 90];

        _objs pushBack (["Land_CncBarrier_F", _b1Pos, _dir] call _make);
        _objs pushBack (["Land_CncBarrier_F", _b2Pos, _dir] call _make);
        _objs pushBack (["Land_CncBarrier_F", _b3Pos, _dir] call _make);
        _objs pushBack (["Land_CncBarrier_F", _b4Pos, _dir] call _make);

        _objs pushBack (["RoadCone_F", (_basePos getPos [10, _dir]), _dir] call _make);
        _objs pushBack (["RoadCone_F", (_basePos getPos [10, _dir + 30]), _dir] call _make);
        _objs pushBack (["RoadCone_F", (_basePos getPos [10, _dir - 30]), _dir] call _make);

        _objs pushBack (["RoadCone_F", (_basePos getPos [4, _dir]), _dir] call _make);
        _objs pushBack (["RoadCone_F", (_basePos getPos [4, _dir + 30]), _dir] call _make);
        _objs pushBack (["RoadCone_F", (_basePos getPos [4, _dir - 30]), _dir] call _make);

        // Optional light.
        _objs pushBack (["Land_PortableLight_double_F", (_basePos getPos [6, _dir + 120]), _dir + 180] call _make);

        
// Track created objects for hard-reset cleanup (debug reset should be absolute).
private _cpNetIds = missionNamespace getVariable ["ARC_persistentCheckpointNetIds", []];
if (!(_cpNetIds isEqualType [])) then { _cpNetIds = []; };
{ if (!isNull _x) then { _cpNetIds pushBack (netId _x); }; } forEach _objs;
missionNamespace setVariable ["ARC_persistentCheckpointNetIds", _cpNetIds];

_sites pushBack _basePos;
        missionNamespace setVariable ["ARC_persistentCheckpointSites", _sites];

        ["OPS", format ["Persistent checkpoint props spawned at %1.", mapGridPosition _basePos], _basePos, [["taskId", _taskId], ["event", "CHECKPOINT_COMPOSITION_SPAWNED"]]] call ARC_fnc_intelLog;
    };
};


// Friendly presence check (west + independent)
private _players = allPlayers select { alive _x && { side group _x in [west, independent] } };

// Anchor list for on-site detection.
// INTERACT tasks may spawn their objective outside the incident center radius. For example,
// a CIV_MEET liaison NPC spawns in the nearest enterable building within up to 350m of the
// incident center, and cache containers can be placed up to 380m away. Without the objective
// position as an additional anchor, players who go straight to the objective (guided by the
// objective map marker) would never trigger AO activation even while standing on it. The
// SITREP anchor list already includes the objective position; this aligns the on-site check.
private _anchorPosList = [_pos];
if (_execKind isEqualTo "INTERACT") then
{
    private _oPos = ["activeObjectivePos", []] call ARC_fnc_stateGet;
    if (_oPos isEqualType [] && { (count _oPos) >= 2 }) then
    {
        _anchorPosList pushBackUnique _oPos;
    };
};

private _onSite = false;
{
    private _p = _x;
    private _nearAnchor = false;
    { if ((_p distance2D _x) <= _radius) exitWith { _nearAnchor = true; }; } forEach _anchorPosList;
    if (_nearAnchor) exitWith { _onSite = true; };
} forEach _players;

// Route recon uses a start point for AO activation (not the incident center).
if (_execKind isEqualTo "ROUTE_RECON") then
{
    private _sPos = ["activeReconRouteStartPos", []] call ARC_fnc_stateGet;
    private _sRad = ["activeReconRouteStartRadius", 60] call ARC_fnc_stateGet;
    if (!(_sRad isEqualType 0) || { _sRad <= 0 }) then { _sRad = 60; };
    _sRad = (_sRad max 25) min 250;

    if (_sPos isEqualType [] && { (count _sPos) >= 2 }) then
    {
        _onSite = false;
        { if ((_x distance2D _sPos) <= _sRad) exitWith { _onSite = true; }; } forEach _players;
    };
};

// AO activation: treat as a server-side trigger.
// This lets us start certain mission logic when players are actually on-scene
// (and prevents early-fail objectives from being destroyed before anyone arrives).
private _activated = ["activeExecActivated", false] call ARC_fnc_stateGet;
if (_onSite && { !_activated }) then
{
    _activated = true;
    ["activeExecActivated", true] call ARC_fnc_stateSet;
    ["activeExecActivatedAt", _now] call ARC_fnc_stateSet;

    // Arm vulnerable objectives (those that fail if killed) only after AO activation.
    private _armed = ["activeObjectiveArmed", true] call ARC_fnc_stateGet;
    if (!_armed) then
    {
        private _nid = ["activeObjectiveNetId", ""] call ARC_fnc_stateGet;
        if (!(_nid isEqualTo "")) then
        {
            private _obj = objectFromNetId _nid;
            if (!isNull _obj) then
            {
                _obj allowDamage true;
	                private _ok = toUpper (_obj getVariable ["ARC_objectiveKind", ""]);
	                if (_ok isEqualTo "IED_DEVICE") then
	                {
	                    // If the IED prop was spawned inert, enable simulation once players are on-station.
	                    _obj enableSimulationGlobal true;
	                };
                ["activeObjectiveArmed", true] call ARC_fnc_stateSet;
            };
        };
    };

    private _grid = mapGridPosition _pos;
    private _msg = if (_execKind isEqualTo "ARRIVE_HOLD") then
    {
        format ["On-station at %1. Beginning stabilization window.", _grid]
    }
    else
    {
        format ["On-station at %1. Beginning mission execution.", _grid]
    };

    ["OPS", _msg, _pos, [["taskId", _taskId], ["event", "AO_ACTIVATED"]]] call ARC_fnc_intelLog;
    // Threat system hook (v0): recordkeeping only, idempotent
    private _zone = ["activeIncidentZone", ""] call ARC_fnc_stateGet;
    if (!(_zone isEqualType "")) then { _zone = ""; };
    if (_zone isEqualTo "") then { _zone = [_pos] call ARC_fnc_worldGetZoneForPos; };

    private _markerName = ["activeIncidentMarker", ""] call ARC_fnc_stateGet;
    if (!(_markerName isEqualType "")) then { _markerName = ""; };

    private _aoCtx = [
        ["ao_id", _taskId],
        ["task_ids_activated", [_taskId]],
        ["task_id", _taskId],
        ["incident_type", _incType],
        ["zone", _zone],
        ["district_id", "D00"],
        ["pos", _pos],
        ["radius_m", _radius],
        ["marker", _markerName]
    ];
    ["AO_ACTIVATED", _aoCtx] call ARC_fnc_threatOnAOActivated;

    // PATROL tasks: generate a route and spawn light contact only after players arrive.
    private _typeU = toUpper (["activeIncidentType", ""] call ARC_fnc_stateGet);
    if (_typeU isEqualTo "PATROL") then
    {
        // Zone context is used to clamp patrol route radius in sensitive areas.
        private _zone = ["activeIncidentZone", ""] call ARC_fnc_stateGet;
        if (!(_zone isEqualType "")) then { _zone = ""; };
        if (_zone isEqualTo "") then
        {
            _zone = [_pos] call ARC_fnc_worldGetZoneForPos;
        };

        [_taskId, _pos, _radius, _zone] call ARC_fnc_opsPatrolOnActivate;
    };
};

// ---------------------------------------------------------------------------
// IED detonation assessment (lightweight snapshotting)
//
// We keep a short-term snapshot of nearby civilians while the IED incident is active so that
// detonation handling can count "new" civilian KIA without needing deep analytics.
// ---------------------------------------------------------------------------
if (_activated && { _incTypeU isEqualTo "IED" }) then
{
    private _handled = ["activeIedDetonationHandled", false] call ARC_fnc_stateGet;
    if (!(_handled isEqualType true)) then { _handled = false; };

    if (!_handled) then
    {
        private _interval = missionNamespace getVariable ["ARC_iedCivSnapshotIntervalSec", 10];
        if (!(_interval isEqualType 0) || { _interval <= 0 }) then { _interval = 10; };
        _interval = (_interval max 5) min 60;

        private _lastSnap = ["activeIedCivSnapshotAt", -1] call ARC_fnc_stateGet;
        if (!(_lastSnap isEqualType 0)) then { _lastSnap = -1; };

        if (_lastSnap < 0 || { (_now - _lastSnap) >= _interval }) then
        {
            private _center = ["activeObjectivePos", []] call ARC_fnc_stateGet;
            if (!(_center isEqualType []) || { (count _center) < 2 }) then { _center = _pos; };
            _center = +_center; _center resize 3;

            private _rad = missionNamespace getVariable ["ARC_iedCivSnapshotRadiusM", 200];
            if (!(_rad isEqualType 0) || { _rad <= 0 }) then { _rad = 200; };
            _rad = (_rad max 50) min 800;

            private _men = nearestObjects [_center, ["Man"], _rad];
            private _nids = [];
            {
                if (alive _x && { (side group _x) isEqualTo civilian }) then
                {
                    _nids pushBackUnique (netId _x);
                };
            } forEach _men;

            ["activeIedCivSnapshotNetIds", _nids] call ARC_fnc_stateSet;
            ["activeIedCivSnapshotAt", _now] call ARC_fnc_stateSet;
        };
    };
};

// Helper: mirror key exec fields to missionNamespace for client-side UI (timers / awareness).
private _broadcast = {
    // NOTE: Keep this lightweight. Client HUD computes countdowns locally using serverTime + these values.
    missionNamespace setVariable ["ARC_activeExecKind", _execKind, true];
    missionNamespace setVariable ["ARC_activeExecPos", _pos, true];
    missionNamespace setVariable ["ARC_activeExecRadius", _radius, true];
    missionNamespace setVariable ["ARC_activeExecDeadlineAt", _deadlineAt, true];
    missionNamespace setVariable ["ARC_activeExecHoldReq", _holdReq, true];
    missionNamespace setVariable ["ARC_activeExecHoldAccum", _holdAccum, true];
    missionNamespace setVariable ["ARC_activeExecArrivalReq", _arrivalReq, true];
    missionNamespace setVariable ["ARC_activeExecArrived", _arrived, true];
    missionNamespace setVariable ["ARC_activeExecActivated", _activated, true];
    missionNamespace setVariable ["ARC_activeExecStartedAt", _startedAt, true];

    // Client-side SITREP gating support: additional anchor positions and dynamic proximity.
    private _sitrepProx = ["activeSitrepProximityM", 350] call ARC_fnc_stateGet;
    if (!(_sitrepProx isEqualType 0) || { _sitrepProx <= 0 }) then
    {
        _sitrepProx = missionNamespace getVariable ["ARC_sitrepProximityM_default", 350];
        if (!(_sitrepProx isEqualType 0)) then { _sitrepProx = 350; };
    };
    _sitrepProx = (_sitrepProx max 75) min 2000;
    missionNamespace setVariable ["ARC_sitrepProximityM", _sitrepProx, true];

    private _anchors = [];
    private _oPos = ["activeObjectivePos", []] call ARC_fnc_stateGet;
    if (_oPos isEqualType [] && { (count _oPos) >= 2 }) then
    {
        _oPos = +_oPos; _oPos resize 3;
        _anchors pushBack _oPos;
    };
    // Broadcast objective position so ATH clients can compute distance to objective,
    // not just distance to the incident center.
    missionNamespace setVariable ["ARC_activeObjectivePos", _oPos, true];

    // If patrol routes are used, include route points as additional anchors.
    private _pPts = ["activePatrolRoutePosList", []] call ARC_fnc_stateGet;
    if (_pPts isEqualType [] && { (count _pPts) > 0 }) then
    {
        {
            if (_x isEqualType [] && { (count _x) >= 2 }) then
            {
                private _p = +_x; _p resize 3;
                _anchors pushBack _p;
            };
        } forEach _pPts;
    };

    // Route recon: include start/end points as additional SITREP anchors.
    if (_execKind isEqualTo "ROUTE_RECON") then
    {
        private _s = ["activeReconRouteStartPos", []] call ARC_fnc_stateGet;
        if (_s isEqualType [] && { (count _s) >= 2 }) then
        {
            _s = +_s; _s resize 3;
            _anchors pushBack _s;
        };

        private _e = ["activeReconRouteEndPos", []] call ARC_fnc_stateGet;
        if (_e isEqualType [] && { (count _e) >= 2 }) then
        {
            _e = +_e; _e resize 3;
            _anchors pushBack _e;
        };
    };

    missionNamespace setVariable ["ARC_sitrepAnchorPosList", _anchors, true];
};

// INTERACT tasks: objective existence + kill-fail enforcement
if (_execKind isEqualTo "INTERACT") then
{
    private _objKind = ["activeObjectiveKind", ""] call ARC_fnc_stateGet;
    private _nid     = ["activeObjectiveNetId", ""] call ARC_fnc_stateGet;

    if (!(_objKind isEqualTo "") && { !(_nid isEqualTo "") }) then
    {
        private _obj = objectFromNetId _nid;

        if (isNull _obj) then
        {
            // Objective vanished (restart cleanup, deletion). Rebuild plan once.
            ["activeExecTaskId", ""] call ARC_fnc_stateSet;
            [] call ARC_fnc_execInitActive;
        }
        else
        {
            // For certain objective kinds, the objective dying should fail the task.
            if (_objKind in ["IED_DEVICE", "CIV_MEET"] && { !alive _obj }) then
            {
                ["FAILED", "OBJECTIVE_KILLED", "Objective asset was lost. Recommend closing this incident as FAILED.", _pos] call ARC_fnc_incidentMarkReadyToClose;
            };
        };
    };
};

// ROUTE_RECON logic: sequential start -> end progression.
if (_execKind isEqualTo "ROUTE_RECON") exitWith
{
    private _sPos = ["activeReconRouteStartPos", []] call ARC_fnc_stateGet;
    private _ePos = ["activeReconRouteEndPos", []] call ARC_fnc_stateGet;

    private _sRad = ["activeReconRouteStartRadius", 60] call ARC_fnc_stateGet;
    if (!(_sRad isEqualType 0) || { _sRad <= 0 }) then { _sRad = 60; };
    _sRad = (_sRad max 25) min 250;

    private _eRad = ["activeReconRouteEndRadius", 60] call ARC_fnc_stateGet;
    if (!(_eRad isEqualType 0) || { _eRad <= 0 }) then { _eRad = 60; };
    _eRad = (_eRad max 25) min 250;

    private _startReached = ["activeReconRouteStartReached", false] call ARC_fnc_stateGet;
    if (!(_startReached isEqualType true)) then { _startReached = false; };

    private _endReached = ["activeReconRouteEndReached", false] call ARC_fnc_stateGet;
    if (!(_endReached isEqualType true)) then { _endReached = false; };

    private _startTaskId = ["activeReconRouteStartTaskId", ""] call ARC_fnc_stateGet;
    if (!(_startTaskId isEqualType "")) then { _startTaskId = ""; };

    private _endTaskId = ["activeReconRouteEndTaskId", ""] call ARC_fnc_stateGet;
    if (!(_endTaskId isEqualType "")) then { _endTaskId = ""; };

    // 1) Start gate
    if (!_startReached && { _sPos isEqualType [] && { (count _sPos) >= 2 } }) then
    {
        private _atStart = false;
        { if ((_x distance2D _sPos) <= _sRad) exitWith { _atStart = true; }; } forEach _players;
        if (_atStart) then
        {
            _startReached = true;
            ["activeReconRouteStartReached", true] call ARC_fnc_stateSet;
            ["activeExecLastProgressAt", _now] call ARC_fnc_stateSet;

            if (!(_startTaskId isEqualTo "")) then { [_startTaskId, "SUCCEEDED", true] call BIS_fnc_taskSetState; };
            if (!(_endTaskId isEqualTo "")) then { [_endTaskId, "ASSIGNED", true] call BIS_fnc_taskSetState; };

	            // Current task is local per-client; broadcast the switch to the end gate task.
	            if (!(_endTaskId isEqualTo "")) then
	            {
	                [_endTaskId] remoteExecCall ["ARC_fnc_clientSetCurrentTask", 0];
	            };

            ["OPS", format ["Route recon initiated at %1.", mapGridPosition _sPos], _sPos, [["taskId", _taskId], ["event", "ROUTE_RECON_START_REACHED"]]] call ARC_fnc_intelLog;
        };
    };

    // 2) End gate
    if (_startReached && { !_endReached } && { _ePos isEqualType [] && { (count _ePos) >= 2 } }) then
    {
        private _atEnd = false;
        { if ((_x distance2D _ePos) <= _eRad) exitWith { _atEnd = true; }; } forEach _players;
        if (_atEnd) then
        {
            _endReached = true;
            ["activeReconRouteEndReached", true] call ARC_fnc_stateSet;
            ["activeExecLastProgressAt", _now] call ARC_fnc_stateSet;

            if (!(_endTaskId isEqualTo "")) then { [_endTaskId, "SUCCEEDED", true] call BIS_fnc_taskSetState; };

            ["OPS", format ["Route recon complete at %1.", mapGridPosition _ePos], _ePos, [["taskId", _taskId], ["event", "ROUTE_RECON_END_REACHED"]]] call ARC_fnc_intelLog;

            ["SUCCEEDED", "ROUTE_RECON_COMPLETE", "Route recon end point reached. Recommend closing this incident as SUCCEEDED.", _ePos] call ARC_fnc_incidentMarkReadyToClose;
        };
    };

    call _broadcast;
    true
};

// ARRIVE_HOLD gating: if not arrived yet, enforce arrival window and stop early
if (_execKind isEqualTo "ARRIVE_HOLD" && { !_arrived }) exitWith
{
    if (_onSite) then
    {
        _arrived = true;
        _holdAccum = 0;
        ["activeExecArrived", true] call ARC_fnc_stateSet;
        ["activeExecHoldAccum", 0] call ARC_fnc_stateSet;
        ["activeExecLastProg", -1] call ARC_fnc_stateSet;
        ["activeExecLastProgressAt", _now] call ARC_fnc_stateSet;

    }
    else
    {
        if (_arrivalReq > 0 && { _startedAt isEqualType 0 } && { (_now - _startedAt) > _arrivalReq }) then
        {
            ["FAILED", "ARRIVAL_WINDOW_MISSED", "Team did not arrive within the required window. Recommend closing this incident as FAILED.", _pos] call ARC_fnc_incidentMarkReadyToClose;
        };
    };

    call _broadcast;
    true
};

// HOLD logic (covers HOLD and ARRIVE_HOLD after arrival)
if (_execKind in ["HOLD", "ARRIVE_HOLD"]) then
{
    if (_holdReq <= 0) exitWith { call _broadcast; true };

    if (_onSite) then
    {
        _holdAccum = _holdAccum + _dt;
        if (_holdAccum > _holdReq) then { _holdAccum = _holdReq; };
        ["activeExecHoldAccum", _holdAccum] call ARC_fnc_stateSet;
        ["activeExecLastProgressAt", _now] call ARC_fnc_stateSet;

        // Progress SITREPs at 25/50/75%; activeExecLastProg remains a bucket index (not a timestamp).
        private _bucket     = floor ((_holdAccum / _holdReq) * 4);
        private _lastBucket = ["activeExecLastProg", -1] call ARC_fnc_stateGet;

        if (_bucket > _lastBucket && { _bucket in [1, 2, 3] }) then
        {
            ["activeExecLastProg", _bucket] call ARC_fnc_stateSet;
            ["activeExecLastProgressAt", _now] call ARC_fnc_stateSet;

            private _pct  = _bucket * 25;
            private _grid = mapGridPosition _pos;
            ["OPS", format ["Hold progress at %1: %2%3 complete.", _grid, _pct, "%"], _pos, [["taskId", _taskId], ["event", "PROGRESS"], ["pct", _pct]]] call ARC_fnc_intelLog;
        };

        if (_holdAccum >= _holdReq) then
        {
            ["SUCCEEDED", "HOLD_COMPLETE", "Hold requirement met. Recommend closing this incident as SUCCEEDED.", _pos] call ARC_fnc_incidentMarkReadyToClose;
        };
    };
};

call _broadcast;
true

/*
    Server: cleanup any spawned objective objects/NPCs associated with the active incident.

    This is called when an incident closes or when resetting the persistence/task system.

    Modes:
        "IMMEDIATE" (default) - delete objects now
        "DEFER"              - register objects for deferred cleanup once players leave the area

    Params:
        0: STRING - mode

    Returns:
        BOOL
*/

if (!isServer) exitWith {false};

params [["_mode", "IMMEDIATE"]];

private _m = toUpper _mode;
private _defer = (_m in ["DEFER", "DEFERRED"]);

// Anchor for deferred cleanup (prefer exec AO position)
private _anchor = ["activeExecPos", []] call ARC_fnc_stateGet;
if (!(_anchor isEqualType []) || { (count _anchor) < 2 }) then
{
    _anchor = ["activeIncidentPos", []] call ARC_fnc_stateGet;
};
if (!(_anchor isEqualType []) || { (count _anchor) < 2 }) then { _anchor = []; };

private _radius = missionNamespace getVariable ["ARC_cleanupRadiusM", 1000];
if (!(_radius isEqualType 0)) then { _radius = 1000; };
_radius = (_radius max 200) min 5000;

private _minDelay = missionNamespace getVariable ["ARC_cleanupMinDelaySec", 25];
if (!(_minDelay isEqualType 0)) then { _minDelay = 25; };
_minDelay = (_minDelay max 0) min 600;

private _debug = missionNamespace getVariable ["ARC_debugCleanup", false];

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

// --- Objective object/NPC -----------------------------------------------------
private _nid = ["activeObjectiveNetId", ""] call ARC_fnc_stateGet;
if (_nid isNotEqualTo "") then
{
    private _obj = objectFromNetId _nid;
    if (!isNull _obj) then
    {
        if (_defer) then
        {
            // Register for cleanup once players leave the AO.
            // Anchor defaults to AO; if missing, anchor will fall back to object position.
            // Default label. Threat system can override for IED/VBIED to enable CLEANED state updates.
        private _label = "objective";
        private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
        private _kind = ["activeObjectiveKind", ""] call ARC_fnc_stateGet;

        if (
            (_taskId isNotEqualTo "")
            && { (_kind isEqualTo "IED_DEVICE") || { _kind isEqualTo "VBIED_VEHICLE" } }
            && { !isNil "ARC_fnc_threatGetCleanupLabelForTask" }
        ) then
        {
            private _tl = [_taskId] call ARC_fnc_threatGetCleanupLabelForTask;
            if (_tl isNotEqualTo "") then { _label = _tl; };
        };

        [_obj, _anchor, _radius, _minDelay, _label] call ARC_fnc_cleanupRegister;
        }
        else
        {
            deleteVehicle _obj;
        };
    };
};

missionNamespace setVariable ["ARC_activeObjective", objNull, true];

// --- IED Phase 1 trigger cleanup (server only) ------------------------------
private _trg = missionNamespace getVariable ["ARC_activeIedTrigger", objNull];
if (!isNull _trg) then { deleteVehicle _trg; };
missionNamespace setVariable ["ARC_activeIedTrigger", objNull];
missionNamespace setVariable ["ARC_activeIedTriggerDeviceId", ""];
["activeIedTriggerEnabled", false] call ARC_fnc_stateSet;
["activeIedTriggerRadiusM", 0] call ARC_fnc_stateSet;
["activeIedDeviceId", ""] call ARC_fnc_stateSet;
["activeIedDeviceNetId", ""] call ARC_fnc_stateSet;
["activeIedDeviceState", ""] call ARC_fnc_stateSet;
["activeIedDeviceRecord", []] call ARC_fnc_stateSet;


// --- IED Phase 2 evidence cleanup -------------------------------------------
private _evNid = ["activeIedEvidenceNetId", ""] call ARC_fnc_stateGet;
if (_evNid isEqualType "" && { _evNid isNotEqualTo "" }) then
{
    private _ev = objectFromNetId _evNid;
    if (!isNull _ev) then { deleteVehicle _ev; };
};
["activeIedEvidenceNetId", ""] call ARC_fnc_stateSet;
["activeIedEvidenceCreatedAt", -1] call ARC_fnc_stateSet;
["activeIedEvidenceCollected", false] call ARC_fnc_stateSet;
["activeIedEvidenceCollectedAt", -1] call ARC_fnc_stateSet;
["activeIedEvidenceCollectedBy", ""] call ARC_fnc_stateSet;
["activeIedEvidenceLeadId", ""] call ARC_fnc_stateSet;
["activeIedDetectedByScan", false] call ARC_fnc_stateSet;


// --- IED Phase 3 (VBIED v1) cleanup ----------------------------------------
private _vTrgNid = ["activeVbiedTriggerNetId", ""] call ARC_fnc_stateGet;
if (_vTrgNid isEqualType "" && { _vTrgNid isNotEqualTo "" }) then
{
    private _vt = objectFromNetId _vTrgNid;
    if (!isNull _vt) then { deleteVehicle _vt; };
};
["activeVbiedTriggerNetId", ""] call ARC_fnc_stateSet;
["activeVbiedTriggerEnabled", false] call ARC_fnc_stateSet;
["activeVbiedTriggerRadiusM", 0] call ARC_fnc_stateSet;
["activeVbiedDeviceId", ""] call ARC_fnc_stateSet;
["activeVbiedVehicleNetId", ""] call ARC_fnc_stateSet;
["activeVbiedDeviceRecord", []] call ARC_fnc_stateSet;
["activeVbiedLastArmedAt", -1] call ARC_fnc_stateSet;
["activeVbiedDetonated", false] call ARC_fnc_stateSet;
["activeVbiedDetonatedAt", -1] call ARC_fnc_stateSet;


missionNamespace setVariable ["ARC_exec_lastTick", nil];


// --- Cache objective containers (multi-object) -------------------------------
private _cacheNids = ["activeCacheContainerNetIds", []] call ARC_fnc_stateGet;
if (_cacheNids isEqualType [] && { (count _cacheNids) > 0 }) then
{
    private _objs = [];
    {
        private _o = objectFromNetId _x;
        if (!isNull _o) then { _objs pushBack _o; };
    } forEach _cacheNids;

    if ((count _objs) > 0) then
    {
        if (_defer) then
        {
            [_objs, _anchor, _radius, _minDelay, "cache"] call ARC_fnc_cleanupRegister;
        }
        else
        {
            { if (!isNull _x) then { deleteVehicle _x; }; } forEach _objs;
        };
    };
};
["activeCacheContainerNetIds", []] call ARC_fnc_stateSet;
["activeCacheTrueNetId", ""] call ARC_fnc_stateSet;

// PATROL: clean up any route markers / spawned contacts tied to the active task.
private _mks = ["activePatrolRouteMarkerNames", []] call ARC_fnc_stateGet;
if (_mks isEqualType []) then
{
    { deleteMarker _x; } forEach _mks;
};
["activePatrolRouteMarkerNames", []] call ARC_fnc_stateSet;
["activePatrolRoutePosList", []] call ARC_fnc_stateSet;

private _pNids = ["activePatrolContactsNetIds", []] call ARC_fnc_stateGet;
if (_pNids isEqualType []) then
{
    {
        private _o = objectFromNetId _x;
        if (!isNull _o) then { deleteVehicle _o; };
    } forEach _pNids;
};
["activePatrolContactsNetIds", []] call ARC_fnc_stateSet;
["activePatrolContactsSpawned", false] call ARC_fnc_stateSet;

// --- Local friendly support presence ----------------------------------------
private _lsNids = ["activeLocalSupportNetIds", []] call ARC_fnc_stateGet;
if (_lsNids isEqualType [] && { (count _lsNids) > 0 }) then
{
    // Optional: persist host-nation support forces in the AO like checkpoint compositions.
    // When enabled, these units remain in the world after task closure (dynamic simulation recommended).
    private _persistLS = missionNamespace getVariable ["ARC_localSupportPersistInAO", false];
    if (!(_persistLS isEqualType true) && !(_persistLS isEqualType false)) then { _persistLS = false; };

    if (!_persistLS) then
    {
        private _lsObjs = [];
        private _lsGroups = [];

        {
            private _u = objectFromNetId _x;
            if (isNull _u) then { continue; };
            _lsObjs pushBack _u;

            private _g = group _u;
            if (!isNull _g) then { _lsGroups pushBackUnique _g; };
        } forEach _lsNids;

        if ((count _lsObjs) > 0) then
        {
            if (_defer) then
            {
                private _lsRad = missionNamespace getVariable ["ARC_cleanupRadiusLocalSupportM", _radius];
                if (!(_lsRad isEqualType 0) || { _lsRad <= 0 }) then { _lsRad = _radius; };
                _lsRad = (_lsRad max 200) min 5000;

                private _lsDelay = missionNamespace getVariable ["ARC_cleanupMinDelayLocalSupportSec", _minDelay];
                if (!(_lsDelay isEqualType 0) || { _lsDelay < 0 }) then { _lsDelay = _minDelay; };
                _lsDelay = (_lsDelay max 0) min 600;

                [_lsObjs, _anchor, _lsRad, _lsDelay, "localSupport"] call ARC_fnc_cleanupRegister;
            }
            else
            {
                { if (!isNull _x && { !isPlayer _x }) then { deleteVehicle _x; }; } forEach _lsObjs;
                { if (!isNull _x) then { deleteGroup _x; }; } forEach _lsGroups;
            };
        };
    };
};
["activeLocalSupportNetIds", []] call ARC_fnc_stateSet;
["activeLocalSupportSpawned", false] call ARC_fnc_stateSet;

// Route support elements
//
// UX01 left these intentionally persistent, but playtests show they accumulate and never despawn.
// We now queue them for cleanup (unless explicitly configured to persist in AO).
private _rsNids = ["activeRouteSupportNetIds", []] call ARC_fnc_stateGet;
if (!(_rsNids isEqualType [])) then { _rsNids = []; };

private _persistRS = missionNamespace getVariable ["ARC_routeSupportPersistInAO", false];
if (!(_persistRS isEqualType true)) then { _persistRS = false; };

if (!_persistRS && { !(_rsNids isEqualTo []) }) then
{
    private _rsObjs = [];
    {
        private _o = objectFromNetId _x;
        if (!isNull _o) then { _rsObjs pushBack _o; };
    } forEach _rsNids;

    _rsObjs = _rsObjs arrayIntersect _rsObjs; // de-dup

    if (!(_rsObjs isEqualTo [])) then
    {
        if (_defer) then
        {
            private _rsRadius = missionNamespace getVariable ["ARC_cleanupRadiusRouteSupportM", 450];
            if (!(_rsRadius isEqualType 0) || { _rsRadius <= 0 }) then { _rsRadius = 450; };
            _rsRadius = (_rsRadius max 50) min 2500;

            private _rsMinDelay = missionNamespace getVariable ["ARC_cleanupMinDelayRouteSupportSec", -1];
            if (!(_rsMinDelay isEqualType 0) || { _rsMinDelay < 0 }) then
            {
                _rsMinDelay = missionNamespace getVariable ["ARC_cleanupMinDelaySec", 25];
                if (!(_rsMinDelay isEqualType 0)) then { _rsMinDelay = 25; };
            };
            _rsMinDelay = (_rsMinDelay max 5) min 3600;

            [_rsObjs, _anchor, _rsRadius, _rsMinDelay, "routeSupport"] call ARC_fnc_cleanupRegister;
        }
        else
        {
            {
                if (!isNull _x && { !isPlayer _x }) then { deleteVehicle _x; };
            } forEach _rsObjs;
        };
    };

    // If route support is not meant to persist, clear the "do-not-stack" site registry.
    // NOTE: keep it when cleanup is deferred to prevent stacking if a new task spawns before cleanup deletes old support.
    if (!_defer) then { missionNamespace setVariable ["ARC_persistentRouteSupportSites", [], true]; };
};

// Clear active-task tracking
["activeRouteSupportNetIds", []] call ARC_fnc_stateSet;
["activeRouteSupportSpawned", false] call ARC_fnc_stateSet;
["activeRouteSupportTaskId", ""] call ARC_fnc_stateSet;

// Clear client-side SITREP gating helpers (anchors + proximity).
missionNamespace setVariable ["ARC_sitrepAnchorPosList", [], true];
private _sitrepDef = missionNamespace getVariable ["ARC_sitrepProximityM_default", 350];
if (!(_sitrepDef isEqualType 0)) then { _sitrepDef = 350; };
missionNamespace setVariable ["ARC_sitrepProximityM", _sitrepDef, true];

// --- Convoy vehicles ----------------------------------------------------------
private _cNids = ["activeConvoyNetIds", []] call ARC_fnc_stateGet;
if (_cNids isEqualType [] && { (count _cNids) > 0 }) then
{
    private _veh = [];
    {
        private _v = objectFromNetId _x;
        if (!isNull _v) then { _veh pushBack _v; };
    } forEach _cNids;

    if ((count _veh) > 0) then
    {
        if (_defer) then
        {
            // Freeze them so they don't keep roaming after handoff.
            {
                if (!isNull _x) then
                {
                    _x setFuel 0;
                    _x limitSpeed 0;
                };
            } forEach _veh;

            private _convoyAnchor = _anchor;
            if ((count _veh) > 0) then
            {
                private _leadV = _veh # 0;
                if (!isNull _leadV) then { _convoyAnchor = getPosATL _leadV; };
            };

            // Convoy assets should despawn even while players are on the same base,
            // so we use a tighter radius than the generic cleanup default.
            private _cRad = missionNamespace getVariable ["ARC_cleanupRadiusConvoyM", _radius];
            if (!(_cRad isEqualType 0) || { _cRad <= 0 }) then { _cRad = _radius; };
            _cRad = (_cRad max 50) min 5000;

            private _cDelay = missionNamespace getVariable ["ARC_cleanupMinDelayConvoySec", _minDelay];
            if (!(_cDelay isEqualType 0) || { _cDelay < 0 }) then { _cDelay = _minDelay; };
            _cDelay = (_cDelay max 0) min 3600;

            [_veh, _convoyAnchor, _cRad, _cDelay, "convoy"] call ARC_fnc_cleanupRegister;
        }
        else
        {
            { [_x] call _deleteVehicleWithCrew; } forEach _veh;
        };
    };
};

// --- Clear execution/convoy state (always) -----------------------------------
["activeExecLastProgressAt", -1] call ARC_fnc_stateSet;
["activeConvoyNetIds", []] call ARC_fnc_stateSet;
["activeConvoyStartPos", []] call ARC_fnc_stateSet;
["activeConvoySpawnPos", []] call ARC_fnc_stateSet;
["activeConvoyStartMarker", ""] call ARC_fnc_stateSet;
["activeConvoyLinkupPos", []] call ARC_fnc_stateSet;
["activeConvoyLinkupReached", false] call ARC_fnc_stateSet;
["activeConvoyDestWpPos", []] call ARC_fnc_stateSet;
["activeConvoySpacingM", -1] call ARC_fnc_stateSet;
["activeConvoySpeedKph", -1] call ARC_fnc_stateSet;
["activeConvoySpeedCapKph", -1] call ARC_fnc_stateSet;
["activeConvoyRoutePoints", []] call ARC_fnc_stateSet;
["activeConvoyRouteMarkers", []] call ARC_fnc_stateSet;
["activeConvoyRouteLenM", -1] call ARC_fnc_stateSet;
["activeConvoyStartedAt", -1] call ARC_fnc_stateSet;
["activeConvoyArrivedAt", -1] call ARC_fnc_stateSet;
["activeConvoyLastProg", -1] call ARC_fnc_stateSet;
["activeConvoyDetectedAt", -1] call ARC_fnc_stateSet;
["activeConvoyDepartAt", -1] call ARC_fnc_stateSet;
["activeConvoyLastMoveAt", -1] call ARC_fnc_stateSet;
["activeConvoyLastMovePos", []] call ARC_fnc_stateSet;
["activeConvoyLastRecoveryAt", -1] call ARC_fnc_stateSet;
["activeConvoyBypassUntil", -1] call ARC_fnc_stateSet;
["activeConvoyIngressPos", []] call ARC_fnc_stateSet;
// Spawn retry bookkeeping
["activeConvoySpawnFailCount", 0] call ARC_fnc_stateSet;
["activeConvoyNextSpawnAttemptAt", -1] call ARC_fnc_stateSet;

// Async spawner state
["activeConvoySpawning", false] call ARC_fnc_stateSet;
["activeConvoySpawningSince", -1] call ARC_fnc_stateSet;

// Link-up child task (created after spawn)
["activeConvoyLinkupTaskId", ""] call ARC_fnc_stateSet;
["activeConvoyLinkupTaskName", ""] call ARC_fnc_stateSet;
["activeConvoyLinkupTaskDone", false] call ARC_fnc_stateSet;

// Clear debug/navigation markers for the completed convoy.
if ("ARC_convoy_start_active" in allMapMarkers) then { deleteMarker "ARC_convoy_start_active"; };
if ("ARC_convoy_linkup_active" in allMapMarkers) then { deleteMarker "ARC_convoy_linkup_active"; };

// Clear route markers (dotted route shown on map).
{
    if ((_x find "ARC_convoy_route_active_") isEqualTo 0) then { deleteMarker _x; };
} forEach allMapMarkers;


// Clear task-related map helpers (objective markers / search areas).
if ("ARC_obj_actor_active" in allMapMarkers) then { deleteMarker "ARC_obj_actor_active"; };
if ("ARC_obj_search_active" in allMapMarkers) then { deleteMarker "ARC_obj_search_active"; };

// Reset server-side marker bookkeeping
missionNamespace setVariable ["ARC_taskMarkers_taskId", ""];
missionNamespace setVariable ["ARC_taskSearchMarkerTaskId", ""];
missionNamespace setVariable ["ARC_taskSearchMarkerCenter", []];
missionNamespace setVariable ["ARC_taskSearchMarkerRadiusM", -1];

// Clear route recon state
["activeReconRouteEnabled", false] call ARC_fnc_stateSet;
["activeReconRouteStartPos", []] call ARC_fnc_stateSet;
["activeReconRouteEndPos", []] call ARC_fnc_stateSet;
["activeReconRouteStartTaskId", ""] call ARC_fnc_stateSet;
["activeReconRouteEndTaskId", ""] call ARC_fnc_stateSet;
["activeReconRouteStartReached", false] call ARC_fnc_stateSet;
["activeReconRouteEndReached", false] call ARC_fnc_stateSet;
["activeReconRouteStartRadius", 60] call ARC_fnc_stateSet;
["activeReconRouteEndRadius", 60] call ARC_fnc_stateSet;

// Clear objective state
["activeObjectiveKind", ""] call ARC_fnc_stateSet;
["activeObjectiveClass", ""] call ARC_fnc_stateSet;
["activeObjectivePos", []] call ARC_fnc_stateSet;
["activeObjectiveNetId", ""] call ARC_fnc_stateSet;
["activeCacheContainerNetIds", []] call ARC_fnc_stateSet;
["activeCacheTrueNetId", ""] call ARC_fnc_stateSet;
["activeObjectiveArmed", true] call ARC_fnc_stateSet;

if (_debug && {_defer}) then
{
    diag_log format ["[ARC][CLEANUP] Deferred cleanup registered (r=%1m) for objective/convoy.", _radius];
};

true

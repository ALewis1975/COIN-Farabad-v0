/*
    Server-side: reset persistence + tasking + intel.

    Intended for debugging and controlled testing.
*/

if (!isServer) exitWith {false};

diag_log "[ARC][RESET] resetAll starting.";

// Guard against the periodic incident loop creating a new task mid-reset.
missionNamespace setVariable ["ARC_resetInProgress", true, true];

// Phase 6: also reset CIVSUB persistence (best-effort)
if (!isNil "ARC_fnc_civsubPersistReset") then { [] call ARC_fnc_civsubPersistReset; };

// After a hard reset, suppress auto incident creation for a short window.
// This prevents a "random" new task from appearing in the log immediately after reset.
private _holdSec = missionNamespace getVariable ["ARC_resetAutoIncidentHoldSec", 300];
if (!(_holdSec isEqualType 0)) then { _holdSec = 300; };
_holdSec = (_holdSec max 0) min 3600;
["autoIncidentSuspendUntil", serverTime + _holdSec] call ARC_fnc_stateSet;

// Collect known task IDs
private _ids = [];

private _pushId = {
    params ["_id"]; 
    if (_id isEqualType "" && {!(_id isEqualTo ""})) then { _ids pushBackUnique _id; };
};

private _active = ["activeTaskId", ""] call ARC_fnc_stateGet;
[_active] call _pushId;

private _linkActive = ["activeConvoyLinkupTaskId", ""] call ARC_fnc_stateGet;
[_linkActive] call _pushId;

private _rStartActive = ["activeReconRouteStartTaskId", ""] call ARC_fnc_stateGet;
[_rStartActive] call _pushId;

private _rEndActive = ["activeReconRouteEndTaskId", ""] call ARC_fnc_stateGet;
[_rEndActive] call _pushId;

private _hist = ["incidentHistory", []] call ARC_fnc_stateGet;
if (_hist isEqualType []) then
{
    {
        _x params ["_tId", "_marker", "_tType", "_tDisp", "_res", "_created", "_closed"];
        [_tId] call _pushId;
        private _lk = format ["%1_LINKUP", _tId];
        [_lk] call _pushId;
        private _rs = format ["%1_routeStart", _tId];
        private _re = format ["%1_routeEnd", _tId];
        [_rs] call _pushId;
        [_re] call _pushId;
    } forEach _hist;
};

// Case-file parent tasks (threads)
private _threads = ["threads", []] call ARC_fnc_stateGet;
if (_threads isEqualType []) then
{
    {
        private _thr = [_x] call ARC_fnc_threadNormalizeRecord;
        if (_thr isEqualTo []) then { continue; };
        private _parent = _thr select 13;
        [_parent] call _pushId;
    } forEach _threads;
};

// Brute cleanup for legacy case-file IDs that may not be present in the thread array
private _oldThreadCounter = ["threadCounter", 0] call ARC_fnc_stateGet;
if (!(_oldThreadCounter isEqualType 0)) then { _oldThreadCounter = 0; };
private _maxCase = (_oldThreadCounter + 250) max 250;
for "_i" from 1 to _maxCase do
{
    private _cid = format ["ARC_case_%1", _i];
    if ([_cid] call BIS_fnc_taskExists) then { [_cid] call _pushId; };
};

// Delete tasks globally
{
    // Best-effort global cleanup. (Tasks may already be gone.)
    [_x, true, true] call BIS_fnc_deleteTask;
} forEach _ids;

// Kill any spawned objective objects/NPCs
// Also purge any deferred cleanup entities immediately (debug reset should be absolute)
[true] call ARC_fnc_cleanupTick;
["IMMEDIATE"] call ARC_fnc_execCleanupActive;


// -------------------------------------------------------------------------
// Extra hard-reset cleanup for persistent AO elements
// -------------------------------------------------------------------------
// Route support elements persist by design during a session, but must be removed during reset.
{
    if (!isPlayer _x && { _x getVariable ["ARC_isRouteSupport", false] }) then
    {
        deleteVehicle _x;
    };
} forEach allUnits;

{
    if (!isNull _x && { _x getVariable ["ARC_isRouteSupport", false] }) then
    {
        deleteVehicle _x;
    };
} forEach vehicles;

// Persisted local-support elements (only those marked persist-in-AO)
{
    if (!isPlayer _x && { _x getVariable ["ARC_isLocalSupport", false] } && { _x getVariable ["ARC_persistInAO", false] }) then
    {
        deleteVehicle _x;
    };
} forEach allUnits;

{
    if (!isNull _x && { _x getVariable ["ARC_isLocalSupport", false] } && { _x getVariable ["ARC_persistInAO", false] }) then
    {
        deleteVehicle _x;
    };
} forEach vehicles;

// Persisted checkpoint props (tracked by netId list)
private _cpNids = missionNamespace getVariable ["ARC_persistentCheckpointNetIds", []];
if (_cpNids isEqualType []) then
{
    {
        private _o = objectFromNetId _x;
        if (!isNull _o) then { deleteVehicle _o; };
    } forEach _cpNids;
};

missionNamespace setVariable ["ARC_persistentCheckpointNetIds", []];
missionNamespace setVariable ["ARC_persistentCheckpointSites", []];
missionNamespace setVariable ["ARC_persistentRouteSupportSites", []];


// Clear state
["taskCounter", 0] call ARC_fnc_stateSet;
["leadCounter", 0] call ARC_fnc_stateSet;
["threadCounter", 0] call ARC_fnc_stateSet;
["incidentHistory", []] call ARC_fnc_stateSet;

// Spawned group designation counters
["unitDesignation_companyIdx", 0] call ARC_fnc_stateSet;
["unitDesignation_platoonNum", 1] call ARC_fnc_stateSet;
["unitDesignation_squadNum", 1] call ARC_fnc_stateSet;

// Strategic / COIN levers (reset to defaults, with optional reroll for testing)
private _rerollEnv = missionNamespace getVariable ["ARC_resetRerollEnvironment", true];
if (!(_rerollEnv isEqualType true) && !(_rerollEnv isEqualType false)) then { _rerollEnv = true; };

private _p = 0.35;
private _corr = 0.55;
private _inf = 0.35;
private _sent = 0.45;
private _leg = 0.45;
// Start at a moderate baseline so logistics pressure exists without dominating the incident catalog.
private _fuel = 0.50;
private _ammo = 0.50;
private _med  = 0.50;

if (_rerollEnv) then
{
	// Keep early campaign pressure lower so mundane tasks can dominate at mission start.
	_p    = ((0.25 + (random 0.25)) max 0) min 1;
	_corr = ((0.40 + (random 0.35)) max 0) min 1;
	_inf  = ((0.20 + (random 0.25)) max 0) min 1;
	_sent = ((0.35 + (random 0.25)) max 0) min 1;
	_leg  = ((0.30 + (random 0.30)) max 0) min 1;
	_fuel = ((0.50 + (random 0.25)) max 0) min 1;
	_ammo = ((0.50 + (random 0.25)) max 0) min 1;
	_med  = ((0.50 + (random 0.25)) max 0) min 1;
};

["civCasualties", 0] call ARC_fnc_stateSet;
["civSentiment", _sent] call ARC_fnc_stateSet;
["govLegitimacy", _leg] call ARC_fnc_stateSet;
["insurgentPressure", _p] call ARC_fnc_stateSet;
["corruption", _corr] call ARC_fnc_stateSet;
["infiltration", _inf] call ARC_fnc_stateSet;
["baseFuel", _fuel] call ARC_fnc_stateSet;
["baseAmmo", _ammo] call ARC_fnc_stateSet;
["baseMed", _med] call ARC_fnc_stateSet;

["activeTaskId", ""] call ARC_fnc_stateSet;
["activeIncidentType", ""] call ARC_fnc_stateSet;
["activeIncidentZone", ""] call ARC_fnc_stateSet;
["activeIncidentMarker", ""] call ARC_fnc_stateSet;
["activeIncidentDisplayName", ""] call ARC_fnc_stateSet;
["activeIncidentCreatedAt", -1] call ARC_fnc_stateSet;
["activeIncidentAccepted", false] call ARC_fnc_stateSet;
["activeIncidentAcceptedAt", -1] call ARC_fnc_stateSet;

["activeIncidentAcceptedBy", ""] call ARC_fnc_stateSet;
["activeIncidentAcceptedByName", ""] call ARC_fnc_stateSet;
["activeIncidentAcceptedByUID", ""] call ARC_fnc_stateSet;
["activeIncidentAcceptedByRoleTag", ""] call ARC_fnc_stateSet;
["activeIncidentAcceptedByGroup", ""] call ARC_fnc_stateSet;

["activeIncidentCivsubDistrictId", ""] call ARC_fnc_stateSet;
["activeIncidentCivsubStartRow", []] call ARC_fnc_stateSet;
["activeIncidentCivsubStartTs", -1] call ARC_fnc_stateSet;


["activeIncidentSitrepSent", false] call ARC_fnc_stateSet;
["activeIncidentSitrepSentAt", -1] call ARC_fnc_stateSet;
["activeIncidentSitrepFrom", ""] call ARC_fnc_stateSet;
["activeIncidentSitrepFromUID", ""] call ARC_fnc_stateSet;
["activeIncidentSitrepFromGroup", ""] call ARC_fnc_stateSet;
["activeIncidentSitrepFromRoleTag", ""] call ARC_fnc_stateSet;
["activeIncidentSitrepSummary", ""] call ARC_fnc_stateSet;
["activeIncidentSitrepDetails", ""] call ARC_fnc_stateSet;
["activeIncidentCloseReady", false] call ARC_fnc_stateSet;
["activeIncidentSuggestedResult", ""] call ARC_fnc_stateSet;
["activeIncidentCloseReason", ""] call ARC_fnc_stateSet;
["activeIncidentCloseMarkedAt", -1] call ARC_fnc_stateSet;

// Sustainment
["sustainLastAt", serverTime] call ARC_fnc_stateSet;

// Lead / thread tracking
["activeIncidentPos", []] call ARC_fnc_stateSet;
["activeLeadId", ""] call ARC_fnc_stateSet;
["activeThreadId", ""] call ARC_fnc_stateSet;
["activeLeadTag", ""] call ARC_fnc_stateSet;

// Last context (follow-on orders / dashboards)
["lastTaskingGroup", ""] call ARC_fnc_stateSet;
["lastTaskingGroupAt", -1] call ARC_fnc_stateSet;
["lastSitrepFrom", ""] call ARC_fnc_stateSet;
["lastSitrepFromGroup", ""] call ARC_fnc_stateSet;
["lastSitrepAt", -1] call ARC_fnc_stateSet;

["lastIncidentPos", []] call ARC_fnc_stateSet;
["lastIncidentZone", ""] call ARC_fnc_stateSet;
["lastIncidentTaskId", ""] call ARC_fnc_stateSet;
["lastIncidentType", ""] call ARC_fnc_stateSet;
["lastIncidentMarker", ""] call ARC_fnc_stateSet;

["leadPool", []] call ARC_fnc_stateSet;
["leadHistory", []] call ARC_fnc_stateSet;
["lastLeadCreated", []] call ARC_fnc_stateSet;
["lastLeadConsumed", []] call ARC_fnc_stateSet;
["threads", []] call ARC_fnc_stateSet;

// Deferred cleanup queue
["cleanupQueue", []] call ARC_fnc_stateSet;

// Execution package
["activeExecTaskId", ""] call ARC_fnc_stateSet;
["activeExecKind", ""] call ARC_fnc_stateSet;
["activeExecPos", []] call ARC_fnc_stateSet;
["activeExecRadius", 0] call ARC_fnc_stateSet;
["activeExecStartedAt", -1] call ARC_fnc_stateSet;
["activeExecDeadlineAt", -1] call ARC_fnc_stateSet;
["activeExecArrivalReq", 0] call ARC_fnc_stateSet;
["activeExecArrived", false] call ARC_fnc_stateSet;
["activeExecHoldReq", 0] call ARC_fnc_stateSet;
["activeExecHoldAccum", 0] call ARC_fnc_stateSet;
["activeExecLastProg", -1] call ARC_fnc_stateSet;
["activeExecLastProgressAt", -1] call ARC_fnc_stateSet;
["activeObjectiveKind", ""] call ARC_fnc_stateSet;
["activeObjectiveClass", ""] call ARC_fnc_stateSet;
["activeObjectivePos", []] call ARC_fnc_stateSet;
["activeObjectiveNetId", ""] call ARC_fnc_stateSet;

// Convoy execution state (LOGISTICS / ESCORT)
["activeConvoyNetIds", []] call ARC_fnc_stateSet;
["activeConvoyStartPos", []] call ARC_fnc_stateSet;
["activeConvoySpawnPos", []] call ARC_fnc_stateSet;
["activeConvoyStartMarker", ""] call ARC_fnc_stateSet;
["activeConvoyLinkupPos", []] call ARC_fnc_stateSet;
["activeConvoyLinkupReached", false] call ARC_fnc_stateSet;
["activeConvoyLinkupTaskId", ""] call ARC_fnc_stateSet;
["activeConvoyLinkupTaskDone", false] call ARC_fnc_stateSet;
["activeConvoyDestWpPos", []] call ARC_fnc_stateSet;
["activeConvoyStartDir", -1] call ARC_fnc_stateSet;
["activeConvoySpeedKph", -1] call ARC_fnc_stateSet;
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
["activeConvoySupplyKind", ""] call ARC_fnc_stateSet;

// Route recon (RECON route variant)
["activeReconRouteEnabled", false] call ARC_fnc_stateSet;
["activeReconRouteStartPos", []] call ARC_fnc_stateSet;
["activeReconRouteEndPos", []] call ARC_fnc_stateSet;
["activeReconRouteStartTaskId", ""] call ARC_fnc_stateSet;
["activeReconRouteEndTaskId", ""] call ARC_fnc_stateSet;
["activeReconRouteStartReached", false] call ARC_fnc_stateSet;
["activeReconRouteEndReached", false] call ARC_fnc_stateSet;
["activeReconRouteStartRadius", 60] call ARC_fnc_stateSet;
["activeReconRouteEndRadius", 60] call ARC_fnc_stateSet;

["intelCounter", 0] call ARC_fnc_stateSet;
["intelLog", []] call ARC_fnc_stateSet;

// Defensive: clear public presentation slices immediately.
// Some client UIs refresh before the next broadcast tick arrives.
missionNamespace setVariable ["ARC_pub_intelLog", [], true];
missionNamespace setVariable ["ARC_pub_opsLog", [], true];
missionNamespace setVariable ["ARC_pub_intelUpdatedAt", serverTime, true];

// Change monitoring snapshots
["metricsLastAt", -1] call ARC_fnc_stateSet;
["metricsSnapshots", []] call ARC_fnc_stateSet;

// TOC request queue + follow-on orders
["queueCounter", 0] call ARC_fnc_stateSet;
["tocQueue", []] call ARC_fnc_stateSet;
["tocBacklog", []] call ARC_fnc_stateSet;
["tocLeadApprovals", []] call ARC_fnc_stateSet;
["orderCounter", 0] call ARC_fnc_stateSet;
["tocOrders", []] call ARC_fnc_stateSet;

// Company command + virtual ops lifecycle
["companyCommandNodes", []] call ARC_fnc_stateSet;
["companyCommandTasking", []] call ARC_fnc_stateSet;
["companyCommandCounter", 0] call ARC_fnc_stateSet;
["companyCommandLastTickAt", -1] call ARC_fnc_stateSet;
["companyVirtualOps", []] call ARC_fnc_stateSet;
["companyVirtualOpsCounter", 0] call ARC_fnc_stateSet;
["companyVirtualOpsLastTickAt", -1] call ARC_fnc_stateSet;
["companyVirtualOpsLastRollupAt", -1] call ARC_fnc_stateSet;

// S1 registry persistence + public mirrors
["s1Registry", []] call ARC_fnc_stateSet;
["s1RegistryUpdatedAt", -1] call ARC_fnc_stateSet;
missionNamespace setVariable ["ARC_s1_registry", [["version", 1], ["updatedAt", serverTime], ["groups", []], ["units", []]]];
missionNamespace setVariable ["ARC_pub_s1_registry", [], true];
missionNamespace setVariable ["ARC_pub_s1_registryUpdatedAt", serverTime, true];

// Threat v0 + IED P1: reset threat store (persistence-safe)
["threat_v0_campaign_id", ""] call ARC_fnc_stateSet;
["threat_v0_seq", 0] call ARC_fnc_stateSet;
["threat_v0_records", []] call ARC_fnc_stateSet;
["threat_v0_open_index", []] call ARC_fnc_stateSet;
["threat_v0_closed_index", []] call ARC_fnc_stateSet;

// Re-init threat blob (regenerates campaign id and debug snapshot)
if (!isNil "ARC_fnc_threatInit") then { [] call ARC_fnc_threatInit; };

// Clear intel map markers
{
    if ((toLower _x) find "arc_intel_" isEqualTo 0) then
    {
        deleteMarker _x;
    };
} forEach allMapMarkers;

// Clear dynamic convoy debug marker
if ("ARC_convoy_start_active" in allMapMarkers) then
{
    deleteMarker "ARC_convoy_start_active";
};

if ("ARC_convoy_linkup_active" in allMapMarkers) then
{
    deleteMarker "ARC_convoy_linkup_active";
};

// Clear dotted convoy route markers
{ if ((_x find "ARC_convoy_route_active_") isEqualTo 0) then { deleteMarker _x; }; } forEach allMapMarkers;

// Clear broadcast vars
missionNamespace setVariable ["ARC_activeTaskId", "", true];
missionNamespace setVariable ["ARC_activeIncidentMarker", "", true];
missionNamespace setVariable ["ARC_activeIncidentType", "", true];
missionNamespace setVariable ["ARC_activeIncidentDisplayName", "", true];
missionNamespace setVariable ["ARC_activeIncidentPos", [], true];
missionNamespace setVariable ["ARC_activeIncidentAccepted", false, true];
missionNamespace setVariable ["ARC_activeIncidentAcceptedAt", -1, true];
missionNamespace setVariable ["ARC_activeIncidentAcceptedByGroup", "", true];

missionNamespace setVariable ["ARC_activeIncidentSitrepSent", false, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepSentAt", -1, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepFrom", "", true];
missionNamespace setVariable ["ARC_activeIncidentSitrepSummary", "", true];
missionNamespace setVariable ["ARC_activeIncidentSitrepDetails", "", true];
missionNamespace setVariable ["ARC_activeIncidentCloseReady", false, true];
missionNamespace setVariable ["ARC_activeIncidentSuggestedResult", "", true];
missionNamespace setVariable ["ARC_activeIncidentCloseReason", "", true];
missionNamespace setVariable ["ARC_activeIncidentCloseMarkedAt", -1, true];
missionNamespace setVariable ["ARC_activeLeadId", "", true];
missionNamespace setVariable ["ARC_activeThreadId", "", true];

// Convoy public anchors (used for client-side SITREP proximity checks)
missionNamespace setVariable ["ARC_activeConvoyNetIds", [], true];

// Reseed server-owned command/S1 models after reset so clients see deterministic defaults.
[] call ARC_fnc_companyCommandInit;
[] call ARC_fnc_s1RegistryInit;

// Persist + broadcast snapshots
[] call ARC_fnc_stateSave;
[] call ARC_fnc_publicBroadcastState;
[] call ARC_fnc_intelBroadcast;

// TOC layer (if present)
if (!isNil "ARC_fnc_intelQueueBroadcast") then { [] call ARC_fnc_intelQueueBroadcast; };
if (!isNil "ARC_fnc_intelOrderBroadcast") then { [] call ARC_fnc_intelOrderBroadcast; };

[] call ARC_fnc_leadBroadcast;
[] call ARC_fnc_threadBroadcast;

// Best-effort client cleanup
[_ids] remoteExec ["ARC_fnc_clientPurgeArcTasks", 0];

// Force client diary records to immediately reflect the reset (no waiting for update ticks)
[] remoteExec ["ARC_fnc_briefingHardResetClient", 0];

missionNamespace setVariable ["ARC_resetInProgress", false, true];

diag_log format ["[ARC][RESET] resetAll complete. deletedTasks=%1", count _ids];

true

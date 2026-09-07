/*
    ARC_fnc_vbiedDrivenSpawnTick

    VBIED Driven v1: spawn and manage a driven VBIED vehicle targeting a checkpoint or gate.
    Fires when activeObjectiveKind is VBIED_DRIVEN_CHECKPOINT or VBIED_DRIVEN_GATE.

    Fairness gate: aborts (sets threat EXPIRED) if no player within 500m of spawn point.
    Telegraphing: emits STAGED lead before spawning.

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

private _todPolicy = [] call ARC_fnc_dynamicTodGetPolicy;
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _canSpawnThreat = [_todPolicy, "canSpawnThreat", true] call _hg;
if (!(_canSpawnThreat isEqualType true) && !(_canSpawnThreat isEqualType false)) then { _canSpawnThreat = true; };
if (!_canSpawnThreat) exitWith {false};
private _todPhase = [_todPolicy, "phase", "DAY"] call _hg;
if (!(_todPhase isEqualType "")) then { _todPhase = "DAY"; };

private _objKind = toUpper (["activeObjectiveKind", ""] call ARC_fnc_stateGet);
if (!(_objKind isEqualTo "VBIED_DRIVEN_CHECKPOINT") && !(_objKind isEqualTo "VBIED_DRIVEN_GATE")) exitWith {false};

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
private _threatId = ["activeIedThreatId", ""] call ARC_fnc_stateGet;
private _kinds = ["VBIED_DRIVEN_CHECKPOINT", "VBIED_DRIVEN_GATE"];
if !([_taskId, _threatId, _kinds] call ARC_fnc_threatRuntimeIsCurrent) exitWith {false};

// ── Escalation-tier gate (VBIED driven requires tier ≥ 2 / HIGH_RISK) ─────
// Mirrors fn_threatGovernorCheck line 88: VBIED _tierMin = 2.
private _districtId = ["activeIncidentCivsubDistrictId", ""] call ARC_fnc_stateGet;
if (!(_districtId isEqualType "")) then { _districtId = ""; };
private _secLevel = missionNamespace getVariable [format ["ARC_district_%1_secLevel", _districtId], "NORMAL"];
if (!(_secLevel isEqualType "")) then { _secLevel = "NORMAL"; };
private _tier = ["NORMAL", "ELEVATED", "HIGH_RISK", "CRITICAL"] find (toUpper _secLevel);
if (_tier < 2) exitWith
{
    diag_log format ["[ARC][THREAT] ARC_fnc_vbiedDrivenSpawnTick: ESCALATION_TIER deny t=%1 actor=SYSTEM task=%2 threat=%3 district=%4 tier=%5 required=2", serverTime, _taskId, _threatId, _districtId, _tier];
    false
};

private _enabled = missionNamespace getVariable ["ARC_vbiedDrivenEnabled", true];
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {false};

// Already spawned this objective?
private _alreadySpawned = missionNamespace getVariable ["ARC_vbiedDrivenSpawned", false];
if (_alreadySpawned) exitWith {false};
if !((missionNamespace getVariable ["threat_v0_drivenPending", []]) isEqualTo []) exitWith {false};

// Get target position (checkpoint or gate marker)
private _targetMarker = ["activeObjectiveMarker", ""] call ARC_fnc_stateGet;
private _targetPos = [];
if (_targetMarker isEqualTo "" || !(_targetMarker in allMapMarkers)) then
{
    _targetPos = ["activeExecPos", []] call ARC_fnc_stateGet;
}
else
{
    _targetPos = getMarkerPos _targetMarker;
};
if (!(_targetPos isEqualType []) || {(count _targetPos) < 2}) exitWith
{
    diag_log "[ARC][WARN] ARC_fnc_vbiedDrivenSpawnTick: no valid target position";
    false
};
_targetPos resize 3;

// Pick spawn position >= 800m from target
private _spawnPos = [_targetPos, 800, 1500, 10, 0, 0.3, 0] call BIS_fnc_findSafePos;
if (!(_spawnPos isEqualType []) || {(count _spawnPos) < 2}) then
{
    private _dir = random 360;
    _spawnPos = [(_targetPos select 0) + 900 * sin _dir, (_targetPos select 1) + 900 * cos _dir, 0];
};
_spawnPos resize 3;

// Fairness gate: at least one player within 500m of spawn point
private _nearPlayers = allPlayers select { alive _x && { (_x distance2D _spawnPos) <= 500 } };
if ((count _nearPlayers) == 0) then
{
    diag_log format ["[ARC][INFO] ARC_fnc_vbiedDrivenSpawnTick: no players near spawn — aborting, setting EXPIRED"];
    private _abortThreatId = ["activeIedThreatId", ""] call ARC_fnc_stateGet;
    if (!(_abortThreatId isEqualTo "")) then
    {
        [_abortThreatId, "EXPIRED", "driven_vbied_no_players_at_spawn"] call ARC_fnc_threatUpdateState;
    };
};
if ((count _nearPlayers) == 0) exitWith {false};

// Telegraphing: emit STAGED lead before spawning (via lead router)
if (!(_threatId isEqualTo "")) then
{
    [_threatId, "STAGED", "driven_vbied_staged"] call ARC_fnc_threatUpdateState;
};

// Wait 60-120s for fairness telegraph window (non-blocking via spawn)
private _spawnDelay = 60 + (floor (random 60));
// Reserve synchronously, before yielding; repeated exec ticks cannot queue workers.
missionNamespace setVariable ["threat_v0_drivenPending", [_taskId, _threatId], false];
diag_log format ["[ARC][THREAT] SPAWN_PENDING t=%1 actor=SYSTEM task=%2 threat=%3 grid=%4 delay=%5", serverTime, _taskId, _threatId, mapGridPosition _spawnPos, _spawnDelay];

private _worker = [_spawnPos, _targetPos, _threatId, _taskId, _spawnDelay, _districtId, _hg] spawn
{
    params ["_sp", "_tp", "_tid", "_task", "_delay", "_district", "_hg"];
    sleep _delay;

    private _kinds = ["VBIED_DRIVEN_CHECKPOINT", "VBIED_DRIVEN_GATE"];
    private _cancel = {
        params ["_reason"];
        if ((missionNamespace getVariable ["threat_v0_drivenPending", []]) isEqualTo [_task, _tid]) then {
            missionNamespace setVariable ["threat_v0_drivenPending", [], false];
        };
        diag_log format ["[ARC][THREAT] SPAWN_CANCELLED t=%1 actor=SYSTEM task=%2 threat=%3 grid=%4 reason=%5", serverTime, _task, _tid, mapGridPosition _sp, _reason];
        if ([_task, _tid, _kinds] call ARC_fnc_threatRuntimeIsCurrent) then {
            [_tid, "EXPIRED", _reason] call ARC_fnc_threatUpdateState;
        };
    };
    if !((missionNamespace getVariable ["threat_v0_drivenPending", []]) isEqualTo [_task, _tid]) exitWith { ["RESERVATION_CHANGED"] call _cancel; };
    if !([_task, _tid, _kinds] call ARC_fnc_threatRuntimeIsCurrent) exitWith { ["TASK_CHANGED"] call _cancel; };
    if (missionNamespace getVariable ["ARC_vbiedDrivenSpawned", false]) exitWith { ["ALREADY_SPAWNED"] call _cancel; };
    if !(missionNamespace getVariable ["ARC_vbiedDrivenEnabled", true]) exitWith { ["DISABLED"] call _cancel; };
    private _todPolicy = [] call ARC_fnc_dynamicTodGetPolicy;
    if !([_todPolicy, "canSpawnThreat", true] call _hg) exitWith { ["TOD_DENIED"] call _cancel; };
    private _todPhase = [_todPolicy, "phase", "DAY"] call _hg;
    private _secLevel = missionNamespace getVariable [format ["ARC_district_%1_secLevel", _district], "NORMAL"];
    if !(_secLevel isEqualType "") then { _secLevel = "NORMAL"; };
    if ((["NORMAL", "ELEVATED", "HIGH_RISK", "CRITICAL"] find (toUpper _secLevel)) < 2) exitWith { ["TIER_CHANGED"] call _cancel; };
    if (({alive _x && {!(_x isKindOf "HeadlessClient_F")} && {(_x distance2D _sp) <= 500}} count allPlayers) isEqualTo 0) exitWith { ["NO_PLAYERS_AT_SPAWN"] call _cancel; };

    // Fairness check: intel level gate
    private _intelLevel = missionNamespace getVariable ["ARC_vbiedDrivenIntelLevel", 0];
    if (!(_intelLevel isEqualType 0)) then { _intelLevel = 0; };
    if (_intelLevel == 0) then
    {
        // Force minimum warning lead
        private _warnLead = [
            "IED",
            "VBIED Driven — Urgent Warning",
            _tp,
            0.8,
            600,
            "",
            "IED",
            "",
            "vbied_watch"
        ] call ARC_fnc_leadCreate;
        diag_log format ["[ARC][INFO] ARC_fnc_vbiedDrivenSpawnTick: force-emit warning lead=%1", _warnLead];
    };

    // Spawn VBIED vehicle — civilian-profile vehicle from the authoritative pool
    // (spec: VBIEDs are telegraphed civilian vehicles, not military placeholders).
    private _pool = missionNamespace getVariable ["ARC_vbiedVehicleClassPool", []];
    if (!(_pool isEqualType [])) then { _pool = []; };
    _pool = _pool select { _x isEqualType "" && { isClass (configFile >> "CfgVehicles" >> _x) } };
    private _vehClass = "C_Offroad_01_F";
    if ((count _pool) > 0) then { _vehClass = selectRandom _pool; };
    if !(isClass (configFile >> "CfgVehicles" >> _vehClass)) then { _vehClass = "C_Van_01_transport_F"; };

    private _veh = createVehicle [_vehClass, _sp, [], 0, "CAN_COLLIDE"];
    if (isNull _veh) exitWith { ["VEHICLE_SPAWN_FAILED"] call _cancel; };

    _veh setPos _sp;
    _veh setVariable ["ARC_isVbiedDrivenActive", true, true];
    _veh setVariable ["ARC_dynamic_tod_phase_spawn", _todPhase, true];
    _veh setVariable ["ARC_dynamic_tod_profile_spawn", [_todPolicy, "profile", "STANDARD"] call _hg, true];

    // Spawn driver
    private _grp = createGroup [east, true];
    _grp setGroupIdGlobal [format ["COBRA VBIED %1", _tid]];
    private _driver = _grp createUnit ["O_Soldier_F", _sp, [], 0, "NONE"];
    if (isNull _driver) exitWith { deleteVehicle _veh; deleteGroup _grp; ["DRIVER_SPAWN_FAILED"] call _cancel; };
    _driver moveInDriver _veh;
    _driver setVariable ["ARC_dynamic_tod_phase_spawn", _todPhase, true];
    _driver setVariable ["ARC_dynamic_tod_profile_spawn", [_todPolicy, "profile", "STANDARD"] call _hg, true];

    if !([_tid, _task, [_veh], [_driver]] call ARC_fnc_threatRegisterWorld) exitWith {
        deleteVehicle _driver; deleteVehicle _veh; deleteGroup _grp; ["WORLD_REGISTRATION_FAILED"] call _cancel;
    };

    // Assign route waypoints toward target
    private _wp1 = _grp addWaypoint [_tp, 0];
    _wp1 setWaypointType "MOVE";
    _wp1 setWaypointBehaviour "AWARE";
    _wp1 setWaypointSpeed "FULL";

    private _wp2 = _grp addWaypoint [_tp, 0];
    _wp2 setWaypointType "HOLD";

    // Store active driven vehicle for tracking
    missionNamespace setVariable ["ARC_vbiedDrivenNetId", netId _veh, true];
    missionNamespace setVariable ["ARC_vbiedDrivenSpawned", true, true];
    missionNamespace setVariable ["threat_v0_drivenPending", [], false];

    diag_log format ["[ARC][INFO] ARC_fnc_vbiedDrivenSpawnTick: spawned veh=%1 driver=%2 target=%3", netId _veh, name _driver, mapGridPosition _tp];

    // Proximity monitor
    while { !isNull _veh && alive _veh && alive _driver } do
    {
        sleep 3;
        if !([_task, _tid, _kinds] call ARC_fnc_threatRuntimeIsCurrent) exitWith {};
        private _dist = _veh distance2D _tp;
        if (_dist <= 50) then
        {
            // Trigger detonation
            private _vNid = netId _veh;
            diag_log format ["[ARC][INFO] ARC_fnc_vbiedDrivenSpawnTick: proximity trigger dist=%1 → detonating", _dist];
            [_vNid] call ARC_fnc_vbiedServerDetonate;
            break;
        };
    };

    // Driver killed = also detonate
    if (!isNull _veh && { alive _veh } && { !alive _driver } && {[_task, _tid, _kinds] call ARC_fnc_threatRuntimeIsCurrent}) then
    {
        private _vNid = netId _veh;
        [_vNid] call ARC_fnc_vbiedServerDetonate;
    };
};
missionNamespace setVariable ["threat_v0_drivenWorker", _worker, false];

true

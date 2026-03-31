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

private _objKind = toUpper (["activeObjectiveKind", ""] call ARC_fnc_stateGet);
if (!(_objKind isEqualTo "VBIED_DRIVEN_CHECKPOINT") && !(_objKind isEqualTo "VBIED_DRIVEN_GATE")) exitWith {false};

private _enabled = missionNamespace getVariable ["ARC_vbiedDrivenEnabled", true];
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {false};

// Already spawned this objective?
private _alreadySpawned = missionNamespace getVariable ["ARC_vbiedDrivenSpawned", false];
if (_alreadySpawned) exitWith {false};

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
    _spawnPos = [_targetPos select 0 + 900 * sin _dir, _targetPos select 1 + 900 * cos _dir, 0];
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
private _threatId = ["activeIedThreatId", ""] call ARC_fnc_stateGet;
if (!(_threatId isEqualType "")) then { _threatId = ""; };

if (!(_threatId isEqualTo "")) then
{
    [_threatId, "STAGED", "driven_vbied_staged"] call ARC_fnc_threatUpdateState;
};

// Wait 60-120s for fairness telegraph window (non-blocking via spawn)
private _spawnDelay = 60 + (floor (random 60));

[_spawnPos, _targetPos, _threatId, _spawnDelay] spawn
{
    params ["_sp", "_tp", "_tid", "_delay"];
    sleep _delay;

    // Validity gate: abort if threat was canceled or objective changed during delay
    private _activeTaskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
    private _activeObjKind = toUpper (["activeObjectiveKind", ""] call ARC_fnc_stateGet);
    if (!(_activeObjKind isEqualTo "VBIED_DRIVEN_CHECKPOINT") && !(_activeObjKind isEqualTo "VBIED_DRIVEN_GATE")) exitWith
    {
        diag_log format ["[ARC][INFO] ARC_fnc_vbiedDrivenSpawnTick: objective changed during delay, aborting spawn tid=%1", _tid];
    };

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

    // Spawn VBIED vehicle
    private _vehClass = "O_MRAP_02_F";
    if !(isClass (configFile >> "CfgVehicles" >> _vehClass)) then { _vehClass = "O_Truck_02_transport_F"; };

    private _veh = createVehicle [_vehClass, _sp, [], 0, "CAN_COLLIDE"];
    if (isNull _veh) exitWith { diag_log "[ARC][WARN] ARC_fnc_vbiedDrivenSpawnTick: vehicle spawn failed"; };

    _veh setPos _sp;
    _veh setVariable ["ARC_isVbiedDrivenActive", true, true];

    // Spawn driver
    private _grp = createGroup [east, true];
    private _driver = _grp createUnit ["O_Soldier_F", _sp, [], 0, "NONE"];
    _driver moveInDriver _veh;

    // Assign route waypoints toward target
    private _wp1 = _grp addWaypoint [_tp, 0];
    _wp1 setWaypointType "MOVE";
    _wp1 setWaypointBehaviour "AWARE";
    _wp1 setWaypointSpeed "FULL";

    private _wp2 = _grp addWaypoint [_tp, 0];
    _wp2 setWaypointType "HOLD";

    // Store active driven vehicle for tracking
    missionNamespace setVariable ["ARC_vbiedDrivenNetId", netId _veh, true];
    missionNamespace setVariable ["ARC_vbiedDrivenSpawned", true];

    diag_log format ["[ARC][INFO] ARC_fnc_vbiedDrivenSpawnTick: spawned veh=%1 driver=%2 target=%3", netId _veh, name _driver, mapGridPosition _tp];

    // Proximity monitor
    while { !isNull _veh && alive _veh && alive _driver } do
    {
        sleep 3;
        private _dist = _veh distance2D _tp;
        if (_dist <= 50) then
        {
            // Trigger detonation
            private _vNid = netId _veh;
            diag_log format ["[ARC][INFO] ARC_fnc_vbiedDrivenSpawnTick: proximity trigger dist=%1 → detonating", _dist];
            [_vNid] remoteExec ["ARC_fnc_vbiedServerDetonate", 2];
            break;
        };
    };

    // Driver killed = also detonate
    if (!isNull _veh && { alive _veh } && { !alive _driver }) then
    {
        private _vNid = netId _veh;
        [_vNid] remoteExec ["ARC_fnc_vbiedServerDetonate", 2];
    };
};

true

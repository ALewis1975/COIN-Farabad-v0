/*
    ARC_fnc_suicideBomberSpawnTick

    Suicide Bomber v1: spawn and manage a suicide bomber approaching a target zone.
    Fires when activeObjectiveKind is SB_MARKET_APPROACH, SB_CHECKPOINT_APPROACH,
    or SB_SHURA_APPROACH.

    Fairness gate: no player within 200m of approach path → abort, set EXPIRED.

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
private _validKinds = ["SB_MARKET_APPROACH","SB_CHECKPOINT_APPROACH","SB_SHURA_APPROACH"];
if (!(_objKind in _validKinds)) exitWith {false};
private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
private _threatId = ["activeIedThreatId", ""] call ARC_fnc_stateGet;
if !([_taskId, _threatId, _validKinds] call ARC_fnc_threatRuntimeIsCurrent) exitWith {false};

// ── Escalation-tier gate (Suicide Bomber requires tier ≥ 3) ────────────────
// Mirrors fn_threatGovernorCheck line 89: SUICIDE _tierMin = 3.
private _districtId = ["activeIncidentCivsubDistrictId", ""] call ARC_fnc_stateGet;
if (!(_districtId isEqualType "")) then { _districtId = ""; };
private _secLevel = missionNamespace getVariable [format ["ARC_district_%1_secLevel", _districtId], "NORMAL"];
if (!(_secLevel isEqualType "")) then { _secLevel = "NORMAL"; };
private _tier = ["NORMAL", "ELEVATED", "HIGH_RISK", "CRITICAL"] find (toUpper _secLevel);
if (_tier < 3) exitWith
{
    diag_log format ["[ARC][THREAT] ARC_fnc_suicideBomberSpawnTick: ESCALATION_TIER deny t=%1 actor=SYSTEM task=%2 threat=%3 district=%4 tier=%5 required=3", serverTime, _taskId, _threatId, _districtId, _tier];
    false
};

private _enabled = missionNamespace getVariable ["ARC_suicideBomberEnabled", true];
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {false};

// Already spawned?
private _alreadySpawned = missionNamespace getVariable ["ARC_suicideBomberSpawned", false];
if (_alreadySpawned) exitWith {false};

// Target zone position
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
    diag_log "[ARC][WARN] ARC_fnc_suicideBomberSpawnTick: no valid target position";
    false
};
_targetPos resize 3;

// Pick spawn position ~100-200m from target
private _dir = random 360;
private _dist = 100 + (random 100);
private _spawnPos = [(_targetPos select 0) + _dist * sin _dir, (_targetPos select 1) + _dist * cos _dir, 0];
_spawnPos resize 3;

// Fairness gate: player within 200m of approach path midpoint
private _midPos = [
    ((_spawnPos select 0) + (_targetPos select 0)) / 2,
    ((_spawnPos select 1) + (_targetPos select 1)) / 2,
    0
];
private _nearPlayers = allPlayers select { alive _x && { (_x distance2D _midPos) <= 200 } };
if ((count _nearPlayers) == 0) then
{
    diag_log "[ARC][INFO] ARC_fnc_suicideBomberSpawnTick: no players near approach path — aborting, EXPIRED";
    private _abortThreatId = ["activeIedThreatId", ""] call ARC_fnc_stateGet;
    if (!(_abortThreatId isEqualTo "")) then
    {
        [_abortThreatId, "EXPIRED", "sb_no_players_near_approach"] call ARC_fnc_threatUpdateState;
    };
};
if ((count _nearPlayers) == 0) exitWith {false};

// Mark spawned and emit STAGED lead

if (!(_threatId isEqualTo "")) then
{
    [_threatId, "STAGED", "sb_approach_staged"] call ARC_fnc_threatUpdateState;
};

// Spawn bomber unit
private _grp = createGroup [east, true];
_grp setGroupIdGlobal [format ["COBRA SB %1", _threatId]];
private _bomber = _grp createUnit ["O_Soldier_F", _spawnPos, [], 0, "NONE"];
if (isNull _bomber) exitWith {
    deleteGroup _grp;
    [_threatId, "EXPIRED", "SB_SPAWN_FAILED"] call ARC_fnc_threatUpdateState;
    false
};
_bomber setPos _spawnPos;
_bomber setVariable ["ARC_isSuicideBomber", true, true];
_bomber setVariable ["ARC_cleanupLabel", format ["SB:%1", _threatId], true];
_bomber setVariable ["ARC_dynamic_tod_phase_spawn", _todPhase, true];
_bomber setVariable ["ARC_dynamic_tod_profile_spawn", [_todPolicy, "profile", "STANDARD"] call _hg, true];
if !([_threatId, _taskId, [], [_bomber]] call ARC_fnc_threatRegisterWorld) exitWith {
    deleteVehicle _bomber; deleteGroup _grp;
    [_threatId, "EXPIRED", "SB_REGISTRATION_FAILED"] call ARC_fnc_threatUpdateState;
    false
};
missionNamespace setVariable ["ARC_suicideBomberSpawned", true, true];

// Civ appearance (unit stays east faction but low-profile)
_bomber setObjectTextureGlobal [0, "#(argb,8,8,3)color(0.35,0.25,0.15,1)"];

// Waypoint toward target
private _wp = _grp addWaypoint [_targetPos, 0];
_wp setWaypointType "MOVE";
_wp setWaypointBehaviour "SAFE";
_wp setWaypointSpeed "LIMITED";

missionNamespace setVariable ["ARC_suicideBomberNetId", netId _bomber, true];

diag_log format ["[ARC][INFO] ARC_fnc_suicideBomberSpawnTick: bomber=%1 target=%2 kind=%3", netId _bomber, mapGridPosition _targetPos, _objKind];

// Proximity monitor (server-side)
private _worker = [_bomber, _targetPos, _threatId, _taskId] spawn
{
    params ["_unit", "_tp", "_tid", "_task"];
    while { alive _unit } do
    {
        sleep 2;

        if !([_task, _tid, ["SB_MARKET_APPROACH", "SB_CHECKPOINT_APPROACH", "SB_SHURA_APPROACH"]] call ARC_fnc_threatRuntimeIsCurrent) exitWith {};

        if ((_unit distance2D _tp) <= 8) then
        {
            // Trigger detonation via server RPC
            [_tid, netId _unit] call ARC_fnc_suicideBomberOnDetonate;
            break;
        };
    };
};
missionNamespace setVariable ["threat_v0_suicideWorker", _worker, false];

true

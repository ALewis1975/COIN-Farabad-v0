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

private _objKind = toUpper (["activeObjectiveKind", ""] call ARC_fnc_stateGet);
private _validKinds = ["SB_MARKET_APPROACH","SB_CHECKPOINT_APPROACH","SB_SHURA_APPROACH"];
if (!(_objKind in _validKinds)) exitWith {false};

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
private _spawnPos = [_targetPos select 0 + _dist * sin _dir, _targetPos select 1 + _dist * cos _dir, 0];
_spawnPos resize 3;

// Fairness gate: player within 200m of approach path midpoint
private _midPos = [
    (_spawnPos select 0 + _targetPos select 0) / 2,
    (_spawnPos select 1 + _targetPos select 1) / 2,
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
missionNamespace setVariable ["ARC_suicideBomberSpawned", true];

private _threatId = ["activeIedThreatId", ""] call ARC_fnc_stateGet;
if (!(_threatId isEqualType "")) then { _threatId = ""; };

if (!(_threatId isEqualTo "")) then
{
    [_threatId, "STAGED", "sb_approach_staged"] call ARC_fnc_threatUpdateState;
};

// Spawn bomber unit
private _grp = createGroup [east, true];
private _bomber = _grp createUnit ["O_Soldier_F", _spawnPos, [], 0, "NONE"];
_bomber setPos _spawnPos;
_bomber setVariable ["ARC_isSuicideBomber", true, true];
_bomber setVariable ["ARC_cleanupLabel", format ["SB:%1", _threatId], true];

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
[_bomber, _targetPos, _threatId] spawn
{
    params ["_unit", "_tp", "_tid"];
    while { alive _unit } do
    {
        sleep 2;

        // Exit if threat is no longer active (EXPIRED, CLOSED, CLEANED)
        if (!(_tid isEqualTo "")) then
        {
            private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
            private _recState = "";
            if (_records isEqualType []) then
            {
                {
                    private _tid2 = "";
                    { if ((_x isEqualType []) && {(count _x) >= 2} && {(_x select 0) isEqualTo "threat_id"}) exitWith { _tid2 = _x select 1; }; } forEach _x;
                    if (_tid2 isEqualTo _tid) exitWith
                    {
                        { if ((_x isEqualType []) && {(count _x) >= 2} && {(_x select 0) isEqualTo "state"}) exitWith { _recState = _x select 1; }; } forEach _x;
                    };
                } forEach _records;
            };
            if (_recState isEqualType "" && { toUpper _recState in ["EXPIRED","CLOSED","CLEANED"] }) then { break; };
        };

        if ((_unit distance2D _tp) <= 8) then
        {
            // Trigger detonation via server RPC
            [_tid, netId _unit] remoteExec ["ARC_fnc_suicideBomberOnDetonate", 2];
            break;
        };
    };
};

true

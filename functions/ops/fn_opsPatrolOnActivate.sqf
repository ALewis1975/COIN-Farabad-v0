/*
    Server: PATROL incident activation helper.

    When a PATROL task becomes "activated" (first friendly unit arrives on-site), we:
      1) Generate a simple patrol route (map markers) to give players a concrete movement plan.
      2) Optionally spawn a small OPFOR patrol contact and assign it a roaming patrol.

    This is intentionally lightweight: the goal is to provide structure + a little friction,
    not to turn every patrol into a full raid.

    Params:
        0: STRING - taskId
        1: ARRAY  - center posATL
        2: NUMBER - exec radius (m)
        3: STRING - zone

    Returns:
        BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_taskId", ""],
    ["_posATL", []],
    ["_execRadius", 150],
    ["_zone", ""]
];

if (!(_taskId isEqualType "") || {_taskId isEqualTo ""}) exitWith {false};
if (!(_posATL isEqualType []) || {(count _posATL) < 2}) exitWith {false};
if (!(_execRadius isEqualType 0)) then { _execRadius = 150; };
if (!(_zone isEqualType "")) then { _zone = ""; };

private _already = ["activePatrolContactsSpawned", false] call ARC_fnc_stateGet;
if (!(_already isEqualType true)) then { _already = false; };
if (_already) exitWith {true};

// --- Route generation -------------------------------------------------------
private _routePtsN = missionNamespace getVariable ["ARC_patrolRoutePointCount", 4];
if (!(_routePtsN isEqualType 0)) then { _routePtsN = 4; };
_routePtsN = (_routePtsN max 3) min 8;

private _routeRadius = missionNamespace getVariable ["ARC_patrolRouteRadiusM", -1];
if (!(_routeRadius isEqualType 0)) then { _routeRadius = -1; };

// Keep patrol route points inside the task completion radius so on-scene time continues to accrue.
private _routeCap = (_execRadius max 75) * 0.95;

if (_routeRadius <= 0) then
{
    _routeRadius = _routeCap;
};

// Secure zones should not encourage wandering routes.
if (_zone in ["Airbase", "GreenZone"]) then
{
    _routeRadius = (_routeRadius min (_routeCap min 300));
};

// Final clamp: never exceed completion radius cap.
_routeRadius = (_routeRadius max 60) min 900;
_routeRadius = (_routeRadius min _routeCap);

private _pts = [];
private _baseAng = random 360;
private _step = 360 / _routePtsN;
for "_i" from 0 to (_routePtsN - 1) do
{
    private _ang = _baseAng + (_i * _step) + (random 30 - 15);
    private _dist = _routeRadius * (0.65 + random 0.35);

    private _px = (_posATL select 0) + (sin _ang) * _dist;
    private _py = (_posATL select 1) + (cos _ang) * _dist;

    private _p = [_px, _py, 0];
    _pts pushBack _p;
};

["activePatrolRoutePosList", _pts] call ARC_fnc_stateSet;

private _mkNames = [];
{
    private _idx = _forEachIndex + 1;
    private _mk = format ["ARC_patrol_%1_wp%2", _taskId, _idx];

    // Defensive cleanup if a marker with the same name exists.
    deleteMarker _mk;

    createMarker [_mk, _x];
    _mk setMarkerType "mil_dot";
    _mk setMarkerText format ["P%1", _idx];

    _mkNames pushBack _mk;
} forEach _pts;

["activePatrolRouteMarkerNames", _mkNames] call ARC_fnc_stateSet;

// Optional: log the route creation (OPS log only, no map marker clutter).
private _routeMsg = format ["PATROL route generated (%1 points, ~%2m radius).", _routePtsN, round _routeRadius];
["OPS", _routeMsg, _posATL, [["event","PATROL_ROUTE"],["taskId",_taskId],["zone",_zone]]] call ARC_fnc_intelLog;

// --- Optional OPFOR contact -------------------------------------------------
private _spawnContacts = missionNamespace getVariable ["ARC_patrolSpawnContactsEnabled", false];
if (!(_spawnContacts isEqualType true)) then { _spawnContacts = true; };

private _spawnedNetIds = [];

if (_spawnContacts && {!(_zone in ["Airbase", "GreenZone"])}) then
{
    private _press = ["insurgentPressure", 0.35] call ARC_fnc_stateGet;
    if (!(_press isEqualType 0)) then { _press = 0.35; };
    _press = (_press max 0) min 1;

    private _groupsN = missionNamespace getVariable ["ARC_patrolContactGroups", 1];
    if (!(_groupsN isEqualType 0)) then { _groupsN = 1; };
    _groupsN = (_groupsN max 0) min 3;
    if (_groupsN == 0) exitWith {};

    // Scale up slightly when insurgent pressure is high.
    if (_press > 0.65) then { _groupsN = (_groupsN max 2); };

    private _grpSize = missionNamespace getVariable ["ARC_patrolContactGroupSize", 4];
    if (!(_grpSize isEqualType 0)) then { _grpSize = 4; };
    _grpSize = (_grpSize max 2) min 12;

    private _unitClasses = missionNamespace getVariable ["ARC_opforPatrolUnitClasses", []];
    if (!(_unitClasses isEqualType []) || { (count _unitClasses) == 0 }) then
    {
        // Vanilla fallback (works without mod dependencies)
        _unitClasses = ["O_G_Soldier_F", "O_G_Soldier_GL_F", "O_G_Soldier_AR_F", "O_G_medic_F", "O_G_Soldier_TL_F"];
    };

    for "_g" from 1 to _groupsN do
    {
        // Pick a spawn point away from players.
        private _spawnPos = _posATL;
        private _tries = 0;
        while {_tries < 25} do
        {
            private _ang = random 360;
            private _dist = _routeRadius * (0.6 + random 0.35);
            _spawnPos = [
                (_posATL select 0) + (sin _ang) * _dist,
                (_posATL select 1) + (cos _ang) * _dist,
                0
            ];

            private _nearPlayers = allPlayers select { alive _x && { (_x distance2D _spawnPos) < 150 } };
            if ((count _nearPlayers) == 0) exitWith {};
            _tries = _tries + 1;
        };

        private _grp = createGroup east;

        for "_i" from 1 to _grpSize do
        {
            private _cls = selectRandom _unitClasses;
            private _u = _grp createUnit [_cls, _spawnPos, [], 0, "NONE"];
            _u setSkill (0.35 + random 0.30);

            _spawnedNetIds pushBack (netId _u);
        };

        // Register spawned contact units for deferred cleanup (keep around for investigation).
        if ((count _spawnedNetIds) > 0) then
        {
            [_spawnedNetIds, _posATL, -1, 30 * 60, format ["patrolContact:%1", _taskId]] call ARC_fnc_cleanupRegister;
        };

        // Patrol tasking: CBA preferred, simple waypoint loop fallback.
        if (!isNil "CBA_fnc_taskPatrol") then
        {
            // [group, position, radius, number of waypoints, type, behaviour, combat mode, speed mode, formation]
            [_grp, _posATL, _routeRadius, 6, "MOVE", "AWARE", "YELLOW", "LIMITED", "STAG COLUMN"] call CBA_fnc_taskPatrol;
        }
        else
        {
            for "_w" from 1 to 6 do
            {
                private _ang = random 360;
                private _dist = _routeRadius * random 1;
                private _wpPos = [
                    (_posATL select 0) + (sin _ang) * _dist,
                    (_posATL select 1) + (cos _ang) * _dist,
                    0
                ];
                private _wp = _grp addWaypoint [_wpPos, 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointBehaviour "AWARE";
                _wp setWaypointCombatMode "YELLOW";
                _wp setWaypointSpeed "LIMITED";
            };

            private _wpC = _grp addWaypoint [_posATL, 0];
            _wpC setWaypointType "CYCLE";
        };
    };
};

["activePatrolContactsNetIds", _spawnedNetIds] call ARC_fnc_stateSet;
["activePatrolContactsSpawned", true] call ARC_fnc_stateSet;

true

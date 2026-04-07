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
private _usedPreScanned = false;

// Try pre-scanned patrol rings first (populated at startup by ARC_fnc_worldScanPatrolWaypoints).
private _patrolRings = missionNamespace getVariable ["ARC_worldPatrolRings", createHashMap];
if (!(_patrolRings isEqualType createHashMap)) then { _patrolRings = createHashMap; };

if (!(_patrolRings isEqualTo createHashMap)) then {
    private _locations = missionNamespace getVariable ["ARC_worldNamedLocations", []];
    if (!(_locations isEqualType [])) then { _locations = []; };

    private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

    // Find nearest named location within 600 m of the task centre
    private _nearId  = "";
    private _nearPos = [];
    private _nearD   = 1e12;
    {
        _x params [["_lid", "", [""]], ["_ldisplay", "", [""]], ["_lpos", [], [[]]]];
        if ((count _lpos) >= 2) then {
            private _d = _posATL distance2D _lpos;
            if (_d < _nearD && {_d < 600}) then {
                _nearD   = _d;
                _nearId  = _lid;
                _nearPos = _lpos;
            };
        };
    } forEach _locations;

    if (!(_nearId isEqualTo "")) then {
        private _locationRings = [_patrolRings, _nearId, []] call _hg;
        if (_locationRings isEqualType [] && {(count _locationRings) >= 3}) then {
            // Ring radii mirror ARC_fnc_worldScanPatrolWaypoints: 0=tight(80m), 1=medium(180m), 2=wide(350m)
            private _ringRadii = [80, 180, 350];
            private _bestIdx   = 0;
            private _bestDiff  = abs (_routeRadius - (_ringRadii select 0));
            for "_ri" from 1 to ((count _ringRadii) - 1) do {
                private _diff = abs (_routeRadius - (_ringRadii select _ri));
                if (_diff < _bestDiff) then { _bestDiff = _diff; _bestIdx = _ri; };
            };

            private _ring = _locationRings select _bestIdx;
            if (_ring isEqualType [] && {(count _ring) > 0}) then {
                // Re-centre ring on task position: shift each waypoint by the
                // offset from the named location to the task centre, then add jitter.
                private _lp3 = +_nearPos;
                if ((count _lp3) < 3) then { _lp3 pushBack 0; };

                private _offX = (_posATL select 0) - (_lp3 select 0);
                private _offY = (_posATL select 1) - (_lp3 select 1);

                {
                    if (!(_x isEqualType []) || {(count _x) < 2}) then { continue; };
                    private _nx = (_x select 0) + _offX + (random 40 - 20);
                    private _ny = (_x select 1) + _offY + (random 40 - 20);
                    _pts pushBack [_nx, _ny, 0];
                } forEach _ring;

                _usedPreScanned = true;
            };
        };
    };
};

// Geometric fallback: generate waypoints from scratch when no pre-scanned ring is nearby.
if (!_usedPreScanned) then {
    private _baseAng = random 360;
    private _step    = 360 / _routePtsN;
    for "_i" from 0 to (_routePtsN - 1) do
    {
        private _ang  = _baseAng + (_i * _step) + (random 30 - 15);
        private _dist = _routeRadius * (0.65 + random 0.35);

        private _px = (_posATL select 0) + (sin _ang) * _dist;
        private _py = (_posATL select 1) + (cos _ang) * _dist;

        _pts pushBack [_px, _py, 0];
    };
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
        _grp setGroupIdGlobal [format ["VIPER Patrol %1-%2", _taskId, _g]];

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

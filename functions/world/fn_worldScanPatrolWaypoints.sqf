/*
    ARC_fnc_worldScanPatrolWaypoints

    Server-only startup scan. Pre-computes three patrol waypoint ring variants
    (tight / medium / wide) for every named location. ARC_fnc_opsPatrolOnActivate
    selects the most appropriate ring rather than generating geometry from scratch
    on each task activation.

    Ring variants:
        0 – tight  (radius  ~80 m)
        1 – medium (radius ~180 m)
        2 – wide   (radius ~350 m)

    Each ring has 5 waypoints distributed at equal angular steps with ±15° jitter.
    Rings are stored relative to the named location's own position; callers must
    re-centre onto the task position at use time.

    Must be called AFTER ARC_fnc_worldInit (which populates ARC_worldNamedLocations).
    Called automatically from ARC_fnc_worldInit.

    State written (server missionNamespace, NOT replicated, NOT persisted):
        ARC_worldPatrolRings (HashMap)
            key   : locationId (STRING)
            value : [[tightWaypoints([]), mediumWaypoints([]), wideWaypoints([])]

    Returns: NUMBER - count of locations with rings generated
*/

if (!isServer) exitWith {0};

private _locations = missionNamespace getVariable ["ARC_worldNamedLocations", []];
if (!(_locations isEqualType [])) then { _locations = []; };

if ((count _locations) == 0) exitWith {
    diag_log "[ARC][WORLD][WARN] ARC_fnc_worldScanPatrolWaypoints: ARC_worldNamedLocations is empty — skipping.";
    0
};

private _ringRadii = [80, 180, 350]; // tight, medium, wide (index 0/1/2)
private _ringPtsN  = 5;

private _rings = createHashMap;

{
    _x params [["_id", "", [""]], ["_displayName", "", [""]], ["_pos", [], [[]]]];

    if (!(_pos isEqualType []) || {(count _pos) < 2}) then { continue; };

    private _p3 = +_pos;
    if ((count _p3) == 2) then { _p3 pushBack 0; };

    private _locationRings = [];

    {
        private _radius  = _x;
        private _pts     = [];
        private _baseAng = random 360;
        private _step    = 360 / _ringPtsN;

        for "_i" from 0 to (_ringPtsN - 1) do {
            private _ang  = _baseAng + (_i * _step) + (random 30 - 15);
            private _dist = _radius * (0.75 + random 0.25);
            private _px   = (_p3 select 0) + (sin _ang) * _dist;
            private _py   = (_p3 select 1) + (cos _ang) * _dist;
            _pts pushBack [_px, _py, 0];
        };

        _locationRings pushBack _pts;
    } forEach _ringRadii;

    _rings set [_id, _locationRings];

} forEach _locations;

missionNamespace setVariable ["ARC_worldPatrolRings", _rings]; // server-local only; no broadcast

diag_log format ["[ARC][WORLD][INFO] ARC_fnc_worldScanPatrolWaypoints: generated patrol rings for %1 location(s).", count _rings];

count _rings

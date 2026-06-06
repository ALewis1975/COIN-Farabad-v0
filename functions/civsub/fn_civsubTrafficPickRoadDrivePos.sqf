/*
    ARC_fnc_civsubTrafficPickRoadDrivePos

    Pick an on-road spawn position for a MOVING ambient civilian vehicle.

    The returned position is the centre of a road segment (lane line) that:
      - Has at least one connected neighbour segment (so the vehicle has
        somewhere to drive to immediately).
      - Whose chosen neighbour itself has further connections (so we do not
        spawn at the very last segment / dead-end of the road network — i.e.
        we avoid the longitudinal "edges" of a road).
      - Is not on water, not on a steep slope, not inside a registered
        traffic-exclusion zone, and not within `_minSep` of another land
        vehicle.

    The returned direction is the bearing from the chosen road segment toward
    its picked connected neighbour — the direction the vehicle will drive in.

    Params:
      0: centerPosATL [x,y,z]
      1: searchRadius (meters)
      2: minSeparation (meters) - avoid existing vehicles nearby

    Returns:
      [posATL, dirDeg, nextRoadPosATL] on success, or [] on failure.
*/

params [
    ["_center", [0,0,0], [[]]],
    ["_searchR", 600, [0]],
    ["_minSep", 30, [0]]
];

if (!(_center isEqualType []) || { (count _center) < 2 }) exitWith {[]};

private _tries = 28;

private _foundPos = [];
private _foundDir = 0;
private _foundNext = [];

for "_i" from 1 to _tries do
{
    private _probe = _center getPos [random _searchR, random 360];
    private _roads = _probe nearRoads 220;
    if ((count _roads) == 0) then { continue; };

    private _r = selectRandom _roads;
    if (isNull _r) then { continue; };

    // Edge-avoidance: candidate road must have at least one connected neighbour,
    // and that neighbour must itself be connected onward — keeps spawns off the
    // very last segment of a road network (dead-end / map edge).
    private _conn = roadsConnectedTo _r;
    if ((count _conn) == 0) then { continue; };

    private _rPos = getPosATL _r;
    _rPos set [2, 0];

    if (surfaceIsWater _rPos) then { continue; };

    private _r2 = objNull;
    private _hwyDir = -1;
    private _bestScore = 1e12; // larger than any bearing + marker-distance score.
    private _hwyRadius = missionNamespace getVariable ["civsub_v1_traffic_highwayMarkerRadius_m", 85];
    if (!(_hwyRadius isEqualType 0)) then { _hwyRadius = 85; };
    _hwyRadius = (_hwyRadius max 20) min 500;
    {
        if (isNull _x) then { continue; };
        private _onward = roadsConnectedTo _x;
        if ((count _onward) > 0) then
        {
            private _candDir = _r getDir _x;
            private _candHwyDir = -1;
            private _candMarkerDist = _hwyRadius;
            private _hwyMarker = [_rPos, _hwyRadius, _candDir] call ARC_fnc_worldHighwayMarkerNearest;
            if (_hwyMarker isEqualType [] && { (count _hwyMarker) >= 4 }) then
            {
                _candHwyDir = _hwyMarker select 2;
                if (!(_candHwyDir isEqualType 0)) then { _candHwyDir = -1; };
                _candMarkerDist = _hwyMarker select 3;
                if (!(_candMarkerDist isEqualType 0)) then { _candMarkerDist = _hwyRadius; };
            };

            private _score = 500;
            if (_candHwyDir >= 0) then
            {
                private _delta = [_candDir, _candHwyDir] call ARC_fnc_worldBearingDelta;
                _score = _delta + (_candMarkerDist * 0.05);
            };

            if (_score < _bestScore) then
            {
                _bestScore = _score;
                _r2 = _x;
                _hwyDir = _candHwyDir;
            };
        };
    } forEach _conn;
    if (isNull _r2) then { continue; };

    private _r2Pos = getPosATL _r2;
    _r2Pos set [2, 0];

    // Highway side marker direction takes precedence when present; otherwise
    // use the road-to-road bearing toward the selected connected segment.
    private _dir = if (_hwyDir >= 0) then { _hwyDir } else { _r getDir _r2 };

    // Slope guard — avoid extreme grades that would tip the vehicle.
    private _n = surfaceNormal _rPos;
    private _slope = acos ((_n vectorDotProduct [0,0,1]) max -1 min 1);
    if (_slope > 0.35) then { continue; };

    // Vehicle separation — avoid clustering on top of another vehicle.
    private _near = nearestObjects [_rPos, ["LandVehicle"], _minSep];
    if ((count _near) > 0) then { continue; };

    // Object-collision clearance — moving vehicles must spawn into clear road
    // space. The road's lane centre commonly has nothing on it, but wrecks,
    // dropped weapons, fence/barrier props, dead bodies, animals, and
    // editor-placed map clutter (signs, bollards) can intersect a road-segment
    // node and would cause the spawned vehicle to explode or tilt into terrain.
    // We reject any candidate where a non-road object lies within `_clearR` of
    // the spawn point. Vehicle separation above already covers LandVehicle at
    // a wider radius, so the inner LandVehicle check here is redundant but
    // harmless.
    private _clearR = missionNamespace getVariable ["civsub_v1_traffic_moving_spawnClearance_m", 7];
    if (!(_clearR isEqualType 0)) then { _clearR = 7; };
    _clearR = (_clearR max 4) min 25;
    private _blocked = false;
    {
        if (_blocked) then { continue; };
        if (isNull _x) then { continue; };
        if (_x isEqualTo _r) then { continue; };
        // `Road` covers all road-segment objects on terrain; they are not blockers.
        if (_x isKindOf "Road") then { continue; };
        // Ignore objects with empty type (fake/terrain-internal objects).
        if ((typeOf _x) isEqualTo "") then { continue; };
        _blocked = true;
    } forEach (_rPos nearObjects _clearR);
    if (_blocked) then { continue; };

    // Exclusion zone check (mirrors fn_civsubTrafficPickRoadsidePos)
    private _exclZones = missionNamespace getVariable ["ARC_trafficExclusionZones", []];
    if ((_exclZones isEqualType []) && { (count _exclZones) > 0 }) then
    {
        private _excluded = false;
        {
            if (_excluded) then { continue; };
            if (_x isEqualType [] && { (count _x) >= 2 }) then
            {
                private _zp = _x select 0;
                private _zr = _x select 1;
                if ((_zp isEqualType []) && { (count _zp) >= 2 } && { (_zr isEqualType 0) }) then
                {
                    if ((_rPos distance2D _zp) <= _zr) then { _excluded = true; };
                };
            };
        } forEach _exclZones;
        if (_excluded) then { continue; };
    };

    _foundPos = _rPos;
    _foundDir = _dir;
    _foundNext = _r2Pos;
    break;
};

if ((count _foundPos) == 0) exitWith { [] };
[_foundPos, _foundDir, _foundNext]

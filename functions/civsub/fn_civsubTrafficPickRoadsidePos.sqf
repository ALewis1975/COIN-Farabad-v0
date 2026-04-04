/*
    ARC_fnc_civsubTrafficPickRoadsidePos

    Pick a plausible roadside shoulder position near a center point.

    Params:
      0: centerPosATL [x,y,z]
      1: searchRadius (meters)
      2: minSeparation (meters) - avoid existing vehicles nearby

    Returns:
      [posATL, dirDeg] on success, or [] on failure
*/

params [
    ["_center", [0,0,0], [[]]],
    ["_searchR", 600, [0]],
    ["_minSep", 30, [0]]
];

if (!(_center isEqualType []) || { (count _center) < 2 }) exitWith {[]};

// Phase 2 helper (defined in civsubInitServer)
private _posIsRoadish = missionNamespace getVariable ["ARC_civsub_fnc_posIsRoadish", { params ["_p"]; isOnRoad _p }];

private _offsetM = missionNamespace getVariable ["civsub_v1_traffic_roadside_offset_m", 8];
if (!(_offsetM isEqualType 0)) then { _offsetM = 8; };
// Base offset from road center. We'll adaptively step farther out if the terrain marks
// a wide corridor as "on road".
_offsetM = (_offsetM max 4) min 14;

private _stepM = missionNamespace getVariable ["civsub_v1_traffic_roadside_step_m", 3];
if (!(_stepM isEqualType 0)) then { _stepM = 3; };
_stepM = (_stepM max 2) min 6;

private _maxExtra = missionNamespace getVariable ["civsub_v1_traffic_roadside_maxExtra_m", 18];
if (!(_maxExtra isEqualType 0)) then { _maxExtra = 18; };
_maxExtra = (_maxExtra max 6) min 26;

private _tries = 28;

// Pre-declared result vars; populated inside the loop and returned after it.
private _foundPos = [];
private _foundDir = 0;

for "_i" from 1 to _tries do
{
    private _probe = _center getPos [random _searchR, random 360];
    private _roads = _probe nearRoads 220;
    if ((count _roads) == 0) then { continue; };

    private _r = selectRandom _roads;
    if (isNull _r) then { continue; };

    private _rPos = getPosATL _r;

    // Determine road direction from connected roads if possible
    private _dir = random 360;
    private _conn = roadsConnectedTo _r;
    if ((count _conn) > 0) then
    {
        // pick a random connected segment for a more stable heading on dense road meshes
        private _r2 = selectRandom _conn;
        if (!isNull _r2) then { _dir = _r getDir _r2; };
    };

    private _perp = _dir + (selectRandom [90, -90]);

    // Try adaptive offsets to find a shoulder position.
    private _pos = [];
    private _usedOff = _offsetM;
    for "_j" from 0 to (ceil (_maxExtra / _stepM)) do
    {
        private _off = _offsetM + (_j * _stepM);
        private _p = _rPos getPos [_off, _perp];
        _p set [2, 0];

        if (surfaceIsWater _p) then { continue; };

        // Phase 2 hard rule: never return a road placement.
        if ([_p] call _posIsRoadish) then { _usedOff = _off; continue; };

        _pos = _p;
        _usedOff = _off;
        break;
    };

    if ((count _pos) == 0) then { continue; };

    // Avoid truly lane-center placements (even if terrain reports wide on-road area)
    if ((_pos distance2D _rPos) < (_usedOff * 0.65)) then { continue; };

    // _pos is guaranteed to be off-road by _posIsRoadish.

    // Avoid steep slopes
    private _n = surfaceNormal _pos;
    private _slope = acos ((_n vectorDotProduct [0,0,1]) max -1 min 1);
    if (_slope > 0.35) then { continue; }; // ~20 degrees

    // Separation check (vehicles)
    private _near = nearestObjects [_pos, ["LandVehicle"], _minSep];
    if ((count _near) > 0) then { continue; };

    // Exclusion zone check: skip positions inside registered no-traffic areas.
    // ARC_trafficExclusionZones is set by fn_civsubTrafficInit.
    // Format: array of [[x,y,z], radiusM] entries.
    private _exclZones = missionNamespace getVariable ["ARC_trafficExclusionZones", []];
    if ((_exclZones isEqualType []) && { (count _exclZones) > 0 }) then
    {
        private _excluded = false;
        {
            if (_excluded) then { continue; };  // already matched; skip remaining zones
            if (_x isEqualType [] && { (count _x) >= 2 }) then
            {
                private _zp = _x select 0;
                private _zr = _x select 1;
                if ((_zp isEqualType []) && { (count _zp) >= 2 } && { (_zr isEqualType 0) }) then
                {
                    if ((_pos distance2D _zp) <= _zr) then { _excluded = true; };
                };
            };
        } forEach _exclZones;
        if (_excluded) then { continue; };
    };

    // Return the base road direction (caller may flip 180 for variety)
    _foundPos = _pos;
    _foundDir = _dir;
    break;
};

if ((count _foundPos) == 0) exitWith { [] };
[_foundPos, _foundDir]

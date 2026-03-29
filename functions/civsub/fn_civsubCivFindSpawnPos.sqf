/* ARC_fnc_civsubCivFindSpawnPos

   Patch B:
     - Prefer building positions (interiors/doorsteps) over open terrain
     - Enforce exclusion zones (default: airbase marker)

   Params:
     0: center (array [x,y] or [x,y,z])
     1: radius (number)
     2: districtId (string, optional)

   Returns: position array [x,y,z]
*/

params [
    ["_center", [0,0,0], [[]]],
    ["_r", 200, [0]],
    ["_districtId", "", [""]]
];

// Phase 2 helpers (defined in civsubInitServer)
private _posIsRoadish = missionNamespace getVariable ["ARC_civsub_fnc_posIsRoadish", { params ["_p"]; isOnRoad _p }];
private _findOffRoad = missionNamespace getVariable ["ARC_civsub_fnc_findPosOffRoad", { params ["_p"]; _p }];

private _c = _center;
if ((count _c) == 2) then { _c = [_c select 0, _c select 1, 0]; };

private _zones = missionNamespace getVariable ["civsub_v1_civ_exclusion_zones", []];
if !(_zones isEqualType []) then { _zones = []; };

// Default exclusion: airbase flightline
if ((count _zones) == 0) then {
    if ("mkr_airbaseCenter" in allMapMarkers) then {
        _zones = [["mkr_airbaseCenter", 1600]]; // marker text says 1500m; add buffer
    };
    missionNamespace setVariable ["civsub_v1_civ_exclusion_zones", _zones, true];
};

private _inExclusion = {
    params ["_p"];
    {
        private _z = _x;
        if !(_z isEqualType []) then { continue };
        if ((count _z) < 2) then { continue };

        private _zc = _z select 0;
        private _zr = _z select 1;
        if !(_zr isEqualType 0) then { continue };

        private _zp = [0,0,0];
        if (_zc isEqualType "") then {
            if (_zc in allMapMarkers) then { _zp = markerPos _zc; };
        } else {
            if (_zc isEqualType []) then {
                _zp = _zc;
            };
        };

        if ((_p distance2D _zp) <= _zr) exitWith { true };
    } forEach _zones;
    false
};

private _pickFromBuilding = {
    params ["_origin"];
    private _blds = nearestObjects [_origin, ["House","Building"], 300];
    if ((count _blds) == 0) exitWith { [] };

    // Shuffle by random sampling to avoid scanning everything
    private _tries = 20;
    for "_i" from 1 to _tries do {
        private _b = selectRandom _blds;
        private _poses = [_b] call BIS_fnc_buildingPositions;
        if ((count _poses) == 0) then { continue };
        private _p = selectRandom _poses;
        if (surfaceIsWater _p) then { continue };
        if ([_p] call _posIsRoadish) then { continue };
        if ([_p] call _inExclusion) then { continue };
        _p
    };
    []
};

// Try multiple origins inside radius, prefer building positions
for "_k" from 1 to 25 do {
    private _angle = random 360;
    private _dist = random _r;
    private _origin = [_c select 0 + (sin _angle) * _dist, _c select 1 + (cos _angle) * _dist, 0];

    if ([_origin] call _inExclusion) then { continue };

    private _bp = [_origin] call _pickFromBuilding;
    if ((count _bp) > 0) exitWith { _bp };
};

// Fallback to safe pos (still enforce exclusions)
for "_k" from 1 to 10 do {
    private _pos = [_c, 0, _r, 3, 0, 0.3, 0] call BIS_fnc_findSafePos;
    if ((_pos select 0) == 0 && {(_pos select 1) == 0}) then { continue };
    if (surfaceIsWater _pos) then { continue };
    if ([_pos] call _posIsRoadish) then
    {
        private _fixed = [_pos, 2, 22, 14] call _findOffRoad;
        if (_fixed isEqualTo [0,0,0]) then { continue };
        _pos = _fixed;
    };
    if ([_pos] call _inExclusion) then { continue };
    _pos
};

// Final fallback: return center, but if excluded, push outside nearest exclusion ring
if !([_c] call _inExclusion) exitWith { _c };

private _best = _c;
private _bestDist = 1e12;
{
    private _z = _x;
    if !(_z isEqualType [] && {(count _z) >= 2}) then { continue };
    private _zc = _z select 0;
    private _zr = _z select 1;
    private _zp = if (_zc isEqualType "") then { markerPos _zc } else { _zc };
    private _d = _c distance2D _zp;
    if (_d < _bestDist) then {
        _bestDist = _d;
        // Randomize the escape direction so multiple spawns don't stack on a single point.
        private _dir = random 360;
        private _pad = 50 + random 250;
        _best = [_zp select 0 + (sin _dir) * (_zr + _pad), _zp select 1 + (cos _dir) * (_zr + _pad), 0];
    };
} forEach _zones;

_best

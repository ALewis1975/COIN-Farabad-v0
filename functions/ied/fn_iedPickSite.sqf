/*
    ARC_fnc_iedPickSite

    Server helper: pick a plausible IED device site near a base position.

    Phase 1 scope:
      - Prefer roadside placements (nearRoads)
      - Avoid Airbase zone unless explicitly allowed
      - Avoid water and steep slopes
      - Return ATL position (z=0)

    Params:
      0: ARRAY  - basePosATL
      1: NUMBER - search radius (optional; default ARC_iedSiteSearchRadiusM)

    Returns:
      ARRAY - posATL (empty array on failure; caller should fall back to basePos)
*/

if (!isServer) exitWith {[]};

params [
    ["_basePos", [], [[]]],
    ["_searchRad", -1, [0]]
];

if (!(_basePos isEqualType []) || { (count _basePos) < 2 }) exitWith {[]};
_basePos = +_basePos; _basePos resize 3;
if (!((_basePos # 0) isEqualType 0) || { !((_basePos # 1) isEqualType 0) }) exitWith {[]};
_basePos set [2, 0];

if (!(_searchRad isEqualType 0) || { _searchRad <= 0 }) then
{
    _searchRad = missionNamespace getVariable ["ARC_iedSiteSearchRadiusM", 350];
    if (!(_searchRad isEqualType 0) || { _searchRad <= 0 }) then { _searchRad = 350; };
};
_searchRad = (_searchRad max 150) min 900;

private _avoidAirbase = missionNamespace getVariable ["ARC_iedSiteAvoidAirbase", true];
if (!(_avoidAirbase isEqualType true) && !(_avoidAirbase isEqualType false)) then { _avoidAirbase = true; };

private _maxSlopeN = missionNamespace getVariable ["ARC_iedSiteMinNormalZ", 0.92];
if (!(_maxSlopeN isEqualType 0)) then { _maxSlopeN = 0.92; };
_maxSlopeN = (_maxSlopeN max 0.80) min 0.99;

private _roads = _basePos nearRoads _searchRad;
private _tries = missionNamespace getVariable ["ARC_iedSitePickTries", 48];
if (!(_tries isEqualType 0) || { _tries <= 0 }) then { _tries = 48; };
_tries = (_tries max 12) min 140;

private _best = [];
private _bestScore = -1e12;

private _scoreCand = {
    params ["_cand", "_roadObj", "_basePos"];

    // Favor closer to base but not exactly on top of the base point.
    private _d = _basePos distance2D _cand;
    private _s = 1000 - _d;

    // Favor positions that are near a road object (road shoulder).
    if (!isNull _roadObj) then
    {
        private _dr = _cand distance2D _roadObj;
        _s = _s + (200 - (_dr min 200));
    };

    _s
};

private _pickFromRoad = {
    params ["_roadObj", "_basePos"];

    private _rp = getPosATL _roadObj;
    _rp resize 3;
    _rp set [2, 0];

    // Approximate road direction.
    private _dir = getDir _roadObj;
    if (!(_dir isEqualType 0)) then { _dir = random 360; };

    // Choose a very small offset and slight forward/back jitter.
    // Requirement: device must be on/very near the road (outside buildings).
    private _side = if (random 1 < 0.5) then { -1 } else { 1 };
    private _off = 0.5 + random 1.2; // 0.5..1.7m from road centerline
    private _fwd = -2 + random 4;    // +/- 2m

    private _p = _rp getPos [_fwd, _dir];
    _p = _p getPos [_side * _off, _dir + 90];
    _p resize 3;
    _p set [2, 0];
    _p
};

for "_i" from 1 to _tries do
{
    private _cand = [];
    private _road = objNull;

    if ((count _roads) > 0) then
    {
        _road = selectRandom _roads;
        _cand = [_road, _basePos] call _pickFromRoad;
    }
    else
    {
        // Roadless fallback: random around base.
        private _dist = random _searchRad;
        private _dir = random 360;
        _cand = _basePos getPos [_dist, _dir];
        _cand resize 3;
        _cand set [2, 0];
    };

    // Reject water.
    if (surfaceIsWater _cand) then { continue; };

    // Reject steep slopes.
    private _n = surfaceNormal _cand;
    if (!(_n isEqualType []) || { (count _n) < 3 }) then { continue; };
    if ((_n # 2) < _maxSlopeN) then { continue; };

    // Reject Airbase zone unless allowed.
    if (_avoidAirbase) then
    {
        private _z = [_cand] call ARC_fnc_worldGetZoneForPos;
        if (_z isEqualType "" && { (toUpper _z) isEqualTo "AIRBASE" }) then { continue; };
    };

    // Reject positions that are inside non-enterable pseudo-buildings (same philosophy as worldPickEnterablePosNear).
    // Hard reject if we're too close to any building object.
    // This prevents indoor/roof placement when the base point is in a structure.
    private _b = nearestBuilding _cand;
    if (!isNull _b && { (_cand distance2D _b) < 8 }) then { continue; };

    // Basic spacing: avoid stacking multiple IED devices too close together.
    private _minSep = missionNamespace getVariable ["ARC_iedSiteMinSeparationM", 120];
    if (!(_minSep isEqualType 0) || { _minSep < 0 }) then { _minSep = 120; };
    _minSep = (_minSep max 0) min 600;

    private _active = missionNamespace getVariable ["ARC_iedPhase1_deviceRecords", []];
    if (!(_active isEqualType [])) then { _active = []; };

    private _tooClose = false;
    if (_minSep > 0 && { (count _active) > 0 }) then
    {
        {
            if (_x isEqualType [] && { (count _x) >= 6 }) then
            {
                private _p = _x # 4;
                if (_p isEqualType [] && { (count _p) >= 2 } && { (_cand distance2D _p) < _minSep }) exitWith { _tooClose = true; };
            };
        } forEach _active;
    };
    if (_tooClose) then { continue; };

    private _sc = [_cand, _road, _basePos] call _scoreCand;
    if (_sc > _bestScore) then
    {
        _bestScore = _sc;
        _best = +_cand;
    };
};

_best

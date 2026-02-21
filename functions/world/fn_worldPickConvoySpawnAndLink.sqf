/*
    Picks convoy spawn and link-up positions on roads.

    Use cases:
      1) Edge-spawn escort convoys: pick a spawn road near the map edge and a link-up point several hundred meters inward.
      2) Marker-defined spawns: snap the preferred position to the nearest road and compute a link-up point down-road.

    Params:
        0: ARRAY  - destPosATL [x,y,z] (destination AO / objective pos)
        1: NUMBER - linkDistM (default 350). Distance along road network from spawn to link-up.
        2: ARRAY  - preferredSpawnPosATL [] to auto-pick. If provided, snaps to nearest road.
        3: NUMBER - preferredSpawnDir (default -1). If >= 0, used as initial facing.
        4: BOOL   - requireEdge (default true). If true and no preferred spawn, only considers roads near map edge.

    Returns:
        ARRAY [spawnPosATL, spawnDir, linkPosATL, linkDir] or [] if no valid road chain found.
*/

params [
    ["_destPos", []],
    ["_linkDist", 350],
    ["_preferredPos", []],
    ["_preferredDir", -1],
    ["_requireEdge", true]
];

if (!(_destPos isEqualType []) || { (count _destPos) < 2 }) exitWith {[]};
_destPos = +_destPos; _destPos resize 3;

if (!(_linkDist isEqualType 0)) then { _linkDist = 350; };
_linkDist = (_linkDist max 0) min 1500;

private _ws = worldSize;
if (!(_ws isEqualType 0) || { _ws <= 0 }) exitWith {[]};

private _center = [_ws * 0.5, _ws * 0.5, 0];

private _edgeBand = missionNamespace getVariable ["ARC_convoyEdgeBandM", 450];
if (!(_edgeBand isEqualType 0)) then { _edgeBand = 450; };
_edgeBand = (_edgeBand max 150) min 2000;

private _sampleStep = missionNamespace getVariable ["ARC_convoyEdgeSampleStepM", 1200];
if (!(_sampleStep isEqualType 0)) then { _sampleStep = 1200; };
_sampleStep = (_sampleStep max 400) min 4000;

private _roadSearch = missionNamespace getVariable ["ARC_convoyEdgeRoadSearchM", 700];
if (!(_roadSearch isEqualType 0)) then { _roadSearch = 700; };
_roadSearch = (_roadSearch max 200) min 2000;

private _minWidth = missionNamespace getVariable ["ARC_convoyEdgeMinRoadWidth", 7];
if (!(_minWidth isEqualType 0)) then { _minWidth = 7; };
_minWidth = (_minWidth max 0) min 20;

private _getRoadWidth = {
    params ["_road"];
    private _w = 0;
    private _ri = getRoadInfo _road;
    if (_ri isEqualType [] && { (count _ri) > 1 } && { (_ri select 1) isEqualType 0 }) then
    {
        _w = _ri select 1;
    };
    _w
};

private _nearestRoad = {
    params ["_p", ["_rad", 500]];
    private _roads = _p nearRoads _rad;
    if ((count _roads) isEqualTo 0) exitWith { objNull };
    private _best = objNull;
    private _bestD = 1e9;
    {
        private _d = _p distance2D (getPosATL _x);
        if (_d < _bestD) then { _bestD = _d; _best = _x; };
    } forEach _roads;
    _best
};

private _angDelta = {
    params ["_a", "_b"];
    // shortest signed delta mapped to [0..180]
    abs(((_a - _b + 540) % 360) - 180)
};

private _pickNextRoadToward = {
    params ["_road", "_targetPos", "_visited"];
    private _con = roadsConnectedTo _road;
    if ((count _con) isEqualTo 0) exitWith { objNull };

    private _curPos = getPosATL _road;
    private _dirToT = _curPos getDir _targetPos;
    private _curDist = _curPos distance2D _targetPos;

    private _best = objNull;
    private _bestScore = 1e9;

    {
        if (_x in _visited) then { continue; };
        private _p = getPosATL _x;
        private _dir = _curPos getDir _p;
        private _delta = [_dir, _dirToT] call _angDelta;

        private _newDist = _p distance2D _targetPos;
        private _away = (_newDist - _curDist) max 0;

        // Prefer moving generally toward the target and not spinning around.
        private _score = (_delta * 1.0) + (_away * 0.05);

        if (_score < _bestScore) then
        {
            _bestScore = _score;
            _best = _x;
        };
    } forEach _con;

    _best
};

// --- Choose spawn road ------------------------------------------------------------
private _spawnRoad = objNull;
private _spawnPos = [];
private _spawnDir = -1;

if (_preferredPos isEqualType [] && { (count _preferredPos) >= 2 }) then
{
    private _p = +_preferredPos; _p resize 3;
    _spawnRoad = [_p, _roadSearch] call _nearestRoad;
    if (!isNull _spawnRoad) then
    {
        _spawnPos = getPosATL _spawnRoad;
    };

    if (_preferredDir isEqualType 0 && { _preferredDir >= 0 }) then
    {
        _spawnDir = _preferredDir % 360;
    };
}
else
{
    if (!_requireEdge) exitWith {[]};

    private _edgeInset = (_edgeBand min 600) max 20;

    // Sample points along the map edge and grab the nearest road at each sample.
    private _cands = [];
    for "_t" from (_sampleStep * 0.5) to (_ws - (_sampleStep * 0.5)) step _sampleStep do
    {
        _cands pushBack [_edgeInset, _t, 0];
        _cands pushBack [_ws - _edgeInset, _t, 0];
        _cands pushBack [_t, _edgeInset, 0];
        _cands pushBack [_t, _ws - _edgeInset, 0];
    };

    private _bestRoad = objNull;
    private _bestScore = 1e9;

    {
        private _s = _x;
        if (surfaceIsWater _s) then { continue; };

        private _r = [_s, _roadSearch] call _nearestRoad;
        if (isNull _r) then { continue; };

        private _rp = getPosATL _r;
        if (surfaceIsWater _rp) then { continue; };

        private _width = [_r] call _getRoadWidth;

        // Determine a plausible inward direction (toward dest, otherwise toward center).
        private _tgt = _destPos;
        if ((_rp distance2D _destPos) < 800) then { _tgt = _center; };

        private _vis = [_r];
        private _nxt = [_r, _tgt, _vis] call _pickNextRoadToward;
        if (isNull _nxt) then { continue; };

        private _dir = _rp getDir (getPosATL _nxt);
        private _dirToDest = _rp getDir _destPos;
        private _delta = [_dir, _dirToDest] call _angDelta;

        // Prefer wide roads (MSR/ASR proxy) and headings roughly toward destination.
        private _widthPenalty = ((_minWidth - _width) max 0) * 25;
        private _distPenalty = (_s distance2D _rp) * 0.02;

        private _score = _delta + _widthPenalty + _distPenalty;

        if (_score < _bestScore) then
        {
            _bestScore = _score;
            _bestRoad = _r;
            _spawnDir = _dir;
        };
    } forEach _cands;

    _spawnRoad = _bestRoad;
    if (!isNull _spawnRoad) then
    {
        _spawnPos = getPosATL _spawnRoad;
    };
};

if (isNull _spawnRoad || { _spawnPos isEqualTo [] }) exitWith {[]};

_spawnPos = +_spawnPos; _spawnPos resize 3;

// If spawnDir wasn't provided or computed yet, compute it using connected roads.
if (!(_spawnDir isEqualType 0) || { _spawnDir < 0 }) then
{
    private _vis0 = [_spawnRoad];
    private _n0 = [_spawnRoad, _destPos, _vis0] call _pickNextRoadToward;
    if (!isNull _n0) then
    {
        _spawnDir = _spawnPos getDir (getPosATL _n0);
    }
    else
    {
        _spawnDir = _spawnPos getDir _destPos;
    };
};
_spawnDir = _spawnDir % 360;

// --- Walk forward to link-up -----------------------------------------------------
private _linkPos = +_spawnPos;
private _linkDir = _spawnDir;

if (_linkDist > 0) then
{
    private _curRoad = _spawnRoad;
    private _curPos = +_spawnPos;
    private _accum = 0;
    private _visited = [_spawnRoad];
    private _iter = 0;

    while { _accum < _linkDist && { _iter < 50 } } do
    {
        private _n = [_curRoad, _destPos, _visited] call _pickNextRoadToward;
        if (isNull _n) exitWith {};
        private _np = getPosATL _n;

        _accum = _accum + (_curPos distance2D _np);
        _curRoad = _n;
        _curPos = +_np;

        _visited pushBack _curRoad;
        _iter = _iter + 1;
    };

    _linkPos = +_curPos; _linkPos resize 3;

    // Link direction based on the next road segment, otherwise toward destination.
    private _vis1 = [_curRoad];
    private _n1 = [_curRoad, _destPos, _vis1] call _pickNextRoadToward;
    if (!isNull _n1) then
    {
        _linkDir = _linkPos getDir (getPosATL _n1);
    }
    else
    {
        _linkDir = _linkPos getDir _destPos;
    };
    _linkDir = _linkDir % 360;
};

[_spawnPos, _spawnDir, _linkPos, _linkDir]

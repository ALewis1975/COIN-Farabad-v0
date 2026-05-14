/*
    ARC_fnc_worldHighwayMarkerNearest

    Resolve the nearest editor-placed highway direction marker.

    Highway markers are named mkr_highway_### and point in the direction of
    travel for that side of the highway. This helper is read-only and can be
    used by server-owned traffic/convoy systems to orient vehicles.

    Params:
      0: posATL [x,y,z]
      1: searchRadiusM
      2: preferredDirDeg (-1 disables direction scoring)

    Returns:
      [markerName, markerPosATL, markerDirDeg, distanceM] or []
*/

params [
    ["_pos", [0,0,0], [[]]],
    ["_radius", 90, [0]],
    ["_preferredDir", -1, [0]]
];

if (!(_pos isEqualType []) || { (count _pos) < 2 }) exitWith {[]};
if (!(_radius isEqualType 0)) then { _radius = 90; };
_radius = (_radius max 20) min 500;
if (!(_preferredDir isEqualType 0)) then { _preferredDir = -1; };
if (_preferredDir >= 0) then { _preferredDir = _preferredDir % 360; };

private _prefix = "mkr_highway_";

private _dirWeight = missionNamespace getVariable ["ARC_highwayMarkerDirScoreWeightM", 0.45];
if (!(_dirWeight isEqualType 0)) then { _dirWeight = 0.45; };
_dirWeight = (_dirWeight max 0) min 3;

private _best = [];
private _bestScore = 1e12;

{
    private _markerName = _x;
    if (!(_markerName isEqualType "")) then { continue; };
    if (!((_markerName find _prefix) isEqualTo 0)) then { continue; };

    private _markerPos = getMarkerPos _markerName;
    if (!(_markerPos isEqualType []) || { (count _markerPos) < 2 }) then { continue; };
    _markerPos resize 3;

    private _dist = _pos distance2D _markerPos;
    if (_dist > _radius) then { continue; };

    private _dir = markerDir _markerName;
    if (!(_dir isEqualType 0) || { _dir < 0 }) then { _dir = 0; };
    _dir = _dir % 360;

    private _score = _dist;
    if (_preferredDir >= 0) then
    {
        private _delta = abs (((_dir - _preferredDir + 540) % 360) - 180);
        _score = _score + (_delta * _dirWeight);
    };

    if (_score < _bestScore) then
    {
        _bestScore = _score;
        _best = [_markerName, _markerPos, _dir, _dist];
    };
} forEach allMapMarkers;

_best

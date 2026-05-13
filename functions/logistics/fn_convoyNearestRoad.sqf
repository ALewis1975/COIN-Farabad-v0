/*
    Server: find the nearest connected road object to a position, with optional zone avoidance.

    Extracted from fn_execInitActive.sqf; used by convoy spawn/link-up positioning,
    road-snapping, and the A* fallback route sampler.

    Penalty is applied to disconnected road segments (taxiways, service roads) to prefer
    road nodes that are actually part of the navigable graph.

    Params:
        0: ARRAY  - centre position (2D/3D)
        1: NUMBER - search radius in metres (default: 120)
        2: STRING - zone name to avoid (e.g. "Airbase"); "" = no avoidance (default: "")
        3: ARRAY  - allow-near position inside avoid zone; [] = none (default: [])
        4: NUMBER - allow-near radius; roads within this distance of _avoidNear that are
                    inside _avoidZone are still considered (default: 220)

    Returns:
        OBJECT - nearest eligible road object, or objNull if none found
*/

if (!isServer) exitWith { objNull };

params [
    ["_p",         [0,0,0], [[]]],
    ["_rad",        120,    [0]],
    ["_avoidZone",  "",     [""]],
    ["_avoidNear",  [],     [[]]],
    ["_avoidNearR", 220,    [0]]
];

if (!(_p isEqualType []) || { (count _p) < 2 }) exitWith { objNull };

private _pos = +_p;
_pos resize 3;

private _roads = _pos nearRoads _rad;
if ((count _roads) isEqualTo 0) exitWith { objNull };

private _best = objNull;
private _bestScore = 1e12;

{
    private _rp = getPosATL _x;
    private _ok = true;

    if (!(_avoidZone isEqualTo "")) then
    {
        private _z = [_rp] call ARC_fnc_worldGetZoneForPos;
        if ((toUpper _z) isEqualTo (toUpper _avoidZone)) then
        {
            private _nearOk = (_avoidNear isEqualType [] && { (count _avoidNear) >= 2 } && { (_rp distance2D _avoidNear) <= _avoidNearR });
            if (!_nearOk) then { _ok = false; };
        };
    };

    if (_ok) then
    {
        private _d = _pos distance2D _rp;

        // Some map road objects (taxiways/parking/service segments) can be disconnected.
        // If we snap to those, A* can't build a real route and you get a single straight-line leg.
        private _conN = count (roadsConnectedTo _x);
        private _conPen = if (_conN isEqualTo 0) then { 5000 } else { 0 };

        private _score = _d + _conPen;
        if (_score < _bestScore) then { _bestScore = _score; _best = _x; };
    };
} forEach _roads;

_best

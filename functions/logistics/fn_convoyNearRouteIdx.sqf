/*
    Server: find the nearest index in a route point array to a given position.

    Extracted from fn_execTickConvoy.sqf; used for follower recovery,
    bridge recovery telemetry, and route progress tracking.

    Params:
        0: ARRAY  - route points (array of 2D/3D positions)
        1: ARRAY  - reference position (2D/3D)
        2: NUMBER - fallback index to return when inputs are invalid

    Returns:
        NUMBER - nearest index in _pts, or _default on bad input
*/

if (!isServer) exitWith { 0 };

params [
    ["_pts",     [], [[]]],
    ["_pos",     [], [[]]],
    ["_default", 0,  [0]]
];

if (!(_pts isEqualType []) || { (count _pts) == 0 }) exitWith { _default };
if (!(_pos isEqualType []) || { (count _pos) < 2 }) exitWith { _default };

private _bestI = _default;
private _bestD = 1e12;

for "_i" from 0 to ((count _pts) - 1) do
{
    private _d = (_pts select _i) distance2D _pos;
    if (_d < _bestD) then { _bestD = _d; _bestI = _i; };
};

_bestI

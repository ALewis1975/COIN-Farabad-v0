/*
    ARC_fnc_worldRoadsideOffsets

    Converts a list of road objects into perpendicular offset (roadside standing)
    positions. Each road object produces one candidate position offset to the side
    of the road by _offsetM metres. Positions that land on water or on a road surface
    are discarded.

    Used by ARC_fnc_worldScanBuildingSlots at startup and as a shared helper for any
    code that needs to place units/civs near roads without blocking traffic.

    Params:
        0: ARRAY  - road objects (from nearRoads)
        1: NUMBER - perpendicular offset distance in metres [default: 4, clamped to [2, 12]]

    Returns:
        ARRAY - [x,y,z] ATL positions
*/

if (!isServer) exitWith {[]};

params [
    ["_roads",   [], [[]]],
    ["_offsetM", 4,  [0]]
];

_offsetM = (_offsetM max 2) min 12;

private _result = [];

{
    private _r  = _x;
    private _p0 = getPosATL _r;
    if (!(_p0 isEqualType []) || {(count _p0) < 2}) then { continue; };
    if ((count _p0) == 2) then { _p0 = [(_p0 select 0), (_p0 select 1), 0]; };

    private _dir = getDir _r;
    private _con = roadsConnectedTo _r;
    if ((count _con) > 0) then {
        private _p1 = getPosATL (_con select 0);
        if (_p1 isEqualType [] && {(count _p1) >= 2}) then {
            _dir = [_p0, _p1] call BIS_fnc_dirTo;
        };
    };

    private _side  = if ((random 1) < 0.5) then { 90 } else { -90 };
    private _tries = 0;
    private _p     = [0, 0, 0];

    while { _tries < 3 } do {
        private _off  = _offsetM + (_tries * (_offsetM * 0.75));
        private _sd   = _dir + _side;
        private _px   = (_p0 select 0) + (sin _sd) * _off;
        private _py   = (_p0 select 1) + (cos _sd) * _off;
        private _zASL = getTerrainHeightASL [_px, _py];
        _p = ASLToATL [_px, _py, _zASL];

        if (!(_p isEqualTo [0,0,0]) && { !(surfaceIsWater _p) } && { !(isOnRoad _p) }) exitWith {};
        _side  = -_side;
        _tries = _tries + 1;
    };

    if (!(_p isEqualTo [0,0,0]) && {(count _p) >= 2}) then {
        _result pushBackUnique _p;
    };
} forEach _roads;

_result

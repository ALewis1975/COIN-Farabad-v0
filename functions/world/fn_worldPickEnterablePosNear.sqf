/*
    Pick a position inside/at an enterable building near a center point.

    Uses data\farabad_enterable_buildings_unique.sqf (cached server-side).

    Params:
        0: ARRAY  - center position [x,y,z]
        1: NUMBER - radius in meters (default 600)
        2: ARRAY  - (optional) avoid zone ids (e.g. ["Airbase","GreenZone"])
        3: BOOL   - (optional) prefer the *nearest* candidate (default false)

    Returns:
        ARRAY - picked position [x,y,z] (falls back to center if none found)
*/

params ["_center", ["_radius", 600], ["_avoidZones", []], ["_preferNearest", false]];

if !(_center isEqualType []) exitWith {_center};
if (_radius <= 0) exitWith {_center};

if !(_avoidZones isEqualType []) then { _avoidZones = []; };
if !(_preferNearest isEqualType true) then { _preferNearest = false; };

// Normalize zone IDs for comparisons (avoid case-related mismatches).
private _avoidZonesU = _avoidZones apply { toUpper _x };

private _c = +_center;
_c resize 2;

private _cx = _c select 0;
private _cy = _c select 1;

private _r2 = _radius * _radius;

// Load/cache building list
private _buildings = missionNamespace getVariable ["ARC_enterableBuildings", []];

if (!(_buildings isEqualType []) || { _buildings isEqualTo [] }) then
{
    _buildings = call compile preprocessFileLineNumbers "data\farabad_enterable_buildings_unique.sqf";
    if (!(_buildings isEqualType [])) then { _buildings = []; };

    // Cache locally (no broadcast)
    missionNamespace setVariable ["ARC_enterableBuildings", _buildings];
};

if (_buildings isEqualTo []) exitWith {_center};

private _candidates = [];

{
    _x params ["_cls", "_pos", "_dir"];

    private _dx = (_pos select 0) - _cx;
    private _dy = (_pos select 1) - _cy;

	// Skip positions inside heavily damaged buildings (e.g., after an IED burn-down)
	private _okBuilding = true;
	private _b = nearestBuilding _pos;
	if (!isNull _b) then
	{
	    if ((_b distance2D _pos) < 35 && { (damage _b) > 0.8 }) then { _okBuilding = false; };

	    // Reject "building-like" statics with no interior positions (towers, tanks, etc.).
	    private _bps = [_b] call BIS_fnc_buildingPositions;
	    if (!(_bps isEqualType [])) then { _bps = []; };
	    if ((count _bps) <= 0) then { _okBuilding = false; };
	};

	if (_okBuilding && { (_dx * _dx + _dy * _dy) <= _r2 }) then
    {
	    if (_avoidZonesU isEqualTo []) then
        {
            _candidates pushBack _pos;
        }
        else
        {
	        private _z = toUpper ([_pos] call ARC_fnc_worldGetZoneForPos);
	        if !(_z in _avoidZonesU) then
            {
                _candidates pushBack _pos;
            };
        };
    };
} forEach _buildings;

if (_candidates isEqualTo []) then
{
    // If we were asked to avoid a zone but everything nearby is inside it,
    // try a simple radial sample to push the position outside.
	if !(_avoidZonesU isEqualTo []) then
    {
	    private _centerZone = toUpper ([_center] call ARC_fnc_worldGetZoneForPos);
	    if (_centerZone in _avoidZonesU) then
        {
            private _fallback = [];
            for "_i" from 1 to 25 do
            {
                private _ang  = random 360;
                private _dist = (_radius * 0.7) + (random (_radius * 1.2));

                private _x = _cx + (sin _ang) * _dist;
                private _y = _cy + (cos _ang) * _dist;

                private _p = [_x, _y, 0];
                if (surfaceIsWater _p) then { continue; };

	            private _z = toUpper ([_p] call ARC_fnc_worldGetZoneForPos);
	            if !(_z in _avoidZonesU) exitWith { _fallback = _p; };
            };

            if !(_fallback isEqualTo []) exitWith { _fallback };
        };
    };

    _center
}
else
{
    private _p = objNull;
    if (_preferNearest) then
    {
        private _best = [];
        private _bestD2 = 1e18;
        {
            private _dx = (_x select 0) - _cx;
            private _dy = (_x select 1) - _cy;
            private _d2 = (_dx * _dx + _dy * _dy);
            if (_d2 < _bestD2) then
            {
                _bestD2 = _d2;
                _best = _x;
            };
        } forEach _candidates;

        _p = _best;
    }
    else
    {
        _p = selectRandom _candidates;
    };

    // Convert the chosen building anchor position into an actual interior building position.
    // This prevents props from snapping to rooftops or falling under building foundations.
    private _b = nearestBuilding _p;
    if (!isNull _b) then
    {
        if (!(_bps isEqualType [])) then { _bps = []; };

        // Filter out roof/outdoor positions by checking for nearby overhead geometry.
        private _good = [];
        {
            if (_x isEqualType [] && { (count _x) >= 2 }) then
            {
                private _pp = +_x; _pp resize 3;
                private _as = ATLtoASL _pp;
                private _hits = lineIntersectsSurfaces [_as, _as vectorAdd [0,0,10], objNull, objNull, true, 1, 'GEOM', 'NONE'];
                if (_hits isEqualType [] && { (count _hits) > 0 }) then
                {
                    _good pushBack _pp;
                };
            };
        } forEach _bps;

        if ((count _good) > 0) then
        {
            _p = selectRandom _good;
        }
        else
        {
            // Fallback: pick the lowest building position (often ground floor)
            if ((count _bps) > 0) then
            {
                private _best = _bps select 0;
                private _bestZ = (_best select 2);
                {
                    private _z = _x select 2;
                    if (_z < _bestZ) then { _best = _x; _bestZ = _z; };
                } forEach _bps;
                _p = +_best;
            };
        };
    };

    _p resize 3;
    _p
};

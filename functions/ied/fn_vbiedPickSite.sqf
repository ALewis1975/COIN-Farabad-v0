/*
    ARC_fnc_vbiedPickSite

    Phase 3 (VBIED v1): pick a plausible parked-vehicle position near a center.

    Roadside biased, vehicle-class aware.

    Params:
      0: ARRAY  - center position ATL
      1: NUMBER - search radius (m)
      2: STRING - vehicle class (for findEmptyPosition)

    Returns:
      ARRAY position ATL [x,y,z] or [] if none.
*/

params [
    ["_center", [0,0,0], [[]]],
    ["_radius", 300, [0]],
    ["_vehClass", "C_Offroad_01_F", [""]]
];

private _avoidAirbase = missionNamespace getVariable ["ARC_vbiedSiteAvoidAirbase", true];
if (!(_avoidAirbase isEqualType true) && !(_avoidAirbase isEqualType false)) then { _avoidAirbase = true; };

private _tries = missionNamespace getVariable ["ARC_vbiedSitePickTries", 36];
if (!(_tries isEqualType 0) || { _tries <= 0 }) then { _tries = 36; };
_tries = (_tries max 12) min 120;

private _slopeMax = missionNamespace getVariable ["ARC_vbiedSiteSlopeMax", 0.22]; // ~12 degrees
if (!(_slopeMax isEqualType 0) || { _slopeMax <= 0 }) then { _slopeMax = 0.22; };
_slopeMax = (_slopeMax max 0.06) min 0.45;

private _roads = _center nearRoads _radius;
private _useRoads = ((count _roads) > 0);

private _best = [];
for "_i" from 0 to (_tries - 1) do
{
    private _candList = [];
    if (_useRoads) then
    {
        private _r = selectRandom _roads;
        private _rp = getPosATL _r;
        _rp = +_rp; _rp resize 3;

        // Approximate road heading; used for very small offsets that still stay on the road surface.
        private _dir = getDir _r;
        if (!(_dir isEqualType 0)) then { _dir = random 360; };

        _candList = [
            _rp,
            (_rp getPos [0.8, _dir + 90]),
            (_rp getPos [-0.8, _dir + 90]),
            (_rp getPos [1.2, _dir]),
            (_rp getPos [-1.2, _dir])
        ];
    }
    else
    {
        _candList = [(_center getPos [random _radius, random 360])];
    };

    {
        private _cand = +_x; _cand resize 3;

        if (surfaceIsWater _cand) then { continue; };

        private _n = surfaceNormal _cand;
        if (!(_n isEqualType []) || { (count _n) < 3 }) then { continue; };
        if (abs (_n # 2) < (1 - _slopeMax)) then { continue; };

        if (_avoidAirbase) then
        {
            private _z = [_cand] call ARC_fnc_worldGetZoneForPos;
            if ((toUpper _z) isEqualTo "AIRBASE") then { continue; };
        };

        // Keep empty-position search tight so we don't "wander" off-road.
        private _ep = _cand findEmptyPosition [0, 2.5, _vehClass];
        if (_ep isEqualTo []) then { continue; };
        _ep = +_ep; _ep resize 3;

        // Hard rule: must remain on/very near a road object.
        private _nearRoads = _ep nearRoads 4;
        if (!(_nearRoads isEqualType []) || { (count _nearRoads) <= 0 }) then { continue; };

        // Hard rule: must not be inside/under a building.
        private _b = nearestBuilding _ep;
        if (!isNull _b && { (_ep distance2D _b) < 8 }) then { continue; };

        _best = _ep;
        break;
    } forEach _candList;

    if (_best isNotEqualTo []) exitWith {};
};

_best

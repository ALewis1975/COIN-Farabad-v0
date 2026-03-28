/*
    Returns the zone id for a given position (or "" if none).

    Zones come from missionNamespace variable ARC_worldZones, created in ARC_fnc_worldInit.

    Params:
        0: ARRAY - position (2D or 3D)

    Returns:
        STRING - zone id (e.g., "Airbase", "GreenZone") or ""
*/

params ["_pos"];

if !(_pos isEqualType []) exitWith {""};

private _p2 = +_pos;
_p2 resize 2;

private _zones = missionNamespace getVariable ["ARC_worldZones", []];
if !(_zones isEqualType []) exitWith {""};

private _px = _p2 select 0;
private _py = _p2 select 1;

private _zone = "";
{
    _x params ["_id", "_displayName", "_center", "_halfExtents", "_dir"];

    private _cx = _center select 0;
    private _cy = _center select 1;
    private _hw = _halfExtents select 0;
    private _hh = _halfExtents select 1;

    // Rotate point into zone-local space (rectangle containment check)
    private _dx = _px - _cx;
    private _dy = _py - _cy;

    // IMPORTANT: Arma SQF trig functions (sin/cos) use DEGREES, not radians.
    // So do NOT convert degrees -> radians.
    // See Bohemia wiki: https://community.bistudio.com/wiki/sin and https://community.bistudio.com/wiki/cos
    private _a = -_dir;
    private _c = cos _a;
    private _s = sin _a;

    private _lx = (_dx * _c) - (_dy * _s);
    private _ly = (_dx * _s) + (_dy * _c);

    if ((abs _lx) <= _hw && { (abs _ly) <= _hh }) exitWith
    {
        _zone = _id;
    };
} forEach _zones;

_zone

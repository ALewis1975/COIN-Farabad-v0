/*
    AIRBASESUB: Security patrol loop (server-only)

    Params:
      0: OBJECT - vehicle
      1: STRING - starting marker name
      2: ARRAY<STRING> - list of marker names the patrol visits

    Notes:
      - Runs regardless of the airbase "bubble" so patrols continue even when players are not nearby.
      - Keeps vehicles on roads (nearestRoad) to avoid wandering onto taxiways/runway.
      - NO moveIn* (driver boards via assignAsDriver + orderGetIn).
*/

if (!isServer) exitWith {false};
if !(["airbaseSecurityPatrol"] call ARC_fnc_airbaseRuntimeEnabled) exitWith {false};

params [
    ["_vehicle", objNull, [objNull]],
    ["_startingMarker", "", [""]],
    ["_markers", [], [[]]]
];

if (isNull _vehicle) exitWith {false};
if (!alive _vehicle) exitWith {false};
if (_markers isEqualTo []) exitWith {false};

// Ensure the vehicle has a driver (NO moveIn*)
// ORBAT: USAF Security Forces (332 ESFG / SENTRY) patrol the installation.
// rhsusf_airforce_m is the USAF enlisted male — correct for SENTRY patrols.
if (isNull (driver _vehicle)) then
{
    private _g = createGroup west;
    private _d = _g createUnit ["rhsusf_airforce_m", getPosATL _vehicle, [], 0, "NONE"];
    _vehicle lock false;
    unassignVehicle _d;
    _d assignAsDriver _vehicle;
    [_d] orderGetIn true;

    private _t0 = time;
    waitUntil {
        sleep 1;
        (!alive _vehicle) || (!alive _d) || ((driver _vehicle) isEqualTo _d) || ((time - _t0) > 60)
    };
};

private _group = group (driver _vehicle);
if (isNull _group) exitWith {false};

// Snap to nearest road near starting marker
if !(_startingMarker isEqualTo "") then
{
    private _startRoad = [getMarkerPos _startingMarker, 50] call BIS_fnc_nearestRoad;
    if (!isNull _startRoad) then
    {
        _vehicle setPosATL (getPosATL _startRoad);
    };
};

_vehicle setConvoySeparation 10;
_vehicle limitSpeed 35;
_vehicle forceSpeed -1;
_group setBehaviour "SAFE";
_group setCombatMode "YELLOW";
_group setFormation "COLUMN";

private _lastMarker = "";

while {alive _vehicle} do
{
    _vehicle limitSpeed 35;

    // Pick a marker different from the last one to reduce ping-pong.
    private _choices = _markers;
    if !(_lastMarker isEqualTo "") then
    {
        _choices = _markers select { !(_x isEqualTo _lastMarker) };
        if (_choices isEqualTo []) then { _choices = _markers; };
    };

    private _marker = selectRandom _choices;
    _lastMarker = _marker;

    private _destPos = getMarkerPos _marker;
    private _road = [_destPos, 80] call BIS_fnc_nearestRoad;
    if (!isNull _road) then { _destPos = getPosATL _road; };

    _group move _destPos;

    private _timeout = time + 300;
    waitUntil
    {
        sleep 2;
        (!alive _vehicle) || { (_vehicle distance2D _destPos) < 25 } || { time > _timeout }
    };

    sleep (10 + random 15);
};

false

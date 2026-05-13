/*
    Server: apply a multi-waypoint road route to a convoy group.

    Extracted from fn_execTickConvoy.sqf; shared by the depart block,
    the waypoint watchdog, and the stuck-recovery branches.

    Samples forward along a pre-computed road-route point chain so the
    convoy commits to the road network, reducing bridge deadlocks and
    end-of-route cross-country shortcuts.

    Params:
        0: GROUP  - convoy group to route
        1: ARRAY  - route point array (array of 3D positions)
        2: ARRAY  - destination waypoint position (3D)
        3: NUMBER - destination waypoint completion radius (metres)
        4: ARRAY  - optional forced ingress position (e.g. Airbase North Gate); [] = none

    Returns:
        Nothing
*/

if (!isServer) exitWith {};

params [
    ["_grp",        grpNull, [grpNull]],
    ["_routePtsIn", [],      [[]]],
    ["_destWp",     [0,0,0], [[]]],
    ["_destRad",    40,      [0]],
    ["_forcedPos",  [],      [[]]]
];

if (isNull _grp) exitWith {};

// _destRad is received for API consistency with convoy callers; the final
// waypoint radius is driven by ARC_convoyFinalWpRadiusM (tunable).
_destRad;

// Clear any existing waypoints.
while { (count waypoints _grp) > 0 } do { deleteWaypoint ((waypoints _grp) select 0); };

private _minWpsUser = missionNamespace getVariable ["ARC_convoyWaypointMin", 8];
if (!(_minWpsUser isEqualType 0)) then { _minWpsUser = 8; };
_minWpsUser = (_minWpsUser max 3) min 25;

private _maxWpsUser = missionNamespace getVariable ["ARC_convoyWaypointMax", 12];
if (!(_maxWpsUser isEqualType 0)) then { _maxWpsUser = 12; };
_maxWpsUser = (_maxWpsUser max _minWpsUser) min 25;

// Waypoint interval is derived from the remaining road-route length so we consistently land
// in the 8-12 waypoint window (per design). Falls back to a tunable interval if route length is unknown.
private _interval = missionNamespace getVariable ["ARC_convoyWaypointIntervalM", 450];
if (!(_interval isEqualType 0)) then { _interval = 450; };
_interval = (_interval max 150) min 2000;

private _maxWps = _maxWpsUser;

private _finalWpRad = missionNamespace getVariable ["ARC_convoyFinalWpRadiusM", 45];
if (!(_finalWpRad isEqualType 0)) then { _finalWpRad = 45; };
_finalWpRad = (_finalWpRad max 25) min 150;

private _wps = [];

// Find the nearest route index to the current lead position, so we can start sampling forward.
private _nearIdx = 0;
if (_routePtsIn isEqualType [] && { (count _routePtsIn) >= 2 }) then
{
    private _vehL = vehicle (leader _grp);
    private _lp = getPosATL _vehL; _lp resize 3;

    private _bestD = 1e12;
    for "_i" from 0 to ((count _routePtsIn) - 1) do
    {
        private _d = (_routePtsIn select _i) distance2D _lp;
        if (_d < _bestD) then { _bestD = _d; _nearIdx = _i; };
    };
};

// Identify a forced index for ingress (closest route point to forcedPos).
private _forceIdx = -1;
if (_forcedPos isEqualType [] && { (count _forcedPos) >= 2 } && { _routePtsIn isEqualType [] && { (count _routePtsIn) >= 2 } }) then
{
    private _bestDg = 1e12;
    for "_i" from 0 to ((count _routePtsIn) - 1) do
    {
        private _d = (_routePtsIn select _i) distance2D _forcedPos;
        if (_d < _bestDg) then { _bestDg = _d; _forceIdx = _i; };
    };
    // If we're already beyond the ingress point, don't force it.
    if (_forceIdx <= _nearIdx) then { _forceIdx = -1; };
};

// Compute remaining road-route length from our current position to the end, then
// derive waypoint count/interval so the convoy commits to the road chain (bridge reliability).
private _remLen = 0;
if (_routePtsIn isEqualType [] && { (count _routePtsIn) >= 2 }) then
{
    for "_j" from (_nearIdx + 1) to ((count _routePtsIn) - 1) do
    {
        _remLen = _remLen + ((_routePtsIn select (_j - 1)) distance2D (_routePtsIn select _j));
    };
};

if (_remLen > 0) then
{
    // Desired total waypoint count (including final): 8-12.
    private _desired = round((_remLen / 700) + 2);
    _desired = (_desired max _minWpsUser) min _maxWpsUser;
    _maxWps = _desired;

    // Interval derived from desired count. Clamp to keep AI from over-steering on short routes.
    _interval = _remLen / ((_maxWps - 1) max 1);
    _interval = (_interval max 180) min 1200;
};

// If we have a forced ingress point (gate), tighten waypoint spacing so the AI commits to the road chain.
if (_forcedPos isEqualType [] && { (count _forcedPos) >= 2 }) then
{
    _interval = _interval min 420;
};

private _forcedAdded = false;

// Sample forward along the route.
if (_routePtsIn isEqualType [] && { (count _routePtsIn) >= 2 }) then
{
    private _acc = 0;
    private _last = _routePtsIn select _nearIdx;
    for "_i" from (_nearIdx + 1) to ((count _routePtsIn) - 1) do
    {
        private _p = _routePtsIn select _i;
        _acc = _acc + (_last distance2D _p);

        // Force-add ingress point when we reach its index.
        if (!_forcedAdded && { _forceIdx >= 0 } && { _i == _forceIdx }) then
        {
            if ((count _wps) isEqualTo 0 || { (_p distance2D (_wps select ((count _wps) - 1))) > 40 }) then
            {
                _wps pushBack _p;
            };
            _forcedAdded = true;
            _acc = 0;
        };

        if (_acc >= _interval) then
        {
            if ((count _wps) isEqualTo 0 || { (_p distance2D (_wps select ((count _wps) - 1))) > 40 }) then
            {
                _wps pushBack _p;
            };
            _acc = 0;
            if ((count _wps) >= (_maxWps - 1)) exitWith {};
        };
        _last = _p;
    };
};

// Always add the final waypoint (dedupe if already close).
if ((count _wps) isEqualTo 0 || { ((_wps select ((count _wps) - 1)) distance2D _destWp) > 60 }) then
{
    _wps pushBack _destWp;
};

{
    private _wp = _grp addWaypoint [_x, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "NORMAL";
    _wp setWaypointBehaviour "AWARE";
    _wp setWaypointCombatMode "YELLOW";
    _wp setWaypointFormation "COLUMN";
    _wp setWaypointCompletionRadius 45;

    // Final wp uses a small radius so the lead stays on-road longer.
    if (_forEachIndex isEqualTo ((count _wps) - 1)) then
    {
        _wp setWaypointCompletionRadius _finalWpRad;
    };
} forEach _wps;

if ((count waypoints _grp) > 0) then
{
    _grp setCurrentWaypoint ((waypoints _grp) select 0);
};

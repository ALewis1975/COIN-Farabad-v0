/*
    ARC_fnc_incidentSeedQueue

    Server-only. Seeds the initial TOC queue with PENDING incidents based on
    starting METT-TC world-state conditions. Called from fn_bootstrapServer.sqf
    after ARC_fnc_intelInit and before ARC_fnc_incidentLoop.

    Only seeds when both:
      - The TOC queue (tocQueue) is currently empty.
      - No active incident exists (activeTaskId is empty).
    This prevents re-seeding on server restart when state is already populated.

    Returns: BOOL (true if incidents were seeded, false otherwise)
*/

if (!isServer) exitWith {false};

// Early-exit: only seed when queue is empty and no active incident exists.
private _tocQueue = ["tocQueue", []] call ARC_fnc_stateGet;
if (!(_tocQueue isEqualType [])) then { _tocQueue = []; };
if ((count _tocQueue) > 0) exitWith {false};

private _activeTaskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (!(_activeTaskId isEqualType "")) then { _activeTaskId = ""; };
if (!(_activeTaskId isEqualTo "")) exitWith {false};

// World-state levers (0..1). Defaults align with ARC_fnc_stateInit starting values.
private _p    = ["insurgentPressure", 0.35] call ARC_fnc_stateGet;
private _corr = ["corruption",        0.55] call ARC_fnc_stateGet;
private _inf  = ["infiltration",      0.35] call ARC_fnc_stateGet;
private _fuel = ["baseFuel",          0.38] call ARC_fnc_stateGet;
private _ammo = ["baseAmmo",          0.32] call ARC_fnc_stateGet;
private _med  = ["baseMed",           0.40] call ARC_fnc_stateGet;

// Clamp all levers to [0, 1]
if (!(_p    isEqualType 0)) then { _p    = 0.35; }; _p    = (_p    max 0) min 1;
if (!(_corr isEqualType 0)) then { _corr = 0.55; }; _corr = (_corr max 0) min 1;
if (!(_inf  isEqualType 0)) then { _inf  = 0.35; }; _inf  = (_inf  max 0) min 1;
if (!(_fuel isEqualType 0)) then { _fuel = 0.38; }; _fuel = (_fuel max 0) min 1;
if (!(_ammo isEqualType 0)) then { _ammo = 0.32; }; _ammo = (_ammo max 0) min 1;
if (!(_med  isEqualType 0)) then { _med  = 0.40; }; _med  = (_med  max 0) min 1;

private _logNeed = ((1 - ((_fuel + _ammo + _med) / 3)) max 0) min 1;

private _safeModeEnabled = missionNamespace getVariable ["ARC_safeModeEnabled", false];
if (!(_safeModeEnabled isEqualType true) && !(_safeModeEnabled isEqualType false)) then { _safeModeEnabled = false; };

// Load incident catalog
private _catalog = call compile preprocessFileLineNumbers "data\incident_markers.sqf";
if (!(_catalog isEqualType [])) exitWith {false};

// Campaign stage: fresh mission = 0 (favours mundane tasks).
private _stage = 0;
private _early = 1;

// Build weighted candidate list (mirrors fn_incidentCreate weighting, stage=0 for fresh mission).
private _choices = [];
private _weights = [];

{
    if !(_x isEqualType []) then { continue; };
    _x params ["_rawMarker", "_displayName", "_incidentType"];

    private _m = [_rawMarker] call ARC_fnc_worldResolveMarker;
    if (!(_m in allMapMarkers)) then { continue; };

    private _typeU = toUpper _incidentType;

    if (_safeModeEnabled && { _typeU isEqualTo "IED" }) then { continue; };

    // Base weight by incident type
    private _w = switch (_typeU) do
    {
        case "LOGISTICS":  { 0.40 + (1.40 * _logNeed) };
        case "ESCORT":     { 0.40 + (1.20 * _logNeed) };
        case "IED":        { 0.60 + (1.20 * _p) };
        case "RAID":       { 0.50 + (1.00 * _p) };
        case "DEFEND":     { 0.50 + (1.00 * _p) };
        case "QRF":        { 0.30 + (0.80 * _p) };
        case "PATROL":     { 0.80 + (0.60 * (1 - _p)) };
        case "RECON":      { 0.80 + (0.70 * (1 - _p)) };
        case "CIVIL":      { 0.70 + (0.80 * _corr) + (0.40 * _inf) };
        case "CHECKPOINT": { 0.60 + (0.40 * _p) + (0.20 * _corr) };
        default            { 1 };
    };

    // Zone-aware weighting
    private _zone = [markerPos _m] call ARC_fnc_worldGetZoneForPos;
    switch (_zone) do
    {
        case "GreenZone":
        {
            if (_typeU in ["CIVIL", "DEFEND", "QRF", "CHECKPOINT"]) then
            {
                _w = _w * (1 + (0.80 * _inf) + (0.40 * _corr));
            };
        };
        case "Airbase":
        {
            if (_typeU in ["LOGISTICS", "ESCORT"]) then
            {
                _w = _w * (1 + (0.80 * _logNeed));
            };
            if (_typeU in ["DEFEND", "QRF"]) then
            {
                _w = _w * (1 + (0.40 * _p));
            };
        };
        default {};
    };

    // Campaign stage skew: stage=0 favours mundane tasks (LOGISTICS/PATROL/etc.)
    private _stageMul = 1;
    if (_typeU in ["LOGISTICS", "ESCORT", "PATROL", "RECON", "CIVIL", "CHECKPOINT"]) then
    {
        _stageMul = 0.85 + (0.35 * _early); // stage=0 => 1.20
    };
    if (_typeU in ["IED", "RAID", "DEFEND", "QRF"]) then
    {
        _stageMul = 0.35 + (0.65 * _stage); // stage=0 => 0.35
    };
    _w = _w * _stageMul;

    if (_w <= 0) then { continue; };

    _choices pushBack [_m, _displayName, _incidentType];
    _weights pushBack _w;

} forEach _catalog;

if (_choices isEqualTo []) exitWith {false};

// Number of incidents to seed (configurable; default 3)
private _seedCount = missionNamespace getVariable ["ARC_incidentSeedCount", 3];
if (!(_seedCount isEqualType 0)) then { _seedCount = 3; };
_seedCount = (_seedCount max 1) min 10;
_seedCount = _seedCount min (count _choices);

private _count = 0;

for "_i" from 0 to (_seedCount - 1) do
{
    if ((count _choices) == 0) exitWith {};

    // Weighted random pick
    private _sumW = 0;
    { _sumW = _sumW + _x; } forEach _weights;

    private _idx = floor (random (count _choices));
    if (_sumW > 0) then
    {
        private _r = random _sumW;
        private _acc = 0;
        {
            _acc = _acc + (_weights select _forEachIndex);
            if (_r <= _acc) exitWith { _idx = _forEachIndex; };
        } forEach _choices;
    };

    private _pick = _choices select _idx;
    _pick params ["_mkr", "_disp", "_incType"];

    private _pos = getMarkerPos ([_mkr] call ARC_fnc_worldResolveMarker);
    private _posATL = +_pos;
    _posATL resize 3;

    private _grid = mapGridPosition _posATL;
    private _summary = format ["METT-TC seed: %1 (%2) at %3", _disp, _incType, _grid];

    private _payload = [
        ["marker",      _mkr],
        ["incidentType",_incType],
        ["displayName", _disp],
        ["pos",         _posATL]
    ];

    [
        objNull,
        "INCIDENT",
        _payload,
        _summary,
        "Auto-generated from starting METT-TC conditions.",
        _posATL,
        [["source", "METT_TC_SEED"], ["seedIndex", _i]]
    ] call ARC_fnc_intelQueueSubmit;

    _count = _count + 1;

    // Remove chosen entry to avoid exact-duplicate selection in subsequent picks.
    _choices deleteAt _idx;
    _weights deleteAt _idx;
};

diag_log format ["[ARC][INC] Seeded %1 incident(s) into TOC queue from METT-TC starting conditions.", _count];

// Publish definitive queue snapshot for clients.
[] call ARC_fnc_intelQueueBroadcast;

(_count > 0)

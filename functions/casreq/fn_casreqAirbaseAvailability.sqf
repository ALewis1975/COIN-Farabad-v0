/*
    ARC_fnc_casreqAirbaseAvailability

    Server-only: derive CAS availability from AIRBASESUB attack aircraft state.

    Returns pairs:
      available, reason, attackReady, attackTotal, attackQueued, attackActive,
      runwayState, holdDepartures, assets
*/

if (!isServer) exitWith {[]};

private _rt = missionNamespace getVariable ["airbase_v1_rt", createHashMap];
private _hg = compile "params ['_h','_k','_d']; if (!(_h isEqualType createHashMap)) exitWith {_d}; (_h) getOrDefault [_k, _d]";
private _assets = [_rt, "assets", []] call _hg;
if (!(_assets isEqualType [])) then { _assets = []; };

private _attackVehVars = missionNamespace getVariable ["casreq_v1_airbase_attack_vehvars", ["plane4", "plane5"]];
if (!(_attackVehVars isEqualType [])) then { _attackVehVars = ["plane4", "plane5"]; };

private _now = serverTime;
private _attackTotal = 0;
private _attackReady = 0;
private _attackQueued = 0;
private _attackActive = 0;
private _assetRows = [];

{
    private _vehVar = [_x, "vehVar", ""] call _hg;
    if (!(_vehVar isEqualType "") || { !(_vehVar in _attackVehVars) }) then { continue; };

    _attackTotal = _attackTotal + 1;

    private _assetId = [_x, "id", _vehVar] call _hg;
    private _state = toUpper ([_x, "state", "PARKED"] call _hg);
    private _activeFlight = [_x, "activeFlight", ""] call _hg;
    private _availableAt = [_x, "availableAt", 0] call _hg;
    if (!(_availableAt isEqualType 0)) then { _availableAt = 0; };

    if (_state in ["PARKED", "COOLDOWN"]) then
    {
        if (_availableAt <= _now) then { _attackReady = _attackReady + 1; };
    };
    if (_state in ["QUEUED", "RETURN_QUEUED"]) then { _attackQueued = _attackQueued + 1; };
    if (_state in ["ACTIVE", "DEPARTING", "ARRIVING", "RETURNING"]) then { _attackActive = _attackActive + 1; };

    _assetRows pushBack [_assetId, _vehVar, _state, _activeFlight, _availableAt];
} forEach _assets;

private _holdDepartures = ["airbase_v1_holdDepartures", false] call ARC_fnc_stateGet;
if (!(_holdDepartures isEqualType true) && !(_holdDepartures isEqualType false)) then { _holdDepartures = false; };

private _runwayState = missionNamespace getVariable ["airbase_v1_runwayState", "OPEN"];
if (!(_runwayState isEqualType "")) then { _runwayState = "OPEN"; };
_runwayState = toUpper _runwayState;

private _available = (_attackReady > 0) && { !_holdDepartures } && { _runwayState isEqualTo "OPEN" };
private _reason = "CAS_READY";
if (_attackTotal <= 0) then { _available = false; _reason = "NO_ATTACK_AIRCRAFT"; };
if (_attackReady <= 0 && { _attackTotal > 0 }) then { _available = false; _reason = "ATTACK_AIRCRAFT_NOT_READY"; };
if (_holdDepartures) then { _available = false; _reason = "AIRBASE_HOLD_DEPARTURES"; };
if (!(_runwayState isEqualTo "OPEN")) then { _available = false; _reason = format ["RUNWAY_%1", _runwayState]; };

[
    ["available", _available],
    ["reason", _reason],
    ["attackReady", _attackReady],
    ["attackTotal", _attackTotal],
    ["attackQueued", _attackQueued],
    ["attackActive", _attackActive],
    ["runwayState", _runwayState],
    ["holdDepartures", _holdDepartures],
    ["assets", _assetRows],
    ["updatedAt", _now]
]

/*
    ARC_fnc_civsubTrafficBuildVehiclePool

    Returns validated civilian vehicle classnames usable for CIVTRAF.

    Reads:
      - civsub_v1_traffic_vehiclePool_prefer (array of classnames)
      - civsub_v1_traffic_vehiclePool_fallback (array of classnames)

    Validation:
      - isClass in CfgVehicles
      - scope >= 2 (spawnable / placeable)
      - car-like (isKindOf "Car" OR simulation "car"/"carx")

    Side effects (server-side cache):
      - civsub_v1_traffic_vehiclePool_valid_prefer
      - civsub_v1_traffic_vehiclePool_valid_fallback
      - civsub_v1_traffic_vehiclePool_valid
      - civsub_v1_traffic_vehiclePool_valid_key

    Returns: array of strings (combined prefer + fallback, unique)
*/

private _prefer = missionNamespace getVariable ["civsub_v1_traffic_vehiclePool_prefer", []];
private _fallback = missionNamespace getVariable ["civsub_v1_traffic_vehiclePool_fallback", []];

if (!(_prefer isEqualType [])) then { _prefer = []; };
if (!(_fallback isEqualType [])) then { _fallback = []; };

private _dbg = missionNamespace getVariable ["civsub_v1_traffic_debug", false];
if (!(_dbg isEqualType true)) then { _dbg = false; };

private _key = format ["P:%1|F:%2", str _prefer, str _fallback];

private _isOk = {
    params ["_cls"];

    if !(_cls isEqualType "") exitWith {false};
    if (_cls isEqualTo "") exitWith {false};

    private _cfg = configFile >> "CfgVehicles" >> _cls;
    if !(isClass _cfg) exitWith {false};

    // Must be placeable/spawnable.
    private _scope = getNumber (_cfg >> "scope");
    if (_scope < 2) exitWith {false};

    // Car-like filter (avoid boats/air/props).
    if (_cls isKindOf "Car") exitWith {true};

    private _sim = toLower (getText (_cfg >> "simulation"));
    (_sim in ["car", "carx"])
};

private _preferOut = [];
{
    if ([_x] call _isOk) then { _preferOut pushBackUnique _x; };
} forEach _prefer;

private _fallbackOut = [];
{
    if ([_x] call _isOk) then { _fallbackOut pushBackUnique _x; };
} forEach _fallback;

private _out = _preferOut + (_fallbackOut select { !(_x in _preferOut) });

// Cache for spawn selection
missionNamespace setVariable ["civsub_v1_traffic_vehiclePool_valid_prefer", _preferOut, true];
missionNamespace setVariable ["civsub_v1_traffic_vehiclePool_valid_fallback", _fallbackOut, true];
missionNamespace setVariable ["civsub_v1_traffic_vehiclePool_valid", _out, true];
missionNamespace setVariable ["civsub_v1_traffic_vehiclePool_valid_key", _key, false];

if (_dbg) then
{
    diag_log format ["[CIVTRAF][POOL] prefer=%1 fallback=%2 combined=%3", count _preferOut, count _fallbackOut, count _out];
};

_out

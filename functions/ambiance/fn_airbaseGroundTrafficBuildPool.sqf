/*
    ARC_fnc_airbaseGroundTrafficBuildPool

    Validates and caches the airbase ground vehicle whitelist.
    Accepts any land vehicle (LandVehicle, scope >= 2); excludes air and maritime.

    Called by: ARC_fnc_airbaseGroundTrafficInit
    Reads (mission namespace keys set by initServer.sqf):
        airbase_v1_gnd_pool_<category>  — array of classnames per category

    Writes (server-side caches):
        airbase_v1_gnd_pool_valid_<category>  — validated classnames per category
        airbase_v1_gnd_pool_valid_all         — all valid classnames combined

    Returns: ARRAY of all valid classnames (combined)
*/

if (!isServer) exitWith { [] };

private _categories = [
    "airfield_logistics",
    "admin",
    "medical",
    "transport",
    "support",
    "tka"
];

private _isLandVehicle = {
    params ["_cls"];

    if (!(_cls isEqualType "")) exitWith { false };
    if (_cls isEqualTo "") exitWith { false };

    private _cfg = configFile >> "CfgVehicles" >> _cls;
    if !(isClass _cfg) exitWith { false };

    private _scope = getNumber (_cfg >> "scope");
    if (_scope < 2) exitWith { false };

    // Must be a land vehicle (covers Car, Truck, Motorcycle, Quadbike, Forklift etc.)
    if (_cls isKindOf "LandVehicle") exitWith { true };

    // Fallback: check simulation type for edge cases not caught by inheritance
    private _sim = toLower (getText (_cfg >> "simulation"));
    (_sim in ["car", "carx", "truck", "truckx"])
};

private _allValid = [];

{
    private _cat = _x;
    private _key = format ["airbase_v1_gnd_pool_%1", _cat];
    private _raw = missionNamespace getVariable [_key, []];
    if (!(_raw isEqualType [])) then { _raw = []; };

    private _validated = [];
    {
        if ([_x] call _isLandVehicle) then { _validated pushBackUnique _x; };
    } forEach _raw;

    private _cacheKey = format ["airbase_v1_gnd_pool_valid_%1", _cat];
    missionNamespace setVariable [_cacheKey, _validated, false];
    _allValid = _allValid + (_validated select { !(_x in _allValid) });

    diag_log format ["[ARC][ABTRAF][POOL] category=%1 raw=%2 valid=%3", _cat, count _raw, count _validated];
} forEach _categories;

missionNamespace setVariable ["airbase_v1_gnd_pool_valid_all", _allValid, false];

diag_log format ["[ARC][ABTRAF][POOL] total valid classnames=%1", count _allValid];

_allValid

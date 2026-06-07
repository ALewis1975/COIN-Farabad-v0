/*
    ARC_fnc_baseServicesSnapshot

    Builds derived MAYOR/S1/S4/MED readiness and modifiers for sustainment,
    medical, and command decisions.
*/

if (!isServer) exitWith {[]};

private _fuel = ["baseFuel", 0.38] call ARC_fnc_stateGet;
private _ammo = ["baseAmmo", 0.32] call ARC_fnc_stateGet;
private _med = ["baseMed", 0.40] call ARC_fnc_stateGet;
private _baseCas = ["baseCasualties", 0] call ARC_fnc_stateGet;
if (!(_fuel isEqualType 0)) then { _fuel = 0.38; };
if (!(_ammo isEqualType 0)) then { _ammo = 0.32; };
if (!(_med isEqualType 0)) then { _med = 0.40; };
if (!(_baseCas isEqualType 0)) then { _baseCas = 0; };
_fuel = (_fuel max 0) min 1;
_ammo = (_ammo max 0) min 1;
_med = (_med max 0) min 1;
_baseCas = _baseCas max 0;

private _s1 = (1 - (_baseCas * 0.06)) max 0.25;
private _s4 = ((_fuel + _ammo) / 2) max 0;
private _medSvc = ((_med * 0.85) + (_s1 * 0.15)) max 0;
private _mayor = ((_s1 + _s4 + _medSvc) / 3) max 0;

private _statusOf = {
    params ["_v"];
    if (_v < 0.30) exitWith {"CRITICAL"};
    if (_v < 0.55) exitWith {"DEGRADED"};
    "READY"
};

private _drainMult = 1 + ((1 - _s4) * 0.35) + ((1 - _s1) * 0.20);
_drainMult = (_drainMult max 1) min 1.75;

private _medicalEffective = _med * (0.75 + (_medSvc * 0.25));
_medicalEffective = (_medicalEffective max 0) min 1;

private _commandRisk = 1 - _mayor;
_commandRisk = (_commandRisk max 0) min 1;

private _services = [
    ["MAYOR", "COMMAND", _mayor, [_mayor] call _statusOf],
    ["S1", "MANPOWER", _s1, [_s1] call _statusOf],
    ["S4", "SUPPLY", _s4, [_s4] call _statusOf],
    ["MED", "MEDICAL", _medSvc, [_medSvc] call _statusOf]
];

private _issues = [];
{
    if ((_x param [3, "READY"]) in ["DEGRADED", "CRITICAL"]) then
    {
        _issues pushBack format ["%1 %2", _x param [0, ""], _x param [3, ""]];
    };
} forEach _services;
if ((count _issues) == 0) then { _issues pushBack "Base services nominal"; };

[
    ["v", 1],
    ["updatedAt", serverTime],
    ["services", _services],
    ["sustainmentDrainMult", _drainMult],
    ["medicalEffective", _medicalEffective],
    ["commandRisk", _commandRisk],
    ["manpowerReadiness", _s1],
    ["s4Readiness", _s4],
    ["medicalReadiness", _medSvc],
    ["mayorReadiness", _mayor],
    ["issues", _issues]
]

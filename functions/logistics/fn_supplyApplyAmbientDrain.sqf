/*
    ARC_fnc_supplyApplyAmbientDrain
    Applies existing ambient sustainment drain and records it in SUPPLYLEDGER v1.
*/

if (!isServer) exitWith { false };

// Idle gate: pause ambient sustainment decay (FUEL/AMMO/MED — includes medical
// decay) while no interfaced players are connected. Advance the drain clock so
// the empty-server interval never accrues retroactive drain on resume.
if ([] call ARC_fnc_idleGateActive) exitWith {
    ["sustainLastAt", serverTime] call ARC_fnc_stateSet;
    ["supply_v1_last_ambient_tick", serverTime] call ARC_fnc_stateSet;
    false
};

private _now = serverTime;
private _last = ["sustainLastAt", -1] call ARC_fnc_stateGet;
if (!(_last isEqualType 0) || { _last < 0 }) exitWith
{
    ["sustainLastAt", _now] call ARC_fnc_stateSet;
    ["supply_v1_last_ambient_tick", _now] call ARC_fnc_stateSet;
    false
};

private _dt = (_now - _last) max 0;
if (_dt < 30) exitWith { false };

private _before = [] call ARC_fnc_supplyGetStockSnapshot;
private _hours = _dt / 3600;
private _fuel = ["baseFuel", 0.38] call ARC_fnc_stateGet;
private _ammo = ["baseAmmo", 0.32] call ARC_fnc_stateGet;
private _med = ["baseMed", 0.40] call ARC_fnc_stateGet;
if (!(_fuel isEqualType 0)) then { _fuel = 0.38; };
if (!(_ammo isEqualType 0)) then { _ammo = 0.32; };
if (!(_med isEqualType 0)) then { _med = 0.40; };

private _nBlu = count (allPlayers select { alive _x && { side group _x in [west, independent] } });
if (_nBlu < 1) then { _nBlu = 1; };
private _perPlayer = missionNamespace getVariable ["ARC_sustainPlayerScale", 0.06];
if (!(_perPlayer isEqualType 0)) then { _perPlayer = 0.06; };
_perPlayer = (_perPlayer max 0) min 0.25;
private _scale = 1 + ((_nBlu - 1) * _perPlayer);
_scale = (_scale max 1) min 3;

private _hasActive = !((["activeTaskId", ""] call ARC_fnc_stateGet) isEqualTo "");
private _accepted = ["activeIncidentAccepted", false] call ARC_fnc_stateGet;
if (_hasActive && { _accepted isEqualType true && { _accepted } }) then
{
    private _m = missionNamespace getVariable ["ARC_sustainActiveIncidentMult", 1.35];
    if (!(_m isEqualType 0)) then { _m = 1.35; };
    _m = (_m max 1) min 3;
    _scale = _scale * _m;
};

private _pairGet = {
    params ["_pairs", "_key", "_def"];
    private _out = _def;
    { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _out = _x select 1; }; } forEach _pairs;
    _out
};
private _baseServices = if (!isNil "ARC_fnc_baseServicesSnapshot") then { [] call ARC_fnc_baseServicesSnapshot } else { ["baseServices_v1_snapshot", []] call ARC_fnc_stateGet };
if (!(_baseServices isEqualType [])) then { _baseServices = []; };
private _serviceDrainMult = [_baseServices, "sustainmentDrainMult", 1] call _pairGet;
if (!(_serviceDrainMult isEqualType 0)) then { _serviceDrainMult = 1; };
_serviceDrainMult = (_serviceDrainMult max 1) min 1.75;
_scale = _scale * _serviceDrainMult;

private _rFuel = missionNamespace getVariable ["ARC_sustainFuelPerHour", 0.07];
private _rAmmo = missionNamespace getVariable ["ARC_sustainAmmoPerHour", 0.05];
private _rMed = missionNamespace getVariable ["ARC_sustainMedPerHour", 0.04];
if (!(_rFuel isEqualType 0)) then { _rFuel = 0.07; };
if (!(_rAmmo isEqualType 0)) then { _rAmmo = 0.05; };
if (!(_rMed isEqualType 0)) then { _rMed = 0.04; };
_rFuel = (_rFuel max 0) min 0.30;
_rAmmo = (_rAmmo max 0) min 0.30;
_rMed = (_rMed max 0) min 0.30;

private _dFuel = _rFuel * _hours * _scale;
private _dAmmo = _rAmmo * _hours * _scale;
private _dMed = _rMed * _hours * _scale;
_fuel = (_fuel - _dFuel) max 0;
_ammo = (_ammo - _dAmmo) max 0;
_med = (_med - _dMed) max 0;

["baseFuel", _fuel] call ARC_fnc_stateSet;
["baseAmmo", _ammo] call ARC_fnc_stateSet;
["baseMed", _med] call ARC_fnc_stateSet;
["sustainLastAt", _now] call ARC_fnc_stateSet;
["supply_v1_last_ambient_tick", _now] call ARC_fnc_stateSet;

private _after = [] call ARC_fnc_supplyGetStockSnapshot;
["supply_v1_stock", _after] call ARC_fnc_stateSet;
["SUPPLY_AMBIENT_DRAIN", [["FUEL", -_dFuel], ["AMMO", -_dAmmo], ["MED", -_dMed]], _before, _after, "SERVER", ["activeTaskId", ""] call ARC_fnc_stateGet, [["dt", _dt], ["scale", _scale], ["baseServices", _baseServices]]] call ARC_fnc_supplyLedgerAppend;
true

/*
    ARC_fnc_supplyApplyLaunchCost
    Applies existing incident launch-cost math through SUPPLYLEDGER v1.
*/

if (!isServer) exitWith { [] };

params [["_caller", objNull]];

private _before = [] call ARC_fnc_supplyGetStockSnapshot;
private _type = ["activeIncidentType", ""] call ARC_fnc_stateGet;
if (!(_type isEqualType "")) then { _type = ""; };
private _typeU = toUpper _type;

private _fuel = ["baseFuel", 0.38] call ARC_fnc_stateGet;
private _ammo = ["baseAmmo", 0.32] call ARC_fnc_stateGet;
private _med = ["baseMed", 0.40] call ARC_fnc_stateGet;
if (!(_fuel isEqualType 0)) then { _fuel = 0.38; };
if (!(_ammo isEqualType 0)) then { _ammo = 0.32; };
if (!(_med isEqualType 0)) then { _med = 0.40; };

private _nBlu = count (allPlayers select { alive _x && { side group _x in [west, independent] } });
if (_nBlu < 1) then { _nBlu = 1; };
private _scale = 1 + (((_nBlu - 1) max 0) * 0.05);
_scale = _scale min 2.5;

private _cFuel = 0.010;
private _cAmmo = 0.008;
private _cMed = 0.004;

switch (_typeU) do
{
    case "LOGISTICS": { _cFuel = 0.012; _cAmmo = 0.004; _cMed = 0.003; };
    case "ESCORT": { _cFuel = 0.013; _cAmmo = 0.005; _cMed = 0.003; };
    case "PATROL": { _cFuel = 0.010; _cAmmo = 0.006; _cMed = 0.003; };
    case "RECON": { _cFuel = 0.009; _cAmmo = 0.004; _cMed = 0.002; };
    case "CHECKPOINT": { _cFuel = 0.008; _cAmmo = 0.006; _cMed = 0.003; };
    case "CIVIL": { _cFuel = 0.009; _cAmmo = 0.003; _cMed = 0.003; };
    case "IED": { _cFuel = 0.011; _cAmmo = 0.010; _cMed = 0.004; };
    case "RAID": { _cFuel = 0.012; _cAmmo = 0.012; _cMed = 0.005; };
    case "DEFEND": { _cFuel = 0.010; _cAmmo = 0.014; _cMed = 0.006; };
    case "QRF": { _cFuel = 0.013; _cAmmo = 0.012; _cMed = 0.006; };
    case "CMDNODE_RAID": { _cFuel = 0.012; _cAmmo = 0.012; _cMed = 0.005; };
    case "CMDNODE_MEET": { _cFuel = 0.010; _cAmmo = 0.005; _cMed = 0.004; };
    case "CMDNODE_INTERCEPT": { _cFuel = 0.013; _cAmmo = 0.010; _cMed = 0.005; };
    default {};
};

_cFuel = _cFuel * _scale;
_cAmmo = _cAmmo * _scale;
_cMed = _cMed * _scale;

private _fuelNew = (_fuel - _cFuel) max 0;
private _ammoNew = (_ammo - _cAmmo) max 0;
private _medNew = (_med - _cMed) max 0;

["baseFuel", _fuelNew] call ARC_fnc_stateSet;
["baseAmmo", _ammoNew] call ARC_fnc_stateSet;
["baseMed", _medNew] call ARC_fnc_stateSet;

private _after = [] call ARC_fnc_supplyGetStockSnapshot;
["supply_v1_stock", _after] call ARC_fnc_stateSet;

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
private _actor = if (isNull _caller) then { "TOC" } else { name _caller };
private _delta = [["FUEL", -_cFuel], ["AMMO", -_cAmmo], ["MED", -_cMed]];
["SUPPLY_LAUNCH_COST", _delta, _before, _after, _actor, _taskId, [["incident_type", _typeU], ["player_scale", _scale]]] call ARC_fnc_supplyLedgerAppend;

[_cFuel, _cAmmo, _cMed, _fuelNew, _ammoNew, _medNew]

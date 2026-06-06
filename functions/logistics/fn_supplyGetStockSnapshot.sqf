/*
    ARC_fnc_supplyGetStockSnapshot
    Server/client-safe read model for abstract SUPPLYLEDGER v1 stock.
*/

private _clamp01 = compile "params ['_v','_d']; if (!(_v isEqualType 0)) then { _v = _d; }; (_v max 0) min 1";

private _fuel = [["baseFuel", 0.68] call ARC_fnc_stateGet, 0.68] call _clamp01;
private _ammo = [["baseAmmo", 0.61] call ARC_fnc_stateGet, 0.61] call _clamp01;
private _med = [["baseMed", 0.57] call ARC_fnc_stateGet, 0.57] call _clamp01;

private _equipment = 0.70;
private _stock = ["supply_v1_stock", []] call ARC_fnc_stateGet;
if (_stock isEqualType []) then
{
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "EQUIPMENT" }) exitWith
        {
            private _v = _x select 1;
            if (_v isEqualType 0) then { _equipment = (_v max 0) min 1; };
        };
    } forEach _stock;
};

[
    ["FUEL", _fuel],
    ["AMMO", _ammo],
    ["MED", _med],
    ["EQUIPMENT", _equipment]
]

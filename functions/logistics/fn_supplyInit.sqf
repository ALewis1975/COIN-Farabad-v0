/*
    ARC_fnc_supplyInit
    Initialize abstract SUPPLYLEDGER v1 stock from legacy baseFuel/baseAmmo/baseMed.
*/

if (!isServer) exitWith { false };

private _snapshot = [] call ARC_fnc_supplyGetStockSnapshot;
["supply_v1_stock", _snapshot] call ARC_fnc_stateSet;

private _ledger = ["supply_v1_ledger", []] call ARC_fnc_stateGet;
if (!(_ledger isEqualType []) || { (count _ledger) == 0 }) then
{
    ["SUPPLY_INIT", [], [], _snapshot, "SERVER", ["activeTaskId", ""] call ARC_fnc_stateGet, []] call ARC_fnc_supplyLedgerAppend;
};

true

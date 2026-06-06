/* Returns compact SUPPLYLEDGER debug state. */
private _ledger = ["supply_v1_ledger", []] call ARC_fnc_stateGet;
if (!(_ledger isEqualType [])) then { _ledger = []; };
[
    ["enabled", ["supply_v1_enabled", true] call ARC_fnc_stateGet],
    ["version", ["supply_v1_version", 1] call ARC_fnc_stateGet],
    ["seq", ["supply_v1_seq", 0] call ARC_fnc_stateGet],
    ["stock", [] call ARC_fnc_supplyGetStockSnapshot],
    ["ledgerCount", count _ledger],
    ["lastLedgerEvent", ["supply_v1_debug_last_event", []] call ARC_fnc_stateGet],
    ["lastAmbientTick", ["supply_v1_last_ambient_tick", -1] call ARC_fnc_stateGet]
]

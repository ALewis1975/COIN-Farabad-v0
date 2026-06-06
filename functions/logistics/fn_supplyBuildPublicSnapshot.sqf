/* Build compact public logistics snapshot for UI/JIP consumers. */
private _ledger = ["supply_v1_ledger", []] call ARC_fnc_stateGet;
if (!(_ledger isEqualType [])) then { _ledger = []; };
private _last = if ((count _ledger) > 0) then { _ledger select ((count _ledger) - 1) } else { [] };
[
    ["stock", [] call ARC_fnc_supplyGetStockSnapshot],
    ["lastLedgerEvent", _last],
    ["activeStartdispId", ["activeIncidentStartdispId", ""] call ARC_fnc_stateGet],
    ["activeStartdispSummary", ["activeIncidentStartdispSummary", []] call ARC_fnc_stateGet],
    ["activeSupplyAnnex", ["activeIncidentSitrepSupplyAnnex", []] call ARC_fnc_stateGet],
    ["activeReadinessDelta", ["activeIncidentSitrepReadinessDelta", []] call ARC_fnc_stateGet],
    ["activeMettTcAssessment", ["activeIncidentMettTcAssessment", []] call ARC_fnc_stateGet]
]

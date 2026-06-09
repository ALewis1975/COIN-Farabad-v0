/* Build compact public logistics snapshot for UI/JIP consumers. */
private _ledger = ["supply_v1_ledger", []] call ARC_fnc_stateGet;
if (!(_ledger isEqualType [])) then { _ledger = []; };
private _last = if ((count _ledger) > 0) then { _ledger select ((count _ledger) - 1) } else { [] };

if (isNil "ARC_fnc_sustainmentReadinessSnapshot") then
{
    ARC_fnc_sustainmentReadinessSnapshot = compile preprocessFileLineNumbers "functions\\logistics\\fn_sustainmentReadinessSnapshot.sqf";
};
private _sustainmentReadiness = [];
if (!isNil "ARC_fnc_sustainmentReadinessSnapshot") then
{
    private _res = [] call ARC_fnc_sustainmentReadinessSnapshot;
    if (_res isEqualType []) then { _sustainmentReadiness = _res; };
};

[
    ["stock", [] call ARC_fnc_supplyGetStockSnapshot],
    ["lastLedgerEvent", _last],
    ["baseServices", if (!isNil "ARC_fnc_baseServicesSnapshot") then { [] call ARC_fnc_baseServicesSnapshot } else { ["baseServices_v1_snapshot", []] call ARC_fnc_stateGet }],
    ["activeStartdispId", ["activeIncidentStartdispId", ""] call ARC_fnc_stateGet],
    ["activeStartdispSummary", ["activeIncidentStartdispSummary", []] call ARC_fnc_stateGet],
    ["activeSupplyAnnex", ["activeIncidentSitrepSupplyAnnex", []] call ARC_fnc_stateGet],
    ["activeReadinessDelta", ["activeIncidentSitrepReadinessDelta", []] call ARC_fnc_stateGet],
    ["activeMettTcAssessment", ["activeIncidentMettTcAssessment", []] call ARC_fnc_stateGet],
    ["sustainmentReadiness", _sustainmentReadiness]
]

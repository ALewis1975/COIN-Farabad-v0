/* Build lightweight METT-TC/readiness assessment from supply annex + readiness delta. */
params [["_annex", [], [[]]], ["_delta", [], [[]]]];
private _get = {
    params ["_pairs", "_key", "_def"];
    private _out = _def;
    { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _out = _x select 1; }; } forEach _pairs;
    _out
};
private _endLace = [_annex, "ending_lace", []] call _get;
private _cas = [_annex, "casualties", []] call _get;
private _overall = toUpper ([_endLace, "overall", "GREEN"] call _get);
private _ammo = toUpper ([_endLace, "ammo", "GREEN"] call _get);
private _casState = toUpper ([_endLace, "casualties", "GREEN"] call _get);
private _equip = toUpper ([_endLace, "equipment", "GREEN"] call _get);
private _casevac = [_cas, "casevac_required", false] call _get;
private _refit = [_annex, "refit_recommended", false] call _get;
private _resupply = [_annex, "resupply_recommended", false] call _get;

private _bias = "PROCEED";
private _issues = [];
if (_casevac) then { _bias = "MEDICAL EVACUATION REQUIRED"; _issues pushBack "CASEVAC required"; };
if (_overall isEqualTo "RED" || { _casState isEqualTo "RED" }) then { if (!_casevac) then { _bias = "RTB"; }; _issues pushBack "Readiness RED"; };
if (_refit || { _equip isEqualTo "RED" }) then { if (!_casevac) then { _bias = "REFIT REQUIRED"; }; _issues pushBack "Refit required"; };
if (_resupply || { _ammo in ["AMBER", "RED"] }) then { if (_bias isEqualTo "PROCEED") then { _bias = "LOGISTICS ISSUE RECOMMENDED"; }; _issues pushBack "Supply pressure"; };
if (_overall isEqualTo "AMBER" && { _bias isEqualTo "PROCEED" }) then { _bias = "HOLD"; _issues pushBack "Readiness AMBER"; };
if ((count _issues) == 0) then { _issues pushBack "No major supply limitation reported"; };

[
    ["v", 1],
    ["task_id", [_annex, "task_id", ""] call _get],
    ["assessed_ts", serverTime],
    ["readiness", _overall],
    ["supply_pressure", if (_resupply || { _ammo in ["AMBER", "RED"] }) then { "ELEVATED" } else { "NORMAL" }],
    ["recommended_follow_on_bias", _bias],
    ["issues", _issues],
    ["base_stock", [] call ARC_fnc_supplyGetStockSnapshot],
    ["readiness_delta", _delta]
]

/*
    ARC_fnc_sustainmentReadinessSnapshot

    Server-owned Sustainment / S4 read model for S3 follow-on decisions.

    Builds a compact snapshot from existing supply, medical, SITREP supply annex,
    readiness delta, METT-TC assessment, and active-task state. This function is
    read-only: it does not mutate tasking, logistics, medical, or public state.

    Returns: ARRAY of [key, value] pairs
*/

if (!isServer) exitWith {[]};

private _get = {
    params ["_pairs", "_key", "_def"];
    if (!(_pairs isEqualType [])) exitWith { _def };
    private _out = _def;
    { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _out = _x select 1; }; } forEach _pairs;
    _out
};

private _clamp01 = {
    params [["_v", 0.5, [0]], ["_def", 0.5, [0]]];
    if (!(_v isEqualType 0)) then { _v = _def; };
    (_v max 0) min 1
};

private _stateScore = {
    params [["_state", "GREEN", [""]]];
    private _s = toUpper _state;
    switch (_s) do
    {
        case "RED": { 2 };
        case "AMBER": { 1 };
        default { 0 };
    }
};

private _stateFromStock = {
    params [["_v", 1, [0]]];
    if (_v < 0.30) exitWith { "RED" };
    if (_v < 0.55) exitWith { "AMBER" };
    "GREEN"
};

private _worseState = {
    params ["_states"];
    private _worst = "GREEN";
    private _worstScore = 0;
    {
        private _score = [_x] call _stateScore;
        if (_score > _worstScore) then
        {
            _worst = toUpper _x;
            _worstScore = _score;
        };
    } forEach _states;
    _worst
};

private _stock = [];
if (!isNil "ARC_fnc_supplyGetStockSnapshot") then { _stock = [] call ARC_fnc_supplyGetStockSnapshot; };
if (!(_stock isEqualType [])) then { _stock = []; };

private _fuel = [[_stock, "FUEL", ["baseFuel", 0.68] call ARC_fnc_stateGet] call _get, 0.68] call _clamp01;
private _ammoStock = [[_stock, "AMMO", ["baseAmmo", 0.61] call ARC_fnc_stateGet] call _get, 0.61] call _clamp01;
private _medStock = [[_stock, "MED", ["baseMed", 0.57] call ARC_fnc_stateGet] call _get, 0.57] call _clamp01;
private _equipmentStock = [[_stock, "EQUIPMENT", 0.70] call _get, 0.70] call _clamp01;

private _medical = [];
if (!isNil "ARC_fnc_medicalSnapshot") then { _medical = [] call ARC_fnc_medicalSnapshot; };
if (!(_medical isEqualType [])) then { _medical = []; };

private _baseMedEffective = [[_medical, "base_med_effective", _medStock] call _get, _medStock] call _clamp01;
private _civCas = [_medical, "civ_casualties", 0] call _get;
private _baseCas = [_medical, "base_casualties", 0] call _get;
if (!(_civCas isEqualType 0)) then { _civCas = 0; };
if (!(_baseCas isEqualType 0)) then { _baseCas = 0; };

private _baseServices = [];
if (!isNil "ARC_fnc_baseServicesSnapshot") then { _baseServices = [] call ARC_fnc_baseServicesSnapshot; } else { _baseServices = ["baseServices_v1_snapshot", []] call ARC_fnc_stateGet; };
if (!(_baseServices isEqualType [])) then { _baseServices = []; };

private _activeTaskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (!(_activeTaskId isEqualType "")) then { _activeTaskId = ""; };
private _activeIncidentType = ["activeIncidentType", ""] call ARC_fnc_stateGet;
if (!(_activeIncidentType isEqualType "")) then { _activeIncidentType = ""; };
private _activeDisplay = ["activeIncidentDisplayName", ""] call ARC_fnc_stateGet;
if (!(_activeDisplay isEqualType "")) then { _activeDisplay = ""; };
private _activePos = ["activeIncidentPos", []] call ARC_fnc_stateGet;
if (!(_activePos isEqualType [])) then { _activePos = []; };

private _supplyAnnex = ["activeIncidentSitrepSupplyAnnex", []] call ARC_fnc_stateGet;
if (!(_supplyAnnex isEqualType [])) then { _supplyAnnex = []; };
if (_supplyAnnex isEqualTo []) then
{
    _supplyAnnex = missionNamespace getVariable ["ARC_activeIncidentSitrepSupplyAnnex", []];
    if (!(_supplyAnnex isEqualType [])) then { _supplyAnnex = []; };
};

private _readinessDelta = ["activeIncidentSitrepReadinessDelta", []] call ARC_fnc_stateGet;
if (!(_readinessDelta isEqualType [])) then { _readinessDelta = []; };
if (_readinessDelta isEqualTo []) then
{
    _readinessDelta = missionNamespace getVariable ["ARC_activeIncidentSitrepReadinessDelta", []];
    if (!(_readinessDelta isEqualType [])) then { _readinessDelta = []; };
};

private _mettTc = ["activeIncidentMettTcAssessment", []] call ARC_fnc_stateGet;
if (!(_mettTc isEqualType [])) then { _mettTc = []; };
if (_mettTc isEqualTo []) then
{
    _mettTc = missionNamespace getVariable ["ARC_activeIncidentMettTcAssessment", []];
    if (!(_mettTc isEqualType [])) then { _mettTc = []; };
};

private _endingLace = [_supplyAnnex, "ending_lace", []] call _get;
if (!(_endingLace isEqualType [])) then { _endingLace = []; };
private _casualties = [_supplyAnnex, "casualties", []] call _get;
if (!(_casualties isEqualType [])) then { _casualties = []; };

private _liquidsState = [_endingLace, "liquids", [_fuel] call _stateFromStock] call _get;
private _ammoState = [_endingLace, "ammo", [_ammoStock] call _stateFromStock] call _get;
private _equipmentState = [_endingLace, "equipment", [_equipmentStock] call _stateFromStock] call _get;

if (!(_liquidsState isEqualType "")) then { _liquidsState = [_fuel] call _stateFromStock; };
if (!(_ammoState isEqualType "")) then { _ammoState = [_ammoStock] call _stateFromStock; };
if (!(_equipmentState isEqualType "")) then { _equipmentState = [_equipmentStock] call _stateFromStock; };
_liquidsState = toUpper _liquidsState;
_ammoState = toUpper _ammoState;
_equipmentState = toUpper _equipmentState;

private _kia = [_readinessDelta, "kia", [_casualties, "kia", 0] call _get] call _get;
private _wia = [_readinessDelta, "wia", [_casualties, "wia", 0] call _get] call _get;
private _casevac = [_readinessDelta, "casevac_required", [_casualties, "casevac_required", false] call _get] call _get;
if (!(_kia isEqualType 0)) then { _kia = 0; };
if (!(_wia isEqualType 0)) then { _wia = 0; };
if (!(_casevac isEqualType true) && !(_casevac isEqualType false)) then { _casevac = false; };

private _casualtyState = [_endingLace, "casualties", "GREEN"] call _get;
if (!(_casualtyState isEqualType "")) then { _casualtyState = "GREEN"; };
_casualtyState = toUpper _casualtyState;
if (_casevac || { _kia > 0 }) then { _casualtyState = "RED"; } else { if (_wia > 0) then { _casualtyState = "AMBER"; }; };

private _overallState = [_endingLace, "overall", ""] call _get;
if (!(_overallState isEqualType "")) then { _overallState = ""; };
_overallState = toUpper _overallState;
if (_overallState isEqualTo "") then
{
    _overallState = [_liquidsState, _ammoState, _casualtyState, _equipmentState] call _worseState;
};

private _resupplyRecommended = [_supplyAnnex, "resupply_recommended", [_readinessDelta, "resupply_recommended", false] call _get] call _get;
private _refitRecommended = [_supplyAnnex, "refit_recommended", [_readinessDelta, "refit_recommended", false] call _get] call _get;
if (!(_resupplyRecommended isEqualType true) && !(_resupplyRecommended isEqualType false)) then { _resupplyRecommended = false; };
if (!(_refitRecommended isEqualType true) && !(_refitRecommended isEqualType false)) then { _refitRecommended = false; };

private _mettBias = [_mettTc, "recommended_follow_on_bias", ""] call _get;
if (!(_mettBias isEqualType "")) then { _mettBias = ""; };
private _issues = [_mettTc, "issues", []] call _get;
if (!(_issues isEqualType [])) then { _issues = []; };

private _followOnBias = if (!(_mettBias isEqualTo "")) then { _mettBias } else { "PROCEED" };
if (_casevac) then { _followOnBias = "MEDICAL EVACUATION REQUIRED"; };
if ((_overallState isEqualTo "RED") && !_casevac) then { _followOnBias = "RTB"; };
if ((_overallState isEqualTo "AMBER") && { _followOnBias isEqualTo "PROCEED" }) then { _followOnBias = "HOLD"; };
if ((_ammoState in ["AMBER", "RED"] || { _resupplyRecommended }) && { _followOnBias isEqualTo "PROCEED" }) then { _followOnBias = "LOGISTICS ISSUE RECOMMENDED"; };
if ((_equipmentState isEqualTo "RED" || { _refitRecommended }) && { !_casevac }) then { _followOnBias = "REFIT REQUIRED"; };

private _lace = [
    ["liquids", _liquidsState],
    ["ammo", _ammoState],
    ["casualties", _casualtyState],
    ["equipment", _equipmentState],
    ["overall", _overallState]
];

private _mettTcInputs = [
    ["mission", [["task_id", _activeTaskId], ["incident_type", _activeIncidentType], ["display_name", _activeDisplay]]],
    ["enemy", [["insurgent_pressure", ["insurgentPressure", 0.35] call ARC_fnc_stateGet], ["threat_state", ["activeThreatState", "UNKNOWN"] call ARC_fnc_stateGet]]],
    ["terrain", [["position", _activePos], ["grid", if ((count _activePos) >= 2) then { mapGridPosition _activePos } else { "" }]]],
    ["troops", [["lace", _lace], ["base_stock", _stock], ["medical", _medical]]],
    ["time", [["serverTime", serverTime], ["dayTime", dayTime]]],
    ["civilian", [["civ_sentiment", ["civSentiment", 0.55] call ARC_fnc_stateGet], ["gov_legitimacy", ["govLegitimacy", 0.45] call ARC_fnc_stateGet]]]
];

[
    ["schema", "sustainment_readiness_v1"],
    ["version", [1,0,0]],
    ["updatedAt", serverTime],
    ["task_id", _activeTaskId],
    ["incident_type", _activeIncidentType],
    ["readiness", _overallState],
    ["follow_on_bias", _followOnBias],
    ["lace", _lace],
    ["mett_tc_inputs", _mettTcInputs],
    ["supply_pressure", if (_ammoState in ["AMBER", "RED"] || { _liquidsState in ["AMBER", "RED"] } || { _resupplyRecommended }) then { "ELEVATED" } else { "NORMAL" }],
    ["medical_pressure", if (_casevac || { _casualtyState isEqualTo "RED" } || { _baseMedEffective < 0.30 }) then { "CRITICAL" } else { if (_casualtyState isEqualTo "AMBER" || { _baseMedEffective < 0.55 }) then { "ELEVATED" } else { "NORMAL" } }],
    ["mobility_pressure", if (_equipmentState isEqualTo "RED" || { _refitRecommended }) then { "ELEVATED" } else { "NORMAL" }],
    ["casevac_required", _casevac],
    ["resupply_recommended", _resupplyRecommended],
    ["refit_recommended", _refitRecommended],
    ["kia", _kia],
    ["wia", _wia],
    ["base_stock", _stock],
    ["medical", _medical],
    ["base_services", _baseServices],
    ["active_supply_annex", _supplyAnnex],
    ["active_readiness_delta", _readinessDelta],
    ["active_mett_tc_assessment", _mettTc],
    ["issues", _issues],
    ["note", "Sustainment/S4 read model for S3 decision support. UI and S3 consume; server authority remains with TASKENG/SITREP/Logistics/Medical owners."]
]

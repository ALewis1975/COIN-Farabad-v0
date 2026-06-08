/*
    ARC_fnc_vbiedEmitLeads

    VBIED subsystem: emit intel leads based on threat state transition.
    Called from ARC_fnc_threatLeadEmitFromOutcome.

    Params:
      0: ARRAY threatRecord (pairs array)
      1: STRING transition ("STAGED","DISCOVERED","INTERDICTED","DETONATED")

    Returns:
      ARRAY of leadIds emitted (may be empty)
*/

if (!isServer) exitWith {[]};

params [
    ["_rec", [], [[]]],
    ["_transition", "", [""]]
];

if ((count _rec) == 0) exitWith {[]};
if (_transition isEqualTo "") exitWith {[]};

private _kvGet = {
    params ["_pairs", "_key", "_default"];
    if (!(_pairs isEqualType [])) exitWith {_default};
    private _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 2 } && { ((_x select 0) isEqualTo _key) }) exitWith { _idx = _forEachIndex; }; } forEach _pairs;
    if (_idx < 0) exitWith {_default};
    private _v = (_pairs select _idx) select 1;
    if (isNil "_v") exitWith {_default};
    _v
};

private _threatId   = [_rec, "threat_id", ""] call _kvGet;
private _links      = [_rec, "links", []] call _kvGet;
private _area       = [_rec, "area", []] call _kvGet;
private _classification = [_rec, "classification", []] call _kvGet;
private _tele       = [_rec, "telegraphing", []] call _kvGet;
private _districtId = [_links, "district_id", "D00"] call _kvGet;
private _taskId     = [_links, "task_id", ""] call _kvGet;
private _pos        = [_area, "pos", [0,0,0]] call _kvGet;
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = [0,0,0]; };
_pos = +_pos; _pos resize 3;

private _recordQuality = [_tele, "intel_quality", -1] call _kvGet;
if (!(_recordQuality isEqualType 0) || { _recordQuality < 0 }) then { _recordQuality = [_classification, "intel_quality", -1] call _kvGet; };
private _hasQuality = (_recordQuality isEqualType 0) && { _recordQuality >= 0 };
private _qualityMeta = [_tele, "intel_quality_meta", [_classification, "intel_quality_meta", []] call _kvGet] call _kvGet;
if (!(_qualityMeta isEqualType [])) then { _qualityMeta = []; };
private _qualityBand = [_qualityMeta, "quality_band", "UNKNOWN"] call _kvGet;
private _precision = [_qualityMeta, "precision", "UNKNOWN"] call _kvGet;
private _timeliness = [_qualityMeta, "timeliness", "UNKNOWN"] call _kvGet;

private _leadStrength = {
    params [["_base", 0.5, [0]]];
    if (!_hasQuality) exitWith { (_base max 0) min 1 };
    (((_base * 0.55) + (_recordQuality * 0.45)) max 0) min 1
};

private _leadMeta = {
    params [["_kind", "", [""]]];
    [
        ["source_threat_id", _threatId],
        ["district_id", _districtId],
        ["lead_kind", _kind],
        ["intel_quality", if (_hasQuality) then { _recordQuality } else { -1 }],
        ["intel_quality_meta", _qualityMeta],
        ["quality_coupling", "DISTRICT_TRUST_INTIMIDATION_STABILITY_V1"],
        ["quality_band", _qualityBand],
        ["precision", _precision],
        ["timeliness", _timeliness]
    ]
};

private _transU = toUpper _transition;
private _emittedLeads = [];
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

switch (_transU) do
{
    case "STAGED":
    {
        private _watchStrength = [0.7] call _leadStrength;
        private _wId = [
            "IED",
            format ["VBIED Watch — %1", _districtId],
            _pos,
            _watchStrength,
            1800,
            _taskId,
            "IED",
            "",
            "vbied_watch",
            ["vbied_watch"] call _leadMeta
        ] call ARC_fnc_leadCreate;

        if (!(_wId isEqualTo "")) then
        {
            _emittedLeads pushBack _wId;
            diag_log format ["[ARC][INFO] ARC_fnc_vbiedEmitLeads: STAGED → vbied_watch lead=%1 threat=%2 intel=%3 band=%4", _wId, _threatId, _watchStrength, _qualityBand];
        };

        private _cpStrength = [0.6] call _leadStrength;
        private _cpId = [
            "IED",
            format ["Checkpoint Advisory — %1", _districtId],
            _pos,
            _cpStrength,
            1800,
            _taskId,
            "IED",
            "",
            "checkpoint_advisory",
            ["checkpoint_advisory"] call _leadMeta
        ] call ARC_fnc_leadCreate;

        if (!(_cpId isEqualTo "")) then
        {
            _emittedLeads pushBack _cpId;
            diag_log format ["[ARC][INFO] ARC_fnc_vbiedEmitLeads: STAGED → checkpoint_advisory lead=%1 threat=%2 intel=%3 band=%4", _cpId, _threatId, _cpStrength, _qualityBand];
        };

        private _standbyExpiry = serverTime + 300;
        missionNamespace setVariable [format ["ARC_checkpointStandby_%1", _districtId], _standbyExpiry, true];
    };

    case "DISCOVERED":
    {
        private _origStrength = [0.5] call _leadStrength;
        private _origId = [
            "IED",
            format ["Vehicle Origin — %1", _districtId],
            _pos,
            _origStrength,
            5400,
            _taskId,
            "IED",
            "",
            "vehicle_origin_lead",
            ["vehicle_origin_lead"] call _leadMeta
        ] call ARC_fnc_leadCreate;

        if (!(_origId isEqualTo "")) then
        {
            _emittedLeads pushBack _origId;
            diag_log format ["[ARC][INFO] ARC_fnc_vbiedEmitLeads: DISCOVERED → vehicle_origin_lead lead=%1 threat=%2 intel=%3 band=%4", _origId, _threatId, _origStrength, _qualityBand];
        };

        private _usStrength = [0.4] call _leadStrength;
        private _usId = [
            "IED",
            format ["Urban Support Network — %1", _districtId],
            _pos,
            _usStrength,
            5400,
            _taskId,
            "IED",
            "",
            "urban_support_lead",
            ["urban_support_lead"] call _leadMeta
        ] call ARC_fnc_leadCreate;

        if (!(_usId isEqualTo "")) then
        {
            _emittedLeads pushBack _usId;
            diag_log format ["[ARC][INFO] ARC_fnc_vbiedEmitLeads: DISCOVERED → urban_support_lead lead=%1 threat=%2 intel=%3 band=%4", _usId, _threatId, _usStrength, _qualityBand];
        };
    };

    case "NEUTRALIZED";
    case "INTERDICTED":
    {
        private _fnStrength = [0.6] call _leadStrength;
        private _fnId = [
            "IED",
            format ["VBIED Cell Facilitator — %1", _districtId],
            _pos,
            _fnStrength,
            7200,
            _taskId,
            "IED",
            "",
            "facilitator_node_lead",
            ["facilitator_node_lead"] call _leadMeta
        ] call ARC_fnc_leadCreate;

        if (!(_fnId isEqualTo "")) then
        {
            _emittedLeads pushBack _fnId;
            diag_log format ["[ARC][INFO] ARC_fnc_vbiedEmitLeads: INTERDICTED → facilitator_node_lead lead=%1 threat=%2 intel=%3 band=%4", _fnId, _threatId, _fnStrength, _qualityBand];
        };

        private _attrStrength = [0.5] call _leadStrength;
        private _attrId = [
            "IED",
            format ["VBIED Cell Attribution — %1", _districtId],
            _pos,
            _attrStrength,
            7200,
            _taskId,
            "IED",
            "",
            "vbied_cell_attribution",
            ["vbied_cell_attribution"] call _leadMeta
        ] call ARC_fnc_leadCreate;

        if (!(_attrId isEqualTo "")) then
        {
            _emittedLeads pushBack _attrId;
            diag_log format ["[ARC][INFO] ARC_fnc_vbiedEmitLeads: INTERDICTED → vbied_cell_attribution lead=%1 threat=%2 intel=%3 band=%4", _attrId, _threatId, _attrStrength, _qualityBand];
        };
    };

    case "DETONATED":
    {
        private _neStrength = [0.8] call _leadStrength;
        private _neId = [
            "IED",
            format ["Network Escalation Risk — %1", _districtId],
            _pos,
            _neStrength,
            7200,
            _taskId,
            "IED",
            "",
            "network_escalation_lead",
            ["network_escalation_lead"] call _leadMeta
        ] call ARC_fnc_leadCreate;

        if (!(_neId isEqualTo "")) then
        {
            _emittedLeads pushBack _neId;
            diag_log format ["[ARC][INFO] ARC_fnc_vbiedEmitLeads: DETONATED → network_escalation_lead lead=%1 threat=%2 intel=%3 band=%4", _neId, _threatId, _neStrength, _qualityBand];
        };

        private _ccStrength = [0.5] call _leadStrength;
        private _ccId = [
            "IED",
            format ["Copycat Risk — %1", _districtId],
            _pos,
            _ccStrength,
            7200,
            _taskId,
            "IED",
            "",
            "copycat_risk_lead",
            ["copycat_risk_lead"] call _leadMeta
        ] call ARC_fnc_leadCreate;

        if (!(_ccId isEqualTo "")) then
        {
            _emittedLeads pushBack _ccId;
            diag_log format ["[ARC][INFO] ARC_fnc_vbiedEmitLeads: DETONATED → copycat_risk_lead lead=%1 threat=%2 intel=%3 band=%4", _ccId, _threatId, _ccStrength, _qualityBand];
        };

        private _vbiedCooldownS = missionNamespace getVariable ["ARC_vbiedDetonationCooldownS", 3600];
        if (!(_vbiedCooldownS isEqualType 0)) then { _vbiedCooldownS = 3600; };

        private _riskMap = ["threat_v0_district_risk", createHashMap] call ARC_fnc_stateGet;
        if (!(_riskMap isEqualType createHashMap)) then { _riskMap = createHashMap; };

        private _dEntry = [_riskMap, _districtId, createHashMap] call _hg;
        if (!(_dEntry isEqualType createHashMap)) then { _dEntry = createHashMap; };

        private _cnt = [_dEntry, "attack_count_30d", 0] call _hg;
        _dEntry set ["attack_count_30d", _cnt + 1];
        _dEntry set ["cooldown_until", serverTime + _vbiedCooldownS];
        _riskMap set [_districtId, _dEntry];
        ["threat_v0_district_risk", _riskMap] call ARC_fnc_stateSet;

        diag_log format ["[ARC][INFO] ARC_fnc_vbiedEmitLeads: DETONATED penalty applied district=%1 cooldown=%2s", _districtId, _vbiedCooldownS];
    };

    default
    {
        diag_log format ["[ARC][WARN] ARC_fnc_vbiedEmitLeads: unhandled transition=%1 threat=%2", _transition, _threatId];
    };
};

_emittedLeads

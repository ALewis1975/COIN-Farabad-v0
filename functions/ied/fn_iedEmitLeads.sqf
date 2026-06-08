/*
    ARC_fnc_iedEmitLeads

    IED subsystem: emit intel leads based on threat state transition.
    Called from ARC_fnc_threatLeadEmitFromOutcome.

    Params:
      0: ARRAY threatRecord (pairs array)
      1: STRING transition ("DISCOVERED","DETONATED","NEUTRALIZED","INTERDICTED")

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

switch (_transU) do
{
    case "DISCOVERED":
    {
        private _warnStrength = [0.6] call _leadStrength;
        private _warnId = [
            "IED",
            format ["IED Warning — %1", _districtId],
            _pos,
            _warnStrength,
            1800,
            _taskId,
            "IED",
            "",
            "ied_warning",
            ["ied_warning"] call _leadMeta
        ] call ARC_fnc_leadCreate;

        if (!(_warnId isEqualTo "")) then
        {
            _emittedLeads pushBack _warnId;
            diag_log format ["[ARC][INFO] ARC_fnc_iedEmitLeads: DISCOVERED → ied_warning lead=%1 threat=%2 intel=%3 band=%4", _warnId, _threatId, _warnStrength, _qualityBand];
        };

        private _traceStrength = [0.3] call _leadStrength;
        private _traceId = [
            "IED",
            format ["Component Trace — %1", _districtId],
            _pos,
            _traceStrength,
            3600,
            _taskId,
            "IED",
            "",
            "component_trace",
            ["component_trace"] call _leadMeta
        ] call ARC_fnc_leadCreate;

        if (!(_traceId isEqualTo "")) then
        {
            _emittedLeads pushBack _traceId;
            diag_log format ["[ARC][INFO] ARC_fnc_iedEmitLeads: DISCOVERED → component_trace lead=%1 threat=%2 intel=%3 band=%4", _traceId, _threatId, _traceStrength, _qualityBand];
        };
    };

    case "DETONATED":
    {
        private _pbStrength = [0.7] call _leadStrength;
        private _pbId = [
            "IED",
            format ["Post-Blast Site — %1", _districtId],
            _pos,
            _pbStrength,
            2700,
            _taskId,
            "IED",
            "",
            "post_blast_followup",
            ["post_blast_followup"] call _leadMeta
        ] call ARC_fnc_leadCreate;

        if (!(_pbId isEqualTo "")) then
        {
            _emittedLeads pushBack _pbId;
            diag_log format ["[ARC][INFO] ARC_fnc_iedEmitLeads: DETONATED → post_blast_followup lead=%1 threat=%2 intel=%3 band=%4", _pbId, _threatId, _pbStrength, _qualityBand];
        };

        private _evidCollected = ["activeIedEvidenceCollected", false] call ARC_fnc_stateGet;
        if (_evidCollected isEqualType true && { _evidCollected }) then
        {
            private _facStrength = [0.5] call _leadStrength;
            private _facId = [
                "IED",
                format ["Facilitator Node — %1", _districtId],
                _pos,
                _facStrength,
                5400,
                _taskId,
                "IED",
                "",
                "facilitator_node_lead",
                ["facilitator_node_lead"] call _leadMeta
            ] call ARC_fnc_leadCreate;

            if (!(_facId isEqualTo "")) then
            {
                _emittedLeads pushBack _facId;
                diag_log format ["[ARC][INFO] ARC_fnc_iedEmitLeads: DETONATED → facilitator_node_lead lead=%1 threat=%2 intel=%3 band=%4", _facId, _threatId, _facStrength, _qualityBand];
            };
        };
    };

    case "NEUTRALIZED";
    case "INTERDICTED":
    {
        private _traceStrength = [0.6] call _leadStrength;
        private _traceId = [
            "IED",
            format ["Component Trace — %1", _districtId],
            _pos,
            _traceStrength,
            5400,
            _taskId,
            "IED",
            "",
            "component_trace",
            ["component_trace"] call _leadMeta
        ] call ARC_fnc_leadCreate;

        if (!(_traceId isEqualTo "")) then
        {
            _emittedLeads pushBack _traceId;
            diag_log format ["[ARC][INFO] ARC_fnc_iedEmitLeads: INTERDICTED → component_trace lead=%1 threat=%2 intel=%3 band=%4", _traceId, _threatId, _traceStrength, _qualityBand];
        };

        private _repStrength = [0.4] call _leadStrength;
        private _repId = [
            "IED",
            format ["Repeat IED Location — %1", _districtId],
            _pos,
            _repStrength,
            7200,
            _taskId,
            "IED",
            "",
            "repeat_location_lead",
            ["repeat_location_lead"] call _leadMeta
        ] call ARC_fnc_leadCreate;

        if (!(_repId isEqualTo "")) then
        {
            _emittedLeads pushBack _repId;
            diag_log format ["[ARC][INFO] ARC_fnc_iedEmitLeads: INTERDICTED → repeat_location_lead lead=%1 threat=%2 intel=%3 band=%4", _repId, _threatId, _repStrength, _qualityBand];
        };
    };

    default
    {
        diag_log format ["[ARC][WARN] ARC_fnc_iedEmitLeads: unhandled transition=%1 threat=%2", _transition, _threatId];
    };
};

_emittedLeads

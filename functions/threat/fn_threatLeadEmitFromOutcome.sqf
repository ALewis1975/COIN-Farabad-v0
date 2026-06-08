/*
    ARC_fnc_threatLeadEmitFromOutcome

    Common lead emission router: dispatches to type-specific emitters based on
    threatRecord type and transition.

    Called from ARC_fnc_threatUpdateState on key tactical transitions.

    Params:
      0: ARRAY threatRecord (pairs array)
      1: STRING transition ("DISCOVERED","STAGED","DETONATED","NEUTRALIZED","INTERDICTED")

    Returns:
      ARRAY of leadIds emitted
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

private _typeU = toUpper ([_rec, "type", ""] call _kvGet);
private _subtypeU = toUpper ([_rec, "subtype", ""] call _kvGet);
private _family = toUpper ([_rec, "family", ""] call _kvGet);
if (_family isEqualTo "") then
{
    _family = [_typeU, _subtypeU] call ARC_fnc_threatInferFamily;
};
private _emittedLeads = switch (_family) do
{
    case "IED": { [_rec, _transition] call ARC_fnc_iedEmitLeads };
    case "VBIED": { [_rec, _transition] call ARC_fnc_vbiedEmitLeads };
    case "SUICIDE":
    {
            private _out = [];
            private _links      = [_rec, "links", []] call _kvGet;
            private _area       = [_rec, "area", []] call _kvGet;
            private _classification = [_rec, "classification", []] call _kvGet;
            private _tele       = [_rec, "telegraphing", []] call _kvGet;
            private _districtId = [_links, "district_id", "D00"] call _kvGet;
            private _taskId     = [_links, "task_id", ""] call _kvGet;
            private _pos        = [_area, "pos", [0,0,0]] call _kvGet;
            if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = [0,0,0]; };
            _pos resize 3;

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

            if (_transU isEqualTo "DETONATED") then
            {
                private _rrStrength = [0.7] call _leadStrength;
                private _rrId = [
                    "IED",
                    format ["Retaliation Risk — %1", _districtId],
                    _pos,
                    _rrStrength,
                    7200,
                    _taskId,
                    "IED",
                    "",
                    "retaliation_risk",
                    ["retaliation_risk"] call _leadMeta
                ] call ARC_fnc_leadCreate;

                if (!(_rrId isEqualTo "")) then
                {
                    _out pushBack _rrId;
                    diag_log format ["[ARC][INFO] ARC_fnc_threatLeadEmitFromOutcome: SUICIDE DETONATED → retaliation_risk lead=%1 intel=%2 band=%3", _rrId, _rrStrength, _qualityBand];
                };

                private _rpStrength = [0.5] call _leadStrength;
                private _rpId = [
                    "IED",
                    format ["Recruitment Pressure — %1", _districtId],
                    _pos,
                    _rpStrength,
                    7200,
                    _taskId,
                    "IED",
                    "",
                    "recruitment_pressure",
                    ["recruitment_pressure"] call _leadMeta
                ] call ARC_fnc_leadCreate;

                if (!(_rpId isEqualTo "")) then
                {
                    _out pushBack _rpId;
                    diag_log format ["[ARC][INFO] ARC_fnc_threatLeadEmitFromOutcome: SUICIDE DETONATED → recruitment_pressure lead=%1 intel=%2 band=%3", _rpId, _rpStrength, _qualityBand];
                };
            };

            if (_transU isEqualTo "STAGED") then
            {
                private _staStrength = [0.6] call _leadStrength;
                private _staId = [
                    "IED",
                    format ["Suicide Threat Advisory — %1", _districtId],
                    _pos,
                    _staStrength,
                    1800,
                    _taskId,
                    "IED",
                    "",
                    "sb_threat_advisory",
                    ["sb_threat_advisory"] call _leadMeta
                ] call ARC_fnc_leadCreate;

                if (!(_staId isEqualTo "")) then
                {
                    _out pushBack _staId;
                    diag_log format ["[ARC][INFO] ARC_fnc_threatLeadEmitFromOutcome: SUICIDE STAGED → sb_threat_advisory lead=%1 intel=%2 band=%3", _staId, _staStrength, _qualityBand];
                };
            };
            _out
    };
    case "NON_IED": { [] };
    default
    {
        diag_log format ["[ARC][WARN] ARC_fnc_threatLeadEmitFromOutcome: unknown family=%1 type=%2 subtype=%3 transition=%4", _family, _typeU, _subtypeU, _transition];
        []
    }
};

_emittedLeads

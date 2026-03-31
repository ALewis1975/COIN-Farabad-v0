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
private _districtId = [_links, "district_id", "D00"] call _kvGet;
private _taskId     = [_links, "task_id", ""] call _kvGet;
private _pos        = [_area, "pos", [0,0,0]] call _kvGet;
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = [0,0,0]; };
_pos = +_pos; _pos resize 3;

private _transU = toUpper _transition;
private _emittedLeads = [];
private _now = serverTime;

switch (_transU) do
{
    case "DISCOVERED":
    {
        // IED Warning Lead
        private _warnId = [
            "IED",
            format ["IED Warning — %1", _districtId],
            _pos,
            0.6,
            1800,
            _taskId,
            "IED",
            "",
            "ied_warning"
        ] call ARC_fnc_leadCreate;

        if (!(_warnId isEqualTo "")) then
        {
            _emittedLeads pushBack _warnId;
            diag_log format ["[ARC][INFO] ARC_fnc_iedEmitLeads: DISCOVERED → ied_warning lead=%1 threat=%2", _warnId, _threatId];
        };

        // Low-confidence component trace lead
        private _traceId = [
            "IED",
            format ["Component Trace — %1", _districtId],
            _pos,
            0.3,
            3600,
            _taskId,
            "IED",
            "",
            "component_trace"
        ] call ARC_fnc_leadCreate;

        if (!(_traceId isEqualTo "")) then
        {
            _emittedLeads pushBack _traceId;
            diag_log format ["[ARC][INFO] ARC_fnc_iedEmitLeads: DISCOVERED → component_trace lead=%1 threat=%2", _traceId, _threatId];
        };
    };

    case "DETONATED":
    {
        // Post-blast follow-up lead
        private _pbId = [
            "IED",
            format ["Post-Blast Site — %1", _districtId],
            _pos,
            0.7,
            2700,
            _taskId,
            "IED",
            "",
            "post_blast_followup"
        ] call ARC_fnc_leadCreate;

        if (!(_pbId isEqualTo "")) then
        {
            _emittedLeads pushBack _pbId;
            diag_log format ["[ARC][INFO] ARC_fnc_iedEmitLeads: DETONATED → post_blast_followup lead=%1 threat=%2", _pbId, _threatId];
        };

        // Facilitator node lead (only when evidence was collected)
        private _evidCollected = ["activeIedEvidenceCollected", false] call ARC_fnc_stateGet;
        if (_evidCollected isEqualType true && { _evidCollected }) then
        {
            private _facId = [
                "IED",
                format ["Facilitator Node — %1", _districtId],
                _pos,
                0.5,
                5400,
                _taskId,
                "IED",
                "",
                "facilitator_node_lead"
            ] call ARC_fnc_leadCreate;

            if (!(_facId isEqualTo "")) then
            {
                _emittedLeads pushBack _facId;
                diag_log format ["[ARC][INFO] ARC_fnc_iedEmitLeads: DETONATED → facilitator_node_lead lead=%1 threat=%2", _facId, _threatId];
            };
        };
    };

    case "NEUTRALIZED";
    case "INTERDICTED":
    {
        // Component trace lead
        private _traceId = [
            "IED",
            format ["Component Trace — %1", _districtId],
            _pos,
            0.6,
            5400,
            _taskId,
            "IED",
            "",
            "component_trace"
        ] call ARC_fnc_leadCreate;

        if (!(_traceId isEqualTo "")) then
        {
            _emittedLeads pushBack _traceId;
            diag_log format ["[ARC][INFO] ARC_fnc_iedEmitLeads: INTERDICTED → component_trace lead=%1 threat=%2", _traceId, _threatId];
        };

        // Repeat location lead
        private _repId = [
            "IED",
            format ["Repeat IED Location — %1", _districtId],
            _pos,
            0.4,
            7200,
            _taskId,
            "IED",
            "",
            "repeat_location_lead"
        ] call ARC_fnc_leadCreate;

        if (!(_repId isEqualTo "")) then
        {
            _emittedLeads pushBack _repId;
            diag_log format ["[ARC][INFO] ARC_fnc_iedEmitLeads: INTERDICTED → repeat_location_lead lead=%1 threat=%2", _repId, _threatId];
        };
    };

    default
    {
        diag_log format ["[ARC][WARN] ARC_fnc_iedEmitLeads: unhandled transition=%1 threat=%2", _transition, _threatId];
    };
};

_emittedLeads

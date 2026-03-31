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
private _districtId = [_links, "district_id", "D00"] call _kvGet;
private _taskId     = [_links, "task_id", ""] call _kvGet;
private _pos        = [_area, "pos", [0,0,0]] call _kvGet;
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = [0,0,0]; };
_pos = +_pos; _pos resize 3;

private _transU = toUpper _transition;
private _emittedLeads = [];
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

switch (_transU) do
{
    case "STAGED":
    {
        // VBIED Watch Lead
        private _wId = [
            "IED",
            format ["VBIED Watch — %1", _districtId],
            _pos,
            0.7,
            1800,
            _taskId,
            "IED",
            "",
            "vbied_watch"
        ] call ARC_fnc_leadCreate;

        if (!(_wId isEqualTo "")) then
        {
            _emittedLeads pushBack _wId;
            diag_log format ["[ARC][INFO] ARC_fnc_vbiedEmitLeads: STAGED → vbied_watch lead=%1 threat=%2", _wId, _threatId];
        };

        // Checkpoint Advisory lead
        private _cpId = [
            "IED",
            format ["Checkpoint Advisory — %1", _districtId],
            _pos,
            0.6,
            1800,
            _taskId,
            "IED",
            "",
            "checkpoint_advisory"
        ] call ARC_fnc_leadCreate;

        if (!(_cpId isEqualTo "")) then
        {
            _emittedLeads pushBack _cpId;
            diag_log format ["[ARC][INFO] ARC_fnc_vbiedEmitLeads: STAGED → checkpoint_advisory lead=%1 threat=%2", _cpId, _threatId];
        };

        // Set checkpoint standby flag for district (auto-cleared after 5 min)
        missionNamespace setVariable [format ["ARC_checkpointStandby_%1", _districtId], true, true];
        private _flagVar = format ["ARC_checkpointStandby_%1", _districtId];
        [_flagVar] spawn {
            params ["_v"];
            sleep 300;
            missionNamespace setVariable [_v, false, true];
        };
    };

    case "DISCOVERED":
    {
        // Vehicle Origin Lead
        private _origId = [
            "IED",
            format ["Vehicle Origin — %1", _districtId],
            _pos,
            0.5,
            5400,
            _taskId,
            "IED",
            "",
            "vehicle_origin_lead"
        ] call ARC_fnc_leadCreate;

        if (!(_origId isEqualTo "")) then
        {
            _emittedLeads pushBack _origId;
            diag_log format ["[ARC][INFO] ARC_fnc_vbiedEmitLeads: DISCOVERED → vehicle_origin_lead lead=%1 threat=%2", _origId, _threatId];
        };

        // Urban Support Lead
        private _usId = [
            "IED",
            format ["Urban Support Network — %1", _districtId],
            _pos,
            0.4,
            5400,
            _taskId,
            "IED",
            "",
            "urban_support_lead"
        ] call ARC_fnc_leadCreate;

        if (!(_usId isEqualTo "")) then
        {
            _emittedLeads pushBack _usId;
            diag_log format ["[ARC][INFO] ARC_fnc_vbiedEmitLeads: DISCOVERED → urban_support_lead lead=%1 threat=%2", _usId, _threatId];
        };
    };

    case "NEUTRALIZED";
    case "INTERDICTED":
    {
        // Facilitator Node Lead
        private _fnId = [
            "IED",
            format ["VBIED Cell Facilitator — %1", _districtId],
            _pos,
            0.6,
            7200,
            _taskId,
            "IED",
            "",
            "facilitator_node_lead"
        ] call ARC_fnc_leadCreate;

        if (!(_fnId isEqualTo "")) then
        {
            _emittedLeads pushBack _fnId;
            diag_log format ["[ARC][INFO] ARC_fnc_vbiedEmitLeads: INTERDICTED → facilitator_node_lead lead=%1 threat=%2", _fnId, _threatId];
        };

        // VBIED cell attribution lead
        private _attrId = [
            "IED",
            format ["VBIED Cell Attribution — %1", _districtId],
            _pos,
            0.5,
            7200,
            _taskId,
            "IED",
            "",
            "vbied_cell_attribution"
        ] call ARC_fnc_leadCreate;

        if (!(_attrId isEqualTo "")) then
        {
            _emittedLeads pushBack _attrId;
            diag_log format ["[ARC][INFO] ARC_fnc_vbiedEmitLeads: INTERDICTED → vbied_cell_attribution lead=%1 threat=%2", _attrId, _threatId];
        };
    };

    case "DETONATED":
    {
        // Network escalation lead
        private _neId = [
            "IED",
            format ["Network Escalation Risk — %1", _districtId],
            _pos,
            0.8,
            7200,
            _taskId,
            "IED",
            "",
            "network_escalation_lead"
        ] call ARC_fnc_leadCreate;

        if (!(_neId isEqualTo "")) then
        {
            _emittedLeads pushBack _neId;
            diag_log format ["[ARC][INFO] ARC_fnc_vbiedEmitLeads: DETONATED → network_escalation_lead lead=%1 threat=%2", _neId, _threatId];
        };

        // Copycat risk lead
        private _ccId = [
            "IED",
            format ["Copycat Risk — %1", _districtId],
            _pos,
            0.5,
            7200,
            _taskId,
            "IED",
            "",
            "copycat_risk_lead"
        ] call ARC_fnc_leadCreate;

        if (!(_ccId isEqualTo "")) then
        {
            _emittedLeads pushBack _ccId;
            diag_log format ["[ARC][INFO] ARC_fnc_vbiedEmitLeads: DETONATED → copycat_risk_lead lead=%1 threat=%2", _ccId, _threatId];
        };

        // Apply district detonation penalty
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

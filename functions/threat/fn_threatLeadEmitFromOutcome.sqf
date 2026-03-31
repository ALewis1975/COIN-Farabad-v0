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
private _emittedLeads = [];

if (_typeU isEqualTo "IED") then
{
    _emittedLeads = [_rec, _transition] call ARC_fnc_iedEmitLeads;
}
else
{
    if (_typeU isEqualTo "VBIED") then
    {
        _emittedLeads = [_rec, _transition] call ARC_fnc_vbiedEmitLeads;
    }
    else
    {
        if (_typeU isEqualTo "SUICIDE") then
        {
            // SUICIDE lead dispatch (inline emitter per Task 020 spec)
            private _links      = [_rec, "links", []] call _kvGet;
            private _area       = [_rec, "area", []] call _kvGet;
            private _districtId = [_links, "district_id", "D00"] call _kvGet;
            private _taskId     = [_links, "task_id", ""] call _kvGet;
            private _pos        = [_area, "pos", [0,0,0]] call _kvGet;
            if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = [0,0,0]; };
            _pos resize 3;

            private _transU = toUpper _transition;

            if (_transU isEqualTo "DETONATED") then
            {
                // Retaliation risk lead
                private _rrId = [
                    "IED",
                    format ["Retaliation Risk — %1", _districtId],
                    _pos,
                    0.7,
                    7200,
                    _taskId,
                    "IED",
                    "",
                    "retaliation_risk"
                ] call ARC_fnc_leadCreate;

                if (!(_rrId isEqualTo "")) then
                {
                    _emittedLeads pushBack _rrId;
                    diag_log format ["[ARC][INFO] ARC_fnc_threatLeadEmitFromOutcome: SUICIDE DETONATED → retaliation_risk lead=%1", _rrId];
                };

                // Recruitment pressure lead
                private _rpId = [
                    "IED",
                    format ["Recruitment Pressure — %1", _districtId],
                    _pos,
                    0.5,
                    7200,
                    _taskId,
                    "IED",
                    "",
                    "recruitment_pressure"
                ] call ARC_fnc_leadCreate;

                if (!(_rpId isEqualTo "")) then
                {
                    _emittedLeads pushBack _rpId;
                    diag_log format ["[ARC][INFO] ARC_fnc_threatLeadEmitFromOutcome: SUICIDE DETONATED → recruitment_pressure lead=%1", _rpId];
                };
            };

            if (_transU isEqualTo "STAGED") then
            {
                // Suicide Threat Advisory lead
                private _staId = [
                    "IED",
                    format ["Suicide Threat Advisory — %1", _districtId],
                    _pos,
                    0.6,
                    1800,
                    _taskId,
                    "IED",
                    "",
                    "sb_threat_advisory"
                ] call ARC_fnc_leadCreate;

                if (!(_staId isEqualTo "")) then
                {
                    _emittedLeads pushBack _staId;
                    diag_log format ["[ARC][INFO] ARC_fnc_threatLeadEmitFromOutcome: SUICIDE STAGED → sb_threat_advisory lead=%1", _staId];
                };
            };
        }
        else
        {
            diag_log format ["[ARC][WARN] ARC_fnc_threatLeadEmitFromOutcome: unknown type=%1 transition=%2", _typeU, _transition];
        };
    };
};

_emittedLeads

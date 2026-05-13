/*
    Threat v0: create (if needed) a ThreatRecord linked to a consumed/promoted lead.

    Params:
        0: ARRAY lead entry [id, incidentType, displayName, pos, strength, createdAt, expiresAt, sourceTaskId, sourceIncidentType, threadId, tag]
           or STRING lead id (looked up in leadPool/lastLeadConsumed)
        1: ARRAY ctxPairs (optional) overrides/additions

    Returns:
        STRING threat_id ("" on failure)

    Notes:
        - Idempotent by lead_id.
        - Writes only on server.
*/

if (!isServer) exitWith {""};

params [
    ["_leadInput", [], [[], ""]],
    ["_ctx", [], [[]]]
];

private _trimFn = compile "params ['_s']; trim _s";

private _kvGet = {
    params ["_pairs", "_key", "_default"];
    if (!(_pairs isEqualType [])) exitWith {_default};
    private _idx = -1;
    {
        if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith
        {
            _idx = _forEachIndex;
        };
    } forEach _pairs;
    if (_idx < 0) exitWith {_default};
    private _entry = _pairs select _idx;
    private _v = _entry select 1;
    if (isNil "_v") exitWith {_default};
    _v
};

private _kvSet = {
    params ["_pairs", "_key", "_value"];
    if (!(_pairs isEqualType [])) then { _pairs = []; };
    private _idx = -1;
    {
        if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith
        {
            _idx = _forEachIndex;
        };
    } forEach _pairs;
    if (_idx < 0) then { _pairs pushBack [_key, _value]; } else { _pairs set [_idx, [_key, _value]]; };
    _pairs
};

private _lead = [];

if (_leadInput isEqualType []) then
{
    _lead = +_leadInput;
}
else
{
    if (_leadInput isEqualType "") then
    {
        private _leadIdWanted = [_leadInput] call _trimFn;
        if (_leadIdWanted isEqualTo "") exitWith {};

        // These are existing core lead-system state keys, not new threat_v0 keys.
        private _last = ["lastLeadConsumed", []] call ARC_fnc_stateGet;
        if (_last isEqualType [] && { (count _last) >= 1 } && { (_last select 0) isEqualTo _leadIdWanted }) then
        {
            _lead = +_last;
        };

        if (_lead isEqualTo []) then
        {
            private _pool = ["leadPool", []] call ARC_fnc_stateGet;
            if (!(_pool isEqualType [])) then { _pool = []; };
            {
                if ((_x isEqualType []) && { (count _x) >= 1 } && { (_x select 0) isEqualTo _leadIdWanted }) exitWith
                {
                    _lead = +_x;
                };
            } forEach _pool;
        };
    };
};

if (!(_lead isEqualType []) || { (count _lead) < 4 }) exitWith {""};

private _leadId = _lead param [0, "", [""]];
_leadId = [_leadId] call _trimFn;
if (_leadId isEqualTo "") exitWith {""};

private _leadType = _lead param [1, "OTHER", [""]];
private _displayName = _lead param [2, "", [""]];
private _pos = _lead param [3, [0,0,0], [[]]];
private _strength = _lead param [4, 0.5];
private _createdAt = _lead param [5, -1];
private _expiresAt = _lead param [6, -1];
private _sourceTaskId = _lead param [7, "", [""]];
private _sourceIncidentType = _lead param [8, "", [""]];
private _threadId = _lead param [9, "", [""]];
private _tag = _lead param [10, "", [""]];

if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = [0,0,0]; };
_pos = +_pos;
_pos resize 3;

private _leadTypeU = toUpper ([_leadType] call _trimFn);
private _type = "OTHER";
private _subtype = "OTHER";

if (_leadTypeU isEqualTo "IED") then
{
    _type = "IED";
    _subtype = "IED_SUSPICIOUS_OBJECT";
};
if (_leadTypeU isEqualTo "VBIED") then
{
    _type = "IED";
    _subtype = "VBIED";
};
if (_leadTypeU in ["SUICIDE", "SUICIDE_BOMBER", "SB"]) then
{
    _type = "IED";
    _subtype = "SUICIDE";
};
if (!(_tag isEqualTo "")) then
{
    private _tagU = toUpper ([_tag] call _trimFn);
    if (_tagU find "VBIED" >= 0) then
    {
        _type = "IED";
        _subtype = "VBIED";
    };
    if (_tagU find "SUICIDE" >= 0 || { _tagU find "SB_" >= 0 }) then
    {
        _type = "IED";
        _subtype = "SUICIDE";
    };
};

private _radiusM = [_ctx, "radius_m", 150] call _kvGet;
if (!(_radiusM isEqualType 0) || { _radiusM <= 0 }) then { _radiusM = 150; };

_ctx = [_ctx, "lead_id", _leadId] call _kvSet;
_ctx = [_ctx, "pos", _pos] call _kvSet;
_ctx = [_ctx, "radius_m", _radiusM] call _kvSet;
_ctx = [_ctx, "lead_display_name", _displayName] call _kvSet;
_ctx = [_ctx, "lead_type", _leadTypeU] call _kvSet;
_ctx = [_ctx, "lead_strength", _strength] call _kvSet;
_ctx = [_ctx, "lead_created_at", _createdAt] call _kvSet;
_ctx = [_ctx, "lead_expires_at", _expiresAt] call _kvSet;
_ctx = [_ctx, "source_incident_type", _sourceIncidentType] call _kvSet;
_ctx = [_ctx, "thread_id", _threadId] call _kvSet;
_ctx = [_ctx, "tag", _tag] call _kvSet;

private _threatId = [_sourceTaskId, _type, _subtype, _ctx] call ARC_fnc_threatCreateFromTask;
if (_threatId isEqualTo "") exitWith
{
    diag_log format ["[ARC][WARN] ARC_fnc_threatCreateFromLead: failed lead-to-threat conversion lead_id=%1 lead_type=%2 source_task_id=%3", _leadId, _leadTypeU, _sourceTaskId];
    ""
};

private _threatFamily = [_type, _subtype] call ARC_fnc_threatInferFamily;

[
    "THREAT_CREATED_FROM_LEAD",
    _threatId,
    [
        ["lead_id", _leadId],
        ["family", _threatFamily],
        ["lead_type", _leadTypeU],
        ["display_name", _displayName],
        ["source_task_id", _sourceTaskId],
        ["source_incident_type", _sourceIncidentType],
        ["thread_id", _threadId],
        ["tag", _tag]
    ],
    [["producer", "ARC_fnc_threatCreateFromLead"]]
] call ARC_fnc_threatEmitEvent;

_threatId

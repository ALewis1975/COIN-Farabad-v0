/*
    Threat v0: create (if needed) a ThreatRecord linked to a task.

    Params:
        0: STRING task_id (required)
        1: STRING type (optional, default "IED")
        2: STRING subtype (optional, default "IED_SUSPICIOUS_OBJECT")
        3: ARRAY  ctxPairs (optional) [["pos",...], ["radius_m",...], ["marker",...], ...]

    Returns:
        STRING threat_id ("" on failure)

    Notes:
        - Idempotent by task_id (returns existing threat_id if found).
        - Writes only on server.
*/

if (!isServer) exitWith {""};

params [
    ["_taskId", ""],
    ["_type", "IED"],
    ["_subtype", "IED_SUSPICIOUS_OBJECT"],
    ["_ctx", []]
];

if (_taskId isEqualTo "") exitWith {""};

private _enabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {""};

private _typeU = toUpper _type;
private _subtypeU = toUpper _subtype;

// Small helpers for "pairs arrays"
private _kvGet = {
    params ["_pairs", "_key", "_default"];
    if (!(_pairs isEqualType [])) exitWith {_default};
    private _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x # 0) isEqualTo _key }) exitWith { _idx = _forEachIndex; }; } forEach _pairs;
    if (_idx < 0) exitWith {_default};
    private _v = (_pairs # _idx) # 1;
    if (isNil "_v") exitWith {_default};
    _v
};

private _kvSet = {
    params ["_pairs", "_key", "_value"];
    if (!(_pairs isEqualType [])) then { _pairs = []; };
    private _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x # 0) isEqualTo _key }) exitWith { _idx = _forEachIndex; }; } forEach _pairs;
    if (_idx < 0) then { _pairs pushBack [_key, _value]; } else { _pairs set [_idx, [_key, _value]]; };
    _pairs
};

// Load records
private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
if (!(_records isEqualType [])) then { _records = []; };

// Idempotent: return existing record for this task_id
private _existingIdx = -1;
{
    private _rec = _x;
    private _links = [_rec, "links", []] call _kvGet;
    if (([_links, "task_id", ""] call _kvGet) isEqualTo _taskId) exitWith { _existingIdx = _forEachIndex; };
} forEach _records;

if (_existingIdx >= 0) then
{
    private _rec = _records # _existingIdx;
    private _tid = [_rec, "threat_id", ""] call _kvGet;
    _tid
}
else
{
    // Campaign + seq
    private _campaignId = ["threat_v0_campaign_id", ""] call ARC_fnc_stateGet;
    if (!(_campaignId isEqualType "") || { _campaignId isEqualTo "" }) then
    {
        _campaignId = if (!isNil "BIS_fnc_guid") then { call BIS_fnc_guid } else { format ["CID-%1-%2", diag_tickTime, floor (random 1e6)] };
        ["threat_v0_campaign_id", _campaignId] call ARC_fnc_stateSet;
    };

    private _seq = ["threat_v0_seq", 0] call ARC_fnc_stateGet;
    if (!(_seq isEqualType 0) || { _seq < 0 }) then { _seq = 0; };
    _seq = _seq + 1;
    ["threat_v0_seq", _seq] call ARC_fnc_stateSet;

    private _s = str _seq;
    private _zeros = "000000";
    private _need = (6 - (count _s)) max 0;
    private _seq6 = (_zeros select [0, _need]) + _s;

    // Context -> area/links
    private _pos = [_ctx, "pos", [0,0,0]] call _kvGet;
    if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = [0,0,0]; };
    _pos = +_pos; _pos resize 3;

    private _districtIdSource = [_ctx, "district_id", ""] call _kvGet;
    if !(_districtIdSource isEqualType "") then { _districtIdSource = ""; };
    _districtIdSource = toUpper (trim _districtIdSource);

    private _districtId = _districtIdSource;
    if !([_districtId] call ARC_fnc_worldIsValidDistrictId) then
    {
        private _resolvedDistrictId = [_pos] call ARC_fnc_threadResolveDistrictId;
        if ([_resolvedDistrictId] call ARC_fnc_worldIsValidDistrictId) then
        {
            _districtId = _resolvedDistrictId;
        }
        else
        {
            _districtId = "D00";
        };
    };

    private _threatId = format ["THR:%1:%2", _districtId, _seq6];

    private _radiusM = [_ctx, "radius_m", 0] call _kvGet;
    if (!(_radiusM isEqualType 0) || { _radiusM <= 0 }) then { _radiusM = 0; };

    private _marker = [_ctx, "marker", ""] call _kvGet;
    if (!(_marker isEqualType "")) then { _marker = ""; };

    private _aoId = [_ctx, "ao_id", _taskId] call _kvGet;
    if (!(_aoId isEqualType "")) then { _aoId = _taskId; };

    private _leadId = [_ctx, "lead_id", ""] call _kvGet;
    if (!(_leadId isEqualType "")) then { _leadId = ""; };

    private _incidentId = [_ctx, "incident_id", ""] call _kvGet;
    if (!(_incidentId isEqualType "")) then { _incidentId = ""; };

    private _now = serverTime;

    private _stateTs = [
        ["created", _now],
        ["active", -1],
        ["discovered", -1],
        ["neutralized", -1],
        ["closed", -1],
        ["cleaned", -1],
        ["expired", -1]
    ];

    private _links = [
        ["ao_id", _aoId],
        ["district_id_source", _districtIdSource],
        ["district_id", _districtId],
        ["task_id", _taskId],
        ["lead_id", _leadId],
        ["incident_id", _incidentId]
    ];

    private _area = [
        ["pos", _pos],
        ["grid", mapGridPosition _pos],
        ["radius_m", _radiusM],
        ["marker", _marker]
    ];

    private _world = [
        ["spawned", false],
        ["objects_net_ids", []],
        ["groups_net_ids", []],
        ["units_net_ids", []],
        ["cleanup_label", ""]
    ];

    private _tele = [
        ["intel_level", 0],
        ["cues_enabled", true]
    ];

    private _outcome = [
        ["result", "NONE"],
        ["notes", ""]
    ];

    private _audit = [
        ["created_by", "SYSTEM"],
        ["last_updated_by", "SYSTEM"],
        ["log_refs", []]
    ];

    private _rec = [
        ["v", 0],
        ["threat_id", _threatId],
        ["campaign_id", _campaignId],
        ["rev", 1],
        ["created_ts", _now],
        ["updated_ts", _now],
        ["type", _typeU],
        ["subtype", _subtypeU],
        ["state", "CREATED"],
        ["state_ts", _stateTs],
        ["links", _links],
        ["area", _area],
        ["world", _world],
        ["telegraphing", _tele],
        ["outcome", _outcome],
        ["audit", _audit]
    ];

    _records pushBack _rec;
    ["threat_v0_records", _records] call ARC_fnc_stateSet;

    // Open index
    private _open = ["threat_v0_open_index", []] call ARC_fnc_stateGet;
    if (!(_open isEqualType [])) then { _open = []; };
    _open pushBackUnique _threatId;
    ["threat_v0_open_index", _open] call ARC_fnc_stateSet;

    // OPS log: THREAT_CREATED
    private _meta = [
        ["event", "THREAT_CREATED"],
        ["threat_id", _threatId],
        ["type", _typeU],
        ["subtype", _subtypeU],
        ["state_from", ""],
        ["state_to", "CREATED"],
        ["ao_id", _aoId],
        ["district_id_source", _districtIdSource],
        ["district_id", _districtId],
        ["task_id", _taskId],
        ["lead_id", _leadId],
        ["incident_id", _incidentId],
        ["pos", _pos],
        ["grid", mapGridPosition _pos],
        ["rev", 1],
        ["note", ""]
    ];

    private _intelId = ["OPS", format ["THREAT_CREATED: %1 (%2/%3)", _threatId, _typeU, _subtypeU], _pos, _meta] call ARC_fnc_intelLog;

    missionNamespace setVariable [
        "threat_v0_debug_last_event",
        [
            ["ts", _now],
            ["event", "THREAT_CREATED"],
            ["threat_id", _threatId],
            ["district_id_source", _districtIdSource],
            ["district_id", _districtId]
        ]
    ];

    // Attach log ref (best-effort)
    if (_intelId isNotEqualTo "") then
    {
        private _a = [_rec, "audit", []] call _kvGet;
        private _refs = [_a, "log_refs", []] call _kvGet;
        if (!(_refs isEqualType [])) then { _refs = []; };
        _refs pushBack _intelId;
        _a = [_a, "log_refs", _refs] call _kvSet;
        _rec = [_rec, "audit", _a] call _kvSet;

        // Update record in array
        _records set [(count _records) - 1, _rec];
        ["threat_v0_records", _records] call ARC_fnc_stateSet;
    };

    [] call ARC_fnc_threatDebugSnapshot;

    _threatId
};

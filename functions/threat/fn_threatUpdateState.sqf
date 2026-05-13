/*
    Threat v0: update a ThreatRecord state.

    Params:
        0: STRING threat_id (required)
        1: STRING state_to (required) ["CREATED","ACTIVE","STAGED","DISCOVERED","NEUTRALIZED","DETONATED","INTERDICTED","CLOSED","CLEANED","EXPIRED"]
        2: STRING note (optional)

    Returns:
        BOOL success

    Notes:
        - Server-only single-writer.
        - Guards lifecycle transitions: if state_to == current_state or transition is invalid, no-op and returns false.
        - ACTIVE is the generic spawned manifestation state; STAGED is the family-specific spawned-active
          state used by VBIED/suicide spawn ticks that stage directly from CREATED.
*/

if (!isServer) exitWith {false};

params [
    ["_threatId", ""],
    ["_stateTo", ""],
    ["_note", ""]
];

if (_threatId isEqualTo "") exitWith {false};
if (_stateTo isEqualTo "") exitWith {false};

private _enabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {false};

private _trimFn = compile "params ['_s']; trim _s";
private _normalizeState = {
    params ["_stateRaw"];
    private _stateU = toUpper ([_stateRaw] call _trimFn);
    switch (_stateU) do
    {
        case "PLANNED": { "CREATED" };
        case "FAILED": { "EXPIRED" };
        default { _stateU };
    }
};

private _stateToU = [_stateTo] call _normalizeState;
private _denyReason = "";
private _knownStates = ["threat_v0_state_enum", ["CREATED","ACTIVE","STAGED","DISCOVERED","NEUTRALIZED","DETONATED","INTERDICTED","CLOSED","CLEANED","EXPIRED"]] call ARC_fnc_stateGet;
if (!(_knownStates isEqualType [])) then { _knownStates = ["CREATED","ACTIVE","STAGED","DISCOVERED","NEUTRALIZED","DETONATED","INTERDICTED","CLOSED","CLEANED","EXPIRED"]; };

// Small helpers for "pairs arrays"
private _kvGet = {
    params ["_pairs", "_key", "_default"];
    if (!(_pairs isEqualType [])) exitWith {_default};
    private _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _idx = _forEachIndex; }; } forEach _pairs;
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
    { if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _idx = _forEachIndex; }; } forEach _pairs;
    if (_idx < 0) then { _pairs pushBack [_key, _value]; } else { _pairs set [_idx, [_key, _value]]; };
    _pairs
};

// Load records and find target
private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
if (!(_records isEqualType [])) exitWith {false};

private _idxRec = -1;
{ if (([_x, "threat_id", ""] call _kvGet) isEqualTo _threatId) exitWith { _idxRec = _forEachIndex; }; } forEach _records;
if (_idxRec < 0) exitWith
{
    _denyReason = "DENY_THREAT_NOT_FOUND";
    diag_log format ["[ARC][WARN] ARC_fnc_threatUpdateState: denied transition threat_id=%1 from=%2 to=%3 family=%4 deny_reason=%5 note=%6", _threatId, "", _stateToU, "UNKNOWN", _denyReason, _note];
    false
};

private _rec = _records select _idxRec;
private _type = [_rec, "type", ""] call _kvGet;
private _subtype = [_rec, "subtype", ""] call _kvGet;
private _family = [_rec, "family", ""] call _kvGet;
if (!(_family isEqualType "")) then { _family = ""; };
if (_family isEqualTo "") then
{
    _family = [_type, _subtype] call ARC_fnc_threatInferFamily;
};

private _stateFrom = [_rec, "state", ""] call _kvGet;
private _stateFromU = [_stateFrom] call _normalizeState;

if (_stateFromU isEqualTo "") exitWith
{
    _denyReason = "DENY_STATE_FROM_EMPTY";
    diag_log format ["[ARC][WARN] ARC_fnc_threatUpdateState: denied transition threat_id=%1 from=%2 to=%3 family=%4 deny_reason=%5 note=%6", _threatId, _stateFromU, _stateToU, _family, _denyReason, _note];
    false
};

if (!(_stateToU in _knownStates)) exitWith
{
    _denyReason = "DENY_STATE_TO_UNKNOWN";
    diag_log format ["[ARC][WARN] ARC_fnc_threatUpdateState: denied transition threat_id=%1 from=%2 to=%3 family=%4 deny_reason=%5 note=%6", _threatId, _stateFromU, _stateToU, _family, _denyReason, _note];
    [
        "THREAT_STATE_CHANGE_DENIED",
        _threatId,
        [
            ["event", "THREAT_STATE_CHANGE_DENIED"],
            ["threat_id", _threatId],
            ["family", _family],
            ["type", _type],
            ["subtype", _subtype],
            ["state_from", _stateFromU],
            ["state_to", _stateToU],
            ["deny_reason", _denyReason],
            ["note", _note]
        ],
        [["producer", "ARC_fnc_threatUpdateState"], ["rev", [_rec, "rev", 1] call _kvGet]]
    ] call ARC_fnc_threatEmitEvent;
    false
};

if (_stateFromU isEqualTo _stateToU) exitWith
{
    _denyReason = "DENY_STATE_NOOP";
    diag_log format ["[ARC][INFO] ARC_fnc_threatUpdateState: denied transition threat_id=%1 from=%2 to=%3 family=%4 deny_reason=%5 note=%6", _threatId, _stateFromU, _stateToU, _family, _denyReason, _note];
    false
};

private _allowedNext = switch (_stateFromU) do
{
    case "CREATED": { ["ACTIVE", "STAGED", "CLOSED", "EXPIRED"] };
    case "ACTIVE": { ["DISCOVERED", "NEUTRALIZED", "DETONATED", "INTERDICTED", "CLOSED", "EXPIRED"] };
    case "STAGED": { ["DISCOVERED", "NEUTRALIZED", "DETONATED", "INTERDICTED", "CLOSED", "EXPIRED"] };
    case "DISCOVERED": { ["NEUTRALIZED", "DETONATED", "INTERDICTED", "CLOSED", "EXPIRED"] };
    case "NEUTRALIZED": { ["CLOSED"] };
    case "DETONATED": { ["CLOSED"] };
    case "INTERDICTED": { ["CLOSED"] };
    case "CLOSED": { ["CLEANED"] };
    case "EXPIRED": { ["CLEANED"] };
    case "CLEANED": { [] };
    default { [] };
};

if (!(_stateToU in _allowedNext)) exitWith
{
    _denyReason = "DENY_TRANSITION_INVALID";
    diag_log format ["[ARC][WARN] ARC_fnc_threatUpdateState: denied transition threat_id=%1 from=%2 to=%3 family=%4 deny_reason=%5 note=%6", _threatId, _stateFromU, _stateToU, _family, _denyReason, _note];
    [
        "THREAT_STATE_CHANGE_DENIED",
        _threatId,
        [
            ["event", "THREAT_STATE_CHANGE_DENIED"],
            ["threat_id", _threatId],
            ["family", _family],
            ["type", _type],
            ["subtype", _subtype],
            ["state_from", _stateFromU],
            ["state_to", _stateToU],
            ["deny_reason", _denyReason],
            ["note", _note]
        ],
        [["producer", "ARC_fnc_threatUpdateState"], ["rev", [_rec, "rev", 1] call _kvGet]]
    ] call ARC_fnc_threatEmitEvent;
    false
};

private _now = serverTime;

// Update state + timestamps
private _stateTs = [_rec, "state_ts", []] call _kvGet;
_stateTs = [_stateTs, toLower _stateToU, _now] call _kvSet;

// Backfill implied timestamps for coarse gameplay hooks
if (_stateToU isEqualTo "NEUTRALIZED") then
{
    private _a = [_stateTs, "active", -1] call _kvGet;
    if (_a isEqualType 0 && { _a < 0 }) then { _stateTs = [_stateTs, "active", _now] call _kvSet; };

    private _d = [_stateTs, "discovered", -1] call _kvGet;
    if (_d isEqualType 0 && { _d < 0 }) then { _stateTs = [_stateTs, "discovered", _now] call _kvSet; };
};

_rec = [_rec, "state_ts", _stateTs] call _kvSet;

// World cleanup on CLEANED
if (_stateToU isEqualTo "CLEANED") then
{
    private _world = [_rec, "world", []] call _kvGet;
    _world = [_world, "spawned", false] call _kvSet;
    _world = [_world, "objects_net_ids", []] call _kvSet;
    _world = [_world, "groups_net_ids", []] call _kvSet;
    _world = [_world, "units_net_ids", []] call _kvSet;
    _rec = [_rec, "world", _world] call _kvSet;
};

private _rev = [_rec, "rev", 1] call _kvGet;
if (!(_rev isEqualType 0)) then { _rev = 1; };
_rev = _rev + 1;

_rec = [_rec, "rev", _rev] call _kvSet;
_rec = [_rec, "state", _stateToU] call _kvSet;
_rec = [_rec, "updated_ts", _now] call _kvSet;
_rec = [_rec, "family", _family] call _kvSet;

// Index maintenance (bounded history)
private _open = ["threat_v0_open_index", []] call ARC_fnc_stateGet;
if (!(_open isEqualType [])) then { _open = []; };

private _closed = ["threat_v0_closed_index", []] call ARC_fnc_stateGet;
if (!(_closed isEqualType [])) then { _closed = []; };

private _closedMax = ["threat_v0_closed_max", 200] call ARC_fnc_stateGet;
if (!(_closedMax isEqualType 0) || { _closedMax < 50 }) then { _closedMax = 200; };

if (_stateToU in ["CLOSED", "CLEANED", "EXPIRED"]) then
{
    _open = _open - [_threatId];
    _closed pushBackUnique _threatId;

    while { (count _closed) > _closedMax } do
    {
        _closed deleteAt 0;
    };
}
else
{
    _open pushBackUnique _threatId;
};

["threat_v0_open_index", _open] call ARC_fnc_stateSet;
["threat_v0_closed_index", _closed] call ARC_fnc_stateSet;

// Save record back
_records set [_idxRec, _rec];
["threat_v0_records", _records] call ARC_fnc_stateSet;

// OPS logging (single event)
private _links = [_rec, "links", []] call _kvGet;
private _area = [_rec, "area", []] call _kvGet;
private _world = [_rec, "world", []] call _kvGet;

private _pos = [_area, "pos", [0,0,0]] call _kvGet;
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = [0,0,0]; };
_pos = +_pos; _pos resize 3;

private _event = "THREAT_STATE_CHANGED";
if (_stateToU isEqualTo "CLOSED") then { _event = "THREAT_CLOSED"; };
if (_stateToU isEqualTo "CLEANED") then { _event = "THREAT_CLEANED"; };

private _objs = [_world, "objects_net_ids", []] call _kvGet;
if (!(_objs isEqualType [])) then { _objs = []; };

private _meta = [
    ["event", _event],
    ["threat_id", _threatId],
    ["family", _family],
    ["type", _type],
    ["subtype", _subtype],
    ["state_from", _stateFromU],
    ["state_to", _stateToU],
    ["ao_id", [_links, "ao_id", ""] call _kvGet],
    ["district_id", [_links, "district_id", ""] call _kvGet],
    ["task_id", [_links, "task_id", ""] call _kvGet],
    ["lead_id", [_links, "lead_id", ""] call _kvGet],
    ["incident_id", [_links, "incident_id", ""] call _kvGet],
    ["pos", _pos],
    ["grid", mapGridPosition _pos],
    ["rev", _rev],
    ["world_spawned", [_world, "spawned", false] call _kvGet],
    ["world_object_count", count _objs],
    ["deny_reason", ""],
    ["note", _note]
];

private _summary = format ["%1: %2 %3→%4", _event, _threatId, _stateFromU, _stateToU];
private _noteTrimmed = [_note] call _trimFn;
if (!(_noteTrimmed isEqualTo "")) then
{
    _summary = _summary + format [" (%1)", _noteTrimmed];
};

private _intelId = ["OPS", _summary, _pos, _meta] call ARC_fnc_intelLog;

// Attach log ref (best-effort)
if (!(_intelId isEqualTo "")) then
{
    private _audit = [_rec, "audit", []] call _kvGet;
    private _refs = [_audit, "log_refs", []] call _kvGet;
    if (!(_refs isEqualType [])) then { _refs = []; };
    _refs pushBack _intelId;

    _audit = [_audit, "log_refs", _refs] call _kvSet;
    _audit = [_audit, "last_updated_by", "SYSTEM"] call _kvSet;

    _rec = [_rec, "audit", _audit] call _kvSet;

    _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
    if (_records isEqualType [] && { _idxRec < count _records }) then
    {
        _records set [_idxRec, _rec];
        ["threat_v0_records", _records] call ARC_fnc_stateSet;
    };
};

// Debug
missionNamespace setVariable [
    "threat_v0_debug_last_event",
    [
        ["ts", _now],
        ["event", _event],
        ["threat_id", _threatId],
        ["family", _family],
        ["district_id_source", [_links, "district_id_source", ""] call _kvGet],
        ["district_id", [_links, "district_id", ""] call _kvGet],
        ["state_from", _stateFromU],
        ["state_to", _stateToU],
        ["note", _note]
    ]
];

[] call ARC_fnc_threatDebugSnapshot;

[
    _event,
    _threatId,
    _meta,
    [["producer", "ARC_fnc_threatUpdateState"], ["rev", _rev]]
] call ARC_fnc_threatEmitEvent;

// Lead emission router: fire on key tactical transitions
if (_stateToU in ["DISCOVERED", "STAGED", "DETONATED", "NEUTRALIZED", "INTERDICTED"]) then
{
    if (!isNil "ARC_fnc_threatLeadEmitFromOutcome") then
    {
        [_rec, _stateToU] call ARC_fnc_threatLeadEmitFromOutcome;
    };
};

// COIN influence application on terminal outcome transitions
if (_stateToU in ["DETONATED", "NEUTRALIZED"]) then
{
    if (!isNil "ARC_fnc_threatApplyCoinInfluence") then
    {
        [_threatId] call ARC_fnc_threatApplyCoinInfluence;
    };
};

true

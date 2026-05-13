/*
    Build a replicated, read-only threat UI snapshot for operator-facing surfaces.

    Notes:
      - Server-only single writer.
      - Reads canonical threat state + public event tail; never mutates threat state.
      - Output is intended for client diary/console consumers and explicit stale/no-data UX.
*/

if (!isServer) exitWith {[]};

private _trimFn = compile "params ['_s']; trim _s";

private _kvGet = {
    params ["_pairs", "_key", "_default"];
    if (!(_pairs isEqualType [])) exitWith { _default };

    private _idx = -1;
    {
        if ((_x isEqualType []) && { (count _x) >= 2 } && { ((_x select 0) isEqualTo _key) }) exitWith {
            _idx = _forEachIndex;
        };
    } forEach _pairs;

    if (_idx < 0) exitWith { _default };

    private _entry = _pairs select _idx;
    private _value = _entry select 1;
    if (isNil "_value") exitWith { _default };
    _value
};

private _stateLabel = {
    params ["_state"];
    private _stateU = toUpper ([_state] call _trimFn);
    switch (_stateU) do
    {
        case "CREATED": { "Created" };
        case "ACTIVE": { "Active" };
        case "STAGED": { "Staged" };
        case "DISCOVERED": { "Discovered" };
        case "NEUTRALIZED": { "Neutralized" };
        case "DETONATED": { "Detonated" };
        case "INTERDICTED": { "Interdicted" };
        case "CLOSED": { "Closed" };
        case "CLEANED": { "Cleaned" };
        case "EXPIRED": { "Expired" };
        default { if (_stateU isEqualTo "") then { "Unknown" } else { _stateU } };
    }
};

private _typeLabel = {
    params ["_type"];
    private _typeU = toUpper ([_type] call _trimFn);
    switch (_typeU) do
    {
        case "IED": { "IED" };
        case "VBIED": { "VBIED" };
        case "SUICIDE": { "Suicide Bomber" };
        case "VIRTUAL_OPFOR": { "Virtual OPFOR" };
        default { if (_typeU isEqualTo "") then { "Other" } else { _typeU } };
    }
};

private _eventBucket = {
    params ["_eventName", "_stateTo"];
    private _eventU = toUpper ([_eventName] call _trimFn);
    private _stateToU = toUpper ([_stateTo] call _trimFn);

    if (_eventU in ["THREAT_CREATED", "THREAT_CREATED_FROM_LEAD"]) exitWith { "CREATE" };
    if (_eventU isEqualTo "THREAT_CLOSED") exitWith { "CLOSE" };
    if (_eventU isEqualTo "THREAT_CLEANED") exitWith { "CLEANUP" };
    if (_stateToU in ["STAGED", "DISCOVERED", "DETONATED", "NEUTRALIZED", "INTERDICTED"]) exitWith { "FOLLOW_ON" };
    "UPDATE"
};

private _eventLabel = {
    params ["_bucket", "_eventName", "_stateFrom", "_stateTo"];

    private _bucketU = toUpper ([_bucket] call _trimFn);
    private _stateFromLabel = [_stateFrom] call _stateLabel;
    private _stateToLabel = [_stateTo] call _stateLabel;

    switch (_bucketU) do
    {
        case "CREATE": {
            if ((toUpper ([_eventName] call _trimFn)) isEqualTo "THREAT_CREATED_FROM_LEAD") exitWith { "Promoted from lead" };
            "Created"
        };
        case "CLOSE": { "Closed" };
        case "CLEANUP": { "Cleaned" };
        case "FOLLOW_ON": { format ["Follow-on cue: %1", _stateToLabel] };
        default {
            if (_stateFromLabel isEqualTo _stateToLabel) exitWith { "Updated" };
            format ["%1 → %2", _stateFromLabel, _stateToLabel]
        };
    }
};

private _buildThreatRow = {
    params ["_rec"];

    private _links = [_rec, "links", []] call _kvGet;
    private _area = [_rec, "area", []] call _kvGet;
    private _world = [_rec, "world", []] call _kvGet;
    private _telegraphing = [_rec, "telegraphing", []] call _kvGet;
    private _outcome = [_rec, "outcome", []] call _kvGet;
    private _worldObjects = [_world, "objects_net_ids", []] call _kvGet;
    if (!(_worldObjects isEqualType [])) then { _worldObjects = []; };

    private _state = [_rec, "state", ""] call _kvGet;
    private _type = [_rec, "type", ""] call _kvGet;

    [
        ["threat_id", [_rec, "threat_id", ""] call _kvGet],
        ["state", _state],
        ["state_label", [_state] call _stateLabel],
        ["type", _type],
        ["type_label", [_type] call _typeLabel],
        ["subtype", [_rec, "subtype", ""] call _kvGet],
        ["district_id", [_links, "district_id", "D00"] call _kvGet],
        ["task_id", [_links, "task_id", ""] call _kvGet],
        ["lead_id", [_links, "lead_id", ""] call _kvGet],
        ["incident_id", [_links, "incident_id", ""] call _kvGet],
        ["grid", [_area, "grid", ""] call _kvGet],
        ["marker", [_area, "marker", ""] call _kvGet],
        ["updated_at", [_rec, "updated_ts", -1] call _kvGet],
        ["created_at", [_rec, "created_ts", -1] call _kvGet],
        ["rev", [_rec, "rev", 0] call _kvGet],
        ["world_spawned", [_world, "spawned", false] call _kvGet],
        ["world_object_count", count _worldObjects],
        ["intel_level", [_telegraphing, "intel_level", 0] call _kvGet],
        ["outcome_result", [_outcome, "result", "NONE"] call _kvGet]
    ]
};

private _buildEventRow = {
    params ["_evt"];

    private _eventName = [_evt, "event", ""] call _kvGet;
    private _stateFrom = [_evt, "state_from", ""] call _kvGet;
    private _stateTo = [_evt, "state_to", ""] call _kvGet;
    private _bucket = [_eventName, _stateTo] call _eventBucket;
    private _threatId = [_evt, "threat_id", ""] call _kvGet;
    private _summary = [_bucket, _eventName, _stateFrom, _stateTo] call _eventLabel;

    if (_threatId isEqualTo "") then {
        _summary = format ["%1", _summary];
    } else {
        _summary = format ["%1 — %2", _summary, _threatId];
    };

    [
        ["seq", [_evt, "seq", -1] call _kvGet],
        ["ts", [_evt, "ts", -1] call _kvGet],
        ["event", _eventName],
        ["bucket", _bucket],
        ["label", [_bucket, _eventName, _stateFrom, _stateTo] call _eventLabel],
        ["summary", _summary],
        ["threat_id", _threatId],
        ["district_id", [_evt, "district_id", "D00"] call _kvGet],
        ["state_from", _stateFrom],
        ["state_to", _stateTo],
        ["rev", [_evt, "rev", 0] call _kvGet]
    ]
};

private _enabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };

private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
if (!(_records isEqualType [])) then { _records = []; };

private _openIds = ["threat_v0_open_index", []] call ARC_fnc_stateGet;
if (!(_openIds isEqualType [])) then { _openIds = []; };

private _closedIds = ["threat_v0_closed_index", []] call ARC_fnc_stateGet;
if (!(_closedIds isEqualType [])) then { _closedIds = []; };

private _events = missionNamespace getVariable ["threat_v0_events_public", []];
if (!(_events isEqualType [])) then { _events = []; };

private _rowsWrapped = [];
{
    private _updatedAt = [_x, "updated_ts", -1] call _kvGet;
    if (!(_updatedAt isEqualType 0)) then { _updatedAt = -1; };
    _rowsWrapped pushBack [0 - _updatedAt, _x];
} forEach _records;
_rowsWrapped sort true;

private _sortedRecords = _rowsWrapped apply { _x select 1 };
private _openRows = [];
private _followOnRows = [];
private _closedRows = [];
private _stateFilters = [];
private _typeFilters = [];
private _districtFilters = [];

{
    private _rec = _x;
    private _row = [_rec] call _buildThreatRow;
    private _threatId = [_row, "threat_id", ""] call _kvGet;
    private _state = [_row, "state", ""] call _kvGet;
    private _type = [_row, "type", ""] call _kvGet;
    private _districtId = [_row, "district_id", "D00"] call _kvGet;

    if (!(_state isEqualTo "")) then { _stateFilters pushBackUnique _state; };
    if (!(_type isEqualTo "")) then { _typeFilters pushBackUnique _type; };
    if (!(_districtId isEqualTo "")) then { _districtFilters pushBackUnique _districtId; };

    if (_threatId in _openIds) then {
        _openRows pushBack _row;
    };
    if (_state in ["STAGED", "DISCOVERED", "DETONATED", "NEUTRALIZED", "INTERDICTED"]) then {
        _followOnRows pushBack _row;
    };
    if (_state in ["CLOSED", "CLEANED", "EXPIRED"]) then {
        _closedRows pushBack _row;
    };
} forEach _sortedRecords;

private _openCap = missionNamespace getVariable ["threat_v0_ui_open_cap", 8];
if (!(_openCap isEqualType 0) || { _openCap < 1 }) then { _openCap = 8; };
if ((count _openRows) > _openCap) then { _openRows resize _openCap; };

private _followOnCap = missionNamespace getVariable ["threat_v0_ui_follow_on_cap", 6];
if (!(_followOnCap isEqualType 0) || { _followOnCap < 1 }) then { _followOnCap = 6; };
if ((count _followOnRows) > _followOnCap) then { _followOnRows resize _followOnCap; };

private _closedCap = missionNamespace getVariable ["threat_v0_ui_closed_cap", 5];
if (!(_closedCap isEqualType 0) || { _closedCap < 1 }) then { _closedCap = 5; };
if ((count _closedRows) > _closedCap) then { _closedRows resize _closedCap; };

private _eventCap = missionNamespace getVariable ["threat_v0_ui_event_cap", 8];
if (!(_eventCap isEqualType 0) || { _eventCap < 1 }) then { _eventCap = 8; };
if ((count _events) > _eventCap) then {
    _events = _events select [(count _events) - _eventCap, _eventCap];
};

private _eventRows = _events apply { [_x] call _buildEventRow };
private _lastEvent = [];
private _lastEventAt = -1;
private _lastEventLabel = "No event";
if ((count _eventRows) > 0) then {
    _lastEvent = _eventRows select ((count _eventRows) - 1);
    _lastEventAt = [_lastEvent, "ts", -1] call _kvGet;
    _lastEventLabel = [_lastEvent, "label", "No event"] call _kvGet;
};

private _emptyTitle = "No active threat data";
private _emptyBody = "Waiting for the next server snapshot. Keep rendering the last known picture and do not infer authoring rights from an empty client view.";
if (!_enabled) then {
    _emptyTitle = "Threat system disabled";
    _emptyBody = "Threat surfacing is read-only and currently offline because threat_v0_enabled is false on the server.";
} else {
    if ((count _records) > 0 && { (count _openIds) == 0 }) then {
        _emptyTitle = "No open threats";
        _emptyBody = "No active threat rows are open. Review the recent event feed and recently closed rows before clearing operator watch.";
    };
};

[
    ["v", 1],
    ["schema", "threat_ui_v1"],
    ["updatedAt", serverTime],
    ["staleAfterS", 30],
    ["summary", [
        ["enabled", _enabled],
        ["open_count", count _openIds],
        ["closed_count", count _closedIds],
        ["follow_on_count", count _followOnRows],
        ["record_count", count _records],
        ["event_count", count _eventRows],
        ["last_event_at", _lastEventAt],
        ["last_event_label", _lastEventLabel]
    ]],
    ["views", [
        ["default", "OPEN"],
        ["available", ["OPEN", "FOLLOW_ON", "RECENTLY_CLOSED", "EVENT_FEED"]],
        ["sort", [["primary", "updated_at"], ["direction", "DESC"]]],
        ["filters", [
            ["states", _stateFilters],
            ["types", _typeFilters],
            ["districts", _districtFilters]
        ]]
    ]],
    ["list", [
        ["open", _openRows],
        ["follow_on", _followOnRows],
        ["recently_closed", _closedRows]
    ]],
    ["events", _eventRows],
    ["emptyState", [
        ["title", _emptyTitle],
        ["body", _emptyBody]
    ]],
    ["errorState", [
        ["title", "Threat snapshot unavailable"],
        ["body", "Clients must keep the last known threat picture, show a stale warning, and never write authoritative threat state directly."]
    ]],
    ["roleBoundaries", [
        ["read_only", ["ARC_THREAT diary", "ARC_pub_threatUiSnapshot", "Console_VM_v1.sections.threat"]],
        ["operator_actions", ["Use existing TOC/S2 lead, intel, and queue tools to request follow-on work."]],
        ["admin_hooks", ["ARC_pub_debug threat fields remain diagnostic-only and do not authorize client writes."]]
    ]]
]

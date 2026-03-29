/*
    Threat v0 hook: incident closure -> close linked threat records (idempotent).

    Expected call site:
        ["INCIDENT_CLOSED", _incidentContextPairs] call ARC_fnc_threatOnIncidentClosed;
*/

if (!isServer) exitWith {false};

params [
    ["_event", ""],
    ["_ctx", []]
];

if (toUpper !(_event isEqualTo "INCIDENT_CLOSED")) exitWith {false};

private _enabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {false};

// Small helpers for "pairs arrays"
private _kvGet = {
    params ["_pairs", "_key", "_default"];
    if (!(_pairs isEqualType [])) exitWith {_default};
    private _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _idx = _forEachIndex; }; } forEach _pairs;
    if (_idx < 0) exitWith {_default};
    private _v = (_pairs select _idx) select 1;
    if (isNil "_v") exitWith {_default};
    _v
};

private _kvSet = {
    params ["_pairs", "_key", "_value"];

// sqflint-compatible helpers
private _trimFn  = compile "params ['_s']; trim _s";
    if (!(_pairs isEqualType [])) then { _pairs = []; };
    private _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _idx = _forEachIndex; }; } forEach _pairs;
    if (_idx < 0) then { _pairs pushBack [_key, _value]; } else { _pairs set [_idx, [_key, _value]]; };
    _pairs
};

private _taskId = [_ctx, "task_id", ""] call _kvGet;
if (_taskId isEqualTo "") exitWith {true};

private _result = [_ctx, "result", ""] call _kvGet;
if (!(_result isEqualType "")) then { _result = ""; };
private _resultU = toUpper _result;

private _reason = [_ctx, "reason", ""] call _kvGet;
if (!(_reason isEqualType "")) then { _reason = ""; };

private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
if (!(_records isEqualType [])) exitWith {true};

// Shared note string for this closure event.
private _noteStr = format ["INCIDENT_CLOSED:%1", _resultU];
if (!(([_reason] call _trimFn) isEqualTo "")) then
{
    _noteStr = _noteStr + format [" (%1)", [_reason] call _trimFn];
};

// Pass 1: patch outcome fields for all threats linked to this task and collect world refs.
private _closeIds = [];
private _worldInfo = []; // each: [threat_id, spawned(bool), objCount(int)]

{
    private _rec = _x;
    private _links = [_rec, "links", []] call _kvGet;
    if (([_links, "task_id", ""] call _kvGet) isEqualTo _taskId) then
    {
        private _tid = [_rec, "threat_id", ""] call _kvGet;
        if (_tid isEqualTo "") then { continue; };

        _closeIds pushBackUnique _tid;

        // Best-effort: record the incident outcome in the threat record.
        private _outcome = [_rec, "outcome", []] call _kvGet;
        _outcome = [_outcome, "result", _resultU] call _kvSet;
        _outcome = [_outcome, "notes", _noteStr] call _kvSet;
        _rec = [_rec, "outcome", _outcome] call _kvSet;

        _records set [_forEachIndex, _rec];

        // Capture world refs decision inputs before state transitions mutate record storage.
        private _world = [_rec, "world", []] call _kvGet;
        private _spawned = [_world, "spawned", false] call _kvGet;
        private _objs = [_world, "objects_net_ids", []] call _kvGet;
        if (!(_objs isEqualType [])) then { _objs = []; };

        _worldInfo pushBack [_tid, _spawned, (count _objs)];
    };
} forEach _records;

if ((count _closeIds) > 0) then
{
    // Persist outcome updates BEFORE calling ARC_fnc_threatUpdateState (which also writes the records array).
    ["threat_v0_records", _records] call ARC_fnc_stateSet;

    // Pass 2: state transitions (idempotent; threatUpdateState guards repeats)
    {
        private _tid = _x;
        [_tid, "CLOSED", _noteStr] call ARC_fnc_threatUpdateState;

        private _wi = -1;
        { if ((_x select 0) isEqualTo _tid) exitWith { _wi = _forEachIndex; }; } forEach _worldInfo;
        if (_wi >= 0) then
        {
            private _spawned = (_worldInfo select _wi) select 1;
            private _objCount = (_worldInfo select _wi) select 2;
            if ((!_spawned) || { _objCount isEqualTo 0 }) then
            {
                [_tid, "CLEANED", "NO_WORLD_REFS"] call ARC_fnc_threatUpdateState;
            };
        };
    } forEach _closeIds;

    [] call ARC_fnc_threatDebugSnapshot;
};

true

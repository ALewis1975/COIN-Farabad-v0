/*
    ARC_fnc_threatIedCleanupSync

    Server: Synchronise cleanup state for an IED threat record.

    Provides deterministic, idempotent cleanup convergence between the threat record,
    world references, and task/incident linkage metadata.  Handles two cases:
      - Normal cleanup path: marks world refs cleared and drives CLEANED state.
      - Stale close path: if threat is already in a terminal state, records a
        CLOSED_STALE evidence event and returns without mutating lifecycle state.

    Params:
        0: STRING threat_id (required)
        1: STRING source    (optional; label for audit, e.g. "INCIDENT_CLOSED", "TIMEOUT")

    Returns:
        BOOL  true = cleanup was applied or already completed; false = denied/not found

    Notes:
        - Server-only single-writer.
        - Idempotent: repeated calls for an already-CLEANED threat are no-ops with evidence.
        - Emits THREAT_CLEANUP_STALE if called on an already-terminal/cleaned record.
        - Writes world.cleanup_completed = true and world.cleanup_ts on completion.
*/

if (!isServer) exitWith {false};

params [
    ["_threatId", ""],
    ["_source", "CLEANUP_SYNC"]
];

if (_threatId isEqualTo "") exitWith {false};

private _enabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {false};

private _trimFn = compile "params ['_s']; trim _s";

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

private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
if (!(_records isEqualType [])) exitWith
{
    diag_log format ["[ARC][WARN] ARC_fnc_threatIedCleanupSync: records unavailable threat_id=%1", _threatId];
    false
};

private _idxRec = -1;
{ if (([_x, "threat_id", ""] call _kvGet) isEqualTo _threatId) exitWith { _idxRec = _forEachIndex; }; } forEach _records;

if (_idxRec < 0) exitWith
{
    diag_log format ["[ARC][WARN] ARC_fnc_threatIedCleanupSync: threat not found threat_id=%1", _threatId];
    false
};

private _rec = _records select _idxRec;
private _stateRaw = [_rec, "state", ""] call _kvGet;
private _stateU = toUpper _stateRaw;
private _type = [_rec, "type", ""] call _kvGet;
private _subtype = [_rec, "subtype", ""] call _kvGet;
private _family = [_rec, "family", ""] call _kvGet;
private _links = [_rec, "links", []] call _kvGet;

private _world = [_rec, "world", []] call _kvGet;
private _cleanupCompleted = [_world, "cleanup_completed", false] call _kvGet;
if (!(_cleanupCompleted isEqualType true) && !(_cleanupCompleted isEqualType false)) then { _cleanupCompleted = false; };

private _area = [_rec, "area", []] call _kvGet;
private _pos = [_area, "pos", [0,0,0]] call _kvGet;
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = [0,0,0]; };
_pos = +_pos; _pos resize 3;

// Already fully cleaned — record stale call as evidence but do not mutate state
if (_stateU isEqualTo "CLEANED" || { _cleanupCompleted }) exitWith
{
    private _srcTrimmed = [_source] call _trimFn;
    diag_log format ["[ARC][INFO] ARC_fnc_threatIedCleanupSync: stale cleanup call threat_id=%1 state=%2 source=%3", _threatId, _stateU, _srcTrimmed];

    [
        "THREAT_CLEANUP_STALE",
        _threatId,
        [
            ["event", "THREAT_CLEANUP_STALE"],
            ["threat_id", _threatId],
            ["family", _family],
            ["type", _type],
            ["subtype", _subtype],
            ["state", _stateU],
            ["source", _srcTrimmed],
            ["cleanup_completed", _cleanupCompleted],
            ["ao_id", [_links, "ao_id", ""] call _kvGet],
            ["task_id", [_links, "task_id", ""] call _kvGet],
            ["incident_id", [_links, "incident_id", ""] call _kvGet],
            ["pos", _pos]
        ],
        [["producer", "ARC_fnc_threatIedCleanupSync"], ["rev", [_rec, "rev", 1] call _kvGet]]
    ] call ARC_fnc_threatEmitEvent;

    true
};

// Not yet cleaned — apply cleanup convergence markers
// Step 1: ensure cleanup_label is canonical
private _cleanupLabel = [_world, "cleanup_label", ""] call _kvGet;
if (!(_cleanupLabel isEqualType "")) then { _cleanupLabel = ""; };
private _wantLabel = format ["THREAT:%1:%2", toUpper _type, _threatId];
if (_cleanupLabel isEqualTo "") then
{
    _cleanupLabel = _wantLabel;
    _world = [_world, "cleanup_label", _cleanupLabel] call _kvSet;
};

// Step 2: mark cleanup metadata
_world = [_world, "cleanup_completed", true] call _kvSet;
_world = [_world, "cleanup_ts", serverTime] call _kvSet;
_world = [_world, "cleanup_source", [_source] call _trimFn] call _kvSet;

_rec = [_rec, "world", _world] call _kvSet;
_records set [_idxRec, _rec];
["threat_v0_records", _records] call ARC_fnc_stateSet;

// Step 3: drive state to CLEANED via the guarded transition (handles open/closed index too)
private _noteStr = format ["CLEANUP_SYNC:%1", [_source] call _trimFn];
private _result = [_threatId, "CLEANED", _noteStr] call ARC_fnc_threatUpdateState;

diag_log format ["[ARC][INFO] ARC_fnc_threatIedCleanupSync: cleanup applied threat_id=%1 state_before=%2 label=%3 result=%4", _threatId, _stateU, _cleanupLabel, _result];

_result

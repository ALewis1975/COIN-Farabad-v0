/*
    ARC_fnc_threatIedSpawnRequest

    Server: Request and record a spawn intent for an IED suspicious-object threat.

    Enforces spawn idempotency using a deterministic token derived from the stable
    threat identity (threat_id) and the creation epoch (floor of created_ts).
    Any attempt to spawn the same threat while a live manifestation already exists
    is denied and emitted as a THREAT_SPAWN_DENIED event for operator visibility.

    Token format: "SPTOKEN:<threat_id>:<floor(created_ts)>"

    Params:
        0: STRING threat_id (required)

    Returns:
        ARRAY [token, granted, deny_reason]
            token       STRING  idempotency token (set even on deny for evidence)
            granted     BOOL    true = caller may proceed with spawn
            deny_reason STRING  "" on success; reason code on denial

    Notes:
        - Server-only single-writer.
        - Writes spawn_token, spawn_intent_ts, and spawn_attempt_count to world sub-record.
        - On duplicate-active deny, emits THREAT_SPAWN_DENIED via ARC_fnc_threatEmitEvent.
*/

if (!isServer) exitWith {["", false, "DENY_NOT_SERVER"]};

params [
    ["_threatId", ""]
];

if (_threatId isEqualTo "") exitWith {["", false, "DENY_THREAT_ID_EMPTY"]};

private _enabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {["", false, "DENY_THREAT_DISABLED"]};

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
    diag_log format ["[ARC][WARN] ARC_fnc_threatIedSpawnRequest: records unavailable threat_id=%1", _threatId];
    ["", false, "DENY_RECORDS_UNAVAILABLE"]
};

private _idxRec = -1;
{ if (([_x, "threat_id", ""] call _kvGet) isEqualTo _threatId) exitWith { _idxRec = _forEachIndex; }; } forEach _records;

if (_idxRec < 0) exitWith
{
    diag_log format ["[ARC][WARN] ARC_fnc_threatIedSpawnRequest: threat not found threat_id=%1", _threatId];
    ["", false, "DENY_THREAT_NOT_FOUND"]
};

private _rec = _records select _idxRec;

// Derive deterministic token from stable threat identity + creation epoch
private _stateTs = [_rec, "state_ts", []] call _kvGet;
private _createdTs = [_stateTs, "created", 0] call _kvGet;
if (!(_createdTs isEqualType 0)) then { _createdTs = 0; };
private _token = format ["SPTOKEN:%1:%2", _threatId, (floor _createdTs)];

private _world = [_rec, "world", []] call _kvGet;
private _existingToken = [_world, "spawn_token", ""] call _kvGet;
if (!(_existingToken isEqualType "")) then { _existingToken = ""; };

private _spawned = [_world, "spawned", false] call _kvGet;
if (!(_spawned isEqualType true) && !(_spawned isEqualType false)) then { _spawned = false; };

private _stateRaw = [_rec, "state", ""] call _kvGet;
private _stateU = toUpper _stateRaw;
private _type = [_rec, "type", ""] call _kvGet;
private _subtype = [_rec, "subtype", ""] call _kvGet;
private _family = [_rec, "family", ""] call _kvGet;

// If a spawn token exists and a live manifestation is already active: deny duplicate spawn
if ((!(_existingToken isEqualTo "")) && { _spawned }) exitWith
{
    private _denyReason = "DENY_DUPLICATE_SPAWN";
    diag_log format ["[ARC][WARN] ARC_fnc_threatIedSpawnRequest: duplicate spawn denied threat_id=%1 token=%2 existing_token=%3 state=%4", _threatId, _token, _existingToken, _stateU];
    [
        "THREAT_SPAWN_DENIED",
        _threatId,
        [
            ["event", "THREAT_SPAWN_DENIED"],
            ["threat_id", _threatId],
            ["family", _family],
            ["type", _type],
            ["subtype", _subtype],
            ["token", _token],
            ["existing_token", _existingToken],
            ["deny_reason", _denyReason],
            ["state", _stateU]
        ],
        [["producer", "ARC_fnc_threatIedSpawnRequest"], ["rev", [_rec, "rev", 1] call _kvGet]]
    ] call ARC_fnc_threatEmitEvent;
    [_token, false, _denyReason]
};

// Record spawn request metadata for restart-safe rehydration
private _attempts = [_world, "spawn_attempt_count", 0] call _kvGet;
if (!(_attempts isEqualType 0)) then { _attempts = 0; };
_attempts = _attempts + 1;

_world = [_world, "spawn_token", _token] call _kvSet;
_world = [_world, "spawn_intent_ts", serverTime] call _kvSet;
_world = [_world, "spawn_attempt_count", _attempts] call _kvSet;

_rec = [_rec, "world", _world] call _kvSet;
_records set [_idxRec, _rec];
["threat_v0_records", _records] call ARC_fnc_stateSet;

diag_log format ["[ARC][INFO] ARC_fnc_threatIedSpawnRequest: spawn granted threat_id=%1 token=%2 attempt=%3 state=%4", _threatId, _token, _attempts, _stateU];

[_token, true, ""]

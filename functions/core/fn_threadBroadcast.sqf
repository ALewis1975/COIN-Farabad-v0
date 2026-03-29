/*
    Server: broadcast thread/case summaries to clients.

    This is intentionally a summary view (no hidden truth), intended for TOC tools.

    Broadcast variables:
      - ARC_threadsPublic (ARRAY)
      - ARC_threadsPublicUpdatedAt (NUMBER, serverTime)

    Thread summary format (per entry):
      [id, type, zoneBias, grid, confidence, heat, commanderState, fuSuccess, fuFail, lastTouchedAt, cooldownUntil, lastCommandNodeAt, parentTaskId, districtId]

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

private _threads = ["threads", []] call ARC_fnc_stateGet;
if (!(_threads isEqualType [])) then { _threads = []; };

private _pub = [];

{
    private _thr = [_x] call ARC_fnc_threadNormalizeRecord;
    if (_thr isEqualTo []) then { continue; };

    private _id   = _thr select 0;
    private _type = _thr select 1;
    private _zone = _thr select 2;
    private _base = _thr select 3;
    private _conf = _thr select 4;
    private _heat = _thr select 5;
    private _st   = _thr select 6;
    private _suc  = _thr select 8;
    private _fail = _thr select 9;
    private _touch= _thr select 10;
    private _cd   = _thr select 11;
    private _last = _thr select 12;
    private _parent = _thr select 13;
    private _districtId = _thr select 14;

    private _grid = if (_base isEqualType [] && { (count _base) >= 2 }) then { mapGridPosition _base } else { "????" };

    _pub pushBack [_id, _type, _zone, _grid, _conf, _heat, _st, _suc, _fail, _touch, _cd, _last, _parent, _districtId];

} forEach _threads;

missionNamespace setVariable ["ARC_threadsPublic", _pub, true];
missionNamespace setVariable ["ARC_threadsPublicUpdatedAt", serverTime, true];


// ---------------------------------------------------------------------------
// Console VM meta (rev) publish: monotonic rev to stabilize UI refresh ordering
// ---------------------------------------------------------------------------
private _rev = missionNamespace getVariable ["ARC_consoleVM_rev", 0];
if (!(_rev isEqualType 0)) then { _rev = 0; };
_rev = _rev + 1;
missionNamespace setVariable ["ARC_consoleVM_rev", _rev];
missionNamespace setVariable ["ARC_consoleVM_meta", [
    ["schema", "Console_VM_v1"],
    ["schemaVersion", 1],
    ["rev", _rev],
    ["publishedAt", serverTime],
    ["source", "threadBroadcast"]
], true];

true

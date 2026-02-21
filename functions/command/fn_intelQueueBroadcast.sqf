/*
    ARC_fnc_intelQueueBroadcast

    Server: publish a JIP-safe snapshot of the TOC request queue for clients.

    We broadcast both:
      - PENDING items (for immediate TOC action)
      - A short queue tail (for visibility/audit in the diary)

    Published vars:
      ARC_pub_queue           = [PENDING queueItem,...]   (compat)
      ARC_pub_queuePending    = [PENDING queueItem,...]
      ARC_pub_queueTail       = [queueItem,...]           (last N, includes decisions)
      ARC_pub_queueUpdatedAt  = serverTime

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

// sqflint-compat helpers
private _trimFn     = compile "params ['_s']; trim _s";

private _maxPending = missionNamespace getVariable ["ARC_pubQueuePendingMax", 40];
if (!(_maxPending isEqualType 0) || { _maxPending < 5 }) then { _maxPending = 40; };
_maxPending = (_maxPending min 80) max 5;

private _maxTail = missionNamespace getVariable ["ARC_tocQueueTailBroadcast", 12];
if (!(_maxTail isEqualType 0)) then { _maxTail = 12; };
_maxTail = (_maxTail max 5) min 50;

private _maxTextLen = missionNamespace getVariable ["ARC_pubQueueTextMaxLen", 220];
if (!(_maxTextLen isEqualType 0) || { _maxTextLen < 60 }) then { _maxTextLen = 220; };
_maxTextLen = (_maxTextLen min 600) max 60;

private _maxPayloadPairs = missionNamespace getVariable ["ARC_pubQueuePayloadMaxPairs", 20];
if (!(_maxPayloadPairs isEqualType 0) || { _maxPayloadPairs < 0 }) then { _maxPayloadPairs = 20; };
_maxPayloadPairs = (_maxPayloadPairs min 60) max 0;

private _maxNestedDepth = missionNamespace getVariable ["ARC_pubQueuePayloadMaxDepth", 2];
if (!(_maxNestedDepth isEqualType 0) || { _maxNestedDepth < 0 }) then { _maxNestedDepth = 2; };
_maxNestedDepth = (_maxNestedDepth min 4) max 0;

private _sanitizeValue = {
    params ["_v", ["_depth", 0]];
    if (_v isEqualType "") exitWith {
        private _s = [_v] call _trimFn;
        if ((count _s) > _maxTextLen) then { _s = _s select [0, _maxTextLen]; };
        _s
    };
    if (_v isEqualType 0 || { _v isEqualType true } || { _v isEqualType false }) exitWith { _v };
    if (_v isEqualType []) then {
        if (_depth >= _maxNestedDepth) exitWith { ["<truncated_depth>"] };
        private _arr = +_v;
        if ((count _arr) > _maxPayloadPairs) then { _arr = _arr select [0, _maxPayloadPairs]; _arr pushBack "<truncated_list>"; };
        _arr apply { [_x, _depth + 1] call _sanitizeValue }
    } else {
        private _s = str _v;
        if ((count _s) > _maxTextLen) then { _s = _s select [0, _maxTextLen]; };
        _s
    }
};

private _sanitizePairs = {
    params ["_pairs"];
    private _in = if (_pairs isEqualType []) then { +_pairs } else { [] };
    private _truncated = false;
    if ((count _in) > _maxPayloadPairs) then { _in = _in select [0, _maxPayloadPairs]; _truncated = true; };
    private _out = [];
    {
        if !(_x isEqualType [] && { (count _x) >= 2 }) then { _truncated = true; continue; };
        private _k = _x select 0;
        if !(_k isEqualType "") then { _truncated = true; continue; };
        private _v = [(_x select 1), 0] call _sanitizeValue;
        _out pushBack [[_k] call _trimFn, _v];
    } forEach _in;
    if (_truncated) then { _out pushBack ["truncated", true]; };
    _out
};

private _sanitizeItem = {
    params ["_it"];
    if !(_it isEqualType [] && { (count _it) >= 12 }) exitWith { [] };
    private _id = _it select 0;
    private _createdAt = _it select 1;
    private _status = _it select 2;
    private _kind = _it select 3;
    private _from = _it select 4;
    private _fromGroup = _it select 5;
    private _fromUid = _it select 6;
    private _pos = _it select 7;
    private _summary = _it select 8;
    private _details = _it select 9;
    private _payload = _it select 10;
    private _meta = _it select 11;
    private _decision = if ((count _it) > 12) then { _it select 12 } else { [] };
    private _tr = false;

    if !(_id isEqualType "") then { _id = ""; _tr = true; };
    if !(_createdAt isEqualType 0) then { _createdAt = 0; _tr = true; };
    if !(_status isEqualType "") then { _status = "PENDING"; _tr = true; };
    if !(_kind isEqualType "") then { _kind = "UNKNOWN"; _tr = true; };
    if !(_from isEqualType "") then { _from = ""; _tr = true; };
    if !(_fromGroup isEqualType "") then { _fromGroup = ""; _tr = true; };
    if !(_fromUid isEqualType "") then { _fromUid = ""; _tr = true; };
    if !(_summary isEqualType "") then { _summary = str _summary; _tr = true; };
    if !(_details isEqualType "") then { _details = str _details; _tr = true; };
    _summary = [_summary] call _trimFn;
    _details = [_details] call _trimFn;
    if ((count _summary) > _maxTextLen) then { _summary = _summary select [0, _maxTextLen]; _tr = true; };
    if ((count _details) > _maxTextLen) then { _details = _details select [0, _maxTextLen]; _tr = true; };
    if !(_pos isEqualType [] && { (count _pos) >= 2 }) then { _pos = [0,0,0]; _tr = true; };
    if ((count _pos) > 3) then { _pos resize 3; _tr = true; };

    private _payloadSafe = [_payload] call _sanitizePairs;
    private _metaSafe = [_meta] call _sanitizePairs;
    private _decisionSafe = [_decision] call _sanitizePairs;
    if (_tr) then { _metaSafe pushBack ["entryTruncated", true]; };
    [_id, _createdAt, toUpper _status, toUpper _kind, _from, _fromGroup, _fromUid, _pos, _summary, _details, _payloadSafe, _metaSafe, _decisionSafe]
};

private _q = ["tocQueue", []] call ARC_fnc_stateGet;
if (!(_q isEqualType [])) then { _q = []; };

private _pendingRaw = [];
{
    if (_x isEqualType [] && { (count _x) >= 12 }) then
    {
        // [id, createdAt, status, kind, from, fromGroup, fromUID, pos, summary, details, payload, meta, decision]
        private _st = _x select 2;
        if (_st isEqualType "" && { toUpper _st isEqualTo "PENDING" }) then
        {
            _pendingRaw pushBack _x;
        };
    };
} forEach _q;

private _pending = +_pendingRaw;
private _pendingTruncated = false;
if ((count _pending) > _maxPending) then
{
    _pending = _pending select [0, _maxPending];
    _pendingTruncated = true;
};

private _tail = +_q;
private _ct = count _q;
if (_ct > _maxTail) then
{
    _tail = _q select [_ct - _maxTail, _maxTail];
};

private _pendingSafe = _pending apply { [_x] call _sanitizeItem };
private _tailSafe = _tail apply { [_x] call _sanitizeItem };

// Compat + explicit vars
missionNamespace setVariable ["ARC_pub_queue", _pendingSafe, true];
missionNamespace setVariable ["ARC_pub_queuePending", _pendingSafe, true];
missionNamespace setVariable ["ARC_pub_queueTail", _tailSafe, true];
missionNamespace setVariable ["ARC_pub_queueUpdatedAt", serverTime, true];
missionNamespace setVariable ["ARC_pub_queueMeta", [
    ["pendingMax", _maxPending],
    ["tailMax", _maxTail],
    ["textMaxLen", _maxTextLen],
    ["payloadMaxPairs", _maxPayloadPairs],
    ["payloadMaxDepth", _maxNestedDepth],
    ["truncated", _pendingTruncated || (_ct > _maxTail)]
], true];

true

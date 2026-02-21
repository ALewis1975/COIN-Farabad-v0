/*
    Broadcast a presentation-safe Intel snapshot for clients (JIP-safe).

    Sets:
      - ARC_pub_intelLog (Array of non-OPS entries)
      - ARC_pub_opsLog (Array of OPS entries)
      - ARC_pub_intelUpdatedAt (Number: serverTime)
*/

if (!isServer) exitWith {false};

// sqflint-compat helpers
private _trimFn     = compile "params ['_s']; trim _s";

private _maxEntries = missionNamespace getVariable ["ARC_pubIntelMaxEntries", 40];
if (!(_maxEntries isEqualType 0) || { _maxEntries < 5 }) then { _maxEntries = 40; };
_maxEntries = (_maxEntries min 80) max 5;

private _maxSummaryLen = missionNamespace getVariable ["ARC_pubIntelSummaryMaxLen", 220];
if (!(_maxSummaryLen isEqualType 0) || { _maxSummaryLen < 40 }) then { _maxSummaryLen = 220; };
_maxSummaryLen = (_maxSummaryLen min 600) max 40;

private _maxMetaPairs = missionNamespace getVariable ["ARC_pubIntelMetaMaxPairs", 12];
if (!(_maxMetaPairs isEqualType 0) || { _maxMetaPairs < 0 }) then { _maxMetaPairs = 12; };
_maxMetaPairs = (_maxMetaPairs min 30) max 0;

private _metaValueMaxLen = missionNamespace getVariable ["ARC_pubIntelMetaValueMaxLen", 140];
if (!(_metaValueMaxLen isEqualType 0) || { _metaValueMaxLen < 20 }) then { _metaValueMaxLen = 140; };
_metaValueMaxLen = (_metaValueMaxLen min 240) max 20;

private _log = ["intelLog", []] call ARC_fnc_stateGet;
if (!(_log isEqualType [])) then { _log = []; };

private _intel = _log select { _x isEqualType [] && { (count _x) >= 3 } && { toUpper !((_x select 2) isEqualTo "OPS") } };
private _ops   = _log select { _x isEqualType [] && { (count _x) >= 3 } && { toUpper (_x select 2) isEqualTo "OPS" } };

private _sanitizeMeta = {
    params ["_metaIn"];
    private _meta = if (_metaIn isEqualType []) then { +_metaIn } else { [] };
    private _truncated = false;
    if ((count _meta) > _maxMetaPairs) then {
        _meta = _meta select [0, _maxMetaPairs];
        _truncated = true;
    };
    private _out = [];
    {
        if !(_x isEqualType [] && { (count _x) >= 2 }) then { _truncated = true; continue; };
        private _k = _x select 0;
        private _v = _x select 1;
        if !(_k isEqualType "") then { _truncated = true; continue; };
        _k = [_k] call _trimFn;
        if (_k isEqualTo "") then { _truncated = true; continue; };

        if (_v isEqualType "") then {
            _v = [_v] call _trimFn;
            if ((count _v) > _metaValueMaxLen) then { _v = _v select [0, _metaValueMaxLen]; _truncated = true; };
        } else {
            if (!(_v isEqualType 0) && !(_v isEqualType true) && !(_v isEqualType false)) then {
                _v = str _v;
                if ((count _v) > _metaValueMaxLen) then { _v = _v select [0, _metaValueMaxLen]; };
                _truncated = true;
            };
        };
        _out pushBack [_k, _v];
    } forEach _meta;

    if (_truncated) then { _out pushBack ["truncated", true]; };
    _out
};

private _sanitizeEntry = {
    params ["_row"];
    if !(_row isEqualType [] && { (count _row) >= 6 }) exitWith { [] };

    private _id = _row select 0;
    private _ts = _row select 1;
    private _cat = _row select 2;
    private _sum = _row select 3;
    private _pos = _row select 4;
    private _meta = _row select 5;
    private _truncated = false;

    if !(_id isEqualType "") then { _id = ""; _truncated = true; };
    if !(_ts isEqualType 0) then { _ts = 0; _truncated = true; };
    if !(_cat isEqualType "") then { _cat = "GEN"; _truncated = true; };
    if !(_sum isEqualType "") then { _sum = str _sum; _truncated = true; };
    _sum = [_sum] call _trimFn;
    if ((count _sum) > _maxSummaryLen) then { _sum = _sum select [0, _maxSummaryLen]; _truncated = true; };

    if !(_pos isEqualType [] && { (count _pos) >= 2 }) then { _pos = [0,0,0]; _truncated = true; };
    if ((count _pos) > 3) then { _pos resize 3; _truncated = true; };

    private _metaSafe = [_meta] call _sanitizeMeta;
    if (([_metaSafe, {_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "truncated" }}] call _findIfFn) >= 0) then { _truncated = true; };
    if (_truncated) then { _metaSafe pushBack ["entryTruncated", true]; };
    [_id, _ts, toUpper _cat, _sum, _pos, _metaSafe]
};

private _iCount = count _intel;
private _oCount = count _ops;
private _iStart = (_iCount - _maxEntries) max 0;
private _oStart = (_oCount - _maxEntries) max 0;

private _intelSlice = (_intel select [_iStart, _iCount - _iStart]) apply { [_x] call _sanitizeEntry };
private _opsSlice   = (_ops select [_oStart, _oCount - _oStart]) apply { [_x] call _sanitizeEntry };

missionNamespace setVariable ["ARC_pub_intelLog", _intelSlice, true];
missionNamespace setVariable ["ARC_pub_opsLog", _opsSlice, true];
missionNamespace setVariable ["ARC_pub_intelUpdatedAt", serverTime, true];
missionNamespace setVariable ["ARC_pub_intelMeta", [
    ["maxEntries", _maxEntries],
    ["summaryMaxLen", _maxSummaryLen],
    ["metaMaxPairs", _maxMetaPairs],
    ["metaValueMaxLen", _metaValueMaxLen],
    ["truncated", (_iCount > _maxEntries) || (_oCount > _maxEntries)]
], true];

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
    ["source", "intelBroadcast"]
], true];

true

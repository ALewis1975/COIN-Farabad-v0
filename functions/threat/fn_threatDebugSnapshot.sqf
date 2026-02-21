/*
    Threat debug snapshot (server-only).

    Populates:
        missionNamespace threat_v0_debug_counts
        missionNamespace threat_v0_debug_last_event
        missionNamespace threat_v0_debug_open

    Returns:
        ARRAY snapshot (pairs)
*/

if (!isServer) exitWith {[]};

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; [(_h), _k, _d] call _hg";
private _hmFrom   = compile "params ['_pairs']; private _r = createHashMap; { _r set [_x select 0, _x select 1]; } forEach _pairs; _r";

private _enabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };

// Small helper for "pairs arrays"
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

private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
if (!(_records isEqualType [])) then { _records = []; };

private _open = ["threat_v0_open_index", []] call ARC_fnc_stateGet;
if (!(_open isEqualType [])) then { _open = []; };

private _closed = ["threat_v0_closed_index", []] call ARC_fnc_stateGet;
if (!(_closed isEqualType [])) then { _closed = []; };

private _byState = createHashMap;
private _byType = createHashMap;

{
    private _rec = _x;
    private _st = toUpper ([_rec, "state", ""] call _kvGet);
    private _tp = toUpper ([_rec, "type", "OTHER"] call _kvGet);

    if (_st isEqualTo "") then { _st = "UNKNOWN"; };
    if (_tp isEqualTo "") then { _tp = "OTHER"; };

    _byState set [_st, ([_byState, _st, 0] call _hg) + 1];
    _byType set [_tp, ([_byType, _tp, 0] call _hg) + 1];
} forEach _records;

// Truncate open list for inspector readability
private _openShort = _open;
if ((count _openShort) > 25) then { _openShort = _openShort select [0, 25]; };

private _counts = [[
    ["enabled", _enabled],
    ["by_state", _byState],
    ["by_type", _byType],
    ["open_count", count _open],
    ["closed_count", count _closed]
]] call _hmFrom;

missionNamespace setVariable ["threat_v0_debug_counts", _counts];
missionNamespace setVariable ["threat_v0_debug_open", _openShort];

private _last = missionNamespace getVariable ["threat_v0_debug_last_event", []];

[
    ["counts", _counts],
    ["last", _last],
    ["open", _openShort]
]

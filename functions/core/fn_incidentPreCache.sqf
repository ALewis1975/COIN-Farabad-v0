/*
    ARC_fnc_incidentPreCache

    Pre-registers dormant virtual OpFor groups along the player-to-objective
    route corridor as VIRTUAL_ACTIVE, so they can physically spawn when players
    enter spawn radius during approach.

    Scans the straight-line corridor from the centroid of all current player
    positions to the incident objective position. Any dormant virtual group
    within corridorRadius metres of that line segment is forced to VIRTUAL_ACTIVE.

    Authority: Server only.

    Params:
        0: ARRAY  — incident position ATL [x, y, z]
        1: STRING — incident type (logging)
        2: ARRAY  — options (optional)
            ["corridorRadius", 250]   route corridor half-width (m)
            ["maxAssets",      6]     max groups to activate (priority: nearest)
            ["priorityPos",    []]    override player centroid (empty = auto)

    Returns:
        NUMBER — count of groups transitioned to VIRTUAL_ACTIVE (0 on error)
*/

if (!isServer) exitWith { 0 };

params [
    ["_incPos",      [0,0,0], [[]]],
    ["_incType",     "",      [""]],
    ["_opts",        [],      [[]]]
];

if ((count _incPos) < 2) exitWith
{
    diag_log "[ARC][PRECACHE][WARN] incidentPreCache: invalid incident position — skipping.";
    0
};

// ---------------------------------------------------------------------------
// Parse options
// ---------------------------------------------------------------------------
private _corridorRadius = 250;
private _maxAssets      = 6;
private _priorityPos    = [];

{
    if (_x isEqualType [] && { (count _x) >= 2 }) then
    {
        private _ok = _x select 0;
        private _ov = _x select 1;
        switch (_ok) do
        {
            case "corridorRadius": { if (_ov isEqualType 0) then { _corridorRadius = (_ov max 50) min 1000; }; };
            case "maxAssets":      { if (_ov isEqualType 0) then { _maxAssets      = (_ov max 1)  min 20;   }; };
            case "priorityPos":    { if (_ov isEqualType [] && { (count _ov) >= 2 }) then { _priorityPos = _ov; }; };
        };
    };
} forEach _opts;

// ---------------------------------------------------------------------------
// Resolve player centroid
// ---------------------------------------------------------------------------
private _fromPos = _priorityPos;

if ((count _fromPos) < 2) then
{
    private _alivePlayers = allPlayers select { alive _x };
    if ((count _alivePlayers) > 0) then
    {
        private _sumX = 0;
        private _sumY = 0;
        { _sumX = _sumX + (getPos _x select 0); _sumY = _sumY + (getPos _x select 1); } forEach _alivePlayers;
        private _n = count _alivePlayers;
        _fromPos = [_sumX / _n, _sumY / _n, 0];
    };
};

if ((count _fromPos) < 2) exitWith
{
    diag_log "[ARC][PRECACHE][WARN] incidentPreCache: no players online, cannot determine route — skipping.";
    0
};

// ---------------------------------------------------------------------------
// Load virtual OpFor records
// ---------------------------------------------------------------------------
private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
if (!(_records isEqualType [])) then { _records = []; };
if ((count _records) == 0) exitWith
{
    diag_log "[ARC][PRECACHE][INFO] incidentPreCache: no threat records in pool — nothing to pre-cache.";
    0
};

// ---------------------------------------------------------------------------
// Key–value helpers (array-of-pairs pattern, sqflint compat)
// ---------------------------------------------------------------------------
private _kvGet = {
    params ["_pairs", "_key", "_default"];
    if (!(_pairs isEqualType [])) exitWith { _default };
    private _val = _default;
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key })
            exitWith { _val = _x select 1; };
    } forEach _pairs;
    _val
};

private _kvSet = {
    params ["_pairs", "_key", "_value"];
    if (!(_pairs isEqualType [])) then { _pairs = []; };
    private _idx = -1;
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key })
            exitWith { _idx = _forEachIndex; };
    } forEach _pairs;
    if (_idx < 0) then { _pairs pushBack [_key, _value]; } else { _pairs set [_idx, [_key, _value]]; };
    _pairs
};

// ---------------------------------------------------------------------------
// Corridor distance helper: perpendicular distance from point P to segment A→B.
// Uses 2-D X/Y only (ATL height irrelevant for corridor scan).
// ---------------------------------------------------------------------------
private _fnDistToSegment = {
    params ["_ax", "_ay", "_bx", "_by", "_px", "_py"];
    private _dx = _bx - _ax;
    private _dy = _by - _ay;
    private _lenSq = (_dx * _dx) + (_dy * _dy);
    if (_lenSq < 0.001) exitWith { sqrt (((_px - _ax)^2) + ((_py - _ay)^2)) };
    private _t = (((_px - _ax) * _dx + (_py - _ay) * _dy) / _lenSq) max 0 min 1;
    private _cx = _ax + _t * _dx;
    private _cy = _ay + _t * _dy;
    sqrt (((_px - _cx)^2) + ((_py - _cy)^2))
};

private _ax = _fromPos select 0;
private _ay = _fromPos select 1;
private _bx = _incPos  select 0;
private _by = _incPos  select 1;

// ---------------------------------------------------------------------------
// Find candidates: DORMANT VIRTUAL_OPFOR groups within corridor
// ---------------------------------------------------------------------------
private _candidates = [];  // [[index, distToLine, distToFrom], ...]

{
    private _rec = _x;
    private _ri  = _forEachIndex;

    if (!(([_rec, "type", ""] call _kvGet) isEqualTo "VIRTUAL_OPFOR")) then { continue; };
    if (!(([_rec, "state", ""] call _kvGet) isEqualTo "VIRTUAL_DORMANT")) then { continue; };

    private _pos = [_rec, "pos", []] call _kvGet;
    if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { continue; };

    private _px = _pos select 0;
    private _py = _pos select 1;

    private _distToLine = [_ax, _ay, _bx, _by, _px, _py] call _fnDistToSegment;
    if (_distToLine > _corridorRadius) then { continue; };

    private _distToFrom = sqrt (((_px - _ax)^2) + ((_py - _ay)^2));
    // Tuple: [distToFrom, distToLine, recordIndex] — distToFrom first so sort true gives nearest-first
    _candidates pushBack [_distToFrom, _distToLine, _ri];
} forEach _records;

if ((count _candidates) == 0) exitWith
{
    diag_log format [
        "[ARC][PRECACHE][INFO] incidentPreCache: no DORMANT groups in corridor (radius=%1 m) from %2 to %3.",
        _corridorRadius, _fromPos, _incPos
    ];
    0
};

// Sort by distance from player centroid (nearest first — priority activation)
_candidates sort true;

// Limit to maxAssets
if ((count _candidates) > _maxAssets) then
{
    _candidates = _candidates select [0, _maxAssets];
};

// ---------------------------------------------------------------------------
// Transition selected groups to VIRTUAL_ACTIVE
// ---------------------------------------------------------------------------
private _activatedCnt = 0;
private _dirty = false;

{
    private _ri = _x select 2;
    private _rec = _records select _ri;

    private _vgId = [_rec, "vgroup_id", format ["vg_unknown_%1", _ri]] call _kvGet;
    _rec = [_rec, "state", "VIRTUAL_ACTIVE"] call _kvSet;
    _records set [_ri, _rec];
    _dirty = true;
    _activatedCnt = _activatedCnt + 1;

    diag_log format [
        "[ARC][PRECACHE][INFO] incidentPreCache: %1 VIRTUAL_DORMANT → VIRTUAL_ACTIVE (corridorDist=%2 m playerDist=%3 m)",
        _vgId, round (_x select 1), round (_x select 0)
    ];
} forEach _candidates;

// Persist updated records
if (_dirty) then
{
    ["threat_v0_records", _records] call ARC_fnc_stateSet;
};

diag_log format [
    "[ARC][PRECACHE][INFO] incidentPreCache: activated %1/%2 corridor assets for %3 (%4). corridor=%5 m.",
    _activatedCnt, count _candidates, _incType, _incPos, _corridorRadius
];

_activatedCnt

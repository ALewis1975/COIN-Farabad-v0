/*
    ARC_fnc_execMsrThreatCheck

    T10 – MSR/Convoy Threat Integration: lightweight server-side check for open threat
    records targeting the active convoy on the MSR route.

    Called once per convoy tick when convoy vehicles are confirmed on the road.
    Emits a de-duplicated OPS intel log entry if any CONVOY-targeted threat records are
    in PLANNED or ACTIVE state within a search radius of the convoy route.

    Players receive no direct popup here; the lead entry in the intel feed is the
    primary notification surface. This function is purely an observability hook.

    Authority: server-only (reads threat_v0_records; no state mutation).

    Params:
      0: OBJECT - convoy lead vehicle
      1: ARRAY  - precomputed route points (ATL positions)

    Returns:
      BOOL (true = at least one relevant threat found and logged, false = clean/skipped)
*/

if (!isServer) exitWith {false};

params [
    ["_lead", objNull, [objNull]],
    ["_routePts", [], [[]]]
];

if (isNull _lead) exitWith {false};
if ((count _routePts) isEqualTo 0) exitWith {false};

private _enabled = missionNamespace getVariable ["ARC_msrThreatCheckEnabled", true];
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {false};

// Rate-limit: run at most once every ARC_msrThreatCheckIntervalS (default 90 s).
private _intervalS = missionNamespace getVariable ["ARC_msrThreatCheckIntervalS", 90];
if (!(_intervalS isEqualType 0) || { _intervalS < 20 }) then { _intervalS = 90; };
_intervalS = (_intervalS max 20) min 600;

private _lastRun = missionNamespace getVariable ["ARC_msrThreatCheck_lastRunAt", -1];
if (!(_lastRun isEqualType 0)) then { _lastRun = -1; };
private _now = serverTime;
if (_lastRun > 0 && { (_now - _lastRun) < _intervalS }) exitWith {false};
missionNamespace setVariable ["ARC_msrThreatCheck_lastRunAt", _now];

// ---------------------------------------------------------------------------
// Helper: pairs-array get (read-only)
// ---------------------------------------------------------------------------
private _kvGet = {
    params ["_pairs", "_key", "_default"];
    if (!(_pairs isEqualType [])) exitWith {_default};
    private _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 2 } && { ((_x select 0) isEqualTo _key) }) exitWith { _idx = _forEachIndex; }; } forEach _pairs;
    if (_idx < 0) exitWith {_default};
    private _v = (_pairs select _idx) select 1;
    if (isNil "_v") exitWith {_default};
    _v
};

// ---------------------------------------------------------------------------
// Collect route sample positions (use a stride to avoid iterating every point
// for large route sets; 300 m stride gives roughly one sample per segment).
// ---------------------------------------------------------------------------
private _searchRadM = missionNamespace getVariable ["ARC_msrThreatSearchRadM", 600];
if (!(_searchRadM isEqualType 0) || { _searchRadM <= 0 }) then { _searchRadM = 600; };
_searchRadM = (_searchRadM max 100) min 2000;

private _routeSamples = [];
private _stride = (floor ((count _routePts) / 12)) max 1;
{
    if ((_forEachIndex mod _stride) isEqualTo 0) then { _routeSamples pushBack _x; };
} forEach _routePts;

// Always include the lead vehicle position as an extra sample.
private _leadPos = getPosATL _lead;
_leadPos resize 3; _leadPos set [2, 0];
_routeSamples pushBack _leadPos;

// ---------------------------------------------------------------------------
// Scan open threat records for CONVOY-targeted IED threats near the route
// ---------------------------------------------------------------------------
private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
if (!(_records isEqualType [])) then { _records = []; };

private _openIds = ["threat_v0_open_index", []] call ARC_fnc_stateGet;
if (!(_openIds isEqualType [])) then { _openIds = []; };

private _openStates = ["PLANNED", "ACTIVE", "STAGED"];

private _found = [];

{
    private _rec = _x;
    private _threatId = [_rec, "threat_id", ""] call _kvGet;
    if (!(_threatId in _openIds)) then { continue; };

    private _state = toUpper ([_rec, "state", ""] call _kvGet);
    if (!(_state in _openStates)) then { continue; };

    private _links = [_rec, "links", []] call _kvGet;
    private _target = toUpper ([_links, "target_profile", ""] call _kvGet);
    if (!(_target isEqualTo "CONVOY")) then { continue; };

    private _area = [_rec, "area", []] call _kvGet;
    private _pos = [_area, "pos", []] call _kvGet;
    if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { continue; };
    _pos = +_pos; _pos resize 3; _pos set [2, 0];

    // Check if the threat position is within search radius of any route sample.
    private _close = false;
    {
        if ((_pos distance2D _x) <= _searchRadM) exitWith { _close = true; };
    } forEach _routeSamples;

    if (_close) then { _found pushBack _threatId; };
} forEach _records;

if ((count _found) isEqualTo 0) exitWith {false};

// ---------------------------------------------------------------------------
// Emit one de-duplicated OPS log entry per encounter interval
// ---------------------------------------------------------------------------
private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (!(_taskId isEqualType "")) then { _taskId = ""; };

private _gridLead = mapGridPosition _leadPos;

[
    "OPS",
    format [
        "MSR THREAT ALERT: %1 open threat record(s) targeting CONVOY on route near %2. Initiate route clearance protocol (THUNDER lead). Threat IDs: %3",
        count _found,
        _gridLead,
        _found joinString ", "
    ],
    _leadPos,
    [
        ["taskId", _taskId],
        ["event", "MSR_THREAT_DETECTED"],
        ["threatCount", count _found],
        ["threatIds", _found]
    ]
] call ARC_fnc_intelLog;

diag_log format [
    "[ARC][THREAT][T10] ARC_fnc_execMsrThreatCheck: %1 CONVOY-targeted threat(s) within %2m of convoy route. threatIds=%3 lead=%4",
    count _found, _searchRadM, _found, _gridLead
];

true

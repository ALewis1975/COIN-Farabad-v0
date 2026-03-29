/*
    Append an intel entry to persistent state and broadcast to clients.

    Params:
        0: STRING - category (e.g., "OPS", "PLAYER", "ISR", "HUMINT")
        1: STRING - summary (one line)
        2: ARRAY  - posATL (optional) [x,y,z]
        3: ARRAY  - metaPairs (optional) [[k,v], ...]

    Returns:
        STRING - intelId (e.g., INT-0007)
*/

if (!isServer) exitWith {""};

params ["_category", "_summary", ["_posATL", [0,0,0]], ["_meta", []]];

if (_category isEqualTo "") then { _category = "GEN"; };
if (_summary isEqualTo "") then { _summary = "No details provided."; };
if (!(_posATL isEqualType [])) then { _posATL = [0,0,0]; };
if (!(_meta isEqualType [])) then { _meta = []; };

// Enrich meta with grid/zone when possible (helps UI formatting)
if !((_posATL select 0) isEqualTo 0 && {(_posATL select 1) isEqualTo 0}) then
{
    private _grid = mapGridPosition _posATL;
    private _zone = [_posATL] call ARC_fnc_worldGetZoneForPos;

    private _foundGrid = false;
    { if ((_x select 0) isEqualTo "grid") exitWith { _foundGrid = true; }; } forEach _meta;
    if (!_foundGrid) then
    {
        _meta pushBack ["grid", _grid];
    };
    private _foundZone = false;
    { if ((_x select 0) isEqualTo "zone") exitWith { _foundZone = true; }; } forEach _meta;
    if (!_foundZone) then
    {
        _meta pushBack ["zone", _zone];
    };
};

// Counter -> ID
private _ctr = ["intelCounter", 0] call ARC_fnc_stateGet;
_ctr = _ctr + 1;
["intelCounter", _ctr] call ARC_fnc_stateSet;

private _n = str _ctr;
while {count _n < 4} do { _n = "0" + _n; };
private _id = "INT-" + _n;

// Append
private _log = ["intelLog", []] call ARC_fnc_stateGet;
if (!(_log isEqualType [])) then { _log = []; };

private _catU = toUpper _category;
_log pushBack [_id, serverTime, _catU, _summary, _posATL, _meta];

// Trim oldest entries (configurable cap; preserves most-recent tail)
private _intelMax = missionNamespace getVariable ["ARC_intelLogMaxEntries", 500];
if (!(_intelMax isEqualType 0)) then { _intelMax = 500; };
_intelMax = (_intelMax max 10) min 2000;
if ((count _log) > _intelMax) then { _log = _log select [((count _log) - _intelMax), _intelMax]; };

["intelLog", _log] call ARC_fnc_stateSet;

// Optional: emit OPS entries to the server RPT for easier triage.
// Toggle (initServer.sqf or debug console):
//   missionNamespace setVariable ["ARC_rptOpsLogEnabled", true];
private _rptOps = missionNamespace getVariable ["ARC_rptOpsLogEnabled", true];
if (!(_rptOps isEqualType true) && !(_rptOps isEqualType false)) then { _rptOps = true; };

if (_rptOps && { _catU isEqualTo "OPS" }) then
{
    private _grid = "";
    private _zone = "";
    if !((_posATL select 0) isEqualTo 0 && {(_posATL select 1) isEqualTo 0}) then
    {
        _grid = mapGridPosition _posATL;
        _zone = [_posATL] call ARC_fnc_worldGetZoneForPos;
    };

    // Format: [ARC][OPS] INT-#### | t=... | zone=... | grid=... | Summary | meta=[...]
    diag_log format ["[ARC][OPS] %1 | t=%2 | zone=%3 | grid=%4 | %5 | meta=%6", _id, serverTime, _zone, _grid, _summary, _meta];
};

// Create/update a map marker so players can navigate to intel items while testing.
// Do NOT create markers for OPS entries (tasks already have map context; OPS markers create clutter).
if (!(_catU isEqualTo "OPS")) then
{
    [_id, _catU, _posATL] call ARC_fnc_intelCreateMarker;
};

// Broadcast to clients and refresh current task text
[] call ARC_fnc_intelBroadcast;
[] call ARC_fnc_taskUpdateActiveDescription;
[] call ARC_fnc_publicBroadcastState;

_id

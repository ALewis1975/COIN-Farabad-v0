/*
    Server-side handler: accept an intel point from a client and persist it.

    Params:
        0: STRING - reporter name
        1: STRING - category (e.g., "SIGHTING", "HUMINT")
        2: ARRAY  - position (from map click)

    This is called via remoteExec from clients.
*/

if (!isServer) exitWith {false};

params [
    "_reporter",
    "_category",
    "_pos",
    ["_noteSummary", ""],
    ["_noteDetails", ""],
    ["_metaExtra", []]
];

if (_reporter isEqualTo "") then { _reporter = "UNKNOWN"; };
if (_category isEqualTo "") then { _category = "SIGHTING"; };
if (!(_noteSummary isEqualType "")) then { _noteSummary = ""; };
if (!(_noteDetails isEqualType "")) then { _noteDetails = ""; };
if (!(_metaExtra isEqualType [])) then { _metaExtra = []; };

private _posATL = _pos;
if (!(_posATL isEqualType [])) then { _posATL = [0,0,0]; };
if ((count _posATL) < 3) then { _posATL pushBack 0; };

private _grid = mapGridPosition _posATL;
private _zone = [_posATL] call ARC_fnc_worldGetZoneForPos;

if (_zone isEqualTo "") then { _zone = "Unzoned"; };

// RPT trace (helps triage client map-click issues)
diag_log format ["[ARC][INTEL][LOG] Request accepted | reporter=%1 | cat=%2 | grid=%3 | zone=%4 | sum=%5", _reporter, toUpper _category, _grid, _zone, _noteSummary];

private _catU = toUpper _category;
private _summary = "";

// If a note was provided, use it as the human-readable core of the entry.
if ((trim _noteSummary) isNotEqualTo "") then
{
    private _prefix = switch (_catU) do
    {
        case "HUMINT": { "HUMINT TIP" };
        case "ISR": { "ISR" };
        case "SIGHTING": { "SIGHTING" };
        default { _catU };
    };

    _summary = format ["%1: %2 (Reported by %3). Grid %4. Zone: %5.", _prefix, trim _noteSummary, _reporter, _grid, _zone];
}
else
{
    _summary = format ["%1 reported %2 at %3 (Zone: %4).", _reporter, _catU, _grid, _zone];
};

private _meta = [
    ["reporter", _reporter],
    ["category", _catU],
    ["grid", _grid],
    ["zone", _zone],
    ["event", "PLAYER_INTEL"]
];

if ((trim _noteDetails) isNotEqualTo "") then
{
    _meta pushBack ["details", trim _noteDetails];
};

// Merge any additional meta pairs
{
    if (_x isEqualType [] && { (count _x) >= 2 }) then
    {
        _meta pushBack [_x # 0, _x # 1];
    };
} forEach _metaExtra;

// If close to active incident, link it
private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
private _marker = ["activeIncidentMarker", ""] call ARC_fnc_stateGet;

if (_taskId isNotEqualTo "" && {_marker isNotEqualTo ""}) then
{
    private _m = [_marker] call ARC_fnc_worldResolveMarker;
    if (_m in allMapMarkers) then
    {
        private _ipos = getMarkerPos _m;
        if ((_ipos distance2D _posATL) < 2500) then
        {
            _meta pushBack ["linkedTaskId", _taskId];
            _meta pushBack ["linkedMarker", _marker];
            _meta pushBack ["confidence", "HIGH"]; // in-ops-area reporting
        };
    };
};

if ((_meta findIf { (_x # 0) isEqualTo "confidence" }) < 0) then
{
    _meta pushBack ["confidence", "UNVERIFIED"]; // TOC reports outside the active incident area
};

[_catU, _summary, _posATL, _meta] call ARC_fnc_intelLog;
true

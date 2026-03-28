/*
    Server-side handler: accept an intel point from a client and persist it.

    Params:
        0: OBJECT - caller (player)
        1: STRING - reporter name
        2: STRING - category (e.g., "SIGHTING", "HUMINT")
        3: ARRAY  - position (from map click)

    This is called via remoteExec from clients.
*/

if (!isServer) exitWith {false};

private _trimFn = compile "params ['_s']; trim _s";

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\\core\\fn_rpcValidateSender.sqf"; };

private _rawPayload = _this;
private _payload = if (_rawPayload isEqualType []) then { +_rawPayload } else { [] };
private _payloadMalformed = !(_rawPayload isEqualType []);

if (!_payloadMalformed) then
{
    if ((count _payload) > 0 && {!((_payload select 0) isEqualType objNull)}) then { _payloadMalformed = true; };
    if ((count _payload) > 1 && {!((_payload select 1) isEqualType "")}) then { _payloadMalformed = true; };
    if ((count _payload) > 2 && {!((_payload select 2) isEqualType "")}) then { _payloadMalformed = true; };
    if ((count _payload) > 3 && {!((_payload select 3) isEqualType [])}) then { _payloadMalformed = true; };
    if ((count _payload) > 4 && {!((_payload select 4) isEqualType "")}) then { _payloadMalformed = true; };
    if ((count _payload) > 5 && {!((_payload select 5) isEqualType "")}) then { _payloadMalformed = true; };
    if ((count _payload) > 6 && {!((_payload select 6) isEqualType [])}) then { _payloadMalformed = true; };
};

if (_payloadMalformed) then
{
    diag_log format ["[ARC][INTEL][LOG] Malformed payload received for ARC_fnc_tocRequestLogIntel; raw=%1", str _rawPayload];
};

if ((count _payload) <= 0 || {!((_payload select 0) isEqualType objNull)}) then { _payload set [0, objNull]; };
if ((count _payload) <= 1 || {!((_payload select 1) isEqualType "")}) then { _payload set [1, "UNKNOWN"]; };
if ((count _payload) <= 2 || {!((_payload select 2) isEqualType "")}) then { _payload set [2, "SIGHTING"]; };
if ((count _payload) <= 3 || {!((_payload select 3) isEqualType [])}) then { _payload set [3, [0,0,0]]; };
if ((count _payload) <= 4 || {!((_payload select 4) isEqualType "")}) then { _payload set [4, ""]; };
if ((count _payload) <= 5 || {!((_payload select 5) isEqualType "")}) then { _payload set [5, ""]; };
if ((count _payload) <= 6 || {!((_payload select 6) isEqualType [])}) then { _payload set [6, []]; };

_payload params [
    ["_caller", objNull, [objNull]],
    ["_reporter", "UNKNOWN", [""]],
    ["_category", "SIGHTING", [""]],
    ["_pos", [0,0,0], [[]]],
    ["_noteSummary", "", [""]],
    ["_noteDetails", "", [""]],
    ["_metaExtra", [], [[]]]
];

private _callerName = if (isNull _caller) then { "UNKNOWN" } else { name _caller };
private _callerUID = if (isNull _caller) then { "" } else { getPlayerUID _caller };

private _posATL = [0,0,0];
private _posIsRecoverable = true;
if (_pos isEqualType []) then
{
    if ((count _pos) >= 2) then
    {
        _posATL set [0, if ((_pos select 0) isEqualType 0) then { _pos select 0 } else { 0 }];
        _posATL set [1, if ((_pos select 1) isEqualType 0) then { _pos select 1 } else { 0 }];
        _posATL set [2, if ((count _pos) > 2 && {(_pos select 2) isEqualType 0}) then { _pos select 2 } else { 0 }];

        if (!((_pos select 0) isEqualType 0) || {!((_pos select 1) isEqualType 0)} || {((count _pos) > 2) && {!((_pos select 2) isEqualType 0)}}) then
        {
            diag_log format ["[ARC][INTEL][LOG] Invalid numeric position payload normalized to [0,0,0] | caller=%1 | uid=%2 | rawPos=%3", _callerName, _callerUID, str _pos];
        };
    }
    else
    {
        _posIsRecoverable = false;
    };
}
else
{
    _posIsRecoverable = false;
};

if (!_posIsRecoverable) then
{
    _posATL = [0,0,0];
    diag_log format ["[ARC][INTEL][LOG] Invalid position payload normalized to safe default | caller=%1 | uid=%2 | rawPos=%3", _callerName, _callerUID, str _pos];
};

// RemoteExec-only validation path: requires remoteExecutedOwner context.
if (!([_caller, "ARC_fnc_tocRequestLogIntel", "Intel log rejected: sender verification failed.", "TOC_LOG_INTEL_SECURITY_DENIED", true] call ARC_fnc_rpcValidateSender)) exitWith {false};

if (!_posIsRecoverable && {_callerName isEqualTo "UNKNOWN" && {_callerUID isEqualTo ""}}) exitWith
{
    diag_log "[ARC][INTEL][LOG] Rejecting irrecoverable intel payload: invalid caller context and position payload.";
    false
};

if (_reporter isEqualTo "") then { _reporter = "UNKNOWN"; };
if (_category isEqualTo "") then { _category = "SIGHTING"; };
if (!(_noteSummary isEqualType "")) then { _noteSummary = ""; };
if (!(_noteDetails isEqualType "")) then { _noteDetails = ""; };
if (!(_metaExtra isEqualType [])) then { _metaExtra = []; };

private _grid = mapGridPosition _posATL;
private _zone = [_posATL] call ARC_fnc_worldGetZoneForPos;

if (_zone isEqualTo "") then { _zone = "Unzoned"; };

// RPT trace (helps triage client map-click issues)
diag_log format ["[ARC][INTEL][LOG] Request accepted | reporter=%1 | caller=%2 | cat=%3 | grid=%4 | zone=%5 | sum=%6", _reporter, _callerName, toUpper _category, _grid, _zone, _noteSummary];

private _catU = toUpper _category;
private _summary = "";

// If a note was provided, use it as the human-readable core of the entry.
if (!(([_noteSummary] call _trimFn) isEqualTo "")) then
{
    private _prefix = switch (_catU) do
    {
        case "HUMINT": { "HUMINT TIP" };
        case "ISR": { "ISR" };
        case "SIGHTING": { "SIGHTING" };
        default { _catU };
    };

    _summary = format ["%1: %2 (Reported by %3). Grid %4. Zone: %5.", _prefix, [_noteSummary] call _trimFn, _reporter, _grid, _zone];
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
    ["event", "PLAYER_INTEL"],
    ["callerName", _callerName],
    ["callerUID", _callerUID]
];

if (!(([_noteDetails] call _trimFn) isEqualTo "")) then
{
    _meta pushBack ["details", [_noteDetails] call _trimFn];
};

// Merge any additional meta pairs
{
    if (_x isEqualType [] && { (count _x) >= 2 }) then
    {
        _meta pushBack [_x select 0, _x select 1];
    };
} forEach _metaExtra;

// If close to active incident, link it
private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
private _marker = ["activeIncidentMarker", ""] call ARC_fnc_stateGet;

if (!(_taskId isEqualTo "") && {!(_marker isEqualTo ""})) then
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

private _foundConfidence = false;
{ if ((_x select 0) isEqualTo "confidence") exitWith { _foundConfidence = true; }; } forEach _meta;
if (!_foundConfidence) then
{
    _meta pushBack ["confidence", "UNVERIFIED"]; // TOC reports outside the active incident area
};

[_catU, _summary, _posATL, _meta] call ARC_fnc_intelLog;
true

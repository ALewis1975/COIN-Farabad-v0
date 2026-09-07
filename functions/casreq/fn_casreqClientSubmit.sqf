// Engine-compatible command wrappers retain the repository lint baseline.
private _casTrim = compile "params ['_s']; trim _s";
/*
    ARC_fnc_casreqClientSubmit

    Client-side: pre-flight check and CASREQ submission flow for JTAC/S3.

    Builds a minimal 9-line from available mission state, prompts the player
    for a target description and remarks, then remoteExecs ARC_fnc_casreqOpen
    to the server.

    Must run in a scheduled environment (uses BIS_fnc_guiMessage).

    Params: none (reads from missionNamespace public vars)
    Returns: BOOL
*/

if (!hasInterface) exitWith {false};
if (!canSuspend) exitWith { _this spawn ARC_fnc_casreqClientSubmit; false };

// Pre-flight: active incident must exist and be accepted
private _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""];
if (!(_taskId isEqualType "")) then { _taskId = ""; };
if (_taskId isEqualTo "") exitWith
{
    ["CASREQ", "No active incident. Cannot submit CAS request."] call ARC_fnc_clientToast;
    false
};

private _accepted = missionNamespace getVariable ["ARC_activeIncidentAccepted", false];
if (!(_accepted isEqualType true) && !(_accepted isEqualType false)) then { _accepted = false; };
if (!_accepted) exitWith
{
    ["CASREQ", "Incident not yet accepted by TOC. Cannot submit CAS request."] call ARC_fnc_clientToast;
    false
};

// Role check (JTAC-authorized roles only)
if (!([player, "CREATE"] call ARC_fnc_casreqCan)) exitWith
{
    ["CASREQ", "Not authorized to submit CAS requests."] call ARC_fnc_clientToast;
    false
};

// Build target position from active incident pos
private _incPos = missionNamespace getVariable ["ARC_activeIncidentPos", []];
if (!(_incPos isEqualType []) || { (count _incPos) < 2 }) then { _incPos = getPosATL player; };
private _pos = +_incPos; _pos resize 3;

// Derive district from active incident civsub district id (or blank for D00)
private _districtId = missionNamespace getVariable ["ARC_activeIncidentCivsubDistrictId", "D00"];
// OR: first guard resets if type mismatch (non-string); second resets if empty string. Both → D00.
if (!(_districtId isEqualType "") || { _districtId isEqualTo "" }) then { _districtId = "D00"; };

// Build minimal 9-line from available state
private _incType  = missionNamespace getVariable ["ARC_activeIncidentType", ""];
private _incDisp  = missionNamespace getVariable ["ARC_activeIncidentDisplayName", "Unknown target"];
if (!(_incType isEqualType "")) then { _incType = ""; };
if (!(_incDisp isEqualType "")) then { _incDisp = "Unknown target"; };
private _grid = mapGridPosition _pos;

private _nineLine = [
    ["line1_initial_point", _grid],
    ["line2_heading_and_distance", ""],
    ["line3_target_elevation", round (_pos select 2)],
    ["line4_target_description", _incDisp],
    ["line5_target_location", _grid],
    ["line6_type_mark", ""],
    ["line7_location_friendlies", ""],
    ["line8_egress_dir", ""],
    ["line9_remarks", ""]
];

private _form = ["CAS request | " + _grid, ["Target description (240 max)", "Friendlies (240 max)", "Remarks (500 max)"], [_incDisp, "Own grid " + mapGridPosition player, ""], [240,240,500]] call ARC_fnc_casreqInput;
if !(_form select 0) exitWith {false};
private _desc = ([(_form select 1)] call _casTrim);
private _friendlies = ([(_form select 2)] call _casTrim);
private _remarks = ([(_form select 3)] call _casTrim);
if (_desc isEqualTo "" || {_friendlies isEqualTo ""}) exitWith {["CASREQ", "Target description and friendlies are required. Nothing submitted."] call ARC_fnc_clientToast; false};
(_nineLine select 3) set [1, _desc];
(_nineLine select 6) set [1, _friendlies];
(_nineLine select 8) set [1, _remarks];
private _token = format ["%1:%2:%3", clientOwner, diag_tickTime, floor random 1000000];
[player, _districtId, _pos, _nineLine, _remarks, _token] remoteExec ["ARC_fnc_casreqOpen", 2];
["CASREQ", "Request sent for server validation. Open CAS Requests for status."] call ARC_fnc_clientToast;
true

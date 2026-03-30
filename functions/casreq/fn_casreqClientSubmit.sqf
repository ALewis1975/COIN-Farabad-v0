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
if (!([player] call ARC_fnc_rolesIsAuthorized) && { !([player] call ARC_fnc_rolesCanApproveQueue) }) exitWith
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

// Summary display for confirmation
private _lines = [
    format ["Task: %1", _taskId],
    format ["Target: %1 (%2)", _incDisp, _incType],
    format ["Grid: %1", _grid],
    "",
    "Submitting CAS request will require TOC approval.",
    "Enter target description and remarks when prompted."
];
private _summary = _lines joinString "\n";

private _ok = [_summary, "Submit CAS Request", true, true] call BIS_fnc_guiMessage;
if (!_ok) exitWith { false };

// Prompt for target description override
private _descPrompt = [format ["Target description (default: %1):", _incDisp], _incDisp] call BIS_fnc_guiMessage;
if (_descPrompt isEqualType "") then
{
    if (!(_descPrompt isEqualTo "")) then
    {
        private _dIdx = -1;
        { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "line4_target_description" }) exitWith { _dIdx = _forEachIndex; }; } forEach _nineLine;
        if (_dIdx >= 0) then { (_nineLine select _dIdx) set [1, _descPrompt]; };
    };
};

// Prompt for remarks
private _remarksPrompt = ["Remarks (optional):", ""] call BIS_fnc_guiMessage;
private _remarks = if (_remarksPrompt isEqualType "") then { _remarksPrompt } else { "" };
private _trimFn = compile "params ['_s']; trim _s";
_remarks = [_remarks] call _trimFn;

// Update line9 with remarks
private _r9Idx = -1;
{ if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "line9_remarks" }) exitWith { _r9Idx = _forEachIndex; }; } forEach _nineLine;
if (_r9Idx >= 0 && { !(_remarks isEqualTo "") }) then { (_nineLine select _r9Idx) set [1, _remarks]; };

// Send to server
[player, _districtId, _pos, _nineLine, _remarks] remoteExec ["ARC_fnc_casreqOpen", 2];

["CASREQ", "CAS request submitted. Awaiting TOC decision."] call ARC_fnc_clientToast;
true

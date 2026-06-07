/*
    ARC_fnc_casreqJtacPrefill

    Client-side: RAVEN JTAC laser/marker → CASREQ 9-line prefill.

    Derives a target position from the JTAC's current marking context
    (laser designator target first, cursor target as fallback), seeds a
    9-line with sensible, editable defaults (target grid/elevation, marking
    method, line-of-friendlies relative to the JTAC), lets the JTAC confirm
    and override the target description and remarks, then remoteExecs the
    existing ARC_fnc_casreqOpen path so the prefilled CAS:Dxx record reaches
    the pilot inbox via ARC_pub_casreqBundle.

    Reuses (does not duplicate) the server role gate, ID builder, broadcast
    and BDA-close plumbing already provided by the CASREQ subsystem.

    Must run in a scheduled environment (uses BIS_fnc_guiMessage).

    Params: none (reads from the player's marking context + mission state)
    Returns: BOOL
*/

if (!hasInterface) exitWith {false};
if (!canSuspend) exitWith { _this spawn ARC_fnc_casreqJtacPrefill; false };

// Feature flag (client-gated; seeded server-side and broadcast)
if (!(missionNamespace getVariable ["ARC_casreqJtacPrefillEnabled", true])) exitWith
{
    ["CASREQ", "JTAC CAS prefill is disabled."] call ARC_fnc_clientToast;
    false
};

// Role check (JTAC-authorized roles only) — mirror of fn_casreqClientSubmit.
if (!([player] call ARC_fnc_rolesIsAuthorized) && { !([player] call ARC_fnc_rolesCanApproveQueue) }) exitWith
{
    ["CASREQ", "Not authorized to submit CAS requests."] call ARC_fnc_clientToast;
    false
};

// Derive target from the JTAC marking context.
// Priority: active laser designator target → cursor target.
private _markObj = laserTarget player;
if (isNull _markObj) then { _markObj = laserTarget (vehicle player); };

private _markMethod = "";
if (!isNull _markObj) then
{
    _markMethod = "LASER";
}
else
{
    _markObj = cursorTarget;
    if (!isNull _markObj) then { _markMethod = "VISUAL (CURSOR)"; };
};

if (isNull _markObj) exitWith
{
    ["CASREQ", "No target marked. Lase or aim at a target, then retry."] call ARC_fnc_clientToast;
    false
};

private _pos = getPosATL _markObj;
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = getPosATL player; };
_pos = +_pos; _pos resize 3;

// Derive district from active incident civsub district id (or blank for D00),
// matching fn_casreqClientSubmit's resolution.
private _districtId = missionNamespace getVariable ["ARC_activeIncidentCivsubDistrictId", "D00"];
if (!(_districtId isEqualType "") || { _districtId isEqualTo "" }) then { _districtId = "D00"; };

private _grid = mapGridPosition _pos;
private _isLaserMark = _markMethod isEqualTo "LASER";
private _isrConfidence = if (_isLaserMark) then { "HIGH" } else { "MED" };

// Default target description: prefer the marked object's display name.
private _desc = "JTAC-marked target";
private _typeName = if (!isNull _markObj) then { typeOf _markObj } else { "" };
if (_typeName isEqualType "" && { !(_typeName isEqualTo "") }) then
{
    private _disp = getText (configFile >> "CfgVehicles" >> _typeName >> "displayName");
    if (_disp isEqualType "" && { !(_disp isEqualTo "") }) then { _desc = _disp; };
};

// Default line-of-friendlies: JTAC own position relative to the target.
private _friendDir = _pos getDir player;
private _friendDist = round (_pos distance2D player);
private _cardinals = ["N","NE","E","SE","S","SW","W","NW"];
private _cardIdx = floor (((_friendDir + 22.5) mod 360) / 45);
if (_cardIdx < 0 || _cardIdx > 7) then { _cardIdx = 0; };
private _friendCard = _cardinals select _cardIdx;
private _friendDefault = format ["JTAC own pos %1m %2 of target", _friendDist, _friendCard];

private _nineLine = [
    ["line1_initial_point", _grid],
    ["line2_heading_and_distance", ""],
    ["line3_target_elevation", round (_pos select 2)],
    ["line4_target_description", _desc],
    ["line5_target_location", _grid],
    ["line6_type_mark", _markMethod],
    ["line7_location_friendlies", _friendDefault],
    ["line8_egress_dir", ""],
    ["line9_remarks", ""]
];

// Confirmation summary.
private _lines = [
    format ["Marking: %1", _markMethod],
    format ["Target: %1", _desc],
    format ["Grid: %1  Elev: %2m", _grid, round (_pos select 2)],
    format ["Friendlies: %1", _friendDefault],
    "",
    "Submitting prefilled CAS request will require TOC approval.",
    "Confirm or override target description and remarks when prompted."
];
private _summary = _lines joinString "\n";

private _ok = [_summary, "JTAC CAS Prefill", true, true] call BIS_fnc_guiMessage;
if (!_ok) exitWith { false };

// Editable default: target description.
private _descPrompt = [format ["Target description (default: %1):", _desc], _desc] call BIS_fnc_guiMessage;
if (_descPrompt isEqualType "" && { !(_descPrompt isEqualTo "") }) then
{
    private _dIdx = -1;
    { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "line4_target_description" }) exitWith { _dIdx = _forEachIndex; }; } forEach _nineLine;
    if (_dIdx >= 0) then { (_nineLine select _dIdx) set [1, _descPrompt]; };
};

// Editable default: line-of-friendlies.
private _friendPrompt = [format ["Friendlies (default: %1):", _friendDefault], _friendDefault] call BIS_fnc_guiMessage;
if (_friendPrompt isEqualType "" && { !(_friendPrompt isEqualTo "") }) then
{
    private _fIdx = -1;
    { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "line7_location_friendlies" }) exitWith { _fIdx = _forEachIndex; }; } forEach _nineLine;
    if (_fIdx >= 0) then { (_nineLine select _fIdx) set [1, _friendPrompt]; };
};

// Remarks (optional).
private _trimFn = compile "params ['_s']; trim _s";
private _remarksPrompt = ["Remarks (optional):", ""] call BIS_fnc_guiMessage;
private _remarks = if (_remarksPrompt isEqualType "") then { _remarksPrompt } else { "" };
_remarks = [_remarks] call _trimFn;
private _isrMeta = format ["ISR source: RAVEN_JTAC; confidence: %1; marking: %2", _isrConfidence, _markMethod];
if (_remarks isEqualTo "") then { _remarks = _isrMeta; } else { _remarks = _remarks + "; " + _isrMeta; };

private _r9Idx = -1;
{ if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "line9_remarks" }) exitWith { _r9Idx = _forEachIndex; }; } forEach _nineLine;
if (_r9Idx >= 0 && { !(_remarks isEqualTo "") }) then { (_nineLine select _r9Idx) set [1, _remarks]; };

// Send to server via the existing, unchanged CASREQ open path.
[player, _districtId, _pos, _nineLine, _remarks] remoteExec ["ARC_fnc_casreqOpen", 2];

["CASREQ", "JTAC CAS prefill submitted. Awaiting TOC decision."] call ARC_fnc_clientToast;
true

// Engine-compatible command wrappers retain the repository lint baseline.
private _casTrim = compile "params ['_s']; trim _s";
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
if (!([player, "CREATE"] call ARC_fnc_casreqCan)) exitWith
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

private _form = ["JTAC CAS | " + _grid + " | " + _markMethod, ["Target description (240 max)", "Friendlies (240 max)", "Remarks (400 max; sensor context appended)"], [_desc, _friendDefault, ""], [240,240,400]] call ARC_fnc_casreqInput;
if !(_form select 0) exitWith {false};
_desc = ([(_form select 1)] call _casTrim);
private _friendlies = ([(_form select 2)] call _casTrim);
private _remarks = ([(_form select 3)] call _casTrim);
if (_desc isEqualTo "" || {_friendlies isEqualTo ""}) exitWith {["CASREQ", "Target description and friendlies are required. Nothing submitted."] call ARC_fnc_clientToast; false};
private _isrMeta = format ["ISR source: RAVEN_JTAC; confidence: %1; marking: %2", _isrConfidence, _markMethod];
_remarks = if (_remarks isEqualTo "") then {_isrMeta} else {_remarks + "; " + _isrMeta};
(_nineLine select 3) set [1, _desc];
(_nineLine select 6) set [1, _friendlies];
(_nineLine select 8) set [1, _remarks];
private _token = format ["%1:%2:%3", clientOwner, diag_tickTime, floor random 1000000];
// Existing compact intake remains the only request creation path.
[player, _districtId, _pos, _nineLine, _remarks, _token] remoteExec ["ARC_fnc_casreqOpen", 2];
["CASREQ", "Request sent for server validation. Open CAS Requests for status."] call ARC_fnc_clientToast;
true

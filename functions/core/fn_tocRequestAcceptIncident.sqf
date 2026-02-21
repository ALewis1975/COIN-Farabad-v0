/*
    Server: TOC accepts the currently assigned incident.

    Design intent:
      - Incident assignment (Generate Next Incident) creates a task in CREATED state.
      - Acceptance promotes the task to ASSIGNED and begins execution (timers, spawning
        physical objectives, convoy spawning, etc.).

    Params:
        0: OBJECT - caller (optional)

    Returns:
        BOOL
*/

if (!isServer) exitWith {false};

// sqflint-compat helpers
private _trimFn     = compile "params ['_s']; trim _s";
private _hg         = compile "params ['_h','_k','_d']; [(_h), _k, _d] call _hg";
private _hmFrom   = compile "params ['_pairs']; private _r = createHashMap; { _r set [_x select 0, _x select 1]; } forEach _pairs; _r";

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\\core\\fn_rpcValidateSender.sqf"; };

// Fail-safe: ensure role helper functions exist even if CfgFunctions.hpp was not updated.
if (isNil "ARC_fnc_rolesIsAuthorized") then { ARC_fnc_rolesIsAuthorized = compile preprocessFileLineNumbers "functions\\core\\fn_rolesIsAuthorized.sqf"; };
if (isNil "ARC_fnc_rolesGetTag") then { ARC_fnc_rolesGetTag = compile preprocessFileLineNumbers "functions\\core\\fn_rolesGetTag.sqf"; };
if (isNil "ARC_fnc_rolesFormatUnit") then { ARC_fnc_rolesFormatUnit = compile preprocessFileLineNumbers "functions\\core\\fn_rolesFormatUnit.sqf"; };

params [
    ["_caller", objNull],
    ["_statusRequest", ""]
];

// RemoteExec-only validation path: requires remoteExecutedOwner context.
if (!([_caller, "ARC_fnc_tocRequestAcceptIncident", "Incident acceptance rejected: sender verification failed.", "TOC_ACCEPT_INCIDENT_SECURITY_DENIED", true] call ARC_fnc_rpcValidateSender)) exitWith {false};

// Role-gated task acceptance (RHSUSAF Officer / Squad Leader classnames).
if (!isNull _caller && { !([_caller] call ARC_fnc_rolesIsAuthorized) }) exitWith
{
    private _whoBad = [_caller] call ARC_fnc_rolesFormatUnit;
    diag_log format ["[ARC][TOC] Rejecting task acceptance from unauthorized role: %1", _whoBad];
    ["You are not authorized to accept ARC tasks. Authorized: RHSUSAF Officer / Squad Leader classnames."] remoteExec ["ARC_fnc_clientHint", owner _caller];
    ["INCIDENT_ACCEPT", "REJECTED", "You are not authorized for incident acceptance."] remoteExec ["ARC_fnc_uiConsoleOpsActionStatus", owner _caller];
    false
};

if (!(_statusRequest isEqualType "")) then { _statusRequest = ""; };
_statusRequest = toUpper ([_statusRequest] call _trimFn);
private _statusCatalog = ["OFFLINE", "AVAILABLE", "IN TRANSIT", "ON SCENE"];
private _setGroupStatus = {
    params ["_gid", "_status", ["_who", ""]];
    if (!(_gid isEqualType "") || { _gid isEqualTo "" }) exitWith { false };
    if (!(_status isEqualType "") || { !(_status in _statusCatalog) }) exitWith { false };

    private _rows = missionNamespace getVariable ["ARC_pub_unitStatuses", []];
    if (!(_rows isEqualType [])) then { _rows = []; };

    private _idx = -1;
    { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _gid }) exitWith { _idx = _forEachIndex; }; } forEach _rows;
    private _row = [_gid, _status, serverTime, _who];
    if (_idx < 0) then { _rows pushBack _row; } else { _rows set [_idx, _row]; };
    missionNamespace setVariable ["ARC_pub_unitStatuses", _rows, true];
    true
};

if (_statusRequest in ["OFFLINE", "AVAILABLE"]) exitWith
{
    private _gidReq = if (isNull _caller) then {""} else { groupId (group _caller) };
    if (_gidReq isEqualTo "") exitWith {false};
    private _whoReq = if (isNull _caller) then {"TOC"} else { [_caller] call ARC_fnc_rolesFormatUnit };
    [_gidReq, _statusRequest, _whoReq] call _setGroupStatus
};

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (_taskId isEqualTo "") exitWith
{
    if (!isNull _caller) then
    {
        ["INCIDENT_ACCEPT", "REJECTED", "No active incident is pending acceptance."] remoteExec ["ARC_fnc_uiConsoleOpsActionStatus", owner _caller];
    };
    false
};

private _already = ["activeIncidentAccepted", false] call ARC_fnc_stateGet;
if (_already isEqualType true && { _already }) exitWith
{
    if (!isNull _caller) then
    {
        ["INCIDENT_ACCEPT", "REJECTED", "Incident already accepted."] remoteExec ["ARC_fnc_uiConsoleOpsActionStatus", owner _caller];
    };
    false
};

private _callerGroup = if (isNull _caller) then {""} else { groupId (group _caller) };
if (_callerGroup isEqualTo "") exitWith {false};
private _unitStatuses = missionNamespace getVariable ["ARC_pub_unitStatuses", []];
if (!(_unitStatuses isEqualType [])) then { _unitStatuses = []; };
private _statusIdx = -1;
{ if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _callerGroup }) exitWith { _statusIdx = _forEachIndex; }; } forEach _unitStatuses;
private _statusNow = if (_statusIdx < 0) then { "OFFLINE" } else { toUpper ([((_unitStatuses select _statusIdx)] call _trimFn select 1)) };
if (!(_statusNow isEqualTo "AVAILABLE")) exitWith
{
    ["Incident acceptance denied: your group must set status to AVAILABLE first."] remoteExec ["ARC_fnc_clientHint", owner _caller];
    ["INCIDENT_ACCEPT", "REJECTED", "Set group status to AVAILABLE, then retry."] remoteExec ["ARC_fnc_uiConsoleOpsActionStatus", owner _caller];
    false
};

// Mark accepted
["activeIncidentAccepted", true] call ARC_fnc_stateSet;
["activeIncidentAcceptedAt", serverTime] call ARC_fnc_stateSet;


// --- CIVSUB Phase 6 closeout: capture incident window start snapshot (baseline A.6)
// We capture influence and key counters at acceptance so SITREPs can report start/end/delta.
if (missionNamespace getVariable ["civsub_v1_enabled", false]) then
{
    private _ipos = ["activeIncidentPos", []] call ARC_fnc_stateGet;
    private _did = ["activeIncidentCivsubDistrictId", ""] call ARC_fnc_stateGet;
    if !(_did isEqualType "") then { _did = ""; };

    if (_did isEqualTo "" && { _ipos isEqualType [] && { count _ipos >= 2 } }) then
    {
        _did = [_ipos] call ARC_fnc_civsubDistrictsFindByPos;
        if (_did isEqualType "" && { !(_did isEqualTo "") }) then
        {
            ["activeIncidentCivsubDistrictId", _did] call ARC_fnc_stateSet;
            missionNamespace setVariable ["ARC_activeIncidentCivsubDistrictId", _did, true];
        };
    };

    if (_did isEqualType "" && { !(_did isEqualTo "") }) then
    {
        private _d = [_did] call ARC_fnc_civsubDistrictsGetById;
        if (_d isEqualType createHashMap) then
        {
            private _snap = [[
                ["districtId", _did],
                ["ts", serverTime],
                ["W", [_d, "W_EFF_U", 0] call _hg],
                ["R", [_d, "R_EFF_U", 0] call _hg],
                ["G", [_d, "G_EFF_U", 0] call _hg],
                ["civ_cas_kia", [_d, "civ_cas_kia", 0] call _hg],
                ["civ_cas_wia", [_d, "civ_cas_wia", 0] call _hg],
                ["crime_db_hits", [_d, "crime_db_hits", 0] call _hg],
                ["detentions_initiated", [_d, "detentions_initiated", 0] call _hg],
                ["detentions_handed_off", [_d, "detentions_handed_off", 0] call _hg],
                ["aid_events", [_d, "aid_events", 0] call _hg]
            ]] call _hmFrom;

            ["activeIncidentCivsubStart", _snap] call ARC_fnc_stateSet;
            missionNamespace setVariable ["ARC_activeIncidentCivsubStart", _snap, true];
        };
    };
};

// Record who accepted (for audit / deconfliction).
private _acceptedBy = if (isNull _caller) then {"TOC"} else { [_caller] call ARC_fnc_rolesFormatUnit };
["activeIncidentAcceptedBy", _acceptedBy] call ARC_fnc_stateSet;
["activeIncidentAcceptedByName", if (isNull _caller) then {"TOC"} else { name _caller }] call ARC_fnc_stateSet;
["activeIncidentAcceptedByUID", if (isNull _caller) then {""} else { getPlayerUID _caller }] call ARC_fnc_stateSet;
["activeIncidentAcceptedByRoleTag", if (isNull _caller) then {""} else { [_caller] call ARC_fnc_rolesGetTag }] call ARC_fnc_stateSet;
["activeIncidentAcceptedByGroup", if (isNull _caller) then {""} else { groupId (group _caller) }] call ARC_fnc_stateSet;

// Remember last tasked group (used for follow-on orders when no incident is active).
private _lastG = if (isNull _caller) then {""} else { groupId (group _caller) };
if (!(_lastG isEqualTo "")) then
{
    [_lastG, "IN TRANSIT", _acceptedBy] call _setGroupStatus;
    ["lastTaskingGroup", _lastG] call ARC_fnc_stateSet;
    ["lastTaskingGroupAt", serverTime] call ARC_fnc_stateSet;
};

// If a "Hold: Main Position" (or any HOLD) order is currently ACCEPTED for this group,
// auto-complete it now. HOLD is intended to be an "until new tasking" order; without an
// auto-complete hook it becomes a dead task and can confuse follow-on logic.
if (!(_lastG isEqualTo "")) then
{
    private _ords = ["tocOrders", []] call ARC_fnc_stateGet;
    if (!(_ords isEqualType [])) then { _ords = []; };

    private _changed = false;
    {
        if (!(_x isEqualType []) || { (count _x) < 7 }) then { continue; };
        _x params ["_orderId", "_issuedAt", "_status", "_orderType", "_tgtGroup", "_data", "_meta"];

        if (!(_tgtGroup isEqualType "") || { _tgtGroup isEqualTo "" }) then { continue; };
        if (!(_tgtGroup isEqualTo _lastG)) then { continue; };
        if (!(toUpper _orderType isEqualTo "HOLD")) then { continue; };
        if (!(toUpper _status isEqualTo "ACCEPTED")) then { continue; };

        // Mark the associated task as succeeded (orderId is the taskId used in fn_intelOrderAccept).
        private _tid = _orderId;
        if (_tid isEqualType "" && { !(_tid isEqualTo "") }) then
        {
            [_tid, "SUCCEEDED", true] call BIS_fnc_taskSetState;
        };

        _x set [2, "COMPLETED"];

        // Add completion meta for audit.
        if (!(_meta isEqualType [])) then { _meta = []; };
        _meta pushBack ["completedAt", serverTime];
        _meta pushBack ["completedReason", "NEW_INCIDENT_ACCEPTED"];
        _meta pushBack ["supersededByTaskId", _taskId];
        _x set [6, _meta];

        _ords set [_forEachIndex, _x];
        _changed = true;

        ["OPS", format ["Auto-completed HOLD order %1 for %2 on new incident acceptance.", _orderId, _lastG], [0,0,0], [["event","ORDER_HOLD_AUTOCOMPLETE"],["orderId",_orderId],["taskId",_taskId],["group",_lastG]]] call ARC_fnc_intelLog;
    } forEach _ords;

    if (_changed) then
    {
        ["tocOrders", _ords] call ARC_fnc_stateSet;
        [] call ARC_fnc_intelBroadcast;
    };
};

missionNamespace setVariable ["ARC_activeIncidentAccepted", true, true];
missionNamespace setVariable ["ARC_activeIncidentAcceptedAt", serverTime, true];
missionNamespace setVariable ["ARC_activeIncidentAcceptedByGroup", _lastG, true];

// Apply a small sustainment cost for launching a mission.
// This works with the over-time sustainment drain to create steady logistics pressure.
private _type = ["activeIncidentType", ""] call ARC_fnc_stateGet;
private _typeU = toUpper _type;

private _fuel = ["baseFuel", 0.38] call ARC_fnc_stateGet;
private _ammo = ["baseAmmo", 0.32] call ARC_fnc_stateGet;
private _med  = ["baseMed", 0.40] call ARC_fnc_stateGet;

private _nBlu = count (allPlayers select { alive _x && { side group _x in [west, independent] } });
if (_nBlu < 1) then { _nBlu = 1; };
private _scale = 1 + (((_nBlu - 1) max 0) * 0.05);
_scale = _scale min 2.5;

private _cFuel = 0.010;
private _cAmmo = 0.008;
private _cMed  = 0.004;

switch (_typeU) do
{
    case "LOGISTICS":      { _cFuel = 0.012; _cAmmo = 0.004; _cMed = 0.003; };
    case "ESCORT":         { _cFuel = 0.013; _cAmmo = 0.005; _cMed = 0.003; };
    case "PATROL":         { _cFuel = 0.010; _cAmmo = 0.006; _cMed = 0.003; };
    case "RECON":          { _cFuel = 0.009; _cAmmo = 0.004; _cMed = 0.002; };
    case "CHECKPOINT":     { _cFuel = 0.008; _cAmmo = 0.006; _cMed = 0.003; };
    case "CIVIL":          { _cFuel = 0.009; _cAmmo = 0.003; _cMed = 0.003; };
    case "IED":            { _cFuel = 0.011; _cAmmo = 0.010; _cMed = 0.004; };
    case "RAID":           { _cFuel = 0.012; _cAmmo = 0.012; _cMed = 0.005; };
    case "DEFEND":         { _cFuel = 0.010; _cAmmo = 0.014; _cMed = 0.006; };
    case "QRF":            { _cFuel = 0.013; _cAmmo = 0.012; _cMed = 0.006; };
    case "CMDNODE_RAID":   { _cFuel = 0.012; _cAmmo = 0.012; _cMed = 0.005; };
    case "CMDNODE_MEET":   { _cFuel = 0.010; _cAmmo = 0.005; _cMed = 0.004; };
    case "CMDNODE_INTERCEPT": { _cFuel = 0.013; _cAmmo = 0.010; _cMed = 0.005; };
    default {};
};

_cFuel = _cFuel * _scale;
_cAmmo = _cAmmo * _scale;
_cMed  = _cMed  * _scale;

private _fuelNew = (_fuel - _cFuel) max 0;
private _ammoNew = (_ammo - _cAmmo) max 0;
private _medNew  = (_med  - _cMed) max 0;

["baseFuel", _fuelNew] call ARC_fnc_stateSet;
["baseAmmo", _ammoNew] call ARC_fnc_stateSet;
["baseMed", _medNew] call ARC_fnc_stateSet;

// Promote task state
[] call ARC_fnc_taskRehydrateActive;
	[_taskId, "ASSIGNED", false] call BIS_fnc_taskSetState;

	private _execKind = ["activeExecKind", ""] call ARC_fnc_stateGet;
	if (!(_execKind isEqualType "")) then { _execKind = ""; };

	// Current task is local per-client. Broadcast the parent incident task as current,
	// except for exec types that immediately create their own actionable child tasks (e.g., ROUTE_RECON).
	if (!(_taskId isEqualTo "") && { !(_execKind isEqualTo "ROUTE_RECON") }) then
	{
	    private _re = [_taskId] remoteExecCall ["ARC_fnc_clientSetCurrentTask", 0];
    if (isNil { _re }) then
    {
        diag_log format ["[ARC][WARN] remoteExecCall ARC_fnc_clientSetCurrentTask failed (taskId=%1)", _taskId];
    };
	};

// Build (and now spawn) the execution package.
[] call ARC_fnc_execInitActive;

// IED abandonment warning: these tasks are intended to be resolved, not left unattended.
if (_typeU isEqualTo "IED") then
{
    private _warn = "WARNING: This is an active IED incident. Do not abandon it. If left unattended, the device may detonate and trigger a post-blast response with negative campaign effects.";
    {
        if (alive _x && { side group _x in [west, independent] }) then
        {
            [_warn] remoteExec ["ARC_fnc_clientHint", _x];
        };
    } forEach allPlayers;
};

// Log
private _who = if (isNull _caller) then {"TOC"} else { [_caller] call ARC_fnc_rolesFormatUnit };
private _pos = ["activeIncidentPos", []] call ARC_fnc_stateGet;
private _msg = format ["Task accepted by %1. Launch cost applied (Fuel -%2, Ammo -%3, Med -%4).", _who, _cFuel toFixed 3, _cAmmo toFixed 3, _cMed toFixed 3];
if (_pos isEqualType [] && { (count _pos) >= 2 }) then
{
    ["OPS", _msg, _pos, [["taskId", _taskId], ["event", "INCIDENT_ACCEPTED"], ["incidentType", _typeU], ["acceptedBy", _who]]] call ARC_fnc_intelLog;
}
else
{
    ["OPS", _msg, [0,0,0], [["taskId", _taskId], ["event", "INCIDENT_ACCEPTED"], ["incidentType", _typeU], ["acceptedBy", _who]]] call ARC_fnc_intelLog;
};

[] call ARC_fnc_taskUpdateActiveDescription;
[] call ARC_fnc_publicBroadcastState;

// Visual prompt so players immediately know the incident moved from "pending" to "active".
private _disp = ["activeIncidentDisplayName", "Incident"] call ARC_fnc_stateGet;
if (!(_disp isEqualType "")) then { _disp = "Incident"; };
private _gridTxt = "";
if (_pos isEqualType [] && { (count _pos) >= 2 }) then { _gridTxt = mapGridPosition _pos; };
[
    "Incident Accepted",
    format ["%1 (%2) active. Accepted by %3%4", _disp, _typeU, _who, if (_gridTxt isEqualTo "") then {""} else {format [" at %1", _gridTxt]}],
    8
] remoteExec ["ARC_fnc_clientToast", 0];

if (!isNull _caller) then
{
    ["INCIDENT_ACCEPT", "ACCEPTED", "Incident accepted and moved to active execution."] remoteExec ["ARC_fnc_uiConsoleOpsActionStatus", owner _caller];
};

true

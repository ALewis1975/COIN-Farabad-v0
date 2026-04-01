/*
    Creates a new incident task (if none is active).
    Pulls from data\incident_markers.sqf.

    Params:
      0: STRING seedLeadId (optional) - if provided, consume this specific lead rather than
         relying on an accepted LEAD order or the catalog. Used by the INCIDENT queue handler.
*/

if (!isServer) exitWith {false};

params [ ["_seedLeadId", "", [""]] ];
if (!(_seedLeadId isEqualType "")) then { _seedLeadId = ""; };
_seedLeadId = trim _seedLeadId;

// Prevent overlapping incidents
private _activeTaskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (_activeTaskId isNotEqualTo "") exitWith {false};

private _catalog = call compile preprocessFileLineNumbers "data\incident_markers.sqf";
if (!(_catalog isEqualType [])) exitWith {
    diag_log format ["[ARC][INC][ERR] incidentCreate: catalog load failed. type=%1", typeName _catalog];
    false
};
if ((count _catalog) == 0) exitWith {
    diag_log "[ARC][INC][ERR] incidentCreate: catalog loaded but is empty (0 entries).";
    false
};

// World-state levers (0..1)
// Defaults align with ARC_fnc_stateInit starting values.
private _p = ["insurgentPressure", 0.35] call ARC_fnc_stateGet;
private _corr = ["corruption", 0.55] call ARC_fnc_stateGet;
private _inf = ["infiltration", 0.35] call ARC_fnc_stateGet;

private _fuel = ["baseFuel", 0.38] call ARC_fnc_stateGet;
private _ammo = ["baseAmmo", 0.32] call ARC_fnc_stateGet;
private _med  = ["baseMed",  0.40] call ARC_fnc_stateGet;

// Clamp
_p = (_p max 0) min 1;
_corr = (_corr max 0) min 1;
_inf = (_inf max 0) min 1;
_fuel = (_fuel max 0) min 1;
_ammo = (_ammo max 0) min 1;
_med  = (_med  max 0) min 1;

private _logNeed = (1 - ((_fuel + _ammo + _med) / 3)) max 0;
_logNeed = _logNeed min 1;
// Supply-critical override: when the base is hurting, force mundane sustainment tasks.
// (This does NOT auto-create a task; it only affects the next TOC-generated incident.)
private _critThresh = missionNamespace getVariable ["ARC_supplyCriticalThreshold", 0.18];
if (!(_critThresh isEqualType 0)) then { _critThresh = 0.18; };
_critThresh = (_critThresh max 0.05) min 0.40;

private _supplyCritical = (_fuel <= _critThresh) || (_ammo <= _critThresh) || (_med <= _critThresh);
private _forceLogistics = _supplyCritical || (_logNeed >= 0.75);

// If we have leads, prefer to task them (they represent actionable intel).
// Exception: when supplies are critical, do NOT burn leads unless a lead itself is LOGISTICS/ESCORT.
// (We want the campaign to pull the player back into sustainment tasks when the base is hurting.)
private _lead = [];
private _useLead = false;

// If a field unit has accepted a LEAD order, that lead should be consumed into the next generated incident.
// This prevents the lead from "disappearing" (it was removed from the lead pool when the LEAD order was issued).
private _orders = ["tocOrders", []] call ARC_fnc_stateGet;
private _leadOrderIdx = -1;
private _leadOrderId = "";
private _leadOrderTarget = "";
private _leadOrderData = [];
private _leadOrderMeta = [];

if (_orders isEqualType [] && { (count _orders) > 0 }) then
{
    private _bestAt = 1e12;

    for "_i" from 0 to ((count _orders) - 1) do
    {
        private _o = _orders # _i;
        if !(_o isEqualType [] && { (count _o) >= 7 }) then { continue; };
        _o params ["_oid", "_issuedAt", "_status", "_orderType", "_targetGroup", "_data", "_meta"];
        if !(_orderType isEqualType "") then { continue; };
        if !(_status isEqualType "") then { continue; };
        if !((toUpper _orderType) isEqualTo "LEAD") then { continue; };
        if !((toUpper _status) isEqualTo "ACCEPTED") then { continue; };

        // Prefer the oldest accepted lead order.
        private _acceptedAt = _issuedAt;
        if (_meta isEqualType []) then
        {
            private _idxA = -1;
            { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x # 0) isEqualTo "acceptedAt" }) exitWith { _idxA = _forEachIndex; }; } forEach _meta;
            if (_idxA >= 0) then
            {
                private _v = (_meta # _idxA) # 1;
                if (_v isEqualType 0) then { _acceptedAt = _v; };
            };
        };

        if (_acceptedAt < _bestAt) then
        {
            _bestAt = _acceptedAt;
            _leadOrderIdx = _i;
            _leadOrderId = _oid;
            _leadOrderTarget = _targetGroup;
            _leadOrderData = _data;
            _leadOrderMeta = _meta;
        };
    };
};

if (_leadOrderIdx >= 0) then
{
    private _leadRec = [];
    if (_leadOrderData isEqualType []) then
    {
        private _idxL = -1;
        { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x # 0) isEqualTo "lead" }) exitWith { _idxL = _forEachIndex; }; } forEach _leadOrderData;
        if (_idxL >= 0) then { _leadRec = (_leadOrderData # _idxL) # 1; };
    };

    if (_leadRec isEqualType [] && { (count _leadRec) > 0 }) then
    {
        _lead = _leadRec;
        _useLead = true;
    }
    else
    {
        // Invalid payload; clear order reference so catalog selection runs below.
        _leadOrderIdx = -1;
        _leadOrderId = "";
        _leadOrderTarget = "";
        _leadOrderData = [];
        _leadOrderMeta = [];
    };
};

// Seed lead from INCIDENT queue handler (TOC approved a specific incident directly).
// This is the only remaining path that consumes a lead without a prior accepted LEAD order.
if (!_useLead && { _seedLeadId isNotEqualTo "" }) then
{
    private _tmp = [_seedLeadId] call ARC_fnc_leadConsumeById;
    if (_tmp isEqualType [] && { (count _tmp) > 0 }) then
    {
        _lead = _tmp;
        _useLead = true;
    };
};

// NOTE: The TOC backlog and lead pool auto-consumption paths have been intentionally removed.
// Leads must now reach incidents only via one of the two explicit paths above:
//   1. A LEAD order was issued via the TOC queue (LEAD_ISSUE_REQUEST approved), accepted by
//      a field unit, and the lead record is embedded in the ACCEPTED order.
//   2. TOC approved an INCIDENT queue item, which passes _seedLeadId directly here.
// This enforces the command review cycle and prevents leads from silently converting to
// incidents without TOC oversight.

// Campaign stage (0..1) based on how many incidents have been closed.
// This lets the catalog task generator skew mundane early, more kinetic later.
private _hist0 = ["incidentHistory", []] call ARC_fnc_stateGet;
if (!(_hist0 isEqualType [])) then { _hist0 = []; };
private _nHist = count _hist0;

private _stageDen = missionNamespace getVariable ["ARC_campaignStageIncidents", 12];
if (!(_stageDen isEqualType 0)) then { _stageDen = 12; };
_stageDen = (_stageDen max 1) min 100;

private _stage = (_nHist / _stageDen) min 1;
if (_stage < 0) then { _stage = 0; };
private _early = 1 - _stage;

private _safeModeEnabled = missionNamespace getVariable ["ARC_safeModeEnabled", false];
if (!(_safeModeEnabled isEqualType true) && !(_safeModeEnabled isEqualType false)) then { _safeModeEnabled = false; };

// Avoid immediate repeats (last closed incident)
private _hist = ["incidentHistory", []] call ARC_fnc_stateGet;
private _lastMarker = "";
private _lastTypeU = "";

if (_hist isEqualType [] && { (count _hist) > 0 }) then
{
    private _last = _hist select ((count _hist) - 1);
    if (_last isEqualType [] && { (count _last) >= 3 }) then
    {
        _lastMarker = _last # 1;
        _lastTypeU = toUpper (_last # 2);
    };
};

// Build a weighted candidate list from the catalog.
private _choices = [];
private _weights = [];

{
    if !(_x isEqualType []) then { continue; };
    _x params ["_rawMarker", "_displayName", "_incidentType"];

    private _m = [_rawMarker] call ARC_fnc_worldResolveMarker;
    if (!(_m in allMapMarkers)) then { continue; };

    private _typeU = toUpper _incidentType;

    if (_safeModeEnabled && { _typeU isEqualTo "IED" }) then { continue; };

// When supplies are critical, only generate sustainment incidents (unless a lead forced something else).
if (_forceLogistics && { !_useLead } && { !(_typeU in ["LOGISTICS","ESCORT"]) }) then { continue; };

    // Base weight by incident type (simple but state-aware)
    private _w = switch (_typeU) do
    {
        case "LOGISTICS": { 0.40 + (1.40 * _logNeed) };
        case "ESCORT":    { 0.40 + (1.20 * _logNeed) };

        case "IED":       { 0.60 + (1.20 * _p) };
        case "RAID":      { 0.50 + (1.00 * _p) };
        case "DEFEND":    { 0.50 + (1.00 * _p) };
        case "QRF":       { 0.30 + (0.80 * _p) };

        case "PATROL":    { 0.80 + (0.60 * (1 - _p)) };
        case "RECON":     { 0.80 + (0.70 * (1 - _p)) };
        case "CIVIL":     { 0.70 + (0.80 * _corr) + (0.40 * _inf) };
        case "CHECKPOINT":{ 0.60 + (0.40 * _p) + (0.20 * _corr) };
        default            { 1 };
    };

    // Zone-aware weighting (Airbase + Green Zone are our political/operational gravity wells)
    private _zone = [markerPos _m] call ARC_fnc_worldGetZoneForPos;

    switch (_zone) do
    {
        case "GreenZone":
        {
            if (_typeU in ["CIVIL", "DEFEND", "QRF", "CHECKPOINT"]) then
            {
                _w = _w * (1 + (0.80 * _inf) + (0.40 * _corr));
            };
        };

        case "Airbase":
        {
            if (_typeU in ["LOGISTICS", "ESCORT"]) then
            {
                _w = _w * (1 + (0.80 * _logNeed));
            };

            if (_typeU in ["DEFEND", "QRF"]) then
            {
                _w = _w * (1 + (0.40 * _p));
            };
        };

        default {};
    };

	// Campaign stage skew:
	// - Early: prefer mundane tasks (LOGISTICS/ESCORT/CIVIL/RECON/PATROL/CHECKPOINT)
	// - Late: allow more kinetic tasks (IED/RAID/DEFEND/QRF) to dominate when pressure supports it
	private _stageMul = 1;
	if (_typeU in ["LOGISTICS", "ESCORT", "PATROL", "RECON", "CIVIL", "CHECKPOINT"]) then
	{
	    _stageMul = 0.85 + (0.35 * _early); // stage=0 => 1.20, stage=1 => 0.85
	};
	if (_typeU in ["IED", "RAID", "DEFEND", "QRF"]) then
	{
	    _stageMul = 0.35 + (0.65 * _stage); // stage=0 => 0.35, stage=1 => 1.00
	};
	_w = _w * _stageMul;

    // Repeat damping
    if (_m isEqualTo _lastMarker) then { _w = _w * 0.20; };
    if (_typeU isEqualTo _lastTypeU) then { _w = _w * 0.60; };

    if (_w <= 0) then { continue; };

    _choices pushBack [_m, _displayName, _incidentType];
    _weights pushBack _w;

} forEach _catalog;

// If we aren't tasking a lead, we need at least one catalog choice.
if (!_useLead && { _choices isEqualTo [] }) exitWith {
    diag_log format ["[ARC][INC][WARN] incidentCreate: catalog has %1 entries but all filtered out. forceLogistics=%2 safeModeEnabled=%3 catalogType=%4",
        count _catalog, _forceLogistics, _safeModeEnabled, typeName _catalog];
    false
};

// Weighted random pick (catalog only)
private _idx = 0;

if (!_useLead) then
{
    private _sumW = 0;
    { _sumW = _sumW + _x; } forEach _weights;

    _idx = floor (random (count _choices));

    if (_sumW > 0) then
    {
        private _r = random _sumW;
        private _acc = 0;

        {
            _acc = _acc + (_weights # _forEachIndex);
            if (_r <= _acc) exitWith { _idx = _forEachIndex; };
        } forEach _choices;
    };
};

private _markerName = "";
private _displayName = "";
private _incidentType = "";
private _posATL = [];
private _zone = "";
private _leadId = "";
private _threadId = "";
private _leadTag = "";

if (_useLead) then
{
    // Lead entry format:
    // [id, incidentType, displayName, pos, strength, createdAt, expiresAt, sourceTaskId, sourceIncidentType, threadId, tag]
    _lead params [
        ["_lId", ""],
        ["_lType", ""],
        ["_lDisp", ""],
        ["_lPos", []],
        ["_lStrength", 0.5],
        ["_lCreated", -1],
        ["_lExpires", -1],
        ["_lSourceTask", ""],
        ["_lSourceIncType", ""],
        ["_lThread", ""],
        ["_lTag", ""]
    ];

    _leadId = _lId;
    _incidentType = _lType;
    _displayName = _lDisp;
    _posATL = +_lPos;
    _posATL resize 3;
    _zone = [_posATL] call ARC_fnc_worldGetZoneForPos;
    _threadId = _lThread;
    _leadTag = _lTag;
    _markerName = ""; // lead-driven incidents may not align with a named Eden marker
}
else
{
    private _pick = _choices # _idx;
    _pick params ["_mkr", "_disp", "_t"]; 

    _markerName = _mkr;
    _displayName = _disp;
    _incidentType = _t;

    private _pos = getMarkerPos ([_markerName] call ARC_fnc_worldResolveMarker);
    _posATL = +_pos;
    _posATL resize 3;
    _zone = [_markerName] call ARC_fnc_worldGetZoneForMarker;
};

private _counter = ["taskCounter", 0] call ARC_fnc_stateGet;
_counter = _counter + 1;
["taskCounter", _counter] call ARC_fnc_stateSet;

private _taskId = format ["ARC_inc_%1", _counter];

["activeTaskId", _taskId] call ARC_fnc_stateSet;
["activeIncidentType", _incidentType] call ARC_fnc_stateSet;
["activeIncidentMarker", _markerName] call ARC_fnc_stateSet;
["activeIncidentDisplayName", _displayName] call ARC_fnc_stateSet;
["activeIncidentCreatedAt", serverTime] call ARC_fnc_stateSet;
	["activeIncidentZone", _zone] call ARC_fnc_stateSet;
["activeIncidentPos", _posATL] call ARC_fnc_stateSet;

// Lifecycle log (cheap; gated by ARC_debugLogEnabled)
["INC", "Created incident %1 (%2) zone=%3 marker=%4 pos=%5",
    [_taskId, _incidentType, _zone, _markerName, _posATL]
] call ARC_fnc_log;


// Assignment/acceptance workflow
["activeIncidentAccepted", false] call ARC_fnc_stateSet;
["activeIncidentAcceptedAt", -1] call ARC_fnc_stateSet;

	// Reset previous acceptance identity (new incident)
	["activeIncidentAcceptedBy", ""] call ARC_fnc_stateSet;
	["activeIncidentAcceptedByName", ""] call ARC_fnc_stateSet;
	["activeIncidentAcceptedByUID", ""] call ARC_fnc_stateSet;
	["activeIncidentAcceptedByRoleTag", ""] call ARC_fnc_stateSet;
	["activeIncidentAcceptedByGroup", ""] call ARC_fnc_stateSet;

["activeIncidentCivsubDistrictId", ""] call ARC_fnc_stateSet;
["activeIncidentCivsubStartRow", []] call ARC_fnc_stateSet;
["activeIncidentCivsubStartTs", -1] call ARC_fnc_stateSet;



// SITREP workflow gating (one SITREP per incident)
["activeIncidentSitrepSent", false] call ARC_fnc_stateSet;
["activeIncidentSitrepSentAt", -1] call ARC_fnc_stateSet;
["activeIncidentSitrepFrom", ""] call ARC_fnc_stateSet;
	["activeIncidentSitrepFromUID", ""] call ARC_fnc_stateSet;
	["activeIncidentSitrepFromGroup", ""] call ARC_fnc_stateSet;
	["activeIncidentSitrepFromRoleTag", ""] call ARC_fnc_stateSet;
["activeIncidentSitrepSummary", ""] call ARC_fnc_stateSet;
["activeIncidentSitrepDetails", ""] call ARC_fnc_stateSet;

// Mirror SITREP state into missionNamespace for client-side gating (public).
missionNamespace setVariable ["ARC_activeIncidentSitrepSent", false, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepFrom", "", true];
missionNamespace setVariable ["ARC_activeIncidentSitrepFromGroup", "", true];
missionNamespace setVariable ["ARC_activeIncidentSitrepSummary", "", true];
missionNamespace setVariable ["ARC_activeIncidentSitrepDetails", "", true];

// Clear any previous close-ready suggestion (TOC remains the closure authority)
["activeIncidentCloseReady", false] call ARC_fnc_stateSet;
["activeIncidentSuggestedResult", ""] call ARC_fnc_stateSet;
["activeIncidentCloseReason", ""] call ARC_fnc_stateSet;
["activeIncidentCloseMarkedAt", -1] call ARC_fnc_stateSet;

// Active lead/thread context
["activeLeadId", _leadId] call ARC_fnc_stateSet;
["activeThreadId", _threadId] call ARC_fnc_stateSet;
["activeLeadTag", _leadTag] call ARC_fnc_stateSet;

// Reset execution bookkeeping for the new incident
["activeExecTaskId", ""] call ARC_fnc_stateSet;
["activeExecKind", ""] call ARC_fnc_stateSet;
["activeExecPos", []] call ARC_fnc_stateSet;
["activeExecRadius", 0] call ARC_fnc_stateSet;
["activeExecStartedAt", -1] call ARC_fnc_stateSet;
["activeExecDeadlineAt", -1] call ARC_fnc_stateSet;
["activeExecArrivalReq", 0] call ARC_fnc_stateSet;
["activeExecArrived", false] call ARC_fnc_stateSet;
["activeExecHoldReq", 0] call ARC_fnc_stateSet;
["activeExecHoldAccum", 0] call ARC_fnc_stateSet;
["activeExecLastProg", -1] call ARC_fnc_stateSet;
["activeExecLastProgressAt", -1] call ARC_fnc_stateSet;
["activeObjectiveKind", ""] call ARC_fnc_stateSet;
["activeObjectiveClass", ""] call ARC_fnc_stateSet;
["activeObjectivePos", []] call ARC_fnc_stateSet;
["activeObjectiveNetId", ""] call ARC_fnc_stateSet;

// Create task entity
[_taskId, _markerName, _displayName, _incidentType, _posATL, _threadId] call ARC_fnc_taskCreateIncident;

// If this incident was generated from an accepted LEAD order, mark that order as completed (consumed into this task).
if (_leadOrderIdx >= 0 && { _leadOrderIdx < (count _orders) }) then
{
    private _ord = _orders # _leadOrderIdx;
    if (_ord isEqualType [] && { (count _ord) >= 7 }) then
    {
        _ord params ["_oid", "_issuedAt", "_status", "_orderType", "_targetGroup", "_data", "_meta"];

        private _setPair = {
            params ["_pairs", "_k", "_v"];
            if !(_pairs isEqualType []) then { _pairs = []; };
            private _j = -1;
            { if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x # 0) isEqualTo _k }) exitWith { _j = _forEachIndex; }; } forEach _pairs;
            if (_j < 0) then { _pairs pushBack [_k, _v]; } else { _pairs set [_j, [_k, _v]]; };
            _pairs
        };

        _status = "COMPLETED";
        _meta = [_meta, "completedAt", serverTime] call _setPair;
        _meta = [_meta, "completedReason", "CONSUMED_TO_TASK"] call _setPair;
        _meta = [_meta, "consumedTaskId", _taskId] call _setPair;
        _meta = [_meta, "consumedIncidentType", _incidentType] call _setPair;
        if (_leadId isEqualType "" && { _leadId != "" }) then
        {
            _meta = [_meta, "consumedLeadId", _leadId] call _setPair;
        };

        _orders set [_leadOrderIdx, [_oid, _issuedAt, _status, _orderType, _targetGroup, _data, _meta]];
        ["tocOrders", _orders] call ARC_fnc_stateSet;

        if (!isNil "ARC_fnc_intelOrderBroadcast") then { [] call ARC_fnc_intelOrderBroadcast; };
        if (!isNil "ARC_fnc_intelLog") then
        {
            ["OPS", format ["ORDER %1 consumed into task %2 (%3).", _oid, _taskId, toUpper _incidentType], _posATL, []] call ARC_fnc_intelLog;
        };
    };
};

// Pre-cache virtual OpFor assets along the player-to-objective corridor.
if (!isNil "ARC_fnc_incidentPreCache") then
{
    [_posATL, _incidentType] call ARC_fnc_incidentPreCache;
};

// Dispatch task-type-specific init hooks for new gameplay types
switch (toUpper _incidentType) do
{
    case "KLE":
    {
        if (!isNil "ARC_fnc_kleInit") then
        {
            [_taskId, _posATL, _displayName] call ARC_fnc_kleInit;
        };
    };
    case "ROUTE_CLEARANCE":
    {
        if (!isNil "ARC_fnc_routeClearanceInit") then
        {
            [_taskId, _posATL, _displayName] call ARC_fnc_routeClearanceInit;
        };
    };
};

// Log initial tasking note into OPS feed (this also refreshes active task text)
private _grid = mapGridPosition _posATL;
private _leadTxt = if (_leadId isEqualTo "") then {""} else {format [" Lead: %1.", _leadId]};
private _sum = format ["Tasked: %1 (%2) at %3. Zone: %4.%5", _displayName, toUpper _incidentType, _grid, _zone, _leadTxt];
["OPS", _sum, _posATL, [["taskId", _taskId], ["marker", _markerName], ["incidentType", _incidentType], ["event", "INCIDENT_CREATED"], ["leadId", _leadId], ["threadId", _threadId]]] call ARC_fnc_intelLog;

// Visual prompt: a new incident exists and requires acceptance before execution progresses.
// This is intentionally broad (all players) so field elements don't miss that the command cycle is waiting.
[
    "New Incident Pending Acceptance",
    format ["%1 (%2) at %3. Accept the incident to start execution.", _displayName, toUpper _incidentType, _grid],
    8
] remoteExec ["ARC_fnc_clientToast", 0];

// Publish updated state snapshot (for SITREP / briefing)
[] call ARC_fnc_publicBroadcastState;

// Broadcast helpful vars for clients (TOC display, debug actions)
missionNamespace setVariable ["ARC_activeTaskId", _taskId, true];
missionNamespace setVariable ["ARC_activeIncidentMarker", _markerName, true];
missionNamespace setVariable ["ARC_activeIncidentType", _incidentType, true];
missionNamespace setVariable ["ARC_activeIncidentDisplayName", _displayName, true];
missionNamespace setVariable ["ARC_activeIncidentPos", _posATL, true];
missionNamespace setVariable ["ARC_activeIncidentAccepted", false, true];
missionNamespace setVariable ["ARC_activeIncidentAcceptedAt", -1, true];
missionNamespace setVariable ["ARC_activeIncidentAcceptedByGroup", "", true];

missionNamespace setVariable ["ARC_activeIncidentSitrepSent", false, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepSentAt", -1, true];
missionNamespace setVariable ["ARC_activeIncidentSitrepFrom", "", true];
missionNamespace setVariable ["ARC_activeIncidentSitrepFromGroup", "", true];
missionNamespace setVariable ["ARC_activeIncidentSitrepSummary", "", true];
missionNamespace setVariable ["ARC_activeIncidentSitrepDetails", "", true];
missionNamespace setVariable ["ARC_activeIncidentCloseReady", false, true];
missionNamespace setVariable ["ARC_activeIncidentSuggestedResult", "", true];
missionNamespace setVariable ["ARC_activeIncidentCloseReason", "", true];
missionNamespace setVariable ["ARC_activeIncidentCloseMarkedAt", -1, true];
missionNamespace setVariable ["ARC_activeLeadId", _leadId, true];
missionNamespace setVariable ["ARC_activeThreadId", _threadId, true];

// Initialize execution plan/objective for this incident.
[] call ARC_fnc_execInitActive;

// Persist immediately
[] call ARC_fnc_stateSave;
true

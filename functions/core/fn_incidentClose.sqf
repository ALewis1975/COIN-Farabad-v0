/*
    Close the currently active incident.

    Params:
        0: STRING - Result state: "SUCCEEDED" or "FAILED" (also accepts "CANCELED").

    Returns:
        BOOL
*/

if (!isServer) exitWith {false};

// Safe logger (does not require ARC_fnc_log to exist)
private _log = {
    params [['_msg','', ['']], ['_args', [], [[]]]];
    if (!isNil "ARC_fnc_log") then { ["INC", _msg, _args] call ARC_fnc_log; }
    else { diag_log format ['[ARC][INC] %1', (if ((count _args)>0) then { format ([_msg] + _args) } else { _msg })]; };
};


private _rawResult = if (_this isEqualType [] && { (count _this) > 0 }) then { _this select 0 } else { nil };
params [["_result", "", [""]]];
_result = toUpper (trim _result);

private _validResults = ["SUCCEEDED", "FAILED", "CANCELED"];
if !(_result in _validResults) exitWith
{
    ["incidentClose invalid _result (type=%1, value=%2)", [typeName _rawResult, str _rawResult]] call _log;
    false
};

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (_taskId isEqualTo "") exitWith {false};

private _marker = ["activeIncidentMarker", ""] call ARC_fnc_stateGet;
private _type = ["activeIncidentType", ""] call ARC_fnc_stateGet;
private _display = ["activeIncidentDisplayName", ""] call ARC_fnc_stateGet;
private _created = ["activeIncidentCreatedAt", -1] call ARC_fnc_stateGet;

// Closure prompt reason (set by incidentMarkReadyToClose); used for downstream hooks/logging
private _closeReason = ["activeIncidentCloseReason", ""] call ARC_fnc_stateGet;
if (!(_closeReason isEqualType "")) then { _closeReason = ""; };

private _posATL = ["activeIncidentPos", []] call ARC_fnc_stateGet;
if (!(_posATL isEqualType []) || { (count _posATL) < 2 }) then { _posATL = []; };

// Lead/thread context ("" when catalog-driven)
private _leadId = ["activeLeadId", ""] call ARC_fnc_stateGet;
private _threadId = ["activeThreadId", ""] call ARC_fnc_stateGet;
private _leadTag = ["activeLeadTag", ""] call ARC_fnc_stateGet;

// Resolve a stable position + zone even when markerName is empty.
private _pos = [];
private _m = "";

if (!(_marker isEqualTo "")) then
{
    _m = [_marker] call ARC_fnc_worldResolveMarker;
    if (_m in allMapMarkers) then { _pos = getMarkerPos _m; };
};

if (_pos isEqualTo [] && { _posATL isEqualType [] && { (count _posATL) >= 2 } }) then
{
    _pos = +_posATL;
    _pos resize 3;
};

if (_pos isEqualTo []) then { _pos = [0,0,0]; };

private _zone = if (_m isEqualTo "") then { [_pos] call ARC_fnc_worldGetZoneForPos } else { [_m] call ARC_fnc_worldGetZoneForMarker };
private _typeU = toUpper _type;

// Store last AO context for follow-on (lead-driven) timing and UI
["lastIncidentPos", _pos] call ARC_fnc_stateSet;
["lastIncidentZone", _zone] call ARC_fnc_stateSet;
["lastIncidentTaskId", _taskId] call ARC_fnc_stateSet;
["lastIncidentType", _typeU] call ARC_fnc_stateSet;
["lastIncidentMarker", _marker] call ARC_fnc_stateSet;


// Set task state (global task framework)
// Syntax per Bohemia wiki: [taskName, taskState, showHint] call BIS_fnc_taskSetState
[_taskId, _result, true] call BIS_fnc_taskSetState;

// Best-effort: close any nested child tasks so the task list doesn't retain stale assigned subtasks.
// (Convoy link-up, Route Recon start/end)
private _childIds = [];

private _lk = ["activeConvoyLinkupTaskId", ""] call ARC_fnc_stateGet;
if (_lk isEqualType "" && { !(_lk isEqualTo "") }) then { _childIds pushBackUnique _lk; };

private _rs = ["activeReconRouteStartTaskId", ""] call ARC_fnc_stateGet;
if (_rs isEqualType "" && { !(_rs isEqualTo "") }) then { _childIds pushBackUnique _rs; };

private _re = ["activeReconRouteEndTaskId", ""] call ARC_fnc_stateGet;
if (_re isEqualType "" && { !(_re isEqualTo "") }) then { _childIds pushBackUnique _re; };

{
    private _cid = _x;
    if (_cid isEqualTo "") then { continue; };
    if (!([_cid] call BIS_fnc_taskExists)) then { continue; };

    private _st = [_cid] call BIS_fnc_taskState;
    if (!(_st isEqualType "")) then { _st = ""; };

    if !(_st in ["SUCCEEDED", "FAILED", "CANCELED"]) then
    {
        private _set = "CANCELED";
        if ((toUpper _result) isEqualTo "SUCCEEDED") then { _set = "SUCCEEDED"; };
        [_cid, _set, false] call BIS_fnc_taskSetState;
    };
} forEach _childIds;


// Append to history
private _hist = ["incidentHistory", []] call ARC_fnc_stateGet;
if (!(_hist isEqualType [])) then { _hist = []; };
_hist pushBack [_taskId, _marker, _type, _display, _result, _created, serverTime, _pos, _zone, _threadId];
// Trim oldest entries (configurable cap; preserves most-recent tail)
private _histMax = missionNamespace getVariable ["ARC_incidentHistoryMaxEntries", 200];
if (!(_histMax isEqualType 0)) then { _histMax = 200; };
_histMax = (_histMax max 10) min 1000;
if ((count _hist) > _histMax) then { _hist = _hist select [((count _hist) - _histMax), _histMax]; };
["incidentHistory", _hist] call ARC_fnc_stateSet;

// Basic COIN pressure hooks (light-touch, can be tuned later)
// Failed incidents increase insurgent pressure and corruption slightly; successes reduce pressure.
private _p = ["insurgentPressure", 0.60] call ARC_fnc_stateGet;
private _c = ["corruption", 0.55] call ARC_fnc_stateGet;

private _inf = ["infiltration", 0.35] call ARC_fnc_stateGet;
private _sent = ["civSentiment", 0.55] call ARC_fnc_stateGet;
private _leg = ["govLegitimacy", 0.45] call ARC_fnc_stateGet;

private _fuel = ["baseFuel", 0.75] call ARC_fnc_stateGet;
private _ammo = ["baseAmmo", 0.60] call ARC_fnc_stateGet;
private _med  = ["baseMed",  0.80] call ARC_fnc_stateGet;

private _fuel0 = _fuel;
private _ammo0 = _ammo;
private _med0  = _med;


switch (toUpper _result) do
{
    case "SUCCEEDED":
    {
        _p = (_p - 0.02) max 0;
        _c = (_c - 0.01) max 0;

        // Zone-sensitive political effects
        if (_zone isEqualTo "GreenZone") then
        {
            _inf = (_inf - 0.03) max 0;
            _leg = (_leg + 0.02) min 1;
            _sent = (_sent + 0.01) min 1;
        };

        // Base sustainment effects
        if (_typeU in ["LOGISTICS", "ESCORT"]) then
        {
            // Logistics feedback loop:
            // - Successful AIRBASE logistics/escort tasks replenish base stocks
            // - Successful non-airbase tasks represent forward distribution (consumes a bit of stock)
            private _isAirbase = (toUpper _zone) isEqualTo "AIRBASE";

            private _supply = ["activeConvoySupplyKind", ""] call ARC_fnc_stateGet;
            if (!(_supply isEqualType "")) then { _supply = ""; };
            _supply = toUpper _supply;

            if (_isAirbase) then
            {
                switch (_supply) do
                {
                    case "FUEL":
                    {
                        _fuel = (_fuel + 0.10) min 1;
                        _ammo = (_ammo + 0.03) min 1;
                        _med  = (_med  + 0.02) min 1;
                    };
                    case "AMMO":
                    {
                        _ammo = (_ammo + 0.10) min 1;
                        _fuel = (_fuel + 0.03) min 1;
                        _med  = (_med  + 0.02) min 1;
                    };
                    case "MED":
                    {
                        _med  = (_med  + 0.10) min 1;
                        _fuel = (_fuel + 0.03) min 1;
                        _ammo = (_ammo + 0.03) min 1;
                    };
                    default
                    {
                        _fuel = (_fuel + 0.06) min 1;
                        _ammo = (_ammo + 0.06) min 1;
                        _med  = (_med  + 0.05) min 1;
                    };
                };
            }
            else
            {
                // Forward distribution: successful delivery still improves overall sustainment,
                // but at a smaller magnitude than an Airbase replenishment run.
                switch (_supply) do
                {
                    case "FUEL":
                    {
                        _fuel = (_fuel + 0.04) min 1;
                        _ammo = (_ammo + 0.01) min 1;
                        _med  = (_med  + 0.01) min 1;
                    };
                    case "AMMO":
                    {
                        _ammo = (_ammo + 0.04) min 1;
                        _fuel = (_fuel + 0.01) min 1;
                        _med  = (_med  + 0.01) min 1;
                    };
                    case "MED":
                    {
                        _med  = (_med  + 0.04) min 1;
                        _fuel = (_fuel + 0.01) min 1;
                        _ammo = (_ammo + 0.01) min 1;
                    };
                    default
                    {
                        _fuel = (_fuel + 0.02) min 1;
                        _ammo = (_ammo + 0.02) min 1;
                        _med  = (_med  + 0.02) min 1;
                    };
                };
// Distribution runs have a positive soft-power effect.
                _sent = (_sent + 0.01) min 1;
                _leg  = (_leg  + 0.01) min 1;
            };

            // Consume and clear the supply hint once the task resolves.
            ["activeConvoySupplyKind", ""] call ARC_fnc_stateSet;
        };
    };
    case "FAILED":
    {
        _p = (_p + 0.03) min 1;
        _c = (_c + 0.02) min 1;

        // Zone-sensitive political effects
        if (_zone isEqualTo "GreenZone") then
        {
            _inf = (_inf + 0.04) min 1;
            _leg = (_leg - 0.02) max 0;
            _sent = (_sent - 0.02) max 0;
        };

        // Base sustainment effects
        if (_typeU in ["LOGISTICS", "ESCORT"]) then
        {
            private _isAirbase = (toUpper _zone) isEqualTo "AIRBASE";

            private _supply = ["activeConvoySupplyKind", ""] call ARC_fnc_stateGet;
            if (!(_supply isEqualType "")) then { _supply = ""; };
            _supply = toUpper _supply;

            if (_isAirbase) then
            {
                // Losing an inbound airbase run is a bigger hit to readiness.
                switch (_supply) do
                {
                    case "FUEL": { _fuel = (_fuel - 0.06) max 0; _ammo = (_ammo - 0.02) max 0; _med = (_med - 0.02) max 0; };
                    case "AMMO": { _ammo = (_ammo - 0.06) max 0; _fuel = (_fuel - 0.02) max 0; _med = (_med - 0.02) max 0; };
                    case "MED":  { _med  = (_med  - 0.06) max 0; _fuel = (_fuel - 0.02) max 0; _ammo = (_ammo - 0.02) max 0; };
                    default       { _fuel = (_fuel - 0.05) max 0; _ammo = (_ammo - 0.04) max 0; _med  = (_med  - 0.03) max 0; };
                };
            }
            else
            {
                // Losing a forward distro convoy still hurts, but slightly less.
                switch (_supply) do
                {
                    case "FUEL": { _fuel = (_fuel - 0.04) max 0; _ammo = (_ammo - 0.02) max 0; _med = (_med - 0.02) max 0; };
                    case "AMMO": { _ammo = (_ammo - 0.04) max 0; _fuel = (_fuel - 0.02) max 0; _med = (_med - 0.02) max 0; };
                    case "MED":  { _med  = (_med  - 0.04) max 0; _fuel = (_fuel - 0.02) max 0; _ammo = (_ammo - 0.02) max 0; };
                    default       { _fuel = (_fuel - 0.04) max 0; _ammo = (_ammo - 0.02) max 0; _med  = (_med  - 0.02) max 0; };
                };
            };

            ["activeConvoySupplyKind", ""] call ARC_fnc_stateSet;
        };

        // IED failures tend to hit sentiment hard
        if (_typeU isEqualTo "IED") then
        {
            _sent = (_sent - 0.02) max 0;
        };
    };
    default
    {
        // no-op
    };
};


private _dFuel = _fuel - _fuel0;
private _dAmmo = _ammo - _ammo0;
private _dMed  = _med  - _med0;

["insurgentPressure", _p] call ARC_fnc_stateSet;
["corruption", _c] call ARC_fnc_stateSet;

["infiltration", _inf] call ARC_fnc_stateSet;
["civSentiment", _sent] call ARC_fnc_stateSet;
["govLegitimacy", _leg] call ARC_fnc_stateSet;

["baseFuel", _fuel] call ARC_fnc_stateSet;
["baseAmmo", _ammo] call ARC_fnc_stateSet;
["baseMed", _med] call ARC_fnc_stateSet;


// End the active execution package.
// We defer despawn of spawned entities until players leave the AO (see ARC_cleanupRadiusM).
["DEFER"] call ARC_fnc_execCleanupActive;

// Generate follow-on leads (the "intel snowball")
// If TOC staged closeout earlier (awaiting unit acceptance), leads may already exist.
private _createdLeads = 0;
private _preGen = ["activeIncidentClosePendingLeadsGenerated", false] call ARC_fnc_stateGet;
if (!(_preGen isEqualType true)) then { _preGen = false; };

if (_preGen) then
{
    _createdLeads = ["activeIncidentClosePendingLeadsCreated", 0] call ARC_fnc_stateGet;
    if (!(_createdLeads isEqualType 0)) then { _createdLeads = 0; };
}
else
{
    _createdLeads = [_result, _type, _marker, _pos, _zone, _taskId, _display] call ARC_fnc_leadGenerateFromIncident;
    if (!(_createdLeads isEqualType 0)) then { _createdLeads = 0; };
};

// If this was a lead-driven task, update the parent thread.
if (!(_threadId isEqualTo "")) then
{
    [_threadId, _result, _type, _leadTag, _zone, _pos, _taskId] call ARC_fnc_threadOnIncidentClosed;
};

// Track lead end-state
if (!(_leadId isEqualTo "")) then
{
    private _lh = ["leadHistory", []] call ARC_fnc_stateGet;
    if (!(_lh isEqualType [])) then { _lh = []; };
    _lh pushBack [_leadId, format ["RESOLVED_%1", toUpper _result], serverTime, _taskId, _type, _zone, _threadId];
    ["leadHistory", _lh] call ARC_fnc_stateSet;
};

// Log closure into OPS feed (and refresh public SITREP snapshot)
private _grid = mapGridPosition _pos;
private _leadTxt = if (_leadId isEqualTo "") then {""} else {format [" Lead: %1.", _leadId]};
private _sum = format ["Closed: %1 (%2) at %3. Result: %4. Zone: %5.%6", _display, toUpper _type, _grid, toUpper _result, _zone, _leadTxt];
["OPS", _sum, _pos, [["taskId", _taskId], ["marker", _marker], ["incidentType", _type], ["event", "INCIDENT_CLOSED"], ["result", toUpper _result], ["leadId", _leadId], ["threadId", _threadId], ["baseFuelDelta", _dFuel], ["baseAmmoDelta", _dAmmo], ["baseMedDelta", _dMed], ["leadsCreated", _createdLeads]]] call ARC_fnc_intelLog;
[] call ARC_fnc_publicBroadcastState;

// Threat system hook (v0): close threats linked to this incident/task (idempotent)
if (isNil "_closeReason") then { _closeReason = ""; };
if (!(_closeReason isEqualType "")) then { _closeReason = ""; };
private _thrCtx = [
    ["task_id", _taskId],
    ["incident_type", _type],
    ["result", _result],
    ["reason", _closeReason],
    ["pos", _pos],
    ["zone", _zone],
    ["marker", _marker],
    ["lead_id", _leadId],
    ["thread_id", _threadId]
];
["INCIDENT_CLOSED", _thrCtx] call ARC_fnc_threatOnIncidentClosed;

// Clear active incident
["activeTaskId", ""] call ARC_fnc_stateSet;
["activeIncidentType", ""] call ARC_fnc_stateSet;
["activeIncidentZone", ""] call ARC_fnc_stateSet;
["activeIncidentMarker", ""] call ARC_fnc_stateSet;
["activeIncidentDisplayName", ""] call ARC_fnc_stateSet;
["activeIncidentCreatedAt", -1] call ARC_fnc_stateSet;

// Clear lead context + position
["activeIncidentPos", []] call ARC_fnc_stateSet;

// Assignment/acceptance workflow
private _prevAcceptedGroup = ["activeIncidentAcceptedByGroup", ""] call ARC_fnc_stateGet;
if (_prevAcceptedGroup isEqualType "" && { !(_prevAcceptedGroup isEqualTo "") }) then
{
    private _rows = missionNamespace getVariable ["ARC_pub_unitStatuses", []];
    if (!(_rows isEqualType [])) then { _rows = []; };
    private _idx = -1;
    { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _prevAcceptedGroup }) exitWith { _idx = _forEachIndex; }; } forEach _rows;
    private _row = [_prevAcceptedGroup, "AVAILABLE", serverTime, "SYSTEM"];
    if (_idx < 0) then { _rows pushBack _row; } else { _rows set [_idx, _row]; };
    missionNamespace setVariable ["ARC_pub_unitStatuses", _rows, true];
};

["activeIncidentAccepted", false] call ARC_fnc_stateSet;
["activeIncidentAcceptedAt", -1] call ARC_fnc_stateSet;
["activeIncidentAcceptedBy", ""] call ARC_fnc_stateSet;
["activeIncidentAcceptedByName", ""] call ARC_fnc_stateSet;
["activeIncidentAcceptedByUID", ""] call ARC_fnc_stateSet;
["activeIncidentAcceptedByRoleTag", ""] call ARC_fnc_stateSet;
["activeIncidentAcceptedByGroup", ""] call ARC_fnc_stateSet;

["activeIncidentCivsubDistrictId", ""] call ARC_fnc_stateSet;
["activeIncidentCivsubStartRow", []] call ARC_fnc_stateSet;
["activeIncidentCivsubStartTs", -1] call ARC_fnc_stateSet;



// SITREP workflow gating
["activeIncidentSitrepSent", false] call ARC_fnc_stateSet;
["activeIncidentSitrepSentAt", -1] call ARC_fnc_stateSet;
["activeIncidentSitrepFrom", ""] call ARC_fnc_stateSet;
["activeIncidentSitrepFromUID", ""] call ARC_fnc_stateSet;
["activeIncidentSitrepFromGroup", ""] call ARC_fnc_stateSet;
["activeIncidentSitrepFromRoleTag", ""] call ARC_fnc_stateSet;
["activeIncidentSitrepSummary", ""] call ARC_fnc_stateSet;
["activeIncidentSitrepDetails", ""] call ARC_fnc_stateSet;
["activeLeadId", ""] call ARC_fnc_stateSet;
["activeThreadId", ""] call ARC_fnc_stateSet;
["activeLeadTag", ""] call ARC_fnc_stateSet;

// IED abandonment/detonation follow-on (cleared on incident close)
["activeIedDetonationQueueId", ""] call ARC_fnc_stateSet;

// Post-blast follow-on lead id (debug/linking only; lead itself lives in leadPool)
["activeIedDetonationResponseLeadId", ""] call ARC_fnc_stateSet;

// Generic follow-on lead pointer (UI/TOC closeout helpers)
["activeIncidentFollowOnLeadId", ""] call ARC_fnc_stateSet;
["activeIncidentFollowOnLeadType", ""] call ARC_fnc_stateSet;
["activeIncidentFollowOnLeadName", ""] call ARC_fnc_stateSet;
["activeIncidentFollowOnLeadPos", []] call ARC_fnc_stateSet;
["activeIncidentFollowOnLeadZone", ""] call ARC_fnc_stateSet;
["activeIncidentFollowOnLeadGrid", ""] call ARC_fnc_stateSet;

missionNamespace setVariable ["ARC_activeIncidentFollowOnLeadId", nil, true];
missionNamespace setVariable ["ARC_activeIncidentFollowOnLeadType", nil, true];
missionNamespace setVariable ["ARC_activeIncidentFollowOnLeadName", nil, true];
missionNamespace setVariable ["ARC_activeIncidentFollowOnLeadPos", nil, true];

// Integrated SITREP follow-on request cache (cleared on close)
["activeIncidentFollowOnRequest", []] call ARC_fnc_stateSet;
["activeIncidentFollowOnQueueId", ""] call ARC_fnc_stateSet;
["activeIncidentFollowOnSummary", ""] call ARC_fnc_stateSet;
["activeIncidentFollowOnDetails", ""] call ARC_fnc_stateSet;
["activeIncidentFollowOnFromGroup", ""] call ARC_fnc_stateSet;
["activeIncidentFollowOnAt", -1] call ARC_fnc_stateSet;
missionNamespace setVariable ["ARC_activeIncidentFollowOnRequest", [], true];
missionNamespace setVariable ["ARC_activeIncidentFollowOnQueueId", "", true];
missionNamespace setVariable ["ARC_activeIncidentFollowOnSummary", "", true];
missionNamespace setVariable ["ARC_activeIncidentFollowOnFromGroup", "", true];
missionNamespace setVariable ["ARC_activeIncidentFollowOnAt", -1, true];
missionNamespace setVariable ["ARC_activeIncidentFollowOnDetails", "", true];
missionNamespace setVariable ["ARC_activeIncidentFollowOnLeadZone", nil, true];
missionNamespace setVariable ["ARC_activeIncidentFollowOnLeadGrid", nil, true];

// Staged closeout state (TOC closeout -> unit acceptance)
["activeIncidentClosePending", false] call ARC_fnc_stateSet;
["activeIncidentClosePendingAt", -1] call ARC_fnc_stateSet;
["activeIncidentClosePendingResult", ""] call ARC_fnc_stateSet;
["activeIncidentClosePendingOrderId", ""] call ARC_fnc_stateSet;
["activeIncidentClosePendingGroup", ""] call ARC_fnc_stateSet;
["activeIncidentClosePendingLeadsGenerated", false] call ARC_fnc_stateSet;
["activeIncidentClosePendingLeadsCreated", 0] call ARC_fnc_stateSet;
missionNamespace setVariable ["ARC_activeIncidentClosePending", false, true];
missionNamespace setVariable ["ARC_activeIncidentClosePendingAt", -1, true];
missionNamespace setVariable ["ARC_activeIncidentClosePendingResult", "", true];
missionNamespace setVariable ["ARC_activeIncidentClosePendingOrderId", "", true];
missionNamespace setVariable ["ARC_activeIncidentClosePendingGroup", "", true];


    // IED detonation assessment state (reset per incident)
    ["activeIedDetonationHandled", false] call ARC_fnc_stateSet;
    ["activeIedDetonationAt", -1] call ARC_fnc_stateSet;
    ["activeIedDetonationPos", []] call ARC_fnc_stateSet;
    ["activeIedCivSnapshotAt", -1] call ARC_fnc_stateSet;
    ["activeIedCivSnapshotNetIds", []] call ARC_fnc_stateSet;
    ["activeIedCivKia", 0] call ARC_fnc_stateSet;

    // Full detonation snapshot (pairs array)
    ["activeIedDetonationSnapshot", []] call ARC_fnc_stateSet;

// Clear TOC closure prompt state
["activeIncidentCloseReady", false] call ARC_fnc_stateSet;
["activeIncidentSuggestedResult", ""] call ARC_fnc_stateSet;
["activeIncidentCloseReason", ""] call ARC_fnc_stateSet;
["activeIncidentCloseMarkedAt", -1] call ARC_fnc_stateSet;

// Clear execution bookkeeping
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

// Broadcast helpful vars
missionNamespace setVariable ["ARC_activeTaskId", "", true];
missionNamespace setVariable ["ARC_activeIncidentMarker", "", true];
missionNamespace setVariable ["ARC_activeIncidentType", "", true];
missionNamespace setVariable ["ARC_activeIncidentDisplayName", "", true];
missionNamespace setVariable ["ARC_activeIncidentPos", [], true];
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
missionNamespace setVariable ["ARC_activeLeadId", "", true];
missionNamespace setVariable ["ARC_activeThreadId", "", true];

// IED detonation assessment (presentation-safe)
missionNamespace setVariable ["ARC_activeIedDetonationHandled", false, true];
missionNamespace setVariable ["ARC_activeIedCivKia", 0, true];
missionNamespace setVariable ["ARC_activeIedDetonationSnapshot", [], true];

// Convoy public anchors (used for client-side SITREP proximity checks)
missionNamespace setVariable ["ARC_activeConvoyNetIds", [], true];

// Also refresh lead/thread UI snapshots
[] call ARC_fnc_leadBroadcast;
[] call ARC_fnc_threadBroadcast;

// Persist immediately
[] call ARC_fnc_stateSave;
true

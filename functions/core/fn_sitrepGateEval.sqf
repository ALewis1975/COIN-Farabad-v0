/*
    ARC_fnc_sitrepGateEval

    Shared SITREP gate evaluator. Returns a consistent gate result callable
    from both client (reads public replicated vars) and server (reads
    authoritative state), preventing rule drift between
    ARC_fnc_clientCanSendSitrep and ARC_fnc_tocReceiveSitrep.

    Params:
      0: OBJECT  - reporting unit (objNull skips role + proximity checks)
      1: ARRAY   - anchor positions [[x,y,z],...] for proximity check
                   (empty = skip proximity check)
      2: NUMBER  - proximity radius in metres (default 350)
      3: BOOL    - updateOnly: when true, skip close-ready gate (default false)
      4: STRING  - requestId (optional; auto-generated when "" or omitted). Used to
                   correlate client-side and server-side breadcrumbs for the same user
                   action. Pass the same value to the server remoteExec to link traces.

    Returns:
      ARRAY — [allowed (BOOL), reasonCode (STRING), stage (STRING)]

    Canonical reason codes:
      OK_ALLOWED                  — all checks passed
      OK_IDEMPOTENT               — SITREP already sent (not an error; caller decides)
      E_NO_ACTIVE_INCIDENT        — no task ID present in state
      E_INCIDENT_NOT_ACCEPTED     — incident exists but not yet accepted by TOC
      E_STATE_NOT_READY_FOR_SITREP — incident not close-ready (non-IED/VBIED only)
      E_ROLE_NOT_AUTHORIZED       — unit does not hold an authorized role
      E_AUTH_SCOPE_DENIED         — proximity check failed

    Note: evaluation order is fixed (task → accepted → close-ready → idempotent
    → role → proximity). When multiple checks would fail simultaneously the first
    failing check wins; callers must not rely on precise reasonCode when several
    gates are open at once.
*/

if (isNil "ARC_fnc_stateGet") then {
    ARC_fnc_stateGet = compile preprocessFileLineNumbers "functions\\core\\fn_stateGet.sqf";
};
if (isNil "ARC_fnc_rolesIsAuthorized") then {
    ARC_fnc_rolesIsAuthorized = compile preprocessFileLineNumbers "functions\\core\\fn_rolesIsAuthorized.sqf";
};

params [
    ["_unit",       objNull, [objNull]],
    ["_anchors",    [],      [[]]],
    ["_prox",       350,     [0]],
    ["_updateOnly", false,   [false]],
    ["_requestId",  "",      [""]]
];

private _trimFn = compile "params ['_s']; trim _s";

if (!(_prox isEqualType 0)) then { _prox = 350; };
_prox = (_prox max 100) min 2000;

// --- Read state (server: authoritative state; client: public replicated vars) ----

private _taskId      = "";
private _accepted    = false;
private _closeReady  = false;
private _typeU       = "";
private _alreadySent = false;

if (isServer) then {
    _taskId      = ["activeTaskId",             ""]    call ARC_fnc_stateGet;
    _accepted    = ["activeIncidentAccepted",   false] call ARC_fnc_stateGet;
    _closeReady  = ["activeIncidentCloseReady", false] call ARC_fnc_stateGet;
    _typeU       = ["activeIncidentType",       ""]    call ARC_fnc_stateGet;
    _alreadySent = ["activeIncidentSitrepSent", false] call ARC_fnc_stateGet;
} else {
    _taskId      = missionNamespace getVariable ["ARC_activeTaskId",             ""];
    _accepted    = missionNamespace getVariable ["ARC_activeIncidentAccepted",   false];
    _closeReady  = missionNamespace getVariable ["ARC_activeIncidentCloseReady", false];
    _typeU       = missionNamespace getVariable ["ARC_activeIncidentType",       ""];
    _alreadySent = missionNamespace getVariable ["ARC_activeIncidentSitrepSent", false];
};

// Type coercion (defensive — public vars may be any type if state is uninitialized)
if (!(_taskId      isEqualType ""))                                         then { _taskId      = ""; };
if (!(_accepted    isEqualType true) && { !(_accepted isEqualType false) }) then { _accepted    = false; };
if (!(_closeReady  isEqualType true) && { !(_closeReady isEqualType false) }) then { _closeReady = false; };
if (!(_typeU       isEqualType ""))                                         then { _typeU       = ""; };
if (!(_alreadySent isEqualType true) && { !(_alreadySent isEqualType false) }) then { _alreadySent = false; };
if (!(_updateOnly  isEqualType true) && { !(_updateOnly  isEqualType false) }) then { _updateOnly  = false; };

_typeU = toUpper ([_typeU] call _trimFn);

// Auto-generate a requestId when caller did not provide one. Uses serverTime + unit
// netId so client-side and server-side breadcrumbs for the same user action can be
// correlated when the caller passes the same id to remoteExec.
// Note: params with type guard [""] already ensures _requestId is a STRING.
if (_requestId isEqualTo "") then {
    private _uid = if (isNull _unit) then {"null"} else { netId _unit };
    _requestId = format ["auto-%1-%2", round (serverTime * 1000), _uid];
};

// ── Derive canonical task-state string from flag combination ───────────────
// Mirrors the task-state machine defined in SITREP_Gate_Parity.md §1.
private _taskStateBefore =
    if (_taskId isEqualTo "") then { "NONE" }
    else {
        if (!_accepted) then { "OFFERED" }
        else {
            if (_alreadySent) then { "SITREP_SUBMITTED_PENDING_TOC" }
            else {
                if (!_closeReady) then { "ACCEPTED" }
                else { "COMPLETE_PENDING_SITREP" }
            }
        }
    };

// ── Breadcrumb emitter ─────────────────────────────────────────────────────
// Emits a structured SITREP_GATE_EVAL event per SITREP_Gate_Parity.md §4.
// Mandatory fields: stage, outcome, reasonCode, gateStage, taskId, taskStateBefore, requestId.
// Emitted via diag_log for immediate audit; future work can route to a telemetry bus.
private _emitBreadcrumb = {
    params ["_outcome", "_reasonCode", "_gateStage", "_taskStateAfter"];
    private _stage = if (isServer) then {"server_authority"} else {"client_precheck"};
    private _crumb = [
        ["event",          "SITREP_GATE_EVAL"],
        ["stage",          _stage],
        ["outcome",        _outcome],
        ["reasonCode",     _reasonCode],
        ["gateStage",      _gateStage],
        ["taskId",         _taskId],
        ["incidentType",   _typeU],
        ["taskStateBefore",_taskStateBefore],
        ["taskStateAfter", _taskStateAfter],
        ["updateOnly",     _updateOnly],
        ["requestId",      _requestId]
    ];
    diag_log format ["[ARC][SITREP_GATE] %1", str _crumb];
};

// --- Gate checks (§2.3 canonical order) -------------------------------------

// 1. Active incident
if (_taskId isEqualTo "") exitWith {
    ["deny", "E_NO_ACTIVE_INCIDENT", "task_id", "NONE"] call _emitBreadcrumb;
    [false, "E_NO_ACTIVE_INCIDENT", "task_id"]
};

// 2. Incident accepted
if (!(_accepted isEqualType true) || { !_accepted }) exitWith {
    ["deny", "E_INCIDENT_NOT_ACCEPTED", "accepted", _taskStateBefore] call _emitBreadcrumb;
    [false, "E_INCIDENT_NOT_ACCEPTED", "accepted"]
};

// 3. Close-ready gate (waived for IED and VBIED, and for updateOnly flag)
if (!_updateOnly && { !_closeReady } && { !(_typeU in ["IED", "VBIED"]) }) exitWith {
    ["deny", "E_STATE_NOT_READY_FOR_SITREP", "close_ready", _taskStateBefore] call _emitBreadcrumb;
    [false, "E_STATE_NOT_READY_FOR_SITREP", "close_ready"]
};

// 4. Idempotency — already sent is surfaced to caller as OK_IDEMPOTENT (not an error)
if (_alreadySent) exitWith {
    ["idempotent", "OK_IDEMPOTENT", "idempotent", "SITREP_SUBMITTED_PENDING_TOC"] call _emitBreadcrumb;
    [true, "OK_IDEMPOTENT", "idempotent"]
};

// 5. Role check (skipped when unit is null)
if (!isNull _unit && { !([_unit] call ARC_fnc_rolesIsAuthorized) }) exitWith {
    ["deny", "E_ROLE_NOT_AUTHORIZED", "role", _taskStateBefore] call _emitBreadcrumb;
    [false, "E_ROLE_NOT_AUTHORIZED", "role"]
};

// 6. Proximity (skipped when no anchors provided or unit is null)
private _nearOk = true;
if ((count _anchors) > 0 && { !isNull _unit }) then {
    private _uPos = getPosATL _unit;
    _nearOk = false;
    {
        if ((_uPos distance2D _x) <= _prox) exitWith { _nearOk = true; };
    } forEach _anchors;
};

if (!_nearOk) exitWith {
    ["deny", "E_AUTH_SCOPE_DENIED", "proximity", _taskStateBefore] call _emitBreadcrumb;
    [false, "E_AUTH_SCOPE_DENIED", "proximity"]
};

// All checks passed
["allow", "OK_ALLOWED", "passed", "SITREP_SUBMITTED_PENDING_TOC"] call _emitBreadcrumb;
[true, "OK_ALLOWED", "passed"]

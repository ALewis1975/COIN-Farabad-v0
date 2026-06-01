/*
    ARC_fnc_opsTnpPartneredRequest

    Client-side: TNP partnered ops → TOC lead request (Lane C / C3).

    Lets a TNP Liaison Officer (or TOC S3 / Command) request a Takistan National
    Police PARTNERED element — a partnered patrol or a partnered checkpoint — at a
    location, without manual map-clicking. Derives the request position from the
    operator's marking context (cursor target, then own position), lets the
    operator pick the partnered task type (PATROL/CHECKPOINT) and urgency via
    button choices, then remoteExecs the existing, unchanged ARC_fnc_intelQueueSubmit
    path so the LEAD_REQUEST lands in the TOC queue for S3/Command approval.

    Selections use BIS_fnc_guiMessage two-button prompts (which return a Boolean),
    so every choice is actually captured; remarks are composed from the marking
    context. (Free-text capture is not attempted, as BIS_fnc_guiMessage cannot
    return typed text.)

    Doctrine: partnered-ops requests are never assigned directly as field tasks.
    They enter the TOC queue (PENDING) and, once approved, flow through the
    standard lead → TOC backlog path (ARC_fnc_intelQueueDecide → ARC_fnc_leadCreate).
    The partnered lead is tagged TNP_PARTNERED, which is carried end-to-end onto the
    active incident (activeLeadTag) and consumed by ARC_fnc_opsSpawnLocalSupport to
    force host-nation police/army support to stand up at the incident regardless of
    the incident type (so the PATROL variant gets a partnered element too, not just
    the CHECKPOINT variant which is already eligible).

    Reuses (does not duplicate) the server-side sender validation, queue id
    allocation, broadcast and approval plumbing already provided by the TOC queue
    subsystem. No new server RPC handler is introduced.

    Must run in a scheduled environment (uses BIS_fnc_guiMessage).

    Params: none (reads from the operator's marking context + mission state)
    Returns: BOOL
*/

if (!hasInterface) exitWith {false};
if (!canSuspend) exitWith { _this spawn ARC_fnc_opsTnpPartneredRequest; false };

// Feature flag (client-gated; seeded server-side and broadcast).
if (!(missionNamespace getVariable ["ARC_opsTnpPartneredRequestEnabled", true])) exitWith
{
    ["TNP", "TNP partnered ops request is disabled."] call ARC_fnc_clientToast;
    false
};

// Role gate: TNP (LNO / partnered) callsign, with TOC S3 / Command as a fallback
// so the partnered-ops cell can also raise a request. Mirrors the addAction condition.
private _isTnp = [player, "TNP"] call ARC_fnc_rolesHasGroupIdToken;
private _isS3  = [player] call ARC_fnc_rolesIsTocS3;
private _isCmd = [player] call ARC_fnc_rolesIsTocCommand;
if (!_isTnp && { !_isS3 } && { !_isCmd }) exitWith
{
    ["TNP", "Not authorized to request TNP partnered ops."] call ARC_fnc_clientToast;
    false
};

// Derive the request position from the operator's marking context.
// Priority: cursor target → own position.
private _markObj = cursorTarget;
private _markMethod = "VISUAL (CURSOR)";
if (isNull _markObj) then { _markMethod = "SELF POSITION"; };

private _pos = if (!isNull _markObj) then { getPosATL _markObj } else { getPosATL player };
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = getPosATL player; };
_pos = [_pos select 0, _pos select 1, 0];

private _grid = mapGridPosition _pos;

// Confirmation summary.
private _lines = [
    "TNP partnered ops request — routes to the TOC queue for approval.",
    format ["Mark: %1", _markMethod],
    format ["Grid: %1", _grid],
    "",
    "Pick the partnered task and urgency when prompted."
];
private _summaryText = _lines joinString "\n";

private _ok = [_summaryText, "TNP Partnered Ops", true, true] call BIS_fnc_guiMessage;
if (!_ok) exitWith { false };

// Partnered task type (PATROL / CHECKPOINT). A two-button BIS_fnc_guiMessage
// returns TRUE for the first button and FALSE for the second, so the choice is
// reliably captured. Drives the lead type so the incident generator stands up the
// right host-nation support (CHECKPOINT garrison/patrol or partnered patrol).
private _taskIsPatrol = [
    "Select the partnered task type:",
    "TNP Partnered Ops — Task",
    "PATROL",
    "CHECKPOINT"
] call BIS_fnc_guiMessage;
private _task = if (_taskIsPatrol) then { "PATROL" } else { "CHECKPOINT" };
private _leadType = _task;

// Urgency. Two reliable button choices (BIS_fnc_guiMessage cannot return a typed
// number): PRIORITY (1) or ROUTINE (3). Maps to the lead priority and strength.
private _isPriority = [
    "Select urgency:",
    "TNP Partnered Ops — Urgency",
    "PRIORITY (1)",
    "ROUTINE (3)"
] call BIS_fnc_guiMessage;
private _pri = if (_isPriority) then { 1 } else { 3 };

private _strength = if (_isPriority) then { 0.80 } else { 0.55 };

// Remarks are composed from the marking context (free text cannot be captured via
// BIS_fnc_guiMessage).
private _remarks = format ["Partnered %1 requested via %2.", _task, _markMethod];

private _ttl = 3600;

private _sum = format ["Lead: %1 (TNP Partnered — %2)", _leadType, _grid];

private _det = format ["Mark: %1\nGrid: %2\nPartnered task: %3\nPriority: %4", _markMethod, _grid, _task, _pri];
if (!(_remarks isEqualTo "")) then { _det = _det + format ["\nRemarks: %1", _remarks]; };

private _payload = [
    ["leadType", _leadType],
    ["displayName", _sum],
    ["strength", _strength],
    ["ttl", _ttl],
    ["priority", _pri],
    ["tag", "TNP_PARTNERED"]
];

// Send to server via the existing, unchanged TOC queue intake path.
[
    player,
    "LEAD_REQUEST",
    _payload,
    _sum,
    _det,
    _pos,
    [["source", "TNP_PARTNERED"]]
] remoteExec ["ARC_fnc_intelQueueSubmit", 2];

["TNP", "TNP partnered ops request submitted to TOC queue. Awaiting approval."] call ARC_fnc_clientToast;
true

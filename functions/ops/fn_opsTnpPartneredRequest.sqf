/*
    ARC_fnc_opsTnpPartneredRequest

    Client-side: TNP partnered ops → TOC lead request (Lane C / C3).

    Lets a TNP Liaison Officer (or TOC S3 / Command) request a Takistan National
    Police PARTNERED element — a partnered patrol or a partnered checkpoint — at a
    location, without manual map-clicking. Derives the request position from the
    operator's marking context (cursor target, then own position), lets the
    operator confirm/override the partnered task type, priority and remarks, then
    remoteExecs the existing, unchanged ARC_fnc_intelQueueSubmit path so the
    LEAD_REQUEST lands in the TOC queue for S3/Command approval.

    Doctrine: partnered-ops requests are never assigned directly as field tasks.
    They enter the TOC queue (PENDING) and, once approved, flow through the
    standard lead → TOC backlog path (ARC_fnc_intelQueueDecide → ARC_fnc_leadCreate).
    The partnered lead is tagged TNP_PARTNERED so the incident generator can prefer
    it and stand up host-nation support (e.g. checkpoint garrison/patrol).

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
    "Confirm or override partnered task, priority and remarks when prompted."
];
private _summaryText = _lines joinString "\n";

private _ok = [_summaryText, "TNP Partnered Ops", true, true] call BIS_fnc_guiMessage;
if (!_ok) exitWith { false };

private _trimFn = compile "params ['_s']; trim _s";

// Editable default: partnered task type (PATROL / CHECKPOINT).
// Drives the lead type so the incident generator can stand up the right
// host-nation support (CHECKPOINT garrison/patrol or partnered patrol).
private _task = "PATROL";
private _taskPrompt = ["Partnered task PATROL / CHECKPOINT (default: PATROL):", _task] call BIS_fnc_guiMessage;
if (_taskPrompt isEqualType "") then
{
    private _tU = toUpper ([_taskPrompt] call _trimFn);
    if (_tU find "CHECKPOINT" >= 0) then { _task = "CHECKPOINT"; };
    if (_tU find "PATROL" >= 0) then { _task = "PATROL"; };
};
private _leadType = _task;

// Editable default: priority (1 highest .. 5 lowest).
private _pri = 3;
private _priPrompt = ["Priority 1 (high) .. 5 (low) (default: 3):", "3"] call BIS_fnc_guiMessage;
if (_priPrompt isEqualType "") then
{
    private _pTrim = [_priPrompt] call _trimFn;
    private _pNum = parseNumber _pTrim;
    if (_pNum >= 1 && { _pNum <= 5 }) then { _pri = round _pNum; };
};

private _strength = switch (_pri) do
{
    case 1: { 0.80 };
    case 2: { 0.70 };
    case 4: { 0.45 };
    case 5: { 0.35 };
    default { 0.55 };
};

// Remarks (optional).
private _remarksPrompt = ["Remarks (optional):", ""] call BIS_fnc_guiMessage;
private _remarks = if (_remarksPrompt isEqualType "") then { [_remarksPrompt] call _trimFn } else { "" };

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

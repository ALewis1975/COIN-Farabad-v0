/*
    ARC_fnc_intelShadowLeadBridge

    Client-side: SHADOW (RQ-7 UAS) ISR observation → TOC lead request.

    Bridges a SHADOW operator's ISR observation into the intel pipeline without
    manual map-clicking. Derives an observation position from the UAS sensor
    context (connected-UAV laser designator first, the operator's own laser,
    then cursor target as a fallback), classifies the observed contact, lets the
    operator confirm/override the lead type, confidence and remarks, then
    remoteExecs the existing, unchanged ARC_fnc_intelQueueSubmit path so the
    LEAD_REQUEST lands in the TOC queue for S3/Command approval.

    Doctrine: ISR leads are never assigned directly as field tasks. They enter
    the TOC queue (PENDING) and, once approved, flow through the standard lead →
    TOC backlog path (ARC_fnc_intelQueueDecide → ARC_fnc_leadCreate).

    Reuses (does not duplicate) the server-side sender validation, queue id
    allocation, broadcast and approval plumbing already provided by the TOC
    queue subsystem. No new server RPC handler is introduced.

    Must run in a scheduled environment (uses BIS_fnc_guiMessage).

    Params: none (reads from the operator's UAS/marking context + mission state)
    Returns: BOOL
*/

if (!hasInterface) exitWith {false};
if (!canSuspend) exitWith { _this spawn ARC_fnc_intelShadowLeadBridge; false };

// Feature flag (client-gated; seeded server-side and broadcast).
if (!(missionNamespace getVariable ["ARC_isrShadowLeadBridgeEnabled", true])) exitWith
{
    ["ISR", "SHADOW ISR lead bridge is disabled."] call ARC_fnc_clientToast;
    false
};

// Role gate: SHADOW (UAS) callsign, with TOC S2 / Command as a fallback so the
// ISR cell can also bridge an observation. Mirrors the addAction condition.
private _isShadow = [player, "SHADOW"] call ARC_fnc_rolesHasGroupIdToken;
private _isS2 = [player] call ARC_fnc_rolesIsTocS2;
private _isCmd = [player] call ARC_fnc_rolesIsTocCommand;
if (!_isShadow && { !_isS2 } && { !_isCmd }) exitWith
{
    ["ISR", "Not authorized to bridge SHADOW ISR observations."] call ARC_fnc_clientToast;
    false
};

// Derive the observed contact from the UAS sensor context.
// Priority: connected-UAV laser → operator laser → cursor target.
private _markObj = objNull;
private _markMethod = "";

private _uav = getConnectedUAV player;
if (!isNull _uav) then
{
    _markObj = laserTarget _uav;
    if (!isNull _markObj) then { _markMethod = "UAS LASER"; };
};

if (isNull _markObj) then
{
    _markObj = laserTarget player;
    if (isNull _markObj) then { _markObj = laserTarget (vehicle player); };
    if (!isNull _markObj) then { _markMethod = "LASER"; };
};

if (isNull _markObj) then
{
    _markObj = cursorTarget;
    if (!isNull _markObj) then { _markMethod = "VISUAL (CURSOR)"; };
};

if (isNull _markObj) exitWith
{
    ["ISR", "No contact observed. Lase or aim the UAS sensor at a target, then retry."] call ARC_fnc_clientToast;
    false
};

private _pos = getPosATL _markObj;
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = getPosATL player; };
_pos = +_pos; _pos resize 3;

private _grid = mapGridPosition _pos;

// Classify the observed contact for a richer observation summary.
private _contact = "contact";
if (_markObj isKindOf "Man") then
{
    _contact = "dismount(s)";
}
else
{
    if (_markObj isKindOf "Air") then { _contact = "air contact"; }
    else
    {
        if ((_markObj isKindOf "Car") || { _markObj isKindOf "Tank" } || { _markObj isKindOf "Wheeled_APC_F" } || { _markObj isKindOf "Ship" }) then
        {
            _contact = "vehicle";
        };
    };
};

private _typeName = typeOf _markObj;
private _dispType = "";
if (_typeName isEqualType "" && { !(_typeName isEqualTo "") }) then
{
    private _disp = getText (configFile >> "CfgVehicles" >> _typeName >> "displayName");
    if (_disp isEqualType "" && { !(_disp isEqualTo "") }) then { _dispType = _disp; };
};

// Default lead type for an ISR observation is RECON (overwatch / route recon).
private _leadType = "RECON";

// Default human-readable observation summary.
private _obsDesc = if (_dispType isEqualTo "") then { _contact } else { format ["%1 (%2)", _contact, _dispType] };

// Confirmation summary.
private _lines = [
    format ["Sensor: %1", _markMethod],
    format ["Observed: %1", _obsDesc],
    format ["Grid: %1", _grid],
    "",
    "Submitting a SHADOW ISR lead routes it to the TOC queue for approval.",
    "Confirm or override lead type, confidence and remarks when prompted."
];
private _summaryText = _lines joinString "\n";

private _ok = [_summaryText, "SHADOW ISR Lead", true, true] call BIS_fnc_guiMessage;
if (!_ok) exitWith { false };

// Editable default: lead type.
private _trimFn = compile "params ['_s']; trim _s";
private _typePrompt = [format ["Lead type (default: %1):", _leadType], _leadType] call BIS_fnc_guiMessage;
if (_typePrompt isEqualType "") then
{
    private _typeTrim = [_typePrompt] call _trimFn;
    if (!(_typeTrim isEqualTo "")) then { _leadType = _typeTrim; };
};
_leadType = toUpper ([_leadType] call _trimFn);
if (_leadType isEqualTo "") then { _leadType = "RECON"; };

// Editable default: confidence (LOW / MED / HIGH).
private _conf = "MED";
private _confPrompt = ["Confidence LOW / MED / HIGH (default: MED):", _conf] call BIS_fnc_guiMessage;
if (_confPrompt isEqualType "") then
{
    private _cU = toUpper ([_confPrompt] call _trimFn);
    if (_cU find "LOW" >= 0) then { _conf = "LOW"; };
    if (_cU find "HIGH" >= 0) then { _conf = "HIGH"; };
    if (_cU find "MED" >= 0) then { _conf = "MED"; };
};

private _strength = switch (_conf) do
{
    case "LOW":  { 0.35 };
    case "HIGH": { 0.75 };
    default      { 0.55 };
};

// Remarks (optional).
private _remarksPrompt = ["Remarks (optional):", ""] call BIS_fnc_guiMessage;
private _remarks = if (_remarksPrompt isEqualType "") then { [_remarksPrompt] call _trimFn } else { "" };

private _ttl = 3600;

private _sum = format ["Lead: %1 (SHADOW ISR — %2)", _leadType, _obsDesc];

private _det = format ["Sensor: %1\nGrid: %2\nConfidence: %3\nObserved: %4", _markMethod, _grid, _conf, _obsDesc];
if (!(_remarks isEqualTo "")) then { _det = _det + format ["\nRemarks: %1", _remarks]; };

private _payload = [
    ["leadType", _leadType],
    ["displayName", _sum],
    ["strength", _strength],
    ["ttl", _ttl],
    ["confidence", _conf],
    ["tag", "SHADOW_ISR"]
];

// Send to server via the existing, unchanged TOC queue intake path.
[
    player,
    "LEAD_REQUEST",
    _payload,
    _sum,
    _det,
    _pos,
    [["source", "SHADOW_ISR"]]
] remoteExec ["ARC_fnc_intelQueueSubmit", 2];

["ISR", "SHADOW ISR lead submitted to TOC queue. Awaiting approval."] call ARC_fnc_clientToast;
true

/*
    Server: handle a player interacting with / completing an on-site objective (action).

    Stages:
      - DISCOVER: inspection step for suspicious-object objectives (IED/VBIED). Logs discovery and
                  updates threat state to DISCOVERED, but does NOT close the incident.
      - COMPLETE: normal completion. Logs completion, updates threat state (if applicable), and
                  marks the incident as close-ready for TOC.

    Params:
        0: STRING - objectiveKind (RAID_INTEL, IED_DEVICE, VBIED_VEHICLE, CACHE_SEARCH, CIV_MEET, LOG_DROP, ESCORT_END)
        1: OBJECT - target object/NPC
        2: OBJECT - player/caller
        3: STRING - summary (optional)
        4: STRING - details (optional)
        5: STRING - stage ("DISCOVER" | "COMPLETE") [optional]

    Returns:
        BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_kind", ""],
    ["_target", objNull],
    ["_caller", objNull],
    ["_summary", ""],
    ["_details", ""],
    ["_stage", "COMPLETE"]
];

if (_kind isEqualTo "") exitWith {false};
if (isNull _target) exitWith {false};
if (isNull _caller) exitWith {false};
if (!isPlayer _caller) exitWith {false};

// Dedicated MP hardening: validate sender identity.
private _trimFn = compile "params ['_s']; trim _s";

if (!isNil "remoteExecutedOwner") then
{
    private _reo = remoteExecutedOwner;
    if (_reo > 0) then
    {
        if ((owner _caller) != _reo) exitWith
        {
            diag_log format ["[ARC][SEC] %1 denied: sender-owner mismatch reo=%2 callerOwner=%3 caller=%4",
                "ARC_fnc_execObjectiveComplete", _reo, owner _caller, name _caller];
            false
        };
    };
};

private _stageU = toUpper ([_stage] call _trimFn);
// IED/VBIED suspicious-object objectives support a "scan" discovery stage.
if !(_stageU in ["DISCOVER", "DISCOVER_SCAN", "COMPLETE"]) then { _stageU = "COMPLETE"; };

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (_taskId isEqualTo "") exitWith {false};

// Validate this objective matches the currently active objective
private _activeKind = ["activeObjectiveKind", ""] call ARC_fnc_stateGet;
private _activeNet = ["activeObjectiveNetId", ""] call ARC_fnc_stateGet;

if (!(_activeKind isEqualTo _kind)) exitWith {false};
if (!(_activeNet isEqualTo "") && { !((netId _target) isEqualTo _activeNet) }) exitWith {false};

private _kindU = toUpper ([_kind] call _trimFn);

// Tiny kv helper for threat records
private _kvGet = {
    params ["_pairs", "_key", ["_default",""]];
    private _out = _default;
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _out = _x select 1; };
    } forEach _pairs;
    _out
};

private _getThreatState = {
    params ["_tid"];
    if (_tid isEqualTo "") exitWith {""};
    private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
    if (!(_records isEqualType [])) then { _records = []; };

    private _idx = -1;
    { if (_x isEqualType [] && { ([_x, "threat_id", ""] call _kvGet) isEqualTo _tid }) exitWith { _idx = _forEachIndex; }; } forEach _records;
    if (_idx < 0) exitWith {""};

    private _st = [_records select _idx, "state", ""] call _kvGet;
    if (!(_st isEqualType "")) then { _st = ""; };
    toUpper ([_st] call _trimFn)
};

// CACHE_SEARCH is a multi-container objective: allow interactions with any cache container.
// The server decides if this specific container is the real cache.
if (_kind isEqualTo "CACHE_SEARCH") then
{
    // Cache searches are always treated as COMPLETE stage.
    private _isTrue = _target getVariable ["ARC_cacheIsTrue", false];
    if (!(_isTrue isEqualType true) && !(_isTrue isEqualType false)) then { _isTrue = false; };

    private _posC = getPosATL _target;

    if (!_isTrue) exitWith
    {
        // Quick negative: log as OPS (not intel) and tell the searching player.
        ["OPS", "Cache container searched: negative.", _posC, [["event", "CACHE_SEARCH_NEGATIVE"], ["taskId", _taskId], ["caller", name _caller]]] call ARC_fnc_intelLog;
        ["Negative. Continue searching the area."] remoteExec ["ARC_fnc_clientHint", _caller];
        true
    };

    // Positive cache find: continue through normal intel logging + close recommendation.
};

private _pos = getPosATL _target;
private _zone = [_pos] call ARC_fnc_worldGetZoneForPos;

// ---------------------------------------------------------------------------
// DISCOVER stage (IED Phase 2): inspection or scan (no prompt)
// ---------------------------------------------------------------------------
if (_stageU in ["DISCOVER","DISCOVER_SCAN"]) exitWith
{
    // Only meaningful for suspicious-object objectives
    if !(_kindU in ["IED_DEVICE", "VBIED_VEHICLE"]) exitWith {false};

    private _already = _target getVariable ["ARC_objectiveDiscovered", false];
    if (!(_already isEqualType true) && !(_already isEqualType false)) then { _already = false; };
    if (_already) exitWith {true};

    _target setVariable ["ARC_objectiveDiscovered", true, true];
    _target setVariable ["ARC_objectiveDiscoveredAt", serverTime, true];

    if (_summary isEqualTo "") then
    {
        _summary = switch (_kindU) do
        {
            case "IED_DEVICE": { if (_stageU isEqualTo "DISCOVER_SCAN") then { "Device scan indicates possible IED." } else { "Suspicious device inspected; possible IED." }; };
            case "VBIED_VEHICLE": { "Suspicious vehicle inspected." };
            default { "Objective inspected." };
        };
    };

    private _meta = [
        ["event", "OBJECTIVE_DISCOVERED"],
        ["stage", _stageU],
        ["objectiveKind", _kindU],
        ["taskId", _taskId],
        ["zone", _zone],
        ["caller", name _caller]
    ];

    if (!(([_details] call _trimFn) isEqualTo "")) then { _meta pushBack ["details", [_details] call _trimFn]; };

    ["TECHINT", _summary, _pos, _meta] call ARC_fnc_intelLog;


// Phase 2: ensure an evidence prop exists for collection.
// Phase 3: also allow suspicious-vehicle (VBIED) discovery to generate SSE evidence pre-blast.
if (_kindU in ["IED_DEVICE", "VBIED_VEHICLE"]) then
{
    if (_kindU isEqualTo "IED_DEVICE" && { _stageU isEqualTo "DISCOVER_SCAN" }) then
    {
        ["activeIedDetectedByScan", true] call ARC_fnc_stateSet;
    };
    [_pos, _stageU] call ARC_fnc_iedEnsureEvidence;
};


    // Threat hook: ensure a record exists and mark as DISCOVERED (do not downgrade existing states).
    private _tCtx = [
        ["task_id", _taskId],
        ["objective_kind", _kindU],
        ["pos", _pos],
        ["note", "OBJECTIVE_DISCOVERED"]
    ];

    private _tid = [_taskId, "IED", "IED_SUSPICIOUS_OBJECT", _tCtx] call ARC_fnc_threatCreateFromTask;
    if (!(_tid isEqualTo "")) then
    {
        private _cur = [_tid] call _getThreatState;
        if (_cur in ["", "CREATED", "ACTIVE"]) then
        {
            [_tid, "DISCOVERED", "OBJECTIVE_DISCOVERED"] call ARC_fnc_threatUpdateState;
        };
    };

    true
};

// ---------------------------------------------------------------------------
// COMPLETE stage: normal completion + close-ready recommendation
// ---------------------------------------------------------------------------

// Basic idempotence for single-object objectives (prevents double-click / two-player spam).
// CACHE_SEARCH is special and must not be blocked here.
if (!(_kindU isEqualTo "CACHE_SEARCH")) then
{
    private _done = _target getVariable ["ARC_objectiveCompleted", false];
    if (!(_done isEqualType true) && !(_done isEqualType false)) then { _done = false; };
    if (_done) exitWith {true};
    _target setVariable ["ARC_objectiveCompleted", true, true];
};

// Default report text (players can override in the prompt)
if (_summary isEqualTo "") then
{
    _summary = switch (_kindU) do
    {
        case "RAID_INTEL": { "Recovered documents / media for exploitation." };
        case "IED_DEVICE": { "IED device located and cleared." };
        case "VBIED_VEHICLE": { "Suspicious vehicle inspected and cleared." };
        case "CACHE_SEARCH": { "Cache located and secured." };
        case "CIV_MEET": { "Conducted local engagement; collected HUMINT." };
        case "LOG_DROP": { "Delivered supplies to the designated point." };
        case "ESCORT_END": { "Escort reached destination; arrival confirmed." };
        default { "Objective complete." };
    };
};

private _cat = switch (_kindU) do
{
    case "RAID_INTEL": { "DOCS" };
    case "IED_DEVICE": { "TECHINT" };
    case "VBIED_VEHICLE": { "TECHINT" };
    case "CACHE_SEARCH": { "DOCS" };
    case "CIV_MEET": { "HUMINT" };
    case "LOG_DROP": { "LOGISTICS" };
    case "ESCORT_END": { "OPS" };
    default { "INTEL" };
};

    ["event", "OBJECTIVE_COMPLETE"],
    ["stage", "COMPLETE"],
    ["objectiveKind", _kindU],
    ["taskId", _taskId],
    ["zone", _zone],
    ["caller", name _caller]
];

if (!(([_details] call _trimFn) isEqualTo "")) then
{
    _meta pushBack ["details", [_details] call _trimFn];
};

[_cat, _summary, _pos, _meta] call ARC_fnc_intelLog;

// Threat hook (IED Phase 1): completion implies neutralization. Backfill discovery if needed.
if (_kindU in ["IED_DEVICE", "VBIED_VEHICLE"]) then
{
    // Ensure "discovered" flag is set for clients even if they somehow hit COMPLETE first.
    private _disc = _target getVariable ["ARC_objectiveDiscovered", false];
    if (!(_disc isEqualType true) && !(_disc isEqualType false)) then { _disc = false; };
    if (!_disc) then
    {
        _target setVariable ["ARC_objectiveDiscovered", true, true];
        _target setVariable ["ARC_objectiveDiscoveredAt", serverTime, true];
    };

        ["task_id", _taskId],
        ["objective_kind", _kindU],
        ["pos", _pos],
        ["note", "OBJECTIVE_COMPLETE"]
    ];

    // Ensure a threat record exists (idempotent) and update states without downgrades.
    if (!(_tid isEqualTo "")) then
    {

        if (_cur in ["", "CREATED", "ACTIVE"]) then
        {
            [_tid, "DISCOVERED", "OBJECTIVE_COMPLETE_BACKFILL_DISCOVERED"] call ARC_fnc_threatUpdateState;
        };

        if (_cur in ["", "CREATED", "ACTIVE", "DISCOVERED"]) then
        {
            [_tid, "NEUTRALIZED", "OBJECTIVE_COMPLETE"] call ARC_fnc_threatUpdateState;
        };
    };
};

// Stabilization: do NOT delete the IED prop on clearance.
// Rationale: the follow-on flow may call for "detonate in place" or "RTB IED".
// Deleting the prop makes both actions impossible and confuses players.
if (_kindU isEqualTo "IED_DEVICE") then
{
    private _deleteOnClear = missionNamespace getVariable ["ARC_iedDeletePropOnClear", false];
    if (!(_deleteOnClear isEqualType true) && !(_deleteOnClear isEqualType false)) then { _deleteOnClear = false; };

    [_target, _deleteOnClear] spawn
    {
        params ["_o", "_doDel"];
        sleep 0.5;
        if (isNull _o) exitWith {};

        _o allowDamage true;
        _o setVariable ["ARC_iedCleared", true, true];
        _o setVariable ["ARC_iedClearedAt", serverTime, true];

        // Best-effort: make it movable via ACE carry/drag if ACE is present.
        _o setVariable ["ace_dragging_canDrag", true, true];
        _o setVariable ["ace_dragging_dragPosition", [0,1.2,0], true];
        _o setVariable ["ace_dragging_dragDirection", 0, true];
        _o setVariable ["ace_dragging_canCarry", true, true];
        _o setVariable ["ace_dragging_carryPosition", [0,1.0,0.2], true];
        _o setVariable ["ace_dragging_carryDirection", 0, true];

        if (_doDel) then
        {
            deleteVehicle _o;
        };
    };
};

// Objective-generated "output" (leads) for OP-layer integration.
// This is intentionally lightweight: it produces a next-step lead, not a task closeout decision.
private _leadOut = missionNamespace getVariable ["ARC_objectiveLeadOutputsEnabled", true];
if (!(_leadOut isEqualType true) && !(_leadOut isEqualType false)) then { _leadOut = true; };

if (_leadOut) then
{
    private _incType = ["activeIncidentType", ""] call ARC_fnc_stateGet;
    if (!(_incType isEqualType "")) then { _incType = ""; };
    private _tag = ["activeLeadTag", ""] call ARC_fnc_stateGet;
    if (!(_tag isEqualType "")) then { _tag = ""; };

    private _tagU = toUpper ([_tag] call _trimFn);

    // 1) HUMINT interview -> follow-on recon lead
    if (_kindU isEqualTo "CIV_MEET") then
    {
        private _existing = _target getVariable ["ARC_objectiveLeadId", ""];
        if (!(_existing isEqualType "")) then { _existing = ""; };

        if (_existing isEqualTo "") then
        {
            private _lid = ["RECON", "Lead: HUMINT follow-up", _pos, 0.45, 55*60, _taskId, _incType, "", "SUS_ACTIVITY"] call ARC_fnc_leadCreate;
            if (!(_lid isEqualTo "")) then
            {
                _target setVariable ["ARC_objectiveLeadId", _lid, true];
            };
        };
    };

    // 2) Suspicious vehicle / VOI -> follow-on recon lead (keeps the chain moving)
    if (_kindU isEqualTo "VBIED_VEHICLE" && { _tagU isEqualTo "SUS_VEHICLE" }) then
    {
        private _existing = _target getVariable ["ARC_objectiveLeadId", ""];
        if (!(_existing isEqualType "")) then { _existing = ""; };

        if (_existing isEqualTo "") then
        {
            private _lid = ["RECON", "Lead: Vehicle of interest follow-up", _pos, 0.45, 50*60, _taskId, _incType, "", "SUS_VEHICLE"] call ARC_fnc_leadCreate;
            if (!(_lid isEqualTo "")) then
            {
                _target setVariable ["ARC_objectiveLeadId", _lid, true];
            };
        };
    };
};

// TOC controls closure; recommend success.
["SUCCEEDED", "OBJECTIVE_COMPLETE", "Objective completed. Recommend closing this incident as SUCCEEDED.", _pos] call ARC_fnc_incidentMarkReadyToClose;
true

/*
    Client: handle interaction with an objective (document, IED prop, liaison, etc.).

    Flow:
      - COMPLETE: prompt player for a short summary + optional details, then send to server.
      - DISCOVER: quick "inspection" stage (no prompt), then send to server.

    Params:
        0: OBJECT - target
        1: OBJECT - caller
        2: STRING - objectiveKind
        3: STRING - stage ("DISCOVER" | "DISCOVER_SCAN" | "COMPLETE") [optional]

    Returns:
        BOOL
*/

if (!hasInterface) exitWith {false};

if (!canSuspend) exitWith { _this spawn ARC_fnc_clientObjectiveInteract; false };

params [
    ["_target", objNull],
    ["_caller", objNull],
    ["_kind", ""],
    ["_stage", "COMPLETE"]
];

if (isNull _target) exitWith {false};
if (isNull _caller) exitWith {false};
if (_kind isEqualTo "") exitWith {false};

private _stageU = toUpper ([_stage] call _trimFn);

// Helper: remove any stored objective actions for this target (supports int or array)
private _removeObjectiveActions = {
    params ["_tgt"];
    if (isNull _tgt) exitWith {};
    private _nid = netId _tgt;
    if (_nid isEqualTo "") exitWith {};
    private _key = format ["ARC_objAct_%1", _nid];

    private _val = missionNamespace getVariable [_key, nil];
    if (isNil "_val") exitWith {};

    if (_val isEqualType 0) then
    {
        if (_val >= 0) then { _tgt removeAction _val; };
    }
    else
    {
        if (_val isEqualType []) then
        {
            { if (_x isEqualType 0 && { _x >= 0 }) then { _tgt removeAction _x; }; } forEach _val;
        };
    };

    missionNamespace setVariable [_key, nil];
};

// Fast path: DISCOVER stage (no prompt)
if (_stageU in ["DISCOVER","DISCOVER_SCAN"]) exitWith
{
    [_kind, _target, _caller, "", "", _stageU] remoteExec ["ARC_fnc_execObjectiveComplete", 2];
    true
};

private _cat = switch (_kind) do
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

private _defaultSummary = switch (_kind) do
{
    case "RAID_INTEL": { "Recovered documents / media" };
    case "IED_DEVICE": { "Device cleared" };
    case "VBIED_VEHICLE": { "Suspicious vehicle cleared" };
    case "CACHE_SEARCH": { "Cache secured" };
    case "CIV_MEET": { "Meeting conducted" };
    case "LOG_DROP": { "Supplies delivered" };
    case "ESCORT_END": { "Arrival confirmed" };
    default { "Objective complete" };
};

private _defaultDetails = "";

// Cache searches should be quick (no prompt); the server will tell the player if it is negative.
if (_kind isEqualTo "CACHE_SEARCH") exitWith
{
    // Prevent spam double-clicks on this client.
    [_target] call _removeObjectiveActions;

    [_kind, _target, _caller, "", "", "COMPLETE"] remoteExec ["ARC_fnc_execObjectiveComplete", 2];
    true
};

// Prompt for better-than-generic entries.
private _resp = [_cat, _defaultSummary, _defaultDetails] call ARC_fnc_clientIntelPrompt;
_resp params ["_ok", "_sum", "_det"];
if (!_ok) exitWith {false};


// sqflint-compatible helpers
private _trimFn  = compile "params ['_s']; trim _s";
// Prevent spam double-clicks on this client.
[_target] call _removeObjectiveActions;

[_kind, _target, _caller, _sum, _det, "COMPLETE"] remoteExec ["ARC_fnc_execObjectiveComplete", 2];
true

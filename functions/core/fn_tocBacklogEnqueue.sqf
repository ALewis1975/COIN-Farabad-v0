/*
    ARC_fnc_tocBacklogEnqueue

    Server: enqueue an approved lead into a TOC backlog so it can be selected as a future incident.

    This is a triage tool:
      - Does not create incidents
      - Does not issue orders
      - Only records an "approved work item" for later TOC-driven incident creation

    Params:
      0: STRING leadId
      1: NUMBER priority (1..5, default 3)
      2: STRING sourceQueueId (optional)
      3: STRING by (formatted name, optional)
      4: STRING note/summary (optional)

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_leadId", "", [""]],
    ["_priority", 3, [0]],
    ["_sourceQid", "", [""]],
    ["_by", "SYSTEM", [""]],
    ["_note", "", [""]]
];

if (!(_leadId isEqualType "")) then { _leadId = ""; };
_leadId = [_leadId] call _trimFn;
if (_leadId isEqualTo "") exitWith {false};

if (!(_priority isEqualType 0)) then { _priority = 3; };
_priority = round _priority;
_priority = (_priority max 1) min 5;

if (!(_sourceQid isEqualType "")) then { _sourceQid = ""; };
_sourceQid = [_sourceQid] call _trimFn;

if (!(_by isEqualType "")) then { _by = "SYSTEM"; };
_by = [_by] call _trimFn;

if (!(_note isEqualType "")) then { _note = ""; };
_note = [_note] call _trimFn;

// Must exist in leadPool, otherwise backlog entry is meaningless.
private _pool = ["leadPool", []] call ARC_fnc_stateGet;
if (!(_pool isEqualType [])) then { _pool = []; };

private _li = -1;
{ if (_x isEqualType [] && { (count _x) >= 1 } && { (_x select 0) isEqualTo _leadId }) exitWith { _li = _forEachIndex; }; } forEach _pool;
if (_li < 0) exitWith {false};


// sqflint-compatible helpers
private _trimFn  = compile "params ['_s']; trim _s";
private _lead = _pool select _li;

private _leadType = "";
private _leadName = "";
private _leadPos = [];
private _tag = "";

if ((count _lead) >= 2 && { (_lead select 1) isEqualType "" }) then { _leadType = _lead select 1; };
if ((count _lead) >= 3 && { (_lead select 2) isEqualType "" }) then { _leadName = _lead select 2; };
if ((count _lead) >= 4 && { (_lead select 3) isEqualType [] }) then { _leadPos = _lead select 3; };
if ((count _lead) >= 11 && { (_lead select 10) isEqualType "" }) then { _tag = _lead select 10; };

private _zone = "";
if (_leadPos isEqualType [] && { (count _leadPos) >= 2 }) then
{
    _zone = [_leadPos] call ARC_fnc_worldGetZoneForPos;
};

private _back = ["tocBacklog", []] call ARC_fnc_stateGet;
if (!(_back isEqualType [])) then { _back = []; };

// Avoid duplicates by leadId.
private _exists = -1;
{ if (_x isEqualType [] && { (count _x) >= 1 } && { (_x select 0) isEqualTo _leadId }) exitWith { _exists = _forEachIndex; }; } forEach _back;
if (_exists >= 0) exitWith {true};

// Record shape:
// [leadId, priority, enqueuedAt, sourceQueueId, by, note, leadType, leadName, zone, tag]
_back pushBack [_leadId, _priority, serverTime, _sourceQid, _by, _note, _leadType, _leadName, _zone, _tag];

// Cap growth.
private _cap = missionNamespace getVariable ["ARC_tocBacklogCap", 30];
if (!(_cap isEqualType 0)) then { _cap = 30; };
_cap = (_cap max 10) min 200;

if ((count _back) > _cap) then
{
    // Keep the most recent items (drop oldest).
    _back = _back select [((count _back) - _cap) max 0, _cap];
};

["tocBacklog", _back] call ARC_fnc_stateSet;

true

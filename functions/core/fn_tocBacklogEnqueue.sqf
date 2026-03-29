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
_leadId = trim _leadId;
if (_leadId isEqualTo "") exitWith {false};

if (!(_priority isEqualType 0)) then { _priority = 3; };
_priority = round _priority;
_priority = (_priority max 1) min 5;

if (!(_sourceQid isEqualType "")) then { _sourceQid = ""; };
_sourceQid = trim _sourceQid;

if (!(_by isEqualType "")) then { _by = "SYSTEM"; };
_by = trim _by;

if (!(_note isEqualType "")) then { _note = ""; };
_note = trim _note;

// Must exist in leadPool, otherwise backlog entry is meaningless.
private _pool = ["leadPool", []] call ARC_fnc_stateGet;
if (!(_pool isEqualType [])) then { _pool = []; };

private _li = -1;
{ if (_x isEqualType [] && { (count _x) >= 1 } && { (_x # 0) isEqualTo _leadId }) exitWith { _li = _forEachIndex; }; } forEach _pool;
if (_li < 0) exitWith {false};

private _lead = _pool # _li;

private _leadType = "";
private _leadName = "";
private _leadPos = [];
private _tag = "";

if ((count _lead) >= 2 && { (_lead # 1) isEqualType "" }) then { _leadType = _lead # 1; };
if ((count _lead) >= 3 && { (_lead # 2) isEqualType "" }) then { _leadName = _lead # 2; };
if ((count _lead) >= 4 && { (_lead # 3) isEqualType [] }) then { _leadPos = _lead # 3; };
if ((count _lead) >= 11 && { (_lead # 10) isEqualType "" }) then { _tag = _lead # 10; };

private _zone = "";
if (_leadPos isEqualType [] && { (count _leadPos) >= 2 }) then
{
    _zone = [_leadPos] call ARC_fnc_worldGetZoneForPos;
};

private _back = ["tocBacklog", []] call ARC_fnc_stateGet;
if (!(_back isEqualType [])) then { _back = []; };

// Avoid duplicates by leadId.
private _exists = -1;
{ if (_x isEqualType [] && { (count _x) >= 1 } && { (_x # 0) isEqualTo _leadId }) exitWith { _exists = _forEachIndex; }; } forEach _back;
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

/*
    ARC_fnc_casreqDecide

    Server-only: TOC approves or denies an open CASREQ.

    Only S3/Command (queue approvers) or OMNI may decide.

    Params:
      0: OBJECT - deciding unit (TOC operator)
      1: STRING - casreq_id
      2: STRING - decision: "APPROVED" | "DENIED"
      3: STRING - reason (optional)

    Returns: BOOL
*/

if (!isServer) exitWith {false};

if (!([_this select 0, "ARC_fnc_casreqDecide", "CASREQ decide rejected: sender mismatch.", "CASREQ_DECIDE_SEC_DENIED", true] call ARC_fnc_rpcValidateSender)) exitWith {false};

params [
    ["_unit",      objNull, [objNull]],
    ["_id",        "",      [""]],
    ["_decision",  "",      [""]],
    ["_reason",    "",      [""]]
];

if (isNull _unit) exitWith {false};
if (_id isEqualTo "") exitWith {false};

private _trimFn = compile "params ['_s']; trim _s";
private _decU = toUpper ([_decision] call _trimFn);
if (!(_decU in ["APPROVED", "DENIED"])) exitWith
{
    diag_log format ["[ARC][CASREQ] casreqDecide: invalid decision '%1' for %2.", _decision, _id];
    false
};

// Role gate: only S3/Command (queue approvers) or OMNI
private _omniTokens = missionNamespace getVariable ["ARC_consoleOmniTokens", ["OMNI"]];
if (!(_omniTokens isEqualType [])) then { _omniTokens = ["OMNI"]; };
private _isOmni = false;
{ if (_x isEqualType "" && { [_unit, _x] call ARC_fnc_rolesHasGroupIdToken }) exitWith { _isOmni = true; }; } forEach _omniTokens;

if (!_isOmni && { !([_unit] call ARC_fnc_rolesCanApproveQueue) }) exitWith
{
    diag_log format ["[ARC][CASREQ] casreqDecide: role denied for %1.", [_unit] call ARC_fnc_rolesFormatUnit];
    if (!isNull _unit) then {
        ["CASREQ decision denied: requires S3/Command or OMNI."] remoteExec ["ARC_fnc_clientHint", owner _unit];
    };
    false
};

private _records = ["casreq_v1_records", createHashMap] call ARC_fnc_stateGet;
if (!(_records isEqualType createHashMap)) exitWith
{
    diag_log "[ARC][CASREQ] casreqDecide: records store missing.";
    false
};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _record = [_records, _id, []] call _hg;
if (!(_record isEqualType []) || { _record isEqualTo [] }) exitWith
{
    diag_log format ["[ARC][CASREQ] casreqDecide: record %1 not found.", _id];
    false
};

// Only OPEN records may be decided
private _stateIdx = -1;
{ if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "state" }) exitWith { _stateIdx = _forEachIndex; }; } forEach _record;
if (_stateIdx < 0) exitWith { false };

private _curState = toUpper ((_record select _stateIdx) select 1);
if (!(_curState in ["OPEN"])) exitWith
{
    diag_log format ["[ARC][CASREQ] casreqDecide: %1 is in state %2, cannot decide.", _id, _curState];
    false
};

(_record select _stateIdx) set [1, _decU];

// Update updated_at
private _now = serverTime;
private _updIdx = -1;
{ if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "updated_at" }) exitWith { _updIdx = _forEachIndex; }; } forEach _record;
if (_updIdx >= 0) then { (_record select _updIdx) set [1, _now]; };

// Append to messages log
private _msgIdx = -1;
{ if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "messages" }) exitWith { _msgIdx = _forEachIndex; }; } forEach _record;
if (_msgIdx >= 0) then
{
    private _msgs = (_record select _msgIdx) select 1;
    if (!(_msgs isEqualType [])) then { _msgs = []; };
    private _actor = [_unit] call ARC_fnc_rolesFormatUnit;
    _msgs pushBack [["event", _decU], ["at", _now], ["by", _actor], ["reason", _reason]];
    (_record select _msgIdx) set [1, _msgs];
};

_records set [_id, _record];
["casreq_v1_records", _records] call ARC_fnc_stateSet;

// If denied, move from open to closed index
if (_decU isEqualTo "DENIED") then
{
    private _openIdx = ["casreq_v1_open_index", []] call ARC_fnc_stateGet;
    if (_openIdx isEqualType []) then
    {
        private _pos = -1;
        { if (_x isEqualTo _id) exitWith { _pos = _forEachIndex; }; } forEach _openIdx;
        if (_pos >= 0) then { _openIdx deleteAt _pos; };
        ["casreq_v1_open_index", _openIdx] call ARC_fnc_stateSet;
    };

    private _closedIdx = ["casreq_v1_closed_index", []] call ARC_fnc_stateGet;
    if (!(_closedIdx isEqualType [])) then { _closedIdx = []; };
    _closedIdx pushBackUnique _id;
    ["casreq_v1_closed_index", _closedIdx] call ARC_fnc_stateSet;
};

[_id, [_unit] call ARC_fnc_rolesFormatUnit, _decU, [["reason", _reason]]] call ARC_fnc_casreqBroadcastDelta;

diag_log format ["[ARC][CASREQ] casreqDecide: %1 %2 by %3.", _id, _decU, [_unit] call ARC_fnc_rolesFormatUnit];
true

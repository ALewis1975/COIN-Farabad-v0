/*
    ARC_fnc_casreqOpen

    Server-only: create a new CASREQ record from a JTAC/S3 submission.

    Params:
      0: OBJECT - requesting unit (player)
      1: STRING - district ID (e.g. "D01") — used for ID generation
      2: ARRAY  - target position [x,y,z]
      3: ARRAY  - nine-line data (array of [key,value] pairs)
      4: STRING - remarks (optional)

    Returns:
      STRING — new casreq_id, or "" on failure
*/

if (!isServer) exitWith {""};

// Sender validation
if (!([_this select 0, "ARC_fnc_casreqOpen", "CASREQ open rejected: sender mismatch.", "CASREQ_OPEN_SEC_DENIED", true] call ARC_fnc_rpcValidateSender)) exitWith {""};

params [
    ["_unit",       objNull, [objNull]],
    ["_districtId", "",      [""]],
    ["_targetPos",  [],      [[]]],
    ["_nineLine",   [],      [[]]],
    ["_remarks",    "",      [""]]
];

if (isNull _unit) exitWith
{
    diag_log "[ARC][CASREQ] casreqOpen: null unit rejected.";
    ""
};

if (!missionNamespace getVariable ["casreq_v1_enabled", true]) exitWith
{
    diag_log "[ARC][CASREQ] casreqOpen: subsystem disabled.";
    ""
};

// Role gate: JTAC-authorized role (queue approvers OR authorized field role)
if (!([_unit] call ARC_fnc_rolesIsAuthorized) && { !([_unit] call ARC_fnc_rolesCanApproveQueue) }) exitWith
{
    private _who = [_unit] call ARC_fnc_rolesFormatUnit;
    diag_log format ["[ARC][CASREQ] casreqOpen: role denied for %1.", _who];
    if (!isNull _unit) then {
        ["CASREQ", "REJECTED: not authorized to submit CAS requests."] remoteExec ["ARC_fnc_clientHint", owner _unit];
    };
    ""
};

private _trimFn = compile "params ['_s']; trim _s";

private _id = [_districtId] call ARC_fnc_casreqBuildId;
if (_id isEqualTo "") exitWith
{
    diag_log "[ARC][CASREQ] casreqOpen: failed to build CASREQ ID.";
    ""
};

private _requester = if (!isNull _unit) then { [_unit] call ARC_fnc_rolesFormatUnit } else { "UNKNOWN" };
private _incidentId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (!(_incidentId isEqualType "")) then { _incidentId = ""; };

private _safePos = if (_targetPos isEqualType [] && { (count _targetPos) >= 2 }) then { +_targetPos } else { [0,0,0] };
_safePos resize 3;

private _safeRemarks = if (_remarks isEqualType "") then { [_remarks] call _trimFn } else { "" };
private _safeNine   = if (_nineLine isEqualType []) then { _nineLine } else { [] };

private _now = serverTime;

private _record = [
    ["casreq_id",   _id],
    ["district_id", _districtId],
    ["state",       "OPEN"],
    ["requester",   _requester],
    ["area",        [["target_pos", _safePos], ["target_marker", ""]]],
    ["messages",    [
        [["event", "OPENED"], ["at", _now], ["by", _requester]]
    ]],
    ["created_at",  _now],
    ["updated_at",  _now],
    // Extended fields
    ["incident_id", _incidentId],
    ["nine_line",   _safeNine],
    ["result",      ""],
    ["closed_at",   -1]
];

private _records = ["casreq_v1_records", createHashMap] call ARC_fnc_stateGet;
if (!(_records isEqualType createHashMap)) then { _records = createHashMap; };
_records set [_id, _record];
["casreq_v1_records", _records] call ARC_fnc_stateSet;

private _openIdx = ["casreq_v1_open_index", []] call ARC_fnc_stateGet;
if (!(_openIdx isEqualType [])) then { _openIdx = []; };
_openIdx pushBackUnique _id;
["casreq_v1_open_index", _openIdx] call ARC_fnc_stateSet;

[_id, _requester, "OPENED", [["district_id", _districtId]]] call ARC_fnc_casreqBroadcastDelta;

diag_log format ["[ARC][CASREQ] casreqOpen: created %1 by %2 incidentId=%3.", _id, _requester, _incidentId];

if (!isNull _unit) then {
    [format ["CASREQ %1 submitted — awaiting TOC decision.", _id]] remoteExec ["ARC_fnc_clientHint", owner _unit];
};

_id

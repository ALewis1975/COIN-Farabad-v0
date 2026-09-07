/*
    ARC_fnc_iedServerRequestDisposition

    Server RPC: start an approved EOD disposition lifecycle.

    Params:
      0: STRING requestType (RTB_IED|TOW_VBIED)

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_req", "", [""]]
];

private _trimFn = compile "params ['_s']; trim _s";
_req = toUpper ([_req] call _trimFn);
if (!(_req in ["RTB_IED", "TOW_VBIED"])) exitWith {false};

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (!(_taskId isEqualType "")) then { _taskId = ""; };
if (_taskId isEqualTo "") exitWith {false};

private _gid = ["activeIncidentAcceptedByGroup", ""] call ARC_fnc_stateGet;
if (!(_gid isEqualType "")) then { _gid = ""; };
if (_gid isEqualTo "") exitWith {false};

private _reoOwner = remoteExecutedOwner;
private _senderAuthorized = if (isRemoteExecuted && { _reoOwner != 2 }) then
{
    private _caller = objNull;
    { if (isPlayer _x && { (owner _x) isEqualTo _reoOwner }) exitWith { _caller = _x; }; } forEach allPlayers;
    if (!([_caller, "ARC_fnc_iedServerRequestDisposition", "Disposition rejected: sender mismatch.", "IED_DISPOSITION_DENIED", true, _reoOwner] call ARC_fnc_rpcValidateSender)) exitWith { false };
    (groupId (group _caller)) isEqualTo _gid
} else { true };
if (!_senderAuthorized) exitWith
{
    diag_log format ["[ARC][SEC] IED_DISPOSITION_DENIED owner=%1 taskId=%2 group=%3 req=%4 ts=%5", _reoOwner, _taskId, _gid, _req, serverTime];
    false
};

private _hasApproval = false;
private _appr = ["eodDispoApprovals", []] call ARC_fnc_stateGet;
if (!(_appr isEqualType [])) then { _appr = []; };

{
    if (!(_x isEqualType [] && { (count _x) >= 6 })) then { continue; };
    if (!((_x select 0) isEqualTo _taskId)) then { continue; };
    if (!((_x select 1) isEqualTo _gid)) then { continue; };
    private _rt = _x select 2;
    if (!(_rt isEqualType "")) then { _rt = ""; };
    if (!((toUpper ([_rt] call _trimFn)) isEqualTo _req)) then { continue; };
    private _exp = _x select 5;
    if (!(_exp isEqualType 0)) then { _exp = -1; };
    if (_exp < 0 || { serverTime > _exp }) then { continue; };
    _hasApproval = true;
    break;
} forEach _appr;

if (!_hasApproval) exitWith
{
    diag_log format ["[ARC][SEC] ARC_fnc_iedServerRequestDisposition: denied no valid approval taskId=%1 group=%2 req=%3", _taskId, _gid, _req];
    false
};

private _objKind = ["activeObjectiveKind", ""] call ARC_fnc_stateGet;
if (!(_objKind isEqualType "")) then { _objKind = ""; };
_objKind = toUpper ([_objKind] call _trimFn);

if (_req isEqualTo "RTB_IED") exitWith
{
    if (!(_objKind isEqualTo "IED_DEVICE")) exitWith
    {
        diag_log format ["[ARC][WARN] ARC_fnc_iedServerRequestDisposition: RTB_IED denied unsupported objectiveKind=%1 taskId=%2", _objKind, _taskId];
        false
    };

    ["activeIedEvidenceRtbRequested", true] call ARC_fnc_stateSet;
    ["activeIedEvidenceRtbRequestedAt", serverTime] call ARC_fnc_stateSet;
    missionNamespace setVariable ["ARC_activeIedEvidenceRtbRequested", true, true];
    missionNamespace setVariable ["ARC_activeIedEvidenceRtbRequestedAt", serverTime, true];

    [] call ARC_fnc_iedServerCheckDisposal;
    diag_log format ["[ARC][INFO] ARC_fnc_iedServerRequestDisposition: RTB_IED lifecycle requested taskId=%1 group=%2", _taskId, _gid];
    true
};

if (_req isEqualTo "TOW_VBIED") exitWith
{
    if (!(_objKind isEqualTo "VBIED_VEHICLE")) exitWith
    {
        diag_log format ["[ARC][WARN] ARC_fnc_iedServerRequestDisposition: TOW_VBIED denied unsupported objectiveKind=%1 taskId=%2", _objKind, _taskId];
        false
    };

    ["activeVbiedTowRequested", true] call ARC_fnc_stateSet;
    ["activeVbiedTowRequestedAt", serverTime] call ARC_fnc_stateSet;
    missionNamespace setVariable ["ARC_activeVbiedTowRequested", true, true];
    missionNamespace setVariable ["ARC_activeVbiedTowRequestedAt", serverTime, true];

    diag_log format ["[ARC][INFO] ARC_fnc_iedServerRequestDisposition: TOW_VBIED lifecycle requested taskId=%1 group=%2", _taskId, _gid];
    true
};

false

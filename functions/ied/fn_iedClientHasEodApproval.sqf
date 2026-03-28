/*
    ARC_fnc_iedClientHasEodApproval

    Client: check whether the player's group has an active TOC approval
    for a given disposition request on the current active incident.

    Params:
      0: STRING requestType (DET_IN_PLACE|RTB_IED|TOW_VBIED)

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

params [
    ["_req", "DET_IN_PLACE", [""]]
];

private _trimFn = compile "params ['_s']; trim _s";

_req = toUpper ([_req] call _trimFn);
if !(_req in ["DET_IN_PLACE","RTB_IED","TOW_VBIED"]) then { _req = "DET_IN_PLACE"; };

private _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""]; if (!(_taskId isEqualType "")) then { _taskId = ""; };
_taskId = [_taskId] call _trimFn;
if (_taskId isEqualTo "") exitWith {false};

private _gid = groupId (group player);
if (!(_gid isEqualType "") || { _gid isEqualTo "" }) exitWith {false};

private _appr = missionNamespace getVariable ["ARC_pub_eodDispoApprovals", []];
if (!(_appr isEqualType [])) then { _appr = []; };

private _ok = false;
{
    if (!(_x isEqualType []) || { (count _x) < 3 }) then { continue; };
    if (!((_x select 0) isEqualTo _taskId)) then { continue; };
    if (!((_x select 1) isEqualTo _gid)) then { continue; };
    if (!((toUpper ([(_x select 2)] call _trimFn)) isEqualTo _req)) then { continue; };
    _ok = true;
    break;
} forEach _appr;

_ok

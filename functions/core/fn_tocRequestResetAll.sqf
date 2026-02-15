/*
    Server-side handler: reset persistence + tasking.

    Called via remoteExec from clients.
*/

if (!isServer) exitWith {false};

private _owner = remoteExecutedOwner;
private _requestor = objNull;

if (!isNil "remoteExecutedOwner" && { _owner > 0 }) then
{
    {
        if (owner _x == _owner) exitWith { _requestor = _x; };
    } forEach allPlayers;

    if (isNull _requestor) exitWith {false};

    // Reset is a privileged command: TOC approver (S3/Command) or OMNI only.
    private _isOmni = [_requestor, "OMNI"] call ARC_fnc_rolesHasGroupIdToken;
    private _can = _isOmni || { [_requestor] call ARC_fnc_rolesCanApproveQueue };
    if (!_can) exitWith {false};
};

diag_log format ["[ARC][RESET] tocRequestResetAll received. owner=%1 requester=%2", _owner, if (isNull _requestor) then {"<server>"} else {name _requestor}];

[] call ARC_fnc_resetAll;
true

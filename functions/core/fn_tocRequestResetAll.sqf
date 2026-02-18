/*
    Server-side handler: reset persistence + tasking.

    Called via remoteExec from clients.
*/

if (!isServer) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\core\fn_rpcValidateSender.sqf"; };

params [["_caller", objNull, [objNull]]];

private _owner = if (!isNil "remoteExecutedOwner") then { remoteExecutedOwner } else { -1 };
private _requestor = _caller;

if (!isNil "remoteExecutedOwner" && { _owner > 0 }) then
{
    if (isNull _requestor) then
    {
        {
            if (owner _x == _owner) exitWith { _requestor = _x; };
        } forEach allPlayers;
    };

    // RemoteExec-only validation path: requires remoteExecutedOwner context.
    if (!([_requestor, "ARC_fnc_tocRequestResetAll", "Reset rejected: sender verification failed.", "TOC_RESET_ALL_SECURITY_DENIED", true] call ARC_fnc_rpcValidateSender)) exitWith {false};

    // Reset is a privileged command: TOC approver (S3/Command) or OMNI only.
    private _isOmni = [_requestor, "OMNI"] call ARC_fnc_rolesHasGroupIdToken;
    private _can = _isOmni || { [_requestor] call ARC_fnc_rolesCanApproveQueue };
    if (!_can) exitWith {false};
};

diag_log format ["[ARC][RESET] tocRequestResetAll received. owner=%1 requester=%2", _owner, if (isNull _requestor) then {"<server>"} else {name _requestor}];

[] call ARC_fnc_resetAll;
true

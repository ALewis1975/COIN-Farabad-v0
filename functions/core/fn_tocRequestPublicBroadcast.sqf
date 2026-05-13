/*
    Server-side handler: authorize and trigger an immediate public state broadcast.

    Params:
      0: OBJECT requester (optional)
*/

if (!isServer) exitWith { false };

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\core\fn_rpcValidateSender.sqf"; };

params [
    ["_requester", objNull, [objNull]]
];

private _owner = if (!isNil "remoteExecutedOwner") then { remoteExecutedOwner } else { -1 };
private _requestor = _requester;

if (!isNil "remoteExecutedOwner" && { _owner > 0 }) then
{
    if (isNull _requestor) then
    {
        {
            if (owner _x == _owner) exitWith { _requestor = _x; };
        } forEach allPlayers;
    };

    if (!([_requestor, "ARC_fnc_tocRequestPublicBroadcast", "Public broadcast rejected: sender verification failed.", "PUBLIC_BROADCAST_SECURITY_DENIED", true] call ARC_fnc_rpcValidateSender)) exitWith { false };

    private _isOmni = [_requestor, "OMNI"] call ARC_fnc_rolesHasGroupIdToken;
    private _can = _isOmni || { [_requestor] call ARC_fnc_rolesCanApproveQueue };
    if (!_can) exitWith
    {
        private _who = if (isNull _requestor) then { "<unknown>" } else { name _requestor };
        diag_log format ["[ARC][SEC] ARC_fnc_tocRequestPublicBroadcast: denied owner=%1 caller=%2", _owner, _who];
        false
    };
};

diag_log format ["[ARC][INFO] ARC_fnc_tocRequestPublicBroadcast: accepted owner=%1 caller=%2", _owner, if (isNull _requestor) then { "<server>" } else { name _requestor }];

[] call ARC_fnc_publicBroadcastState;
true

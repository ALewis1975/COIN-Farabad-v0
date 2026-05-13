/*
    Server-side handler: authorize and trigger an immediate public state broadcast.

    Params:
      0: OBJECT requester (optional)
*/

if (!isServer) exitWith { false };

params [
    ["_requester", objNull, [objNull]]
];

private _owner = if (!isNil "remoteExecutedOwner") then { remoteExecutedOwner } else { -1 };
private _requesterObj = _requester;

if (_owner > 0) then
{
    if (isNull _requesterObj) then
    {
        {
            if (owner _x == _owner) exitWith { _requesterObj = _x; };
        } forEach allPlayers;
    };

    private _senderValid = [
        _requesterObj,
        "ARC_fnc_tocRequestPublicBroadcast",
        "Public broadcast rejected: sender verification failed.",
        "PUBLIC_BROADCAST_SECURITY_DENIED",
        true
    ] call ARC_fnc_rpcValidateSender;
    if (!_senderValid) exitWith { false };

    private _isOmni = [_requesterObj, "OMNI"] call ARC_fnc_rolesHasGroupIdToken;
    private _can = _isOmni || { [_requesterObj] call ARC_fnc_rolesCanApproveQueue };
    if (!_can) exitWith
    {
        diag_log format ["[ARC][SEC] ARC_fnc_tocRequestPublicBroadcast: denied owner=%1 caller=%2", _owner, if (isNull _requesterObj) then { "<unknown>" } else { name _requesterObj }];
        false
    };
};

diag_log format ["[ARC][INFO] ARC_fnc_tocRequestPublicBroadcast: accepted owner=%1 caller=%2", _owner, if (isNull _requesterObj) then { "<server>" } else { name _requesterObj }];

[] call ARC_fnc_publicBroadcastState;
true

/*
    Server-side handler: authorize and trigger an immediate public state broadcast.

    Params:
      0: OBJECT requester (optional)
*/

if (!isServer) exitWith { false };

params [
    ["_requester", objNull, [objNull]]
];

private _owner = if (!isNil "remoteExecutedOwner") then { remoteExecutedOwner } else { 0 };
private _requesterObj = _requester;

if (_owner > 0) then
{
    if (isNull _requesterObj) then
    {
        {
            if (owner _x == _owner) exitWith { _requesterObj = _x; };
        } forEach allPlayers;
    };

    if (isNull _requesterObj) exitWith
    {
        diag_log format ["[ARC][SEC] ARC_fnc_tocRequestPublicBroadcast: denied owner=%1 caller=<unresolved>", _owner];
        false
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

    private _cooldownS = missionNamespace getVariable ["ARC_tocPublicBroadcastCooldownSec", 5];
    if (!(_cooldownS isEqualType 0)) then { _cooldownS = 5; };
    _cooldownS = (_cooldownS max 1) min 60;

    private _lastByOwner = missionNamespace getVariable ["ARC_tocPublicBroadcastLastByOwner", []];
    if (!(_lastByOwner isEqualType [])) then { _lastByOwner = []; };

    private _now = diag_tickTime;
    private _idx = -1;
    {
        if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo _owner }) exitWith
        {
            _idx = _forEachIndex;
        };
    } forEach _lastByOwner;

    private _lastAt = -1;
    if (_idx >= 0) then
    {
        private _entry = _lastByOwner select _idx;
        private _rawLastAt = _entry select 1;
        if (_rawLastAt isEqualType 0) then { _lastAt = _rawLastAt; };
    };

    if (_lastAt >= 0 && { (_now - _lastAt) < _cooldownS }) exitWith
    {
        diag_log format ["[ARC][WARN] ARC_fnc_tocRequestPublicBroadcast: throttled owner=%1 caller=%2 remaining=%3", _owner, name _requesterObj, _cooldownS - (_now - _lastAt)];
        false
    };

    if (_idx >= 0) then
    {
        _lastByOwner set [_idx, [_owner, _now]];
    }
    else
    {
        _lastByOwner pushBack [_owner, _now];
    };
    missionNamespace setVariable ["ARC_tocPublicBroadcastLastByOwner", _lastByOwner, false];
};

diag_log format ["[ARC][INFO] ARC_fnc_tocRequestPublicBroadcast: accepted owner=%1 caller=%2", _owner, if (isNull _requesterObj) then { "<server>" } else { name _requesterObj }];

[] call ARC_fnc_publicBroadcastState;
true

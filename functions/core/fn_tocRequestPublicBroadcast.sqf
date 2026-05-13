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
    private _lastByOwnerClean = [];
    {
        if (_x isEqualType []) then
        {
            private _entry = _x;
            if ((count _entry) >= 2) then
            {
                private _entryOwner = _entry select 0;
                private _entryLastAt = _entry select 1;
                if ((_entryOwner isEqualType 0) && { _entryLastAt isEqualType 0 } && { (_now - _entryLastAt) < _cooldownS }) then
                {
                    _lastByOwnerClean pushBack [_entryOwner, _entryLastAt];
                };
            };
        };
    } forEach _lastByOwner;
    _lastByOwner = _lastByOwnerClean;

    private _idx = -1;
    {
        private _entry = _x;
        if ((count _entry) >= 2) then
        {
            private _entryOwner = _entry select 0;
            if (_idx < 0 && { _entryOwner isEqualTo _owner }) then
            {
                _idx = _forEachIndex;
            };
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
        private _remaining = (_cooldownS - (_now - _lastAt)) max 0;
        private _requesterName = if (isNull _requesterObj) then { "<unknown>" } else { name _requesterObj };
        diag_log format ["[ARC][WARN] ARC_fnc_tocRequestPublicBroadcast: throttled owner=%1 caller=%2 remaining=%3", _owner, _requesterName, _remaining];
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

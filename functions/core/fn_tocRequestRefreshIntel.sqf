/*
    Server-side handler: force a fresh broadcast of public intel/state snapshots.

    Called via remoteExec from clients.
*/

if (!isServer) exitWith {false};

// Dedicated MP hardening:
// If remotely requested, bind request to sender-owner and require the same
// role family the Intel UI exposes for admin refresh tools (S2/CMD/OMNI).
if (!isNil "remoteExecutedOwner") then
{
    private _reo = remoteExecutedOwner;
    if (_reo > 0) then
    {
        private _requestor = objNull;
        {
            if (owner _x == _reo) exitWith { _requestor = _x; };
        } forEach allPlayers;

        if (isNull _requestor) exitWith {false};

        private _isOmni = [_requestor, "OMNI"] call ARC_fnc_rolesHasGroupIdToken;
        private _canRefresh = _isOmni || { [_requestor] call ARC_fnc_rolesIsTocS2 } || { [_requestor] call ARC_fnc_rolesIsTocCommand };
        if (!_canRefresh) exitWith {false};
    };
};

// Keep broadcast order explicit and stable:
//  1) campaign/public headline state
//  2) intel + ops feed slices
//  3) lead pool snapshot
//  4) thread/case summary snapshot
{
    [] call _x;
} forEach [
    ARC_fnc_publicBroadcastState,
    ARC_fnc_intelBroadcast,
    ARC_fnc_leadBroadcast,
    ARC_fnc_threadBroadcast
];

true

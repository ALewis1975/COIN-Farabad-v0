/*
    Server-side handler: force a fresh broadcast of public intel/state snapshots.

    Called via remoteExec from clients.
*/

if (!isServer) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\core\fn_rpcValidateSender.sqf"; };

params [
    ["_caller", objNull, [objNull]]
];

// Dedicated MP hardening:
// If remotely requested, bind request to sender-owner and require the same
// role family the Intel UI exposes for admin refresh tools (S2/CMD/OMNI).
private _isRemoteRpc = !isNil "remoteExecutedOwner";
if (_isRemoteRpc) then
{
    private _reo = remoteExecutedOwner;
    if (_reo > 0) then
    {
        if (isNull _caller) then
        {
            {
                if (owner _x == _reo) exitWith { _caller = _x; };
            } forEach allPlayers;
        };

        if (!([_caller, "ARC_fnc_tocRequestRefreshIntel", "Intel refresh rejected: sender verification failed.", "TOC_REFRESH_INTEL_SECURITY_DENIED"] call ARC_fnc_rpcValidateSender)) exitWith {false};

        private _isOmni = [_caller, "OMNI"] call ARC_fnc_rolesHasGroupIdToken;
        private _canRefresh = _isOmni || { [_caller] call ARC_fnc_rolesIsTocS2 } || { [_caller] call ARC_fnc_rolesIsTocCommand };
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

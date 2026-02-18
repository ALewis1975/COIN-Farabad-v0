/*
    Server: rebuild/rehydrate active incident task.

    Params:
      0: OBJECT caller (optional)
*/

if (!isServer) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\core\fn_rpcValidateSender.sqf"; };

params [
    ["_caller", objNull, [objNull]]
];

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
    if (!([_requestor, "ARC_fnc_tocRequestRebuildActive", "Rebuild active incident rejected: sender verification failed.", "TOC_REBUILD_ACTIVE_SECURITY_DENIED", true] call ARC_fnc_rpcValidateSender)) exitWith {false};

    private _isOmni = [_requestor, "OMNI"] call ARC_fnc_rolesHasGroupIdToken;
    private _can = _isOmni || { [_requestor] call ARC_fnc_rolesCanApproveQueue };
    if (!_can) exitWith
    {
        private _who = if (isNull _requestor) then {"<unknown>"} else {name _requestor};
        diag_log format ["[ARC][TOC] RebuildActive rejected (unauthorized). owner=%1 caller=%2", _owner, _who];

        ["OPS", format ["SECURITY: ARC_fnc_tocRequestRebuildActive rejected (insufficient privileges). owner=%1 caller=%2", _owner, _who], [0,0,0],
            [
                ["event", "TOC_REBUILD_ACTIVE_SECURITY_DENIED"],
                ["rpc", "ARC_fnc_tocRequestRebuildActive"],
                ["reason", "NOT_AUTHORIZED"],
                ["remoteOwner", _owner],
                ["callerUID", if (isNull _requestor) then {""} else {getPlayerUID _requestor}],
                ["callerName", _who]
            ]
        ] call ARC_fnc_intelLog;

        ["Rebuild active incident rejected: insufficient privileges."] remoteExec ["ARC_fnc_clientHint", _owner];
        false
    };
};

diag_log format ["[ARC][TOC] tocRequestRebuildActive received. owner=%1 requester=%2", _owner, if (isNull _requestor) then {"<server>"} else {name _requestor}];

[] call ARC_fnc_taskRehydrateActive;
true

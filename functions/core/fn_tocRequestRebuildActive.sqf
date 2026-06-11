/*
    Server: rebuild/rehydrate active incident task.

    Params:
      0: OBJECT caller (optional)
      1: SCALAR callerOwner (optional test seam; live remoteExecutedOwner wins)
*/

if (!isServer) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\core\fn_rpcValidateSender.sqf"; };

params [
    ["_caller", objNull, [objNull]],
    ["_callerOwner", -1, [0]]
];

// Tests may pass _callerOwner explicitly; live RemoteExec context always wins.
private _owner = if (!isNil "remoteExecutedOwner") then { remoteExecutedOwner } else { _callerOwner };
private _requestor = _caller;

private _testMode = missionNamespace getVariable ["ARC_TEST_mode", false];
if (!(_testMode isEqualType true)) then { _testMode = false; };

if (_owner > 0) then
{
    if (isNull _requestor) then
    {
        {
            if (owner _x == _owner) exitWith { _requestor = _x; };
        } forEach allPlayers;
    };

    // RemoteExec validation path: callers may pass the captured owner explicitly for testability.
    if (!([_requestor, "ARC_fnc_tocRequestRebuildActive", "Rebuild active incident rejected: sender verification failed.", "TOC_REBUILD_ACTIVE_SECURITY_DENIED", true, _owner] call ARC_fnc_rpcValidateSender)) exitWith {false};

    private _authOverride = if (_testMode) then {
        missionNamespace getVariable ["ARC_TEST_tocCanApproveQueueOverride", "ARC_TEST_NO_OVERRIDE"]
    } else {
        "ARC_TEST_NO_OVERRIDE"
    };

    private _can = false;
    if (_authOverride isEqualType true) then
    {
        _can = _authOverride;
    }
    else
    {
        private _isOmni = [_requestor, "OMNI"] call ARC_fnc_rolesHasGroupIdToken;
        _can = _isOmni || { [_requestor] call ARC_fnc_rolesCanApproveQueue };
    };

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

private _dryRun = if (_testMode) then { missionNamespace getVariable ["ARC_TEST_tocDryRun", false] } else { false };
if (!(_dryRun isEqualType true)) then { _dryRun = false; };
if (_dryRun) exitWith
{
    private _calls = missionNamespace getVariable ["ARC_TEST_tocRebuildCalls", 0];
    if (!(_calls isEqualType 0)) then { _calls = 0; };
    missionNamespace setVariable ["ARC_TEST_tocRebuildCalls", _calls + 1];
    true
};

diag_log format ["[ARC][TOC] tocRequestRebuildActive received. owner=%1 requester=%2", _owner, if (isNull _requestor) then {"<server>"} else {name _requestor}];

[] call ARC_fnc_taskRehydrateActive;
true

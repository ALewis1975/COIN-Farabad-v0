/*
    Runs on server.
    Forces a save. Useful for admin / TOC operators.

    Phase 6:
      - Also forces CIVSUB persistence save (if enabled), so "Save World" includes CIVSUB.
*/

if (!isServer) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\core\fn_rpcValidateSender.sqf"; };

params [
    ["_caller", objNull, [objNull]],
    ["_callerOwner", -1, [0]]
];

// Dedicated MP hardening:
// Resolve requestor from network sender and require TOC approver authority.
// Tests may pass _callerOwner explicitly; live RemoteExec context always wins.
private _owner = remoteExecutedOwner;
private _requestor = _caller;

private _testMode = missionNamespace getVariable ["ARC_TEST_mode", false];
if (!(_testMode isEqualType true)) then { _testMode = false; };
_testMode = _testMode && { !isRemoteExecuted };
if (_testMode && { _callerOwner > 0 }) then { _owner = _callerOwner; };

private _rpcAuthorized = if (isRemoteExecuted || { _owner > 0 } || { !isNull _requestor }) then
{
    if (isNull _requestor) then
    {
        {
            if (owner _x == _owner) exitWith { _requestor = _x; };
        } forEach allPlayers;
    };

    // RemoteExec validation path: callers may pass the captured owner explicitly for testability.
    if (!([_requestor, "ARC_fnc_tocRequestSave", "Save rejected: sender verification failed.", "TOC_SAVE_SECURITY_DENIED", true, _owner] call ARC_fnc_rpcValidateSender)) exitWith {false};

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

    if (!_can) exitWith {false};

    true
} else { true };
if (!_rpcAuthorized) exitWith
{
    diag_log format ["[ARC][SEC] ARC_fnc_tocRequestSave: AUTHORIZATION_DENIED owner=%1 ts=%2", remoteExecutedOwner, serverTime];
    ["ARC_fnc_tocRequestSave", "AUTHORIZATION_DENIED", remoteExecutedOwner] call ARC_fnc_securityDenyRecord;
    false
};

private _dryRun = if (_testMode) then { missionNamespace getVariable ["ARC_TEST_tocDryRun", false] } else { false };
if (!(_dryRun isEqualType true)) then { _dryRun = false; };
if (_dryRun) exitWith
{
    private _calls = missionNamespace getVariable ["ARC_TEST_tocSaveCalls", 0];
    if (!(_calls isEqualType 0)) then { _calls = 0; };
    missionNamespace setVariable ["ARC_TEST_tocSaveCalls", _calls + 1];
    true
};

if (missionNamespace getVariable ["civsub_v1_enabled", false]) then
{
    // Best-effort: do not hard error if CIVSUB not initialized yet
    if (!isNil "ARC_fnc_civsubPersistSave") then { [] call ARC_fnc_civsubPersistSave; };
};

[] call ARC_fnc_stateSave

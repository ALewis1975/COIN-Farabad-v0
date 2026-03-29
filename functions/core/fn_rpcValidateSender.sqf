/*
    ARC_fnc_rpcValidateSender

    Common server-side RemoteExec guard for RPC handlers that accept a caller object.

    Params:
      0: OBJECT caller object supplied by client.
      1: STRING rpc name (for logging context).
      2: STRING notify message (optional; sent only to requesting owner when available).
      3: STRING security event code (optional).
      4: BOOL requireRemoteContext (optional; when true, reject non-RemoteExec invocation).

    Returns:
      BOOL true when sender/object binding is valid; false when rejected.
*/

if (!isServer) exitWith {false};

params [
    ["_caller", objNull],
    ["_rpc", "RPC"],
    ["_notify", ""],
    ["_event", "RPC_SENDER_REJECTED"],
    ["_requireRemoteContext", false]
];

private _isRemoteRpc = !isNil "remoteExecutedOwner";
if (!_isRemoteRpc) exitWith
{
    // Hosted-server self-call detection:
    // When the host player calls remoteExec ["fnc", 2] on a non-dedicated server,
    // the engine optimizes this to a local call without setting remoteExecutedOwner.
    // Validate that the caller object is local and non-null — this is a legitimate path.
    if (!isDedicated && {!isNull _caller} && {local _caller}) exitWith
    {
        diag_log format ["[ARC][INFO] %1: hosted-server self-call detected for %2 — allowing.", _rpc, name _caller];
        true
    };

    ["OPS", format ["SECURITY: %1 invoked without RemoteExec context (remoteExecutedOwner missing).", _rpc], [0,0,0],
        [
            ["event", _event],
            ["rpc", _rpc],
            ["reason", "MISSING_REMOTE_CONTEXT"],
            ["strictMode", _requireRemoteContext]
        ]
    ] call ARC_fnc_intelLog;

    if (_requireRemoteContext) exitWith {false};
    true
};

private _actualOwner = remoteExecutedOwner;

if (isNull _caller) exitWith
{
    ["OPS", format ["SECURITY: %1 rejected (null caller object). remoteOwner=%2", _rpc, _actualOwner], [0,0,0],
        [
            ["event", _event],
            ["rpc", _rpc],
            ["reason", "NULL_OBJECT"],
            ["remoteOwner", _actualOwner]
        ]
    ] call ARC_fnc_intelLog;

    if (_notify isEqualType "" && { !(_notify isEqualTo "") } && { _actualOwner > 0 }) then
    {
        [_notify] remoteExec ["ARC_fnc_clientHint", _actualOwner];
    };

    false
};

private _expectedOwner = owner _caller;
if (_expectedOwner != _actualOwner) exitWith
{
        ["OPS", format ["SECURITY: %1 rejected (sender owner mismatch). expected=%2 actual=%3 caller=%4", _rpc, _expectedOwner, _actualOwner, name _caller], [0,0,0],
            [
                ["event", _event],
                ["rpc", _rpc],
                ["reason", "OWNER_MISMATCH"],
                ["expectedOwner", _expectedOwner],
                ["remoteOwner", _actualOwner],
                ["callerUID", getPlayerUID _caller],
                ["callerName", name _caller]
            ]
        ] call ARC_fnc_intelLog;

        if (_notify isEqualType "" && { !(_notify isEqualTo "") } && { _actualOwner > 0 }) then
        {
            [_notify] remoteExec ["ARC_fnc_clientHint", _actualOwner];
        };

        false
};

true

/*
    ARC_fnc_rpcValidateSender

    Common server-side RemoteExec guard for RPC handlers that accept a caller object.

    Params:
      0: OBJECT caller object supplied by client.
      1: STRING rpc name (for logging context).
      2: STRING notify message (optional; sent only to requesting owner when available).
      3: STRING security event code (optional).
      4: BOOL requireRemoteContext (optional; when true, reject non-RemoteExec invocation).
      5: SCALAR callerOwner (optional; explicit remoteExecutedOwner captured at the
         outer remoteExec frame by the calling handler). Required on dedicated servers
         because `remoteExecutedOwner` is only defined in the directly remoteExec'd
         function's scope and does NOT propagate into nested `call` frames — leaving
         the validator unable to read it itself. Pass -1 (or omit) to let the validator
         fall back to its own scope read for legacy/hosted self-call paths.

    Returns:
      BOOL true when sender/object binding is valid; false when rejected.
*/

if (!isServer) exitWith {false};

params [
    ["_caller", objNull],
    ["_rpc", "RPC"],
    ["_notify", ""],
    ["_event", "RPC_SENDER_REJECTED"],
    ["_requireRemoteContext", false],
    ["_callerOwner", -1, [0]]
];

// Resolve the effective remote-execution owner.
//
// Preferred path: the calling handler captured `remoteExecutedOwner` at its own top
// frame and passed it explicitly as `_callerOwner`. This is the only reliable path on
// dedicated servers — see header comment.
//
// Fallback path: legacy callers that have not yet been updated may pass -1; in that
// case we try to read `remoteExecutedOwner` from this scope, which works for hosted
// (non-dedicated) self-calls and for the older single-frame remoteExec flow.
private _hasExplicitOwner = (_callerOwner isEqualType 0) && { _callerOwner > 0 };
private _scopeOwner = if (!isNil "remoteExecutedOwner") then { remoteExecutedOwner } else { -1 };
private _isRemoteRpc = _hasExplicitOwner || { (_scopeOwner isEqualType 0) && { _scopeOwner > 0 } };

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

private _actualOwner = if (_hasExplicitOwner) then { _callerOwner } else { _scopeOwner };

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

    if (_notify isEqualType "" && { _notify isNotEqualTo "" } && { _actualOwner > 0 }) then
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

        if (_notify isEqualType "" && { _notify isNotEqualTo "" } && { _actualOwner > 0 }) then
        {
            [_notify] remoteExec ["ARC_fnc_clientHint", _actualOwner];
        };

        false
};

true

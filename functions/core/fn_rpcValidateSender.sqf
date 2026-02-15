/*
    ARC_fnc_rpcValidateSender

    Common server-side RemoteExec guard for RPC handlers that accept a caller object.

    Params:
      0: OBJECT caller object supplied by client.
      1: STRING rpc name (for logging context).
      2: STRING notify message (optional; sent only to requesting owner when available).
      3: STRING security event code (optional).

    Returns:
      BOOL true when sender/object binding is valid; false when rejected.
*/

if (!isServer) exitWith {false};

params [
    ["_caller", objNull],
    ["_rpc", "RPC"],
    ["_notify", ""],
    ["_event", "RPC_SENDER_REJECTED"]
];

private _isRemoteRpc = !isNil "remoteExecutedOwner";
if (!_isRemoteRpc) exitWith {true};

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

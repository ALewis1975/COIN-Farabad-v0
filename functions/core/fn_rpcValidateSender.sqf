/*
    ARC_fnc_rpcValidateSender

    Server-only sender/object binding; six-argument API unchanged.
    Read engine commands directly. Live engine identity always takes precedence
    over an owner captured by a trusted server wrapper (or local test harness).
    This helper is not remotely allowlisted and accepts no client test overrides.
*/
if (!isServer) exitWith {false};

params [
    ["_caller", objNull, [objNull]],
    ["_rpc", "RPC", [""]],
    ["_notify", "", [""]],
    ["_event", "RPC_SENDER_REJECTED", [""]],
    ["_requireRemoteContext", false, [true]],
    ["_callerOwner", -1, [0]]
];

private _engineRemote = isRemoteExecuted;
private _engineOwner = remoteExecutedOwner;
private _actualOwner = if (_engineRemote || { _engineOwner > 0 }) then { _engineOwner } else { _callerOwner };
private _isRemoteRpc = _engineRemote || { _engineOwner > 0 } || { _callerOwner > 0 };
private _reason = "";

if (_isRemoteRpc) then
{
    if (_actualOwner <= 0) then { _reason = "INVALID_REMOTE_OWNER"; };
    if (isNull _caller) then { _reason = "NULL_OBJECT"; }
    else
    {
        if (!isPlayer _caller || { !(_caller in allPlayers) }) then { _reason = "NOT_PLAYER"; };
        if ((owner _caller) != _actualOwner) then { _reason = "OWNER_MISMATCH"; };
    };
}
else
{
    // Explicit server-local call, never a missing-owner remote fallback.
    // Hosted UI self-calls retain their player identity. System calls use
    // requireRemoteContext=false or their endpoint's explicit internal path.
    if (_requireRemoteContext && { isNull _caller || { !isPlayer _caller } || { !(_caller in allPlayers) } }) then
    {
        _reason = "MISSING_REMOTE_CONTEXT";
    };
};

if (!(_reason isEqualTo "")) exitWith
{
    private _pos = if (isNull _caller) then { [0,0,0] } else { getPosATL _caller };
    diag_log format ["[ARC][SEC] %1 denied: reason=%2 owner=%3 callerOwner=%4 ts=%5 grid=%6", _rpc, _reason, _actualOwner, if (isNull _caller) then {-1} else {owner _caller}, serverTime, mapGridPosition _pos];
    ["OPS", format ["SECURITY: %1 rejected (%2).", _rpc, _reason], _pos,
        [["event", _event], ["rpc", _rpc], ["reason", _reason], ["remoteOwner", _actualOwner], ["callerUID", if (isNull _caller) then {""} else {getPlayerUID _caller}]]
    ] call ARC_fnc_intelLog;
    if (!isNil "ARC_fnc_securityDenyRecord") then { [_rpc, _reason, _actualOwner] call ARC_fnc_securityDenyRecord; };
    if (!(_notify isEqualTo "") && { _actualOwner > 0 }) then { [_notify] remoteExec ["ARC_fnc_clientHint", _actualOwner]; };
    false
};

true

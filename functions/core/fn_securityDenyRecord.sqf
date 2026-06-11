/*
    ARC_fnc_securityDenyRecord

    Server: record a SECURITY_DENIED event into the bounded, replicated
    diagnostics ring buffer `ARC_pub_securityDenials` (last 10 entries).

    Consumed by the Farabad Console HQ/ADMIN "Server Health (Live)" diagnostics
    pane so operators can see recent RPC security denials without RPT access
    (Dedicated Server Activation Plan — Track 3).

    Entry shape: [serverTime, rpcName, reason, remoteOwner]

    Params:
      0: STRING rpc name (e.g. "ARC_fnc_tocRequestNextIncident").
      1: STRING deny reason code (e.g. "MISSING_REMOTE_CONTEXT", "OWNER_MISMATCH").
      2: SCALAR remote owner id of the denied sender (-1 when unknown).

    Returns:
      BOOL true when the event was recorded.
*/

if (!isServer) exitWith { false };

params [
    ["_rpc", "", [""]],
    ["_reason", "", [""]],
    ["_remoteOwner", -1, [0]]
];

if (_rpc isEqualTo "") exitWith { false };
if (_reason isEqualTo "") exitWith { false };

private _log = missionNamespace getVariable ["ARC_pub_securityDenials", []];
if (!(_log isEqualType [])) then { _log = []; };

_log pushBack [serverTime, _rpc, toUpper _reason, _remoteOwner];

private _max = 10;
while { (count _log) > _max } do { _log deleteAt 0; };

missionNamespace setVariable ["ARC_pub_securityDenials", _log, true];

true

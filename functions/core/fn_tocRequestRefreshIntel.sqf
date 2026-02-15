/*
    Server-side handler: force a fresh broadcast of public intel/state snapshots.

    Called via remoteExec from clients.
*/

if (!isServer) exitWith {false};

[] call ARC_fnc_publicBroadcastState;
[] call ARC_fnc_intelBroadcast;
[] call ARC_fnc_leadBroadcast;
[] call ARC_fnc_threadBroadcast;
true

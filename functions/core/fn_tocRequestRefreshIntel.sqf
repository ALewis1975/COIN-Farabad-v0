/*
    Server-side handler: force a fresh broadcast of public intel/state snapshots.

    Called via remoteExec from clients.
*/

if (!isServer) exitWith {false};

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

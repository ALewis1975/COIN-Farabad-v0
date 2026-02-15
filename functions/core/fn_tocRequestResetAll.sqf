/*
    Server-side handler: reset persistence + tasking.

    Called via remoteExec from clients.
*/

if (!isServer) exitWith {false};

private _owner = remoteExecutedOwner;
diag_log format ["[ARC][RESET] tocRequestResetAll received. owner=%1", _owner];

[] call ARC_fnc_resetAll;
true

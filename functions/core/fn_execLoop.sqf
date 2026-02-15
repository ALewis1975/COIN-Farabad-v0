/*
    Server: incident execution / end-state loop.

    Runs more frequently than ARC_fnc_incidentTick so timed/hold tasks feel responsive.

    Returns:
        BOOL
*/

if (!isServer) exitWith {false};

if (!isNil { missionNamespace getVariable "ARC_execLoopRunning" }) exitWith {true};
missionNamespace setVariable ["ARC_execLoopRunning", true];

[] spawn {
    while {true} do
    {
        [] call ARC_fnc_execTickActive;

        // Deferred despawn (convoys, objectives, etc.)
        private _now = serverTime;
        private _last = missionNamespace getVariable ["ARC_cleanup_lastTick", 0];
        if (!(_last isEqualType 0)) then { _last = 0; };
        if ((_now - _last) >= 15) then
        {
            [] call ARC_fnc_cleanupTick;
            missionNamespace setVariable ["ARC_cleanup_lastTick", _now];
        };

        sleep 5;
    };
};

true

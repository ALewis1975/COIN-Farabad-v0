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

        // Adaptive cadence: run faster while an incident is active, relax when idle.
        // Configurable via missionNamespace: ARC_execLoopActiveSleepSec (default 5),
        // ARC_execLoopIdleSleepSec (default 15).
        private _activeId = ["activeTaskId", ""] call ARC_fnc_stateGet;
        if (!(_activeId isEqualType "")) then { _activeId = ""; };
        private _sleepSec = if (!(_activeId isEqualTo "")) then
        {
            private _s = missionNamespace getVariable ["ARC_execLoopActiveSleepSec", 5];
            if (!(_s isEqualType 0)) then { _s = 5; };
            (_s max 2) min 30
        }
        else
        {
            private _s = missionNamespace getVariable ["ARC_execLoopIdleSleepSec", 15];
            if (!(_s isEqualType 0)) then { _s = 15; };
            (_s max 5) min 60
        };
        sleep _sleepSec;
    };
};

true

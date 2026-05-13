/*
    ARC_fnc_govStatsScheduler

    Server: start the low-frequency government stats aggregate loop.

    Spawns a persistent scheduler that calls ARC_fnc_govStatsCompute on the
    same cadence as the worldtime broadcast interval.  Uses ARC_govStatsLoopRunning
    as a server-local guard to prevent duplicate loops if this function is ever
    called more than once.

    Must be called after ARC_fnc_bootstrapServer so that ARC_serverReady can
    be awaited from inside the spawned thread.

    Authority: Server only.

    Returns:
        BOOL — true if the scheduler was started, false if already running or
               not server.
*/

if (!isServer) exitWith { false };

if (missionNamespace getVariable ["ARC_govStatsLoopRunning", false]) exitWith
{
    diag_log "[ARC][GOVSTATS] aggregate loop already running — no-op";
    false
};

missionNamespace setVariable ["ARC_govStatsLoopRunning", true];

[] spawn
{
    waitUntil { missionNamespace getVariable ["ARC_serverReady", false] };

    private _interval = missionNamespace getVariable ["ARC_worldTime_broadcastIntervalSec", 30];
    if (!(_interval isEqualType 0) || { _interval < 10 }) then { _interval = 30; };

    diag_log format ["[ARC][GOVSTATS] aggregate loop start (interval=%1s)", _interval];

    while { missionNamespace getVariable ["ARC_govStatsLoopRunning", true] } do
    {
        [] call ARC_fnc_govStatsCompute;
        sleep _interval;
        _interval = missionNamespace getVariable ["ARC_worldTime_broadcastIntervalSec", _interval];
        if (!(_interval isEqualType 0) || { _interval < 10 }) then { _interval = 30; };
    };
};

true

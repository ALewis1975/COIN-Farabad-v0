/*
    ARC_fnc_civsubSchedulerInit

    Starts the CIVSUB Phase 5 scheduler loop.
    Guarded by civsub_v1_enabled and civsub_v1_scheduler_enabled.

    Returns: true if started or already running, else false.
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_scheduler_enabled", false]) exitWith {false};

if (missionNamespace getVariable ["civsub_v1_schedulerThreadRunning", false]) exitWith {true};
missionNamespace setVariable ["civsub_v1_schedulerThreadRunning", true, true];

private _schedS = missionNamespace getVariable ["civsub_v1_scheduler_s", 300];
if (!(_schedS isEqualType 0)) then { _schedS = 300; };
if (_schedS < 30) then { _schedS = 30; };

missionNamespace setVariable ["civsub_v1_scheduler_lastTick_ts", serverTime, true];

[] spawn {
    while { isServer && { missionNamespace getVariable ["civsub_v1_enabled", false] } && { missionNamespace getVariable ["civsub_v1_scheduler_enabled", false] } } do {
        uiSleep (missionNamespace getVariable ["civsub_v1_scheduler_s", 300]);
        [] call ARC_fnc_civsubSchedulerTick;
    };

    missionNamespace setVariable ["civsub_v1_schedulerThreadRunning", false, true];
};

true

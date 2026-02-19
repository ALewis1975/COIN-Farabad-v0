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

private _schedRaw = missionNamespace getVariable ["civsub_v1_scheduler_s", 300];
private _schedCheck = [_schedRaw, "SCALAR_BOUNDS", "civsub_v1_scheduler_s", [300, 30, 86400]] call ARC_fnc_paramAssert;
private _schedS = _schedCheck param [1, 300];
if !(_schedCheck param [0, false]) then {
    ["CIVSUB", format ["scheduler init guard: code=%1 msg=%2", _schedCheck param [2, "ARC_ASSERT_UNKNOWN"], _schedCheck param [3, "scheduler interval invalid"]], [["code", _schedCheck param [2, "ARC_ASSERT_UNKNOWN"]], ["guard", "civsubSchedulerInit"], ["key", "civsub_v1_scheduler_s"]]] call ARC_fnc_farabadWarn;
};

missionNamespace setVariable ["civsub_v1_scheduler_lastTick_ts", serverTime, true];

[_schedS] spawn {
    params [["_sleepS", 300, [0]]];

    while { isServer && { missionNamespace getVariable ["civsub_v1_enabled", false] } && { missionNamespace getVariable ["civsub_v1_scheduler_enabled", false] } } do {
        uiSleep _sleepS;
        [] call ARC_fnc_civsubSchedulerTick;
    };

    missionNamespace setVariable ["civsub_v1_schedulerThreadRunning", false, true];
};

true

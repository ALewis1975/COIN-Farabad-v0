/*
    ARC_fnc_civsubSchedulerStop

    Stops the CIVSUB scheduler loop on next cycle by disabling civsub_v1_scheduler_enabled.
    We do not terminate the spawned thread directly; it exits cleanly.

    Returns: true
*/

if (!isServer) exitWith {false};
missionNamespace setVariable ["civsub_v1_scheduler_enabled", false, true];
true

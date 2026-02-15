/*
    Server: rebuild/rehydrate active incident task.
*/

if (!isServer) exitWith {false};

[] call ARC_fnc_taskRehydrateActive;
true

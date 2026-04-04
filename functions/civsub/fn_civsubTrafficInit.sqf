/*
    ARC_fnc_civsubTrafficInit

    CIVTRAF (CIVSUB v1 adjunct): Ambient civilian traffic layer.
    Posture:
      - Server-authoritative.
      - Mostly parked vehicles, minimal moving vehicles (feature-gated).
      - Strict caps + cleanup discipline (uses ARC cleanup system).

    Enable via:
      civsub_v1_traffic_enabled = true
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_traffic_enabled", false]) exitWith {false};

if (missionNamespace getVariable ["civsub_v1_traffic_threadRunning", false]) exitWith {true};
missionNamespace setVariable ["civsub_v1_traffic_threadRunning", true, true];

// Default tunables (safe fallbacks)
if (isNil { missionNamespace getVariable "civsub_v1_traffic_spawnRadius_m" }) then {
    missionNamespace setVariable ["civsub_v1_traffic_spawnRadius_m", 600, true];
};
if (isNil { missionNamespace getVariable "civsub_v1_traffic_debug" }) then {
    missionNamespace setVariable ["civsub_v1_traffic_debug", false, true];
};

// Stores (ephemeral, not persisted)
if (isNil { missionNamespace getVariable "civsub_v1_traffic_list_parked" }) then {
    missionNamespace setVariable ["civsub_v1_traffic_list_parked", [], true];
};
if (isNil { missionNamespace getVariable "civsub_v1_traffic_list_moving" }) then {
    missionNamespace setVariable ["civsub_v1_traffic_list_moving", [], true];
};

// Build and cache a validated vehicle pool now (rebuild in tick if empty)
private _pool = [] call ARC_fnc_civsubTrafficBuildVehiclePool;
missionNamespace setVariable ["civsub_v1_traffic_vehiclePool_valid", _pool, true];

// ---------------------------------------------------------------------------
// Register static traffic exclusion zones (areas where civ vehicles must not spawn).
// Format: [[x,y,z], radiusM]   — position from getMarkerPos, radius in metres.
// Karkanak Prison: vehicles spawning inside the prison compound break immersion.
// Use the central guard tower marker as the compound centroid (250 m covers the
// full footprint including the dorms, hospital, and entry office).
// ---------------------------------------------------------------------------
private _trafficExclZones = [];
private _prisonAnchorMkr = "prison_central_guard_tower";
if (!((getMarkerType _prisonAnchorMkr) isEqualTo "")) then
{
    _trafficExclZones pushBack [getMarkerPos _prisonAnchorMkr, 250];
    diag_log format ["[CIVTRAF][INIT] exclusion zone registered: marker=%1 radius=250 m", _prisonAnchorMkr];
}
else
{
    diag_log "[CIVTRAF][INIT] WARN: prison_central_guard_tower not found — prison compound not excluded from civ traffic.";
};
missionNamespace setVariable ["ARC_trafficExclusionZones", _trafficExclZones];

private _tickS = missionNamespace getVariable ["civsub_v1_traffic_tick_s", 30];
if (!(_tickS isEqualType 0)) then { _tickS = 30; };
// Enforce 1s minimum cadence to align with initServer guidance (1-2s recommended).
if (_tickS < 1) then { _tickS = 1; };
missionNamespace setVariable ["civsub_v1_traffic_tick_s", _tickS, true];

// One-time init log for RPT validation
private _capG = missionNamespace getVariable ["civsub_v1_traffic_cap_global", 18];
private _capD = missionNamespace getVariable ["civsub_v1_traffic_cap_perDistrict", 10];
private _spawnR = missionNamespace getVariable ["civsub_v1_traffic_spawnRadius_m", 600];
diag_log format ["[CIVTRAF][INIT] enabled=YES tickS=%1 pool=%2 capG=%3 capD=%4 spawnR=%5 allowMoving=%6", _tickS, count _pool, _capG, _capD, _spawnR, (missionNamespace getVariable ["civsub_v1_traffic_allow_moving", false])];

[] spawn
{
    while { isServer && { missionNamespace getVariable ["civsub_v1_enabled", false] } && { missionNamespace getVariable ["civsub_v1_traffic_enabled", false] } } do
    {
        [] call ARC_fnc_civsubTrafficTick;

        private _tickSLoop = missionNamespace getVariable ["civsub_v1_traffic_tick_s", 30];
        if (!(_tickSLoop isEqualType 0)) then { _tickSLoop = 30; };
        if (_tickSLoop < 1) then { _tickSLoop = 1; };
        uiSleep _tickSLoop;
    };

    missionNamespace setVariable ["civsub_v1_traffic_threadRunning", false, true];
};

true

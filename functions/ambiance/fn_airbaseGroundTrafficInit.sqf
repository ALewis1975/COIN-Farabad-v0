/*
    ARC_fnc_airbaseGroundTrafficInit

    Initializes the airbase ground vehicle traffic system (server-only).

    Sets up:
      - Vehicle whitelist pools by ORBAT category (stored in mission namespace).
      - Spawn zone definitions keyed to existing airbase markers.
      - Tracking list and tunables.
      - Tick loop.

    Enable via:
        airbase_v1_gnd_traffic_enabled = true     (set in initServer.sqf)

    The vehicle whitelist below is the canonical source of truth for
    all ground vehicles permitted on the airbase.  Each category maps
    to one or more spawn zones (see zone definitions further below).

    ORBAT alignment:
      - airfield_logistics  → 332 EMSG / USAF flightline support  (Peral GSE)
      - admin               → HQ/admin traffic (HMMWVs, quadbikes, SOCOM light)
      - medical             → 332 EMG / LIFELINE (medical trucks)
      - transport           → 407 BSB GRIFFIN + 332 LRS (cargo/covered trucks)
      - support             → 407 BSB MAINT/MCP + 332 LRS (recovery/repair/fuel)
      - tka                 → TNA/TNP liaison vehicles at gate areas
*/

if (!isServer) exitWith { false };
if !(["airbaseGroundTrafficInit"] call ARC_fnc_airbaseRuntimeEnabled) exitWith { false };
if !(missionNamespace getVariable ["airbase_v1_gnd_traffic_enabled", false]) exitWith { false };

if (missionNamespace getVariable ["airbase_v1_gnd_traffic_inited", false]) exitWith { true };
missionNamespace setVariable ["airbase_v1_gnd_traffic_inited", true];

// =========================================================================
// VEHICLE WHITELIST — canonical ground vehicle pool for Joint Base Farabad
// =========================================================================

// -- AIRFIELD LOGISTICS (332 EMSG / USAF flightline) ----------------------
missionNamespace setVariable ["airbase_v1_gnd_pool_airfield_logistics",
[
    "Peral_B600",
    "Peral_527_58M",
    "Peral_H2_Forklift",
    "Peral_MJ_1E",
    "Peral_USN6"
], false];

// -- US ARMY AND USAF HQ / ADMIN / TRANSPORT (light) ----------------------
missionNamespace setVariable ["airbase_v1_gnd_pool_admin",
[
    "rhsusf_m1025_d",
    "rhsusf_m1043_d",
    "rhsusf_m998_d_2dr_fulltop",
    "rhsusf_m998_d_2dr_halftop",
    "rhsusf_m998_d_2dr",
    "rhsusf_m998_d_4dr_fulltop",
    "rhsusf_m998_d_4dr_halftop",
    "rhsusf_m998_d_4dr",
    "rhsusf_m1151_usarmy_d",
    "rhsusf_m1152_usarmy_d",
    "rhsusf_m1152_rsv_usarmy_d",
    "rhsusf_m1152_sicps_usarmy_d",
    "rhsusf_m1165_usarmy_d",
    "UK3CB_B_M1030_NATO",
    "B_Quadbike_01_F",
    "rhsusf_mrzr4_d",
    "rhsusf_M1239_socom_d",
    "rhsusf_M1238A1_socom_d"
], false];

// -- US ARMY MEDICAL (332 EMG / LIFELINE) ----------------------------------
missionNamespace setVariable ["airbase_v1_gnd_pool_medical",
[
    "rhsusf_M1085A1P2_B_D_Medical_fmtv_usarmy",
    "B_Truck_01_medical_F",
    "UK3CB_TKA_B_Hilux_Ambulance"
], false];

// -- US ARMY TRANSPORT AND LOGISTICS (407 BSB GRIFFIN + 332 LRS) ----------
missionNamespace setVariable ["airbase_v1_gnd_pool_transport",
[
    "rhsusf_M1078A1P2_D_fmtv_usarmy",
    "rhsusf_M1078A1P2_D_flatbed_fmtv_usarmy",
    "rhsusf_M1078A1P2_B_D_fmtv_usarmy",
    "rhsusf_M1078A1P2_B_D_flatbed_fmtv_usarmy",
    "rhsusf_M1078A1P2_B_D_CP_fmtv_usarmy",
    "rhsusf_M1083A1P2_D_fmtv_usarmy",
    "rhsusf_M1083A1P2_D_flatbed_fmtv_usarmy",
    "rhsusf_M1083A1P2_B_D_fmtv_usarmy",
    "rhsusf_M1083A1P2_B_D_flatbed_fmtv_usarmy",
    "rhsusf_M1084A1P2_D_fmtv_usarmy",
    "rhsusf_M1084A1P2_B_D_fmtv_usarmy",
    "rhsusf_M977A4_usarmy_d",
    "rhsusf_M978A4_usarmy_d",
    "UK3CB_B_MTVR_Closed_DES",
    "UK3CB_B_M939_Closed_DES",
    "UK3CB_B_M939_Open_DES",
    "d3s_tundra_19_UNM",
    "B_Truck_01_transport_F",
    "B_Truck_01_covered_F",
    "UK3CB_B_MTVR_Open_DES"
], false];

// -- US ARMY SUPPORT (407 BSB MAINT/MCP + 332 LRS) -----------------------
missionNamespace setVariable ["airbase_v1_gnd_pool_support",
[
    "UK3CB_B_M939_Reammo_DES",
    "UK3CB_B_M939_Recovery_DES",
    "UK3CB_B_M939_Refuel_DES",
    "UK3CB_B_M939_Repair_DES",
    "rhsusf_M977A4_AMMO_usarmy_d",
    "rhsusf_M977A4_REPAIR_usarmy_d",
    "rhsusf_M977A4_BKIT_usarmy_d",
    "rhsusf_M977A4_AMMO_BKIT_usarmy_d",
    "rhsusf_M977A4_REPAIR_BKIT_usarmy_d",
    "rhsusf_M978A4_BKIT_usarmy_d",
    "UK3CB_B_MTVR_Reammo_DES",
    "UK3CB_B_MTVR_Refuel_DES",
    "UK3CB_B_MTVR_Recovery_DES",
    "UK3CB_B_MTVR_Repair_DES",
    "B_Truck_01_mover_F",
    "B_Truck_01_ammo_F",
    "B_Truck_01_cargo_F",
    "B_Truck_01_box_F",
    "B_Truck_01_flatbed_F",
    "B_Truck_01_fuel_F",
    "B_Truck_01_Repair_F"
], false];

// -- TKA / TKP SUPPORT AND LIAISON (gate areas / TNA liaison cell) --------
missionNamespace setVariable ["airbase_v1_gnd_pool_tka",
[
    "UK3CB_TKA_B_Hilux_Closed",
    "UK3CB_TKA_B_M1025",
    "UK3CB_TKA_B_M998_2DR",
    "UK3CB_TKA_B_M998_4DR",
    "UK3CB_TKA_B_SUV_Armoured",
    "UK3CB_TKA_B_Ural",
    "UK3CB_TKA_B_Ural_Fuel",
    "UK3CB_TKA_B_Ural_Open",
    "UK3CB_TKA_B_Ural_Ammo",
    "UK3CB_TKA_B_Ural_Empty",
    "UK3CB_TKA_B_Ural_Recovery",
    "UK3CB_TKA_B_Ural_Repair",
    "UK3CB_TKP_B_Offroad",
    "UK3CB_TKP_B_Hilux_Open",
    "UK3CB_TKP_B_Hilux_Closed"
], false];

// =========================================================================
// SPAWN ZONE DEFINITIONS
// Format: [zoneId, markerName, spawnRadius_m, [poolCategories], zoneCap]
//
// Each zone is anchored to an existing airbase marker and assigned pool
// categories appropriate to the ORBAT function of that area.
// =========================================================================

private _zones = [
    // Flightline / hangar area: USAF GSE (Peral equipment)
    // Anchor: C-17 parking ramp (central hardstand reference)
    ["FLIGHTLINE",   "ARC_m_base_c17_parking",        350, ["airfield_logistics"],          4],

    // Convoy staging yard / MCP: 407 BSB logistics trucks and support vehicles
    // Anchor: convoy staging / MCP marker
    ["STAGING",      "arc_m_base_convoy_staging",      280, ["transport", "support"],        6],

    // Supply depot: sustainment transport and support vehicles
    // Anchor: supply depot marker
    ["SUPPLY",       "arc_m_base_supply_depot",        150, ["transport", "support"],        3],

    // Joint Base HQ and admin: light transport (HMMWVs, quadbikes) for staff
    // Anchor: Joint Base HQ
    ["HQ_ADMIN",     "ARC_m_base_hq_1",               120, ["admin"],                       3],

    // Base Mayor / 332 EMSG admin area: light transport
    // Anchor: 332 EMSG (Base Mayor) marker
    ["MAYOR",        "ARC_m_base_mayor_1",             100, ["admin"],                       2],

    // Theater hospital: fixed ORBAT ambulances already occupy this footprint.
    // Keep the zone defined but disable dynamic medical spawns to prevent stacking.
    ["MEDICAL",      "arc_m_base_theater_hospital",     80, ["medical"],                     0],

    // Maintenance / motor pool: support, recovery, repair vehicles
    // Anchor: base maintenance marker
    ["MAINT",        "arc_m_base_maintenance",          180, ["support"],                    3],

    // Fuel depot: fuel trucks and support
    // Anchor: base fuel depot marker
    ["FUEL_DEPOT",   "arc_m_base_fuel_depot",           120, ["support"],                    2],

    // Main Gate / perimeter: mixed light transport and TKA liaison vehicles
    // Anchor: Main Gate
    ["MAIN_GATE",    "Main_Gate",                       100, ["admin", "tka"],               2],

    // TOC area: command HMMWVs and SICPS
    // Anchor: TOC marker
    ["TOC",          "ARC_m_base_toc",                   80, ["admin"],                      2]
];

missionNamespace setVariable ["airbase_v1_gnd_zones", _zones, false];

// =========================================================================
// TUNABLES (defaults; may be overridden in initServer.sqf before this runs)
// =========================================================================

if (isNil { missionNamespace getVariable "airbase_v1_gnd_cap_global" }) then {
    missionNamespace setVariable ["airbase_v1_gnd_cap_global", 24, false];
};
if (isNil { missionNamespace getVariable "airbase_v1_gnd_playerPresenceRadius_m" }) then {
    missionNamespace setVariable ["airbase_v1_gnd_playerPresenceRadius_m", 1800, false];
};
if (isNil { missionNamespace getVariable "airbase_v1_gnd_cleanupRadius_m" }) then {
    missionNamespace setVariable ["airbase_v1_gnd_cleanupRadius_m", missionNamespace getVariable ["ARC_airbase_dynamic_radius_m", 1600], false];
};
if (isNil { missionNamespace getVariable "airbase_v1_gnd_cleanupDelay_s" }) then {
    missionNamespace setVariable ["airbase_v1_gnd_cleanupDelay_s", 90, false];
};
if (isNil { missionNamespace getVariable "airbase_v1_gnd_tick_s" }) then {
    missionNamespace setVariable ["airbase_v1_gnd_tick_s", 60, false];
};
if (isNil { missionNamespace getVariable "airbase_v1_gnd_debug" }) then {
    missionNamespace setVariable ["airbase_v1_gnd_debug", false, false];
};

// Tracking list
missionNamespace setVariable ["airbase_v1_gnd_list", [], false];

// =========================================================================
// VALIDATE POOLS
// =========================================================================

private _allValid = [] call ARC_fnc_airbaseGroundTrafficBuildPool;
diag_log format ["[ARC][ABTRAF][INIT] pool build complete: %1 valid classnames across all categories.", count _allValid];

// =========================================================================
// TICK LOOP
// =========================================================================

private _tickS = missionNamespace getVariable ["airbase_v1_gnd_tick_s", 60];
if (!(_tickS isEqualType 0)) then { _tickS = 60; };
if (_tickS < 5) then { _tickS = 5; };

diag_log format ["[ARC][ABTRAF][INIT] ground traffic started: %1 zones, tickS=%2, capGlobal=%3", count _zones, _tickS, missionNamespace getVariable ["airbase_v1_gnd_cap_global", 24]];

[] spawn
{
    while { isServer && { missionNamespace getVariable ["airbase_v1_gnd_traffic_enabled", false] } } do
    {
        [] call ARC_fnc_airbaseGroundTrafficTick;

        private _t = missionNamespace getVariable ["airbase_v1_gnd_tick_s", 60];
        if (!(_t isEqualType 0)) then { _t = 60; };
        if (_t < 5) then { _t = 5; };
        uiSleep _t;
    };
};

true

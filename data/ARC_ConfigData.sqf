/*
    Farabad COIN (ARC) - Config Data (Defaults)

    Purpose:
    - Single source-of-truth for *editable* classname pools and other tunables that were
      previously scattered across bootstrap scripts.

    Rules:
    - Do NOT overwrite values that already exist (use isNil guards).
    - Server is authoritative writer; broadcast with public=true when clients need visibility.

    Suggested workflow:
    - Modify pools here (convoy, civilian, etc.), not inside core logic functions.
*/

// --- Convoy pools -------------------------------------------------------------
if (isNil "ARC_convoyCarPool") then {
    missionNamespace setVariable ["ARC_convoyCarPool", [
        "C_Offroad_01_F",
        "C_Offroad_01_repair_F",
        "C_SUV_01_F",
        "C_Van_01_transport_F",
        "C_Van_01_box_F",
        "C_Hatchback_01_F",
        "C_Hatchback_01_sport_F"
    ], true];
};

if (isNil "ARC_convoyTruckPool") then {
    missionNamespace setVariable ["ARC_convoyTruckPool", [
        "C_Van_01_box_F",
        "C_Truck_02_transport_F",
        "C_Truck_02_covered_F"
    ], true];
};

if (isNil "ARC_convoyFuelPool") then {
    missionNamespace setVariable ["ARC_convoyFuelPool", [
        "C_Van_01_fuel_F",
        "C_Truck_02_fuel_F"
    ], true];
};

if (isNil "ARC_convoySecurityPool") then {
    missionNamespace setVariable ["ARC_convoySecurityPool", [
        "B_MRAP_01_F",
        "B_MRAP_01_gmg_F",
        "B_MRAP_01_hmg_F"
    ], true];
};

// --- Console terminal proximity classes --------------------------------------
// If a player lacks a tablet, being within range of ANY of these objects allows opening the Console.
if (isNil "ARC_consoleTerminalClasses") then {
    missionNamespace setVariable ["ARC_consoleTerminalClasses", [
        "RuggedTerminal_01_communications_F",
        "Land_Laptop_03_black_F",
        "Land_Laptop_03_olive_F",
        "Land_Laptop_03_closed_black_F",
        "Land_Laptop_03_closed_olive_F",
        "Land_Laptop_02_F",
        "Land_FlatTV_01_F"
    ], true];
};

// --- Airbase ---------------------------------------------------------------
// First outbound departure delay (seconds) from airbase init.
if (isNil "airbase_v1_firstDepartureDelayS") then {
    missionNamespace setVariable ["airbase_v1_firstDepartureDelayS", 300, true];
};


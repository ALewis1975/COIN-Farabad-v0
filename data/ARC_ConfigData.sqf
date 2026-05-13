/*
    Farabad COIN (ARC) - Config Data (Defaults)

    Purpose:
    - Single source-of-truth for *editable* classname pools and other tunables that were
      previously scattered across bootstrap scripts.

    Rules:
    - Do NOT overwrite values that already exist (use isNil guards).
    - Server is authoritative writer; broadcast with public=true when clients need visibility.

    Suggested workflow:
    - Modify classname pools here (civilian, etc.), not inside core logic functions.
*/

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


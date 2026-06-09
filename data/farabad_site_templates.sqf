/*
    farabad_site_templates.sqf

    Site population templates for the dynamic site population (SitePop) subsystem.
    Loaded by ARC_fnc_sitePopInit on mission start.

    Returns: ARRAY of site template entries.

    Template entry format:
        [
            siteId          STRING  - matches locationId in ARC_worldNamedLocations
            markerName      STRING  - canonical ARC_loc_* marker name
            triggerRadiusM  NUMBER  - activate when a player enters this radius (meters)
            despawnRadiusM  NUMBER  - grace-period countdown starts when no player is within this radius
            gracePeriodS    NUMBER  - seconds all players must stay outside despawnRadiusM before site despawns
            popGroups       ARRAY   - array of population group definitions (see below)
        ]

    Population group format:
        [
            roleTag         STRING  - human-readable role ("guard", "prisoner", "vendor", ...)
            sideStr         STRING  - "west" | "east" | "indep" | "civ"
            unitClassPool   ARRAY   - candidate CfgVehicles classnames; invalid classes filtered at spawn time
            countRange      ARRAY   - [minCount, maxCount]
            behavior        STRING  - "garrison" | "camp" | "wander" | "parked"
            spawnRadiusM    NUMBER  - spawn units within this radius of the anchor (or site centre if no anchor)
            spawnAnchor     STRING  - (optional) Eden marker name for zone-local spawning and wander.
                                      When non-empty, ARC_worldBuildingSlots entries and wander waypoints
                                      are filtered to within spawnRadiusM of this marker.
                                      Falls back to site centre if the marker does not exist in the mission.
                                      Omit or leave "" to use site-wide (legacy 6-field) behaviour.
        ]

    Side notes:
    - "garrison": LAMBS lambs_danger_fnc_garrison if available; falls back to SAFE/WHITE hold in buildings.
    - "camp":     LAMBS lambs_danger_fnc_camp if available; falls back to loiter waypoints.
    - "wander":   When spawnAnchor is set, generates anchor-local waypoints (bypasses ARC_worldPatrolRings).
                  When no anchor, uses pre-scanned ARC_worldPatrolRings (tight/medium ring); falls back to random loiter.
    - Civilian ("civ") and prisoner roles (roleTag containing "prisoner") always have weapons stripped.
    - Prisoner roles additionally have vest and backpack removed and receive ARC_prisoner / ARC_prisonHomeZone /
      ARC_prisonRiskTier variable tags.
    - Class pool entries that are not present in CfgVehicles are silently skipped.

    NOTE: The optional 7th field (spawnAnchor) is backward-compatible. All existing 6-field group
    definitions continue to work unchanged; the anchor defaults to "" (site-wide behaviour).
*/

// ---------------------------------------------------------------------------
// Shared unit class pools
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Resolve host-nation (3CB) infantry pools directly from CfgVehicles.
//
// The 3CB Factions BLUFOR infantry classnames are abbreviated (e.g.
// UK3CB_TKA_B_AR / _TL / _OFF), not the *_Soldier / *_NCO names some pools
// historically assumed. A static list of the wrong names silently filters to
// zero valid classes at spawn time, so the guard group is skipped even though
// the faction mod is loaded. Enumerating the faction here keeps the pools
// correct regardless of the mod's exact roster; the hardcoded lists below
// remain as a graceful fallback for when the faction is genuinely absent.
// ---------------------------------------------------------------------------
private _tkaFound = [];
private _tkpFound = [];
{
    if (getNumber (_x >> "scope") != 2) then { continue; };
    if (getNumber (_x >> "side") != 1) then { continue; }; // 1 = west / BLUFOR
    private _cn = configName _x;
    if !(_cn isKindOf "Man") then { continue; };
    switch (getText (_x >> "faction")) do
    {
        case "UK3CB_TKA_B": { _tkaFound pushBack _cn; };
        case "UK3CB_TKP_B": { _tkpFound pushBack _cn; };
    };
} forEach ("true" configClasses (configFile >> "CfgVehicles"));

// Takistan National Police (3CB UK3CB_TKP_B faction, BLUFOR)
// No vanilla fallbacks: if 3CB TKP classes are absent from CfgVehicles the
// group will not spawn rather than substituting wrong-faction units.
// Fallback classnames use the 3CB abbreviated roster (e.g. _AR/_TL/_OFF), NOT
// the *_Soldier/*_NCO names — the latter do not exist in CfgVehicles and would
// filter to an empty pool at spawn time, skipping the guard group. Every class
// below is corroborated by an external source: the infantry roles (_RIF_1/_RIF_2/
// _SL/_TL/_MK/_MD/_AR/_ENG/_MG) match the 3CB Takistan Police faction template,
// and _OFF/_Officer_U appear in the live server RPT (CfgVehicles deinit log).
private _tnpPool = if ((count _tkpFound) > 0) then { +_tkpFound } else {
    [
        "UK3CB_TKP_B_TL",
        "UK3CB_TKP_B_SL",
        "UK3CB_TKP_B_RIF_2",
        "UK3CB_TKP_B_RIF_1",
        "UK3CB_TKP_B_OFF",
        "UK3CB_TKP_B_Officer_U",
        "UK3CB_TKP_B_MD",
        "UK3CB_TKP_B_MK",
        "UK3CB_TKP_B_MG",
        "UK3CB_TKP_B_ENG",
        "UK3CB_TKP_B_AR"
    ]
};

// Takistan National Police — medical/escort role. Prefers medic/doctor classes
// from the resolved faction roster, falling back to the general TNP pool (then
// to the hardcoded list) so the escort still spawns if no medic class exists.
// No vanilla fallbacks: group skips gracefully if 3CB TKP classes are absent.
// The hardcoded medic uses the abbreviated _MD classname (the *_Medic name does
// not exist in CfgVehicles); _TL/_SL keep the escort viable if it is absent.
private _tnpMedPool = if ((count _tkpFound) > 0) then {
    private _meds = _tkpFound select { ((toLower _x) find "medic") >= 0 || { ((toLower _x) find "doc") >= 0 } || { ((_x select [(count _x) - 3]) == "_MD") } };
    if ((count _meds) > 0) then { _meds } else { +_tkpFound }
} else {
    [
        "UK3CB_TKP_B_MD",
        "UK3CB_TKP_B_TL",
        "UK3CB_TKP_B_SL"
    ]
};

// Civilian medical personnel: doctors, nurses, paramedics (3CB + IDAP).
// Invalid classes are silently skipped at spawn time.
private _civMedPool = [
    "UK3CB_MEC_C_DOC",
    "UK3CB_TKC_C_DOC",
    "UK3CB_CHC_C_DOC",
    "UK3CB_ADC_C_DOC_CHR",
    "UK3CB_ADC_C_DOC_ISL",
    "C_IDAP_Man_Paramedic_01_F"
];

// Ambulance / medical transport vehicles.
// UK3CB_TKC_C_S1203_Amb is the primary civilian ambulance class.
// C_Offroad_01_red_F provides a minimal vanilla fallback.
private _ambVehiclePool = [
    "UK3CB_TKC_C_S1203_Amb",
    "UK3CB_TKC_C_S1203",
    "C_Offroad_01_red_F"
];

// Takistan National Army (3CB UK3CB_TKA_B faction, BLUFOR)
// No vanilla fallbacks: group skips gracefully if 3CB TKA classes are absent.
// Fallback classnames use the 3CB abbreviated roster (e.g. _AR/_TL/_OFF), NOT
// the *_Soldier/*_NCO names — the latter do not exist in CfgVehicles and would
// filter to an empty pool at spawn time, skipping the guard group. The classes
// below are confirmed present in the live server CfgVehicles roster.
private _tnaPool = if ((count _tkaFound) > 0) then { +_tkaFound } else {
    [
        "UK3CB_TKA_B_Infantry_U_01",
        "UK3CB_TKA_B_Infantry_U_Shortsleeve_01",
        "UK3CB_TKA_B_AR",
        "UK3CB_TKA_B_TL",
        "UK3CB_TKA_B_OFF",
        "UK3CB_TKA_B_Officer_U"
    ]
};

// Civilian population: common civs from 3CB MEC, TKC, and ADC factions.
// Invalid classes are silently skipped at spawn time.
private _civPool = [
    "UK3CB_MEC_C_CIV_01",
    "UK3CB_MEC_C_CIV_02",
    "UK3CB_MEC_C_HUNTER",
    "UK3CB_MEC_C_CIT",
    "UK3CB_MEC_C_COACH",
    "UK3CB_MEC_C_PROF",
    "UK3CB_MEC_C_CIV",
    "UK3CB_MEC_C_SPOT",
    "UK3CB_TKC_C_CIV",
    "UK3CB_TKC_C_SPOT",
    "UK3CB_ADC_C_SPOT_ISL"
];

// Workers and contractors (labourers, manual trades).
private _workerPool = [
    "UK3CB_MEC_C_LABOURER",
    "UK3CB_MEC_C_WORKER",
    "UK3CB_TKC_C_WORKER",
    "UK3CB_ADC_C_LABOURER_CHR",
    "UK3CB_ADC_C_LABOURER_ISL"
];

// Palace / embassy staff: government officials, diplomats, VIPs.
private _staffPool = [
    "UK3CB_MEC_C_FUNC",
    "UK3CB_CHC_C_BODYG",
    "UK3CB_CHC_C_FUNC",
    "UK3CB_CHC_C_POLITIC",
    "UK3CB_CHC_C_CAN",
    "UK3CB_ADC_C_FUNC",
    "C_Story_Scientist_01_F",
    "C_Nikos_aged"
];

// ---------------------------------------------------------------------------
// Vehicle pools for the purpose-expansion sites (issue #633 step 4).
// Each pool mixes 3CB civilian classes with vanilla fallbacks; classes absent
// from CfgVehicles are silently filtered at spawn time, so a thin mod preset
// degrades gracefully to the vanilla entries rather than producing missing-class
// RPT spam. All are spawned with behaviour "parked" (locked, dynamic-sim).
// ---------------------------------------------------------------------------

// General civilian cars parked in markets, hotels, and urban sites.
private _civCarPool = [
    "UK3CB_TKC_C_S1203",
    "C_Offroad_01_F",
    "C_Hatchback_01_F",
    "C_SUV_01_F"
];

// Light utility/box trucks for industrial, power, and mine sites.
private _utilityTruckPool = [
    "C_Van_01_box_F",
    "C_Truck_02_transport_F",
    "C_Truck_02_covered_F",
    "UK3CB_TKC_C_S1203"
];

// Fuel transport for oil/gas sites.
private _fuelTruckPool = [
    "C_Van_01_fuel_F",
    "C_Truck_02_fuel_F"
];

// Cargo transport for the port.
private _cargoTruckPool = [
    "C_Truck_02_covered_F",
    "C_Truck_02_transport_F",
    "C_Van_01_box_F"
];

// Military soft-skin transport for the military compound baseline.
private _milVehiclePool = [
    "B_Truck_01_transport_F",
    "B_Truck_01_covered_F",
    "C_Offroad_01_F"
];

// ---------------------------------------------------------------------------
// Templates
// ---------------------------------------------------------------------------
//
// _baseTemplates: the three original SitePop sites. ALWAYS returned, unchanged.
// _expansionTemplates (further below): purpose-specific baselines for the rest of
// the high-value named AO locations (issue #633 step 4). These are appended ONLY
// when ARC_sitePurposeExpansionEnabled is true (default false in initServer.sqf),
// so SitePop behaviour is identical to the pre-expansion mission until an operator
// opts in. The active-sites cap (ARC_sitePopActiveSitesCap, default 6, enforced in
// ARC_fnc_sitePopSpawnSite) bounds concurrent AI regardless of how many sites are
// registered here.
// ---------------------------------------------------------------------------

private _baseTemplates = [
    // -------------------------------------------------------------------------
    // KARKANAK PRISON  (zone-aware, anchor-local spawning)
    //   All guard roles use TNP (BLUFOR). Civilian roles: medical staff, vendors,
    //   contractors, prisoners. TNA is NOT a baseline role — use as conditional
    //   QRF overlay only.
    //
    //   Spawn anchors reference Eden markers placed inside the prison footprint.
    //   Each anchor gates building-slot filtering and wander waypoints to its own
    //   radius, so no group bleeds across subzone boundaries.
    //
    //   Anchor markers required in mission.sqm (place once in Eden):
    //     prison_admin_offices        — command/admin block
    //     prison_entry_office         — main gate / entry processing
    //     prison_guard_tower_1        — north perimeter tower
    //     prison_guard_tower_2        — south perimeter tower
    //     prison_central_guard_tower  — central internal tower
    //     prison_dorm_01 .. _04       — individual dormitory blocks
    //     prison_intake_01            — intake/processing cluster
    //     prison_hospital             — medical wing
    //     prison_holding_area         — holding yard / high-risk block
    //   When a marker is absent, the group falls back to site-centre with a WARN log.
    //
    //   Guard composition (BLUFOR, doctrinal):
    //     hq_admin       (4)   Prison HQ / Admin Cell
    //     gate_guard     (8)   Main Gate / Vehicle Search
    //     tower_north    (2-3) North perimeter tower
    //     tower_south    (2-3) South perimeter tower
    //     tower_central  (2-3) Central internal guard tower
    //     internal_a     (6)   Internal Guard Section A — dorm 01/02 block
    //     internal_b     (6)   Internal Guard Section B — dorm 03/04 block
    //     intake         (4)   Intake / Processing / Evidence Cell
    //     escort         (4)   Escort / Transport Section
    //     reaction       (4)   Prison Reaction / Reserve Section
    //   Prison hospital (BLUFOR + CIV):
    //     prison_medic     (3-4)  TKP armed medical escort / security
    //     prison_civ_doc   (2-3)  Civilian doctors / nurses (unarmed)
    //     prison_ambulance (1-2)  Parked ambulance(s) — roadside slots near hospital
    //   Prisoners (CIV, stripped, tagged):
    //     prisoner_dorm_01 .. _04  (3-5 each)  Dorm-bound wander populations
    //     prisoner_holding         (2-4)        Holding-yard wander population
    //   Support (CIV):
    //     vendor      (3-6)   Gate compound clusters
    //     contractor  (2-4)   Outer maintenance / perimeter support (no anchor)
    // -------------------------------------------------------------------------
    [
        "KarkanakPrison",
        "ARC_loc_KarkanakPrison",
        600,
        900,
        120,
        [
            // --- Admin & Command ---
            ["hq_admin",            "west", _tnpPool,        [4, 4], "camp",     35, "prison_admin_offices"],
            // --- Entry ---
            ["gate_guard",          "west", _tnpPool,        [8, 8], "garrison", 50, "prison_entry_office"],
            // --- Perimeter / Towers (split from monolithic "perimeter") ---
            ["tower_north",         "west", _tnpPool,        [2, 3], "garrison", 25, "prison_guard_tower_1"],
            ["tower_south",         "west", _tnpPool,        [2, 3], "garrison", 25, "prison_guard_tower_2"],
            ["tower_central",       "west", _tnpPool,        [2, 3], "garrison", 25, "prison_central_guard_tower"],
            // --- Internal Guard Sections ---
            ["internal_a",          "west", _tnpPool,        [6, 6], "garrison", 45, "prison_dorm_01"],
            ["internal_b",          "west", _tnpPool,        [6, 6], "garrison", 45, "prison_dorm_03"],
            // --- Intake ---
            ["intake",              "west", _tnpPool,        [4, 4], "camp",     35, "prison_intake_01"],
            // --- Escort / Reaction (both anchor to admin area) ---
            ["escort",              "west", _tnpPool,        [4, 4], "wander",   50, "prison_admin_offices"],
            ["reaction",            "west", _tnpPool,        [4, 4], "camp",     40, "prison_admin_offices"],
            // --- Hospital (all three groups anchored to hospital marker) ---
            ["prison_medic",        "west", _tnpMedPool,     [3, 4], "camp",     30, "prison_hospital"],
            ["prison_civ_doc",      "civ",  _civMedPool,     [2, 3], "camp",     30, "prison_hospital"],
            ["prison_ambulance",    "civ",  _ambVehiclePool, [1, 2], "parked",   40, "prison_hospital"],
            // --- Prisoner populations (one per dormitory block + holding yard) ---
            ["prisoner_dorm_01",    "civ",  _civPool,        [3, 5], "wander",   25, "prison_dorm_01"],
            ["prisoner_dorm_02",    "civ",  _civPool,        [3, 5], "wander",   25, "prison_dorm_02"],
            ["prisoner_dorm_03",    "civ",  _civPool,        [3, 5], "wander",   25, "prison_dorm_03"],
            ["prisoner_dorm_04",    "civ",  _civPool,        [3, 5], "wander",   25, "prison_dorm_04"],
            ["prisoner_holding",    "civ",  _civPool,        [2, 4], "wander",   30, "prison_holding_area"],
            // --- Support (CIV) ---
            ["vendor",              "civ",  _civPool,        [3, 6], "camp",     50, "prison_entry_office"],
            // Contractor has no anchor: omitting the 7th field is equivalent to ""
            // and demonstrates backward-compatible 6-field usage.
            ["contractor",          "civ",  _workerPool,     [2, 4], "wander",  100]
        ]
    ],

    // -------------------------------------------------------------------------
    // PRESIDENTIAL PALACE
    //   Army guards (TNA), palace staff (CIV), diplomatic visitors (CIV).
    //   Trigger at 500 m; despawn after 120 s with no player within 750 m.
    // -------------------------------------------------------------------------
    [
        "PresidentialPalace",
        "ARC_loc_PresidentialPalace",
        500,
        750,
        120,
        [
            ["guard",   "west", _tnaPool,   [6, 10], "garrison", 80],
            ["staff",   "civ",  _staffPool, [4,  8], "camp",     60],
            ["visitor", "civ",  _civPool,   [2,  5], "wander",   50]
        ]
    ],

    // -------------------------------------------------------------------------
    // EMBASSY COMPOUND
    //   Army guards (TNA), civilian embassy staff (CIV), contractors (CIV).
    //   Trigger at 450 m; despawn after 120 s with no player within 700 m.
    // -------------------------------------------------------------------------
    [
        "EmbassyCompound",
        "ARC_loc_EmbassyCompound",
        450,
        700,
        120,
        [
            ["guard",      "west", _tnaPool,    [6,  8], "garrison", 70],
            ["staff",      "civ",  _staffPool,  [3,  6], "camp",     50],
            ["contractor", "civ",  _workerPool, [2,  4], "wander",   80]
        ]
    ]
];

// ---------------------------------------------------------------------------
// Purpose-expansion templates (issue #633 step 4).
//
// One bounded SitePop baseline per high-value named AO location, translating the
// purpose patterns declared in data/farabad_spawn_patterns.sqf ("purposePatterns"
// + "locationPurposes") into concrete SitePop role groups. Counts are kept on the
// conservative end of the matrix ranges because uncontrolled AI count is the
// primary risk called out in the issue; richer fidelity should be tuned upward
// only after MP validation.
//
// SitePop supports four behaviours (garrison | camp | wander | parked); the
// richer matrix behaviours are mapped down here (construction/medical/inspect ->
// camp, guard -> garrison, loiter/queue -> wander, traffic_through -> parked
// vehicles). Each site uses site-wide (6-field) groups: no Eden anchor markers
// are required, so these spawn correctly without additional mission.sqm edits.
//
// siteId / markerName values match ARC_worldNamedLocations + the canonical
// ARC_loc_* markers in data/farabad_world_locations.sqf. Civilian-side units are
// auto-disarmed by ARC_fnc_sitePopBuildGroup.
// ---------------------------------------------------------------------------
private _expansionTemplates = [
    // GRAND MOSQUE — RELIGIOUS: elder, worshippers, vendors, TNP outer security.
    [
        "GrandMosque",
        "ARC_loc_GrandMosque",
        450,
        700,
        120,
        [
            ["elder",      "civ",  _civPool,    [1, 1], "camp",     30],
            ["worshipper", "civ",  _civPool,    [5, 8], "wander",   60],
            ["vendor",     "civ",  _civPool,    [1, 3], "camp",     50],
            ["tnp_outer",  "west", _tnpPool,    [2, 4], "garrison", 70],
            ["civ_car",    "civ",  _civCarPool, [1, 3], "parked",   70]
        ]
    ],

    // BELLE FOILLE HOTEL — HOTEL: staff, guests, security, parked cars.
    [
        "BelleFoilleHotel",
        "ARC_loc_BelleFoilleHotel",
        450,
        700,
        120,
        [
            ["hotel_staff", "civ",  _civPool,    [2, 4], "camp",     40],
            ["guest",       "civ",  _civPool,    [3, 6], "wander",   55],
            ["security",    "west", _tnpPool,    [2, 4], "garrison", 50],
            ["civ_car",     "civ",  _civCarPool, [2, 5], "parked",   70]
        ]
    ],

    // HOSPITAL — MEDICAL: civilian doctors/nurses, patients, TNP outer, ambulance.
    [
        "hospital",
        "ARC_loc_hospital",
        450,
        700,
        120,
        [
            ["civ_doctor", "civ",  _civMedPool,    [2, 4], "camp",     40],
            ["patient",    "civ",  _civPool,       [3, 6], "wander",   55],
            ["tnp_outer",  "west", _tnpPool,       [2, 4], "garrison", 60],
            ["ambulance",  "civ",  _ambVehiclePool,[1, 2], "parked",   60]
        ]
    ],

    // INDUSTRIAL COMPLEX — INDUSTRIAL: workers, contractors, limited security.
    [
        "industrial022",
        "ARC_loc_industrial022",
        450,
        700,
        120,
        [
            ["worker",     "civ",  _workerPool,      [4, 6], "camp",     70],
            ["contractor", "civ",  _workerPool,      [1, 3], "wander",   90],
            ["security",   "west", _tnpPool,         [2, 3], "garrison", 80],
            ["utility_truck","civ",_utilityTruckPool,[1, 3], "parked",   90]
        ]
    ],

    // JUNKYARD — INDUSTRIAL: mechanics/scavengers, light security, derelict trucks.
    [
        "Junkyard",
        "ARC_loc_Junkyard",
        450,
        700,
        120,
        [
            ["mechanic",   "civ",  _workerPool,      [2, 4], "camp",     60],
            ["scavenger",  "civ",  _civPool,         [2, 4], "wander",   80],
            ["security",   "west", _tnpPool,         [1, 2], "garrison", 70],
            ["junk_truck", "civ",  _utilityTruckPool,[1, 3], "parked",   80]
        ]
    ],

    // SOLAR FARM — POWER: technicians, light security, utility trucks.
    [
        "SolarFarm",
        "ARC_loc_SolarFarm",
        450,
        700,
        120,
        [
            ["technician",   "civ",  _workerPool,      [2, 4], "camp",     80],
            ["security",     "west", _tnpPool,         [1, 3], "garrison", 90],
            ["utility_truck","civ",  _utilityTruckPool,[1, 2], "parked",   90]
        ]
    ],

    // PORT FARABAD — PORT: stevedores, port security, customs, cargo trucks.
    [
        "PortFarabad",
        "ARC_loc_PortFarabad",
        500,
        750,
        120,
        [
            ["stevedore",    "civ",  _workerPool,     [4, 6], "camp",     90],
            ["port_security","west", _tnpPool,        [2, 4], "garrison", 80],
            ["customs",      "west", _tnpPool,        [1, 3], "camp",     70],
            ["cargo_truck",  "civ",  _cargoTruckPool, [1, 3], "parked",   90]
        ]
    ],

    // JAZIRA OIL REFINERY — OIL_GAS: workers, perimeter security, fuel trucks.
    [
        "JaziraOilRefinery",
        "ARC_loc_JaziraOilRefinery",
        500,
        750,
        120,
        [
            ["worker",     "civ",  _workerPool,   [3, 6], "camp",     90],
            ["security",   "west", _tnpPool,      [2, 4], "garrison", 90],
            ["fuel_truck", "civ",  _fuelTruckPool,[1, 3], "parked",   90]
        ]
    ],

    // JAZIRA OIL FIELD — OIL_GAS: workers, perimeter security, fuel trucks.
    [
        "JaziraOilField",
        "ARC_loc_JaziraOilField",
        500,
        750,
        120,
        [
            ["worker",     "civ",  _workerPool,   [3, 5], "camp",     90],
            ["security",   "west", _tnpPool,      [2, 3], "garrison", 90],
            ["fuel_truck", "civ",  _fuelTruckPool,[1, 2], "parked",   90]
        ]
    ],

    // MILITARY COMPOUND — MILITARY: TNA staff, patrols, parked military vehicles.
    [
        "military",
        "ARC_loc_military",
        500,
        750,
        120,
        [
            ["tna_staff",  "west", _tnaPool,        [4, 6], "garrison", 90],
            ["patrol",     "west", _tnaPool,        [2, 4], "wander",   100],
            ["mil_vehicle","west", _milVehiclePool, [1, 3], "parked",   90]
        ]
    ]
];

// ---------------------------------------------------------------------------
// Assemble the returned template set.
//   - Base sites are always present.
//   - Expansion sites are appended only when the operator has opted in via the
//     ARC_sitePurposeExpansionEnabled toggle (default false). When off, this file
//     returns exactly the pre-expansion three-site set.
// ---------------------------------------------------------------------------
private _result = +_baseTemplates;
if (missionNamespace getVariable ["ARC_sitePurposeExpansionEnabled", false]) then
{
    _result append _expansionTemplates;
    diag_log format ["[ARC][SITEPOP][INFO] farabad_site_templates: purpose expansion ON — +%1 site template(s).", count _expansionTemplates];
};

_result

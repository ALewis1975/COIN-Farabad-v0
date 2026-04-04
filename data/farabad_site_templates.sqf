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

// Takistan National Police (3CB UK3CB_TKP_B faction, BLUFOR)
// No vanilla fallbacks: if 3CB TKP classes are absent from CfgVehicles the
// group will not spawn rather than substituting wrong-faction units.
private _tnpPool = [
    "UK3CB_TKP_B_Soldier",
    "UK3CB_TKP_B_Soldier_L",
    "UK3CB_TKP_B_Soldier_AR",
    "UK3CB_TKP_B_Soldier_GL",
    "UK3CB_TKP_B_NCO"
];

// Takistan National Police — medical/escort role.
// No vanilla fallbacks: group skips gracefully if 3CB TKP classes are absent.
private _tnpMedPool = [
    "UK3CB_TKP_B_Medic",
    "UK3CB_TKP_B_Soldier",
    "UK3CB_TKP_B_NCO"
];

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
private _tnaPool = [
    "UK3CB_TKA_B_Soldier",
    "UK3CB_TKA_B_Soldier_L",
    "UK3CB_TKA_B_Soldier_AR",
    "UK3CB_TKA_B_Soldier_LAT",
    "UK3CB_TKA_B_NCO"
];

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
// Templates
// ---------------------------------------------------------------------------

[
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
]

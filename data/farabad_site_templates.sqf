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
            behavior        STRING  - "garrison" | "camp" | "wander"
            spawnRadiusM    NUMBER  - spawn units within this radius of site center
        ]

    Side notes:
    - "garrison": LAMBS lambs_danger_fnc_garrison if available; falls back to SAFE/WHITE hold in buildings.
    - "camp":     LAMBS lambs_danger_fnc_camp if available; falls back to loiter waypoints.
    - "wander":   Uses pre-scanned ARC_worldPatrolRings (tight/medium ring); falls back to random loiter waypoints.
    - Civilian ("civ") and "prisoner" roles always have weapons stripped after spawn.
    - Class pool entries that are not present in CfgVehicles are silently skipped.
*/

// ---------------------------------------------------------------------------
// Shared unit class pools
// ---------------------------------------------------------------------------

// Takistan National Police (3CB UK3CB_TKP_B faction, BLUFOR)
// Vanilla BLUFOR classes serve as fallback when 3CB is absent.
private _tnpPool = [
    "UK3CB_TKP_B_Soldier",
    "UK3CB_TKP_B_Soldier_L",
    "UK3CB_TKP_B_Soldier_AR",
    "UK3CB_TKP_B_Soldier_GL",
    "UK3CB_TKP_B_NCO",
    "B_GEN_Soldier_F",
    "B_Soldier_F",
    "B_Soldier_AR_F"
];

// Takistan National Army (3CB UK3CB_TKA_B faction, BLUFOR)
private _tnaPool = [
    "UK3CB_TKA_B_Soldier",
    "UK3CB_TKA_B_Soldier_L",
    "UK3CB_TKA_B_Soldier_AR",
    "UK3CB_TKA_B_Soldier_LAT",
    "UK3CB_TKA_B_NCO",
    "B_GEN_Soldier_F",
    "B_Soldier_F",
    "B_Soldier_AR_F"
];

// Civilian population: 3CB Takistan (TKC) and Middle Eastern (MEC) civilians.
// Invalid classes are silently skipped at spawn time (fn_sitePopBuildGroup validates via CfgVehicles).
// Vanilla Arma 3 classes are included as a final fallback for no-mod environments.
private _civPool = [
    // 3CB Takistan Civilians (faction: UK3CB_TKC_C) — primary Takistan population
    "UK3CB_TKC_C_CIV",
    "UK3CB_TKC_C_SPOT",
    "UK3CB_TKC_C_WORKER",
    "UK3CB_TKC_C_DOC",
    // 3CB Middle Eastern Civilians (faction: UK3CB_MEC_C) — broader regional population
    "UK3CB_MEC_C_CIV",
    "UK3CB_MEC_C_WORKER",
    // Vanilla fallback (skipped when 3CB classes are present and valid)
    "C_Man_casual_1_F",
    "C_man_polo_1_F",
    "C_man_w_worker1_F"
];

// Worker / contractor subset — same pool, different behavior applied per group.
private _workerPool = +_civPool;

// Palace / embassy staff (civilian appearance).
private _staffPool = +_civPool;

// ---------------------------------------------------------------------------
// Templates
// ---------------------------------------------------------------------------

[
    // -------------------------------------------------------------------------
    // KARKANAK PRISON
    //   BLUFOR (TNP) guard sections: 8 named elements totalling 40 personnel.
    //   Civilian roles: prisoners (unarmed), vendors, maintenance contractors.
    //   LAMBS garrison for armed guards; wander/camp for civilians.
    //   Trigger at 600 m; despawn after 120 s with no player within 900 m.
    //
    //   BLUFOR composition (doctrinal):
    //     hq_admin   (4)  Prison HQ / Admin Cell – commander, deputy, radio clerk, records clerk
    //     gate_guard (8)  Main Gate / Vehicle Search – gate guards, vehicle search, visitor control, outer sally port
    //     perimeter  (8)  Perimeter / Tower Section – wall posts, roving exterior guard, alarm response
    //     internal_a (6)  Internal Guard Section A – cellblock security, key control, prisoner movement
    //     internal_b (6)  Internal Guard Section B – second block / segregation / overflow guard
    //     intake     (4)  Intake / Processing / Evidence Cell – search, booking, property, paperwork
    //     escort     (4)  Escort / Transport Section – detainee transfer, courtroom or handoff movement
    //     reaction   (4)  Prison Reaction / Reserve Section – riot response, breakout response, emergency reserve
    // -------------------------------------------------------------------------
    [
        "KarkanakPrison",
        "ARC_loc_KarkanakPrison",
        600,
        900,
        120,
        [
            // Prison HQ / Admin Cell – commander, deputy, radio clerk, records clerk (4)
            ["hq_admin",   "west", _tnpPool,    [4,  4], "camp",      40],
            // Main Gate / Vehicle Search Section – gate guards, search, visitor control, outer sally port (8)
            ["gate_guard", "west", _tnpPool,    [8,  8], "garrison",  70],
            // Perimeter / Tower Section – wall posts, roving exterior guard, alarm response (8)
            ["perimeter",  "west", _tnpPool,    [8,  8], "garrison", 100],
            // Internal Guard Section A – cellblock security, key control, prisoner movement (6)
            ["internal_a", "west", _tnpPool,    [6,  6], "garrison",  50],
            // Internal Guard Section B – second block / segregation / overflow guard (6)
            ["internal_b", "west", _tnpPool,    [6,  6], "garrison",  50],
            // Intake / Processing / Evidence Cell – search, booking, property, paperwork (4)
            ["intake",     "west", _tnpPool,    [4,  4], "camp",      40],
            // Escort / Transport Section – detainee transfer, courtroom or handoff movement (4)
            ["escort",     "west", _tnpPool,    [4,  4], "wander",    60],
            // Prison Reaction / Reserve Section – riot response, breakout response, emergency reserve (4)
            ["reaction",   "west", _tnpPool,    [4,  4], "camp",      50],
            // Prisoners wander the yard (tight patrol ring, unarmed)
            ["prisoner",   "civ",  _civPool,    [10, 18], "wander",    80],
            // Vendors cluster near the compound gate (LAMBS camp or loiter)
            ["vendor",     "civ",  _civPool,    [3,   6], "camp",      60],
            // Maintenance contractors move around the outer area
            ["contractor", "civ",  _workerPool, [2,   4], "wander",   120]
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

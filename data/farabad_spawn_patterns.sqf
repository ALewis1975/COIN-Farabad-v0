/*
    farabad_spawn_patterns.sqf

    Data-driven Incident / Lead / site spawn-pattern matrix (issue #633, step 1).

    This file is DATA ONLY. It declares *what* each place is supposed to be and
    *what* belongs there, but it does NOT spawn anything itself. The audit
    function ARC_fnc_worldSpawnPatternAudit resolves every Incident catalog row,
    named location, and terrain site type against this matrix and reports
    coverage / warnings. Transient overlay spawning (issue #633 steps 4-6) is a
    later, separately-toggled phase that will consume the same tables.

    Returns: ARRAY of [key, value] pairs (consumed via a compiled getOrDefault
    helper to stay sqflint-compat). Keys:

        "purposePatterns"  ARRAY of [purposeTag, patternDef]
                           Baseline ambient population + props for a place
                           whose purpose is purposeTag.
        "locationPurposes" ARRAY of [locationId, purposeTag]
                           Maps every ARC_worldNamedLocations id to a purpose
                           tag (or NO_BASELINE_POP).
        "siteTypePurposes" ARRAY of [terrainSiteType, purposeTag]
                           Maps every exported terrain site type to a purpose.
        "incidentOverlays" ARRAY of [incidentType, overlayDef]
                           Task-specific overlay layered on top of the baseline
                           when an Incident of this type starts.
        "leadOverlays"     ARRAY of [leadTag, overlayDef]
                           Lead-tag-driven overlay (drives spawns from lead
                           fields rather than display-name string checks).
        "civicMissionOverlays" ARRAY of [subtype, overlayDef]
                           Structured-civic-mission overlay keyed by the
                           `subtype` field in data/coin_civic_mission_catalog.sqf
                           (purpose-specific aid/governance/repair context that
                           the bare incidentType overlay cannot express).

    purposeTag values (issue #633 step 5 building-purpose classification):
        RESIDENTIAL MARKET RELIGIOUS MEDICAL GOVERNMENT HOTEL SECURITY INDUSTRIAL
        OIL_GAS POWER PORT MINE CONSTRUCTION AGRICULTURAL MILITARY PRISON
        RURAL_HAMLET CHECKPOINT MSR_ROAD
        plus the sentinel NO_BASELINE_POP for places that intentionally get no
        baseline ambient population.

    patternDef format (pairs array):
        ["purpose",       STRING]                        - echoes the purpose tag
        ["placement",     STRING]                        - default placement strategy:
                            indoor | roadside | courtyard | gate_lane | perimeter |
                            rooftop | route_segment | district_centroid | open
        ["baselinePop",   ARRAY of roleSpec]             - ambient AI roles
        ["objects",       ARRAY of objectSpec]           - ambient props/vehicles
        ["cleanupOwner",  STRING]                         - SITEPOP | INCIDENT | LEAD | EDITOR | NONE
        ["despawnPolicy", STRING]                         - SITE_GRACE | INCIDENT_DESPAWN | LEAD_DESPAWN | PERSISTENT

    overlayDef format (pairs array):
        ["overlay",       ARRAY of roleSpec]             - task-added AI roles
        ["objects",       ARRAY of objectSpec]           - task-added props/vehicles
        ["placement",     STRING]                         - placement strategy override
        ["cleanupOwner",  STRING]
        ["despawnPolicy", STRING]

    roleSpec format:
        [roleTag STRING, sideStr STRING, [minCount, maxCount], behavior STRING, placement STRING]
        sideStr:   "west" | "east" | "indep" | "civ"
        behavior:  garrison | camp | wander | queue | parked | traffic_through |
                   route_drive | flee | loiter | inspect | guard | search |
                   detain | medical | construction

    objectSpec format:
        [objTag STRING, [minCount, maxCount], placement STRING]

    Class pools are intentionally NOT declared here. Role tags are symbolic; the
    overlay-spawning phase resolves concrete CfgVehicles classes from the SitePop
    pools / faction enumeration (data/farabad_site_templates.sqf), which already
    filter invalid classes against the live mod preset. This keeps the matrix
    free of class-pool drift and missing-class RPT spam.
*/

[
    // =====================================================================
    // Purpose patterns — baseline ambient population per place-purpose.
    // =====================================================================
    ["purposePatterns", [

        ["RESIDENTIAL", [
            ["purpose", "RESIDENTIAL"],
            ["placement", "roadside"],
            ["baselinePop", [
                ["resident",   "civ", [4, 8], "wander",          "indoor"],
                ["pedestrian", "civ", [2, 5], "traffic_through", "roadside"]
            ]],
            ["objects", [
                ["civ_car", [2, 4], "parked"]
            ]],
            ["cleanupOwner", "SITEPOP"],
            ["despawnPolicy", "SITE_GRACE"]
        ]],

        ["MARKET", [
            ["purpose", "MARKET"],
            ["placement", "courtyard"],
            ["baselinePop", [
                ["vendor",     "civ", [4, 8],  "camp",           "courtyard"],
                ["shopper",    "civ", [6, 12], "wander",         "courtyard"],
                ["tnp_patrol", "west",[0, 3],  "wander",         "perimeter"]
            ]],
            ["objects", [
                ["market_stall", [3, 6], "courtyard"],
                ["civ_car",      [2, 5], "parked"]
            ]],
            ["cleanupOwner", "SITEPOP"],
            ["despawnPolicy", "SITE_GRACE"]
        ]],

        ["RELIGIOUS", [
            ["purpose", "RELIGIOUS"],
            ["placement", "courtyard"],
            ["baselinePop", [
                ["elder",      "civ", [1, 1], "loiter",   "courtyard"],
                ["worshipper", "civ", [5, 10],"wander",   "courtyard"],
                ["vendor",     "civ", [1, 3], "camp",     "perimeter"],
                ["tnp_outer",  "west",[0, 4], "guard",    "perimeter"]
            ]],
            ["objects", [
                ["civ_car", [1, 3], "parked"]
            ]],
            ["cleanupOwner", "SITEPOP"],
            ["despawnPolicy", "SITE_GRACE"]
        ]],

        ["MEDICAL", [
            ["purpose", "MEDICAL"],
            ["placement", "courtyard"],
            ["baselinePop", [
                ["civ_doctor", "civ", [2, 4], "medical", "indoor"],
                ["patient",    "civ", [3, 6], "wander",  "courtyard"],
                ["tnp_outer",  "west",[0, 4], "guard",   "perimeter"]
            ]],
            ["objects", [
                ["ambulance", [1, 2], "parked"]
            ]],
            ["cleanupOwner", "SITEPOP"],
            ["despawnPolicy", "SITE_GRACE"]
        ]],

        ["GOVERNMENT", [
            ["purpose", "GOVERNMENT"],
            ["placement", "gate_lane"],
            ["baselinePop", [
                ["gov_staff", "civ", [3, 6], "camp",     "indoor"],
                ["guard",     "west",[4, 8], "garrison", "gate_lane"]
            ]],
            ["objects", [
                ["official_car", [1, 3], "parked"]
            ]],
            ["cleanupOwner", "SITEPOP"],
            ["despawnPolicy", "SITE_GRACE"]
        ]],

        ["HOTEL", [
            ["purpose", "HOTEL"],
            ["placement", "courtyard"],
            ["baselinePop", [
                ["hotel_staff", "civ", [2, 4], "camp",   "indoor"],
                ["guest",       "civ", [3, 6], "wander", "courtyard"],
                ["security",    "west",[2, 4], "guard",  "gate_lane"]
            ]],
            ["objects", [
                ["civ_car", [2, 5], "parked"]
            ]],
            ["cleanupOwner", "SITEPOP"],
            ["despawnPolicy", "SITE_GRACE"]
        ]],

        ["SECURITY", [
            ["purpose", "SECURITY"],
            ["placement", "perimeter"],
            ["baselinePop", [
                ["guard", "west", [4, 8], "garrison", "perimeter"]
            ]],
            ["objects", []],
            ["cleanupOwner", "SITEPOP"],
            ["despawnPolicy", "SITE_GRACE"]
        ]],

        ["INDUSTRIAL", [
            ["purpose", "INDUSTRIAL"],
            ["placement", "perimeter"],
            ["baselinePop", [
                ["worker",     "civ", [4, 8], "construction", "courtyard"],
                ["contractor", "civ", [1, 3], "wander",       "perimeter"],
                ["security",   "west",[0, 3], "guard",        "perimeter"]
            ]],
            ["objects", [
                ["utility_truck", [1, 3], "parked"],
                ["work_clutter",  [2, 5], "courtyard"]
            ]],
            ["cleanupOwner", "SITEPOP"],
            ["despawnPolicy", "SITE_GRACE"]
        ]],

        ["OIL_GAS", [
            ["purpose", "OIL_GAS"],
            ["placement", "perimeter"],
            ["baselinePop", [
                ["worker",   "civ", [3, 6], "construction", "courtyard"],
                ["security", "west",[2, 4], "guard",        "perimeter"]
            ]],
            ["objects", [
                ["fuel_truck",      [1, 3], "parked"],
                ["hazard_clutter",  [2, 4], "courtyard"]
            ]],
            ["cleanupOwner", "SITEPOP"],
            ["despawnPolicy", "SITE_GRACE"]
        ]],

        ["POWER", [
            ["purpose", "POWER"],
            ["placement", "perimeter"],
            ["baselinePop", [
                ["technician", "civ", [2, 4], "construction", "courtyard"],
                ["security",   "west",[0, 3], "guard",        "perimeter"]
            ]],
            ["objects", [
                ["utility_truck", [1, 2], "parked"],
                ["repair_crate",  [1, 3], "courtyard"]
            ]],
            ["cleanupOwner", "SITEPOP"],
            ["despawnPolicy", "SITE_GRACE"]
        ]],

        ["PORT", [
            ["purpose", "PORT"],
            ["placement", "perimeter"],
            ["baselinePop", [
                ["stevedore",   "civ", [4, 8], "construction", "courtyard"],
                ["port_security","west",[2, 4],"guard",        "gate_lane"],
                ["customs",     "west",[1, 3], "inspect",      "gate_lane"]
            ]],
            ["objects", [
                ["cargo_truck",  [1, 3], "parked"],
                ["cargo_clutter",[3, 6], "courtyard"]
            ]],
            ["cleanupOwner", "SITEPOP"],
            ["despawnPolicy", "SITE_GRACE"]
        ]],

        ["MINE", [
            ["purpose", "MINE"],
            ["placement", "perimeter"],
            ["baselinePop", [
                ["worker",     "civ", [3, 6], "construction", "courtyard"],
                ["contractor", "west",[1, 3], "guard",        "perimeter"]
            ]],
            ["objects", [
                ["utility_truck", [1, 2], "parked"],
                ["ore_clutter",   [2, 4], "courtyard"]
            ]],
            ["cleanupOwner", "SITEPOP"],
            ["despawnPolicy", "SITE_GRACE"]
        ]],

        ["CONSTRUCTION", [
            ["purpose", "CONSTRUCTION"],
            ["placement", "courtyard"],
            ["baselinePop", [
                ["worker",   "civ", [3, 6], "construction", "courtyard"],
                ["security", "west",[0, 2], "guard",        "perimeter"]
            ]],
            ["objects", [
                ["utility_truck", [1, 2], "parked"],
                ["barrier",       [2, 5], "perimeter"],
                ["cone",          [3, 8], "perimeter"],
                ["pallet",        [2, 5], "courtyard"],
                ["generator",     [1, 2], "courtyard"],
                ["repair_crate",  [1, 3], "courtyard"]
            ]],
            ["cleanupOwner", "SITEPOP"],
            ["despawnPolicy", "SITE_GRACE"]
        ]],

        ["AGRICULTURAL", [
            ["purpose", "AGRICULTURAL"],
            ["placement", "open"],
            ["baselinePop", [
                ["farmer", "civ", [2, 4], "wander", "open"]
            ]],
            ["objects", [
                ["pickup",       [1, 2], "parked"],
                ["livestock",    [0, 6], "wander"],
                ["water_object", [1, 2], "open"]
            ]],
            ["cleanupOwner", "SITEPOP"],
            ["despawnPolicy", "SITE_GRACE"]
        ]],

        ["MILITARY", [
            ["purpose", "MILITARY"],
            ["placement", "perimeter"],
            ["baselinePop", [
                ["tna_staff", "west", [4, 8], "garrison", "perimeter"],
                ["patrol",    "west", [2, 4], "wander",   "perimeter"]
            ]],
            ["objects", [
                ["mil_vehicle",   [1, 3], "parked"],
                ["supply_clutter",[2, 4], "courtyard"]
            ]],
            ["cleanupOwner", "SITEPOP"],
            ["despawnPolicy", "SITE_GRACE"]
        ]],

        ["PRISON", [
            ["purpose", "PRISON"],
            ["placement", "perimeter"],
            ["baselinePop", [
                ["guard",    "west", [6, 10], "garrison", "perimeter"],
                ["prisoner", "civ",  [4, 8],  "wander",   "courtyard"]
            ]],
            ["objects", []],
            ["cleanupOwner", "SITEPOP"],
            ["despawnPolicy", "SITE_GRACE"]
        ]],

        ["RURAL_HAMLET", [
            ["purpose", "RURAL_HAMLET"],
            ["placement", "roadside"],
            ["baselinePop", [
                ["villager", "civ", [2, 5], "wander", "indoor"],
                ["farmer",   "civ", [1, 3], "wander", "open"]
            ]],
            ["objects", [
                ["pickup",    [1, 2], "parked"],
                ["livestock", [0, 4], "wander"]
            ]],
            ["cleanupOwner", "SITEPOP"],
            ["despawnPolicy", "SITE_GRACE"]
        ]],

        ["CHECKPOINT", [
            ["purpose", "CHECKPOINT"],
            ["placement", "gate_lane"],
            ["baselinePop", [
                ["gate_guard", "west", [3, 6], "guard",          "gate_lane"],
                ["pedestrian", "civ",  [2, 5], "queue",          "gate_lane"]
            ]],
            ["objects", [
                ["civ_car", [2, 4], "traffic_through"],
                ["barrier", [2, 4], "gate_lane"]
            ]],
            ["cleanupOwner", "SITEPOP"],
            ["despawnPolicy", "SITE_GRACE"]
        ]],

        ["MSR_ROAD", [
            ["purpose", "MSR_ROAD"],
            ["placement", "route_segment"],
            ["baselinePop", [
                ["roadside_civ", "civ", [1, 3], "loiter",         "roadside"]
            ]],
            ["objects", [
                ["civ_truck", [1, 3], "traffic_through"],
                ["pickup",    [1, 2], "parked"]
            ]],
            ["cleanupOwner", "SITEPOP"],
            ["despawnPolicy", "SITE_GRACE"]
        ]],

        // Sentinel: no baseline ambient population by design.
        ["NO_BASELINE_POP", [
            ["purpose", "NO_BASELINE_POP"],
            ["placement", "open"],
            ["baselinePop", []],
            ["objects", []],
            ["cleanupOwner", "NONE"],
            ["despawnPolicy", "PERSISTENT"]
        ]]
    ]],

    // =====================================================================
    // Named-location -> purpose tag.
    // Every id in data/farabad_world_locations.sqf must appear here (or be
    // explicitly mapped to NO_BASELINE_POP). The audit fails on any gap.
    // =====================================================================
    ["locationPurposes", [
        ["IndependencePark",   "MARKET"],
        ["PresidentialPalace", "GOVERNMENT"],
        ["GrandMosque",        "RELIGIOUS"],
        ["GreenZone",          "GOVERNMENT"],
        ["ParadeGround",       "MILITARY"],
        ["VictoryMonument",    "MARKET"],
        ["CityCenter",         "MARKET"],
        ["BelleFoilleHotel",   "HOTEL"],
        ["EmbassyCompound",    "GOVERNMENT"],
        ["Farabad",            "MARKET"],
        ["CentralPark",        "MARKET"],
        ["hospital",           "MEDICAL"],
        ["Sharif1",            "NO_BASELINE_POP"],
        ["AwenaResevoir",      "POWER"],
        ["Kulij",              "NO_BASELINE_POP"],
        ["industrial022",      "INDUSTRIAL"],
        ["AirportInterchange", "MSR_ROAD"],
        ["Sharif2",            "NO_BASELINE_POP"],
        ["JaziraOilRefinery",  "OIL_GAS"],
        ["FortKelati",         "MILITARY"],
        ["military",           "MILITARY"],
        ["Naseri",             "RURAL_HAMLET"],
        ["AliKala",            "RURAL_HAMLET"],
        ["Hamza",              "RURAL_HAMLET"],
        ["LashgarKuh",         "RURAL_HAMLET"],
        ["AlmawtPass",         "MSR_ROAD"],
        ["JaziraOilField",     "OIL_GAS"],
        ["Shahruk",            "RURAL_HAMLET"],
        ["CampBulwark",        "MILITARY"],
        ["Kahak",              "NO_BASELINE_POP"],
        ["SolarFarm",          "POWER"],
        ["Shirazan",           "RURAL_HAMLET"],
        ["KarkanakPrison",     "PRISON"],
        ["Pashtat",            "RURAL_HAMLET"],
        ["Sharif3",            "NO_BASELINE_POP"],
        ["Junkyard",           "INDUSTRIAL"],
        ["PortFarabad",        "PORT"],
        ["Kandah",             "RURAL_HAMLET"],
        ["Karkanak",           "RURAL_HAMLET"],
        ["AlNazara",           "RURAL_HAMLET"],
        ["KaftarKar",          "RURAL_HAMLET"]
    ]],

    // =====================================================================
    // Terrain site type -> purpose tag.
    // Every site type exported in data/farabad_world_locations.sqf must map to
    // a purpose tag that has a default pattern in purposePatterns above.
    // =====================================================================
    ["siteTypePurposes", [
        ["FUELSTATION", "OIL_GAS"],
        ["POWERSOLAR",  "POWER"],
        ["POWERWAVE",   "POWER"],
        ["POWERWIND",   "POWER"],
        ["TRANSMITTER", "POWER"],
        ["SHIPWRECK",   "PORT"],
        ["HOSPITAL",    "MEDICAL"]
    ]],

    // =====================================================================
    // Incident-type -> task overlay. Layered on top of the location baseline.
    // Covers every incidentType in data/incident_markers.sqf.
    // =====================================================================
    ["incidentOverlays", [
        ["PATROL", [
            ["overlay", []],
            ["objects", []],
            ["placement", "perimeter"],
            ["cleanupOwner", "INCIDENT"],
            ["despawnPolicy", "INCIDENT_DESPAWN"]
        ]],
        ["DEFEND", [
            ["overlay", [
                ["hostile", "east", [3, 6], "search", "perimeter"]
            ]],
            ["objects", []],
            ["placement", "perimeter"],
            ["cleanupOwner", "INCIDENT"],
            ["despawnPolicy", "INCIDENT_DESPAWN"]
        ]],
        ["QRF", [
            ["overlay", [
                ["hostile", "east", [4, 8], "search", "perimeter"]
            ]],
            ["objects", []],
            ["placement", "perimeter"],
            ["cleanupOwner", "INCIDENT"],
            ["despawnPolicy", "INCIDENT_DESPAWN"]
        ]],
        ["RAID", [
            ["overlay", [
                ["hostile", "east", [3, 6], "garrison", "indoor"],
                ["hvt",     "east", [0, 1], "garrison", "indoor"]
            ]],
            ["objects", [
                ["cache", [1, 2], "indoor"]
            ]],
            ["placement", "indoor"],
            ["cleanupOwner", "INCIDENT"],
            ["despawnPolicy", "INCIDENT_DESPAWN"]
        ]],
        ["IED", [
            ["overlay", [
                ["observer", "east", [0, 2], "loiter", "roadside"]
            ]],
            ["objects", [
                ["ied_object", [1, 1], "roadside"]
            ]],
            ["placement", "roadside"],
            ["cleanupOwner", "INCIDENT"],
            ["despawnPolicy", "INCIDENT_DESPAWN"]
        ]],
        ["CIVIL", [
            ["overlay", [
                ["crowd", "civ", [4, 10], "loiter", "courtyard"]
            ]],
            ["objects", [
                ["aid_table", [1, 3], "courtyard"]
            ]],
            ["placement", "courtyard"],
            ["cleanupOwner", "INCIDENT"],
            ["despawnPolicy", "INCIDENT_DESPAWN"]
        ]],
        ["LOGISTICS", [
            ["overlay", []],
            ["objects", [
                ["supply_crate", [2, 4], "roadside"],
                ["cargo_truck",  [1, 2], "parked"]
            ]],
            ["placement", "roadside"],
            ["cleanupOwner", "INCIDENT"],
            ["despawnPolicy", "INCIDENT_DESPAWN"]
        ]],
        ["RECON", [
            ["overlay", [
                ["observer", "east", [0, 2], "loiter", "perimeter"]
            ]],
            ["objects", []],
            ["placement", "route_segment"],
            ["cleanupOwner", "INCIDENT"],
            ["despawnPolicy", "INCIDENT_DESPAWN"]
        ]],
        ["CHECKPOINT", [
            ["overlay", [
                ["gate_guard", "west", [2, 4], "guard",          "gate_lane"],
                ["voi_vehicle","civ", [0, 1], "inspect",         "gate_lane"]
            ]],
            ["objects", [
                ["civ_car", [2, 5], "traffic_through"]
            ]],
            ["placement", "gate_lane"],
            ["cleanupOwner", "INCIDENT"],
            ["despawnPolicy", "INCIDENT_DESPAWN"]
        ]],
        ["ESCORT", [
            ["overlay", [
                ["escortee", "civ", [1, 2], "route_drive", "route_segment"]
            ]],
            ["objects", [
                ["voi_vehicle", [1, 2], "route_drive"]
            ]],
            ["placement", "route_segment"],
            ["cleanupOwner", "INCIDENT"],
            ["despawnPolicy", "INCIDENT_DESPAWN"]
        ]],
        ["KLE", [
            ["overlay", [
                ["elder",      "civ", [1, 1], "loiter", "courtyard"],
                ["local_sec",  "civ", [1, 3], "guard",  "courtyard"]
            ]],
            ["objects", []],
            ["placement", "courtyard"],
            ["cleanupOwner", "INCIDENT"],
            ["despawnPolicy", "INCIDENT_DESPAWN"]
        ]],
        ["ROUTE_CLEARANCE", [
            ["overlay", [
                ["observer", "east", [0, 1], "loiter", "roadside"]
            ]],
            ["objects", [
                ["ied_object", [0, 2], "roadside"]
            ]],
            ["placement", "route_segment"],
            ["cleanupOwner", "INCIDENT"],
            ["despawnPolicy", "INCIDENT_DESPAWN"]
        ]]
    ]],

    // =====================================================================
    // Lead-tag -> task overlay. Driven by lead fields (type/pos/tag/meta),
    // NOT by display-name string checks (issue #633 step 7).
    // =====================================================================
    ["leadOverlays", [
        ["SUS_VEHICLE", [
            ["overlay", [
                ["voi_driver", "civ", [1, 2], "inspect", "roadside"]
            ]],
            ["objects", [
                ["voi_vehicle", [1, 1], "parked"],
                ["civ_car",     [1, 3], "traffic_through"]
            ]],
            ["placement", "roadside"],
            ["cleanupOwner", "LEAD"],
            ["despawnPolicy", "LEAD_DESPAWN"]
        ]],
        ["VBIED_DRIVEN_CHECKPOINT", [
            ["overlay", [
                ["gate_guard", "west", [2, 4], "guard",       "gate_lane"]
            ]],
            ["objects", [
                ["vbied_vehicle", [1, 1], "route_drive"],
                ["civ_car",       [2, 4], "traffic_through"]
            ]],
            ["placement", "gate_lane"],
            ["cleanupOwner", "LEAD"],
            ["despawnPolicy", "LEAD_DESPAWN"]
        ]],
        ["VBIED_DRIVEN_GATE", [
            ["overlay", [
                ["gate_guard", "west", [2, 4], "guard",       "gate_lane"]
            ]],
            ["objects", [
                ["vbied_vehicle", [1, 1], "route_drive"],
                ["civ_car",       [2, 4], "traffic_through"]
            ]],
            ["placement", "gate_lane"],
            ["cleanupOwner", "LEAD"],
            ["despawnPolicy", "LEAD_DESPAWN"]
        ]],
        ["SB_MARKET_APPROACH", [
            ["overlay", [
                ["suicide_bomber", "east", [1, 1], "search", "courtyard"],
                ["crowd",          "civ",  [6, 12],"loiter", "courtyard"]
            ]],
            ["objects", []],
            ["placement", "courtyard"],
            ["cleanupOwner", "LEAD"],
            ["despawnPolicy", "LEAD_DESPAWN"]
        ]],
        ["CASEVAC", [
            ["overlay", [
                ["casualty", "west", [1, 1], "medical", "open"],
                ["security", "west", [1, 3], "guard",   "perimeter"]
            ]],
            ["objects", [
                ["ambulance", [0, 1], "parked"]
            ]],
            ["placement", "open"],
            ["cleanupOwner", "LEAD"],
            ["despawnPolicy", "LEAD_DESPAWN"]
        ]]
    ]],

    // =====================================================================
    // Structured civic-mission subtype -> task overlay (issue #633 step 3).
    // Keyed by the `subtype` field of data/coin_civic_mission_catalog.sqf so
    // each civic mission gets purpose-specific context (aid tables, doctors,
    // work crews, gate flow) that the bare incidentType overlay cannot express.
    // Layered on top of the location baseline, same as incidentOverlays.
    // =====================================================================
    ["civicMissionOverlays", [
        ["FOOD_WATER_DISTRIBUTION", [
            ["overlay", [
                ["aid_worker",  "west", [2, 4],  "queue",  "courtyard"],
                ["elder",       "civ",  [1, 1],  "loiter", "courtyard"],
                ["crowd",       "civ",  [6, 12], "queue",  "courtyard"],
                ["local_sec",   "west", [0, 3],  "guard",  "perimeter"]
            ]],
            ["objects", [
                ["aid_table",      [2, 4], "courtyard"],
                ["water_container",[2, 4], "courtyard"],
                ["cargo_truck",    [1, 1], "parked"]
            ]],
            ["placement", "courtyard"],
            ["cleanupOwner", "INCIDENT"],
            ["despawnPolicy", "INCIDENT_DESPAWN"]
        ]],
        ["MEDICAL_OUTREACH", [
            ["overlay", [
                ["doctor",   "west", [1, 2], "medical", "courtyard"],
                ["nurse",    "west", [1, 3], "medical", "courtyard"],
                ["patient",  "civ",  [4, 8], "queue",   "courtyard"],
                ["crowd",    "civ",  [2, 5], "loiter",  "courtyard"]
            ]],
            ["objects", [
                ["aid_crate", [1, 3], "courtyard"],
                ["ambulance", [1, 1], "parked"]
            ]],
            ["placement", "courtyard"],
            ["cleanupOwner", "INCIDENT"],
            ["despawnPolicy", "INCIDENT_DESPAWN"]
        ]],
        ["GOVERNMENT_LIAISON", [
            ["overlay", [
                ["gov_staff",  "west", [1, 3], "loiter", "indoor"],
                ["gate_guard", "west", [2, 4], "guard",  "gate_lane"]
            ]],
            ["objects", [
                ["official_car", [1, 2], "parked"]
            ]],
            ["placement", "courtyard"],
            ["cleanupOwner", "INCIDENT"],
            ["despawnPolicy", "INCIDENT_DESPAWN"]
        ]],
        ["COMMUNITY_ENGAGEMENT", [
            ["overlay", [
                ["elder",      "civ",  [1, 1], "loiter", "courtyard"],
                ["crowd",      "civ",  [4, 8], "loiter", "courtyard"],
                ["vendor",     "civ",  [1, 3], "camp",   "perimeter"],
                ["local_sec",  "west", [0, 2], "guard",  "perimeter"]
            ]],
            ["objects", []],
            ["placement", "courtyard"],
            ["cleanupOwner", "INCIDENT"],
            ["despawnPolicy", "INCIDENT_DESPAWN"]
        ]],
        ["WATER_POWER_REPAIR", [
            ["overlay", [
                ["worker", "civ", [2, 4], "construction", "courtyard"]
            ]],
            ["objects", [
                ["utility_truck", [1, 2], "parked"],
                ["generator",     [1, 2], "courtyard"],
                ["repair_crate",  [1, 3], "courtyard"]
            ]],
            ["placement", "courtyard"],
            ["cleanupOwner", "INCIDENT"],
            ["despawnPolicy", "INCIDENT_DESPAWN"]
        ]],
        ["FUEL_SITE_REPAIR", [
            ["overlay", [
                ["mechanic", "civ", [2, 4], "construction", "courtyard"],
                ["work_crew","civ", [1, 3], "construction", "courtyard"]
            ]],
            ["objects", [
                ["fuel_truck", [1, 2], "parked"],
                ["civ_car",    [1, 3], "parked"]
            ]],
            ["placement", "courtyard"],
            ["cleanupOwner", "INCIDENT"],
            ["despawnPolicy", "INCIDENT_DESPAWN"]
        ]],
        ["GATE_CHECKPOINT_CONTROL", [
            ["overlay", [
                ["gate_guard", "west", [3, 6], "guard",   "gate_lane"],
                ["pedestrian", "civ",  [2, 5], "queue",   "gate_lane"],
                ["voi_vehicle","civ",  [0, 1], "inspect", "gate_lane"]
            ]],
            ["objects", [
                ["civ_car", [2, 5], "traffic_through"],
                ["barrier", [2, 4], "gate_lane"]
            ]],
            ["placement", "gate_lane"],
            ["cleanupOwner", "INCIDENT"],
            ["despawnPolicy", "INCIDENT_DESPAWN"]
        ]],
        ["MSR_RECON", [
            ["overlay", [
                ["roadside_civ", "civ",  [1, 3], "loiter", "roadside"],
                ["observer",     "east", [0, 1], "loiter", "perimeter"]
            ]],
            ["objects", [
                ["civ_truck", [1, 3], "traffic_through"],
                ["pickup",    [1, 2], "parked"]
            ]],
            ["placement", "route_segment"],
            ["cleanupOwner", "INCIDENT"],
            ["despawnPolicy", "INCIDENT_DESPAWN"]
        ]],
        ["LOCAL_LEADER_ENGAGEMENT", [
            ["overlay", [
                ["elder",     "civ",  [1, 1], "loiter", "courtyard"],
                ["local_sec", "civ",  [1, 3], "guard",  "courtyard"],
                ["crowd",     "civ",  [2, 6], "loiter", "courtyard"],
                ["observer",  "east", [0, 1], "loiter", "perimeter"]
            ]],
            ["objects", []],
            ["placement", "courtyard"],
            ["cleanupOwner", "INCIDENT"],
            ["despawnPolicy", "INCIDENT_DESPAWN"]
        ]]
    ]]
]

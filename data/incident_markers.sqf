/*
    Incident marker catalog (expanded from Eden markers).

    Each row: [markerName, displayName, incidentType]

    Core types: PATROL, IED, RAID, CIVIL, LOGISTICS
    Added types: DEFEND, QRF, RECON, CHECKPOINT, ESCORT
*/

[
    ["mkr_airbaseCenter", "Patrol: Airport Perimeter", "PATROL"],
    ["mkr_airbaseCenter", "Defend: Farabad International Airport", "DEFEND"],
    ["mkr_airbaseCenter", "Logistics: Airbase Resupply Drop", "LOGISTICS"],
    ["mkr_airbaseCenter", "QRF: Airport Alarm", "QRF"],
    // NOTE: Airbase checkpoint tasks use gate markers, but do NOT spawn extra props/AI there (gates already have editor-placed assets).
    ["Main_Gate", "Checkpoint: Airbase Main Gate Access Control", "CHECKPOINT"],
    ["North_Gate", "Checkpoint: Airbase North Gate Access Control", "CHECKPOINT"],
    ["South_Gate", "Checkpoint: Airbase South Gate Access Control", "CHECKPOINT"],

    ["ARC_loc_GreenZone", "Patrol: Green Zone Presence", "PATROL"],
    ["ARC_loc_GreenZone", "Defend: Green Zone Under Threat", "DEFEND"],
    ["ARC_loc_GreenZone", "Civil: Liaison in the Green Zone", "CIVIL"],
    ["ARC_loc_GreenZone", "QRF: Green Zone Quick Reaction", "QRF"],
    ["ARC_loc_GreenZone", "Checkpoint: Green Zone Gate Search", "CHECKPOINT"],

    ["ARC_loc_GrandMosque", "Civil: Community Engagement at Grand Mosque", "CIVIL"],
    ["ARC_loc_GrandMosque", "Patrol: Mosque Security Walkthrough", "PATROL"],
    ["ARC_loc_GrandMosque", "Defend: Protect Grand Mosque Gathering", "DEFEND"],
    ["ARC_loc_GrandMosque", "IED: Suspicious Package at Mosque", "IED"],

    ["ARC_loc_BelleFoilleHotel", "Civil: VIP Meeting Security at Belle Fuelle Hotel", "CIVIL"],
    ["ARC_loc_BelleFoilleHotel", "Defend: Hotel Security Incident", "DEFEND"],
    ["ARC_loc_BelleFoilleHotel", "Raid: Detain HVT at Belle Fuelle Hotel", "RAID"],
    ["ARC_loc_BelleFoilleHotel", "QRF: Hotel Distress Call", "QRF"],

    ["ARC_loc_hospital", "Civil: Medical Outreach at Hospital", "CIVIL"],
    ["ARC_loc_hospital", "Logistics: Deliver Medical Supplies", "LOGISTICS"],
    ["ARC_loc_hospital", "Defend: Secure Hospital Perimeter", "DEFEND"],
    ["ARC_loc_hospital", "QRF: Mass Casualty Response", "QRF"],

    ["ARC_loc_industrial022", "Patrol: Industrial Complex Sweep", "PATROL"],
    ["ARC_loc_industrial022", "IED: VBIED Threat at Industrial Complex", "IED"],
    ["ARC_loc_industrial022", "Raid: Clear Industrial Facility", "RAID"],
    ["ARC_loc_industrial022", "Defend: Protect Industrial Workforce", "DEFEND"],

    ["ARC_loc_KarkanakPrison", "Defend: Prison Riot / Breakout Attempt", "DEFEND"],
    ["ARC_loc_KarkanakPrison", "QRF: Reinforce Karkanak Prison", "QRF"],
    ["ARC_loc_KarkanakPrison", "Raid: Cell Extraction at Prison", "RAID"],
    ["ARC_loc_KarkanakPrison", "Patrol: Prison Outer Ring", "PATROL"],

    ["ARC_loc_SolarFarm", "Defend: Protect Solar Farm Infrastructure", "DEFEND"],
    ["ARC_loc_SolarFarm", "Patrol: Solar Farm Security Patrol", "PATROL"],
    ["ARC_loc_SolarFarm", "Raid: Saboteur Cell at Solar Farm", "RAID"],
    ["ARC_loc_SolarFarm", "Logistics: Deliver Repair Parts to Solar Farm", "LOGISTICS"],

    ["ARC_loc_PortFarabad", "Logistics: Secure Port Offload", "LOGISTICS"],
    ["ARC_loc_PortFarabad", "Escort: Convoy From Port Farabad", "ESCORT"],
    ["ARC_loc_PortFarabad", "Raid: Interdict Smuggling at Port", "RAID"],
    ["ARC_loc_PortFarabad", "IED: Port Vehicle Bomb Report", "IED"],
    ["ARC_loc_PortFarabad", "Defend: Hold Port Farabad", "DEFEND"],
    ["ARC_loc_PortFarabad", "Patrol: Waterfront Presence", "PATROL"],

    ["ARC_loc_PresidentialPalace", "Defend: Presidential Palace Threat", "DEFEND"],
    ["ARC_loc_PresidentialPalace", "QRF: Palace Security Alert", "QRF"],
    ["ARC_loc_PresidentialPalace", "Escort: Presidential Motorcade Support", "ESCORT"],
    ["ARC_loc_PresidentialPalace", "Patrol: Palace District Presence", "PATROL"],
    ["ARC_loc_PresidentialPalace", "Civil: Government Liaison at Palace", "CIVIL"],

    ["ARC_loc_EmbassyCompound", "Defend: Embassy Compound Attack", "DEFEND"],
    ["ARC_loc_EmbassyCompound", "QRF: Embassy Emergency Response", "QRF"],
    ["ARC_loc_EmbassyCompound", "Escort: Diplomatic Convoy", "ESCORT"],
    ["ARC_loc_EmbassyCompound", "Patrol: Embassy District Patrol", "PATROL"],
    ["ARC_loc_EmbassyCompound", "Civil: Embassy Liaison Meeting", "CIVIL"],

    ["ARC_loc_AwenaResevoir", "Patrol: Reservoir Security Patrol", "PATROL"],
    ["ARC_loc_AwenaResevoir", "Defend: Protect Awena Reservoir", "DEFEND"],
    ["ARC_loc_AwenaResevoir", "Recon: Survey Reservoir Approaches", "RECON"],
    ["ARC_loc_AwenaResevoir", "Raid: Disrupt Water-Sabotage Cell", "RAID"],

    ["ARC_loc_JaziraOilRefinery", "Defend: Secure Jazira Oil Refinery", "DEFEND"],
    ["ARC_loc_JaziraOilRefinery", "Patrol: Refinery Perimeter Patrol", "PATROL"],
    ["ARC_loc_JaziraOilRefinery", "Logistics: Fuel Shipment Security", "LOGISTICS"],
    ["ARC_loc_JaziraOilRefinery", "Raid: Saboteur Cell at Refinery", "RAID"],
    ["ARC_loc_JaziraOilRefinery", "IED: Refinery Vehicle Bomb Report", "IED"],

    ["ARC_loc_Junkyard", "Recon: Inspect Junkyard Activity", "RECON"],
    ["ARC_loc_Junkyard", "Raid: Raid Junkyard Chop-Shop", "RAID"],
    ["ARC_loc_Junkyard", "IED: IED Workshop Lead at Junkyard", "IED"],
    ["ARC_loc_Junkyard", "Patrol: Junkyard Area Patrol", "PATROL"],

    ["marker_14", "Defend: Protect Oil Processing Site", "DEFEND"],
    ["marker_14", "Patrol: Oil Processing Security", "PATROL"],
    ["marker_14", "Logistics: Deliver Engineering Supplies", "LOGISTICS"],
    ["marker_14", "Raid: Capture Oil Facility Saboteurs", "RAID"],
    ["marker_14", "IED: Suspicious Vehicle Near Oil Processing", "IED"],

    ["ARC_loc_JaziraOilField", "Patrol: Jazira Oil Field Presence", "PATROL"],
    ["ARC_loc_JaziraOilField", "Defend: Oil Field Under Attack", "DEFEND"],
    ["ARC_loc_JaziraOilField", "Logistics: Escort Field Equipment", "LOGISTICS"],
    ["ARC_loc_JaziraOilField", "Recon: Route Recon Through Oil Field", "RECON"],
    ["ARC_loc_JaziraOilField", "Raid: Clear Insurgent Camp Near Oil Field", "RAID"],

    ["marker_16", "Recon: Mine Recon", "RECON"],
    ["marker_16", "Patrol: Mine Security Patrol", "PATROL"],
    ["marker_16", "Raid: Disrupt Mine Extortion Cell", "RAID"],
    ["marker_16", "Logistics: Deliver Mine Supplies", "LOGISTICS"],

    ["ARC_loc_military", "Defend: Military Compound Defense", "DEFEND"],
    ["ARC_loc_military", "Logistics: Ammo / Fuel Resupply Run", "LOGISTICS"],
    ["ARC_loc_military", "QRF: Scramble From Military Compound", "QRF"],
    ["ARC_loc_military", "Patrol: Outpost Patrol", "PATROL"],

    ["marker_18", "Recon: Mine Recon (East)", "RECON"],
    ["marker_18", "Patrol: Mine Patrol (East)", "PATROL"],
    ["marker_18", "Raid: Clear Mine Ambush Site", "RAID"],
    ["marker_18", "IED: Suspected IED Near Mine Road", "IED"],

    ["marker_19", "Recon: Mine Recon (South)", "RECON"],
    ["marker_19", "Patrol: Mine Patrol (South)", "PATROL"],
    ["marker_19", "Raid: Disrupt Illegal Mining Crew", "RAID"],
    ["marker_19", "Logistics: Recover Equipment From Mine", "LOGISTICS"],

    ["marker_20", "Recon: Mine Recon (West)", "RECON"],
    ["marker_20", "Patrol: Mine Patrol (West)", "PATROL"],
    ["marker_20", "Raid: Destroy Insurgent Cache at Mine", "RAID"],
    ["marker_20", "IED: Mine Access Route IED", "IED"],

    ["marker_21", "Recon: Mine Recon (North)", "RECON"],
    ["marker_21", "Patrol: Mine Patrol (North)", "PATROL"],
    ["marker_21", "Raid: Interdict Weapons Smuggling at Mine", "RAID"],
    ["marker_21", "Logistics: Mine Security Contractor Escort", "ESCORT"],

    ["ARC_loc_FortKelati", "Recon: Fort Kelati Recon", "RECON"],
    ["ARC_loc_FortKelati", "Raid: Clear Fort Kelati Strongpoint", "RAID"],
    ["ARC_loc_FortKelati", "Defend: Hold Fort Kelati", "DEFEND"],
    ["ARC_loc_FortKelati", "Patrol: Fort Kelati Patrol", "PATROL"],

    ["ARC_m_base_toc", "Defend: TOC / Base Alarm", "DEFEND"],
    ["ARC_m_base_toc", "Logistics: TOC Inventory Check", "LOGISTICS"],

    ["ARC_m_patrol_01", "Patrol: Hamza Route", "PATROL"],
    ["ARC_m_patrol_01", "Checkpoint: Hamza Route Control", "CHECKPOINT"],

    ["ARC_m_patrol_02", "Patrol: Farabad District", "PATROL"],
    ["ARC_m_patrol_02", "Recon: Farabad District Route Recon", "RECON"],

    ["ARC_m_patrol_03", "Patrol: Farabad District South", "PATROL"],
    ["ARC_m_patrol_03", "Checkpoint: District Interdiction Point", "CHECKPOINT"],

    ["ARC_m_ied_01", "IED: MSR IED Report", "IED"],
    ["ARC_m_ied_01", "IED: EOD — Clear and Reopen Route", "IED"],

    ["ARC_m_civil_01", "Civil: Crowd Control / Mediation", "CIVIL"],

    ["ARC_m_logistics_01", "Logistics: Convoy Escort", "LOGISTICS"],
    ["ARC_m_logistics_01", "Escort: Convoy Protection", "ESCORT"],

    // ── Key Leader Engagement (KLE) task type ─────────────────────────────
    // KLE tasks are non-kinetic: a player element conducts a structured
    // meeting with a district elder to build legitimacy and gather HUMINT.
    // Outcome drives WHITE/GREEN influence delta and may emit a HUMINT lead.
    ["ARC_loc_GrandMosque",   "KLE: Elder Engagement — Grand Mosque District",    "KLE"],
    ["ARC_loc_GreenZone",     "KLE: Elder Engagement — Green Zone Council",       "KLE"],
    ["ARC_loc_MarketDistrict","KLE: Elder Engagement — Market District Shura",    "KLE"],
    ["ARC_loc_ResidentialNorth","KLE: Elder Engagement — North Residential Leaders","KLE"],
    ["ARC_loc_FarmlandEast",  "KLE: Elder Engagement — Farmland Cooperative",     "KLE"],

    // ── Route Clearance task type ─────────────────────────────────────────
    // Route clearance tasks reduce IED placement probability on the cleared
    // MSR segment for a configurable number of hours. EOD-led, results in
    // an intel lead if evidence is found.
    ["ARC_m_patrol_01", "Route Clearance: MSR Hamza Sweep",          "ROUTE_CLEARANCE"],
    ["ARC_m_patrol_02", "Route Clearance: Farabad District Arterial", "ROUTE_CLEARANCE"],
    ["ARC_m_patrol_03", "Route Clearance: South Route Sweep",         "ROUTE_CLEARANCE"],
    ["ARC_m_ied_01",    "Route Clearance: EOD Clearance — MSR IED",   "ROUTE_CLEARANCE"]
]

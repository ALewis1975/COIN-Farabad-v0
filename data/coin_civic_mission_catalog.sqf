/*
    Structured COIN civic mission catalog.

    Each record is a pairs array consumed by ARC_fnc_incidentCatalogBuild.
    The builder expands physical placement references into normal incident rows:
      [markerName, displayName, incidentType, missionMeta]

    Keep incidentType at the existing execution layer unless unique behavior is
    required. Use subtype/missionSet metadata for CIVSUB/threat tuning.
*/

[
    [
        ["id", "CIV_HUM_FOOD_WATER_D01"],
        ["missionSet", "HUMANITARIAN"],
        ["subtype", "FOOD_WATER_DISTRIBUTION"],
        ["incidentType", "CIVIL"],
        ["displayName", "Civil: Food and Water Distribution"],
        ["locations", ["ARC_loc_Farabad", "ARC_loc_CityCenter", "ARC_loc_GrandMosque"]],
        ["siteTypes", []],
        ["districts", ["D01", "D07"]],
        ["civsubFactors", [["food_idx", "LOW"], ["water_idx", "LOW"], ["aid_events", "COUNT"]]],
        ["endState", "INTERACT"],
        ["threatHooks", ["AID_HIGH_RISK", "CROWD_SECURITY"]],
        ["outcomeDeltas", [["W", 3.0], ["R", -1.0], ["G", 1.5]]]
    ],
    [
        ["id", "CIV_HUM_MEDICAL_OUTREACH"],
        ["missionSet", "MEDICAL_HEALTH"],
        ["subtype", "MEDICAL_OUTREACH"],
        ["incidentType", "CIVIL"],
        ["displayName", "Civil: Medical Outreach"],
        ["locations", ["ARC_loc_hospital"]],
        ["siteTypes", ["HOSPITAL"]],
        ["districts", []],
        ["civsubFactors", [["aid_events", "COUNT"], ["fear_idx", "REDUCE"]]],
        ["endState", "INTERACT"],
        ["threatHooks", ["AID_HIGH_RISK"]],
        ["outcomeDeltas", [["W", 3.0], ["R", -0.5], ["G", 1.5]]]
    ],
    [
        ["id", "CIV_GOV_LIAISON"],
        ["missionSet", "GOVERNANCE"],
        ["subtype", "GOVERNMENT_LIAISON"],
        ["incidentType", "CIVIL"],
        ["displayName", "Civil: Government Liaison"],
        ["locations", ["ARC_loc_GreenZone", "ARC_loc_PresidentialPalace", "ARC_loc_EmbassyCompound"]],
        ["siteTypes", []],
        ["districts", []],
        ["civsubFactors", [["G_EFF_U", "LIFT"], ["R_EFF_U", "REDUCE"]]],
        ["endState", "INTERACT"],
        ["threatHooks", ["GOVERNMENT_TARGET"]],
        ["outcomeDeltas", [["W", 1.0], ["R", -1.5], ["G", 3.0]]]
    ],
    [
        ["id", "CIV_STABILITY_ENGAGEMENT"],
        ["missionSet", "STABILITY"],
        ["subtype", "COMMUNITY_ENGAGEMENT"],
        ["incidentType", "CIVIL"],
        ["displayName", "Civil: Community Engagement"],
        ["locations", ["ARC_loc_CentralPark", "ARC_loc_GrandMosque", "ARC_loc_CityCenter"]],
        ["siteTypes", []],
        ["districts", ["D01"]],
        ["civsubFactors", [["W_EFF_U", "LIFT"], ["fear_idx", "REDUCE"]]],
        ["endState", "INTERACT"],
        ["threatHooks", ["CROWD_SECURITY"]],
        ["outcomeDeltas", [["W", 2.5], ["R", -1.0], ["G", 1.5]]]
    ],
    [
        ["id", "CIV_INFRA_WATER_POWER"],
        ["missionSet", "INFRASTRUCTURE"],
        ["subtype", "WATER_POWER_REPAIR"],
        ["incidentType", "LOGISTICS"],
        ["displayName", "Logistics: Infrastructure Repair Support"],
        ["locations", ["ARC_loc_AwenaResevoir", "ARC_loc_SolarFarm"]],
        ["siteTypes", ["POWERSOLAR", "TRANSMITTER"]],
        ["districts", []],
        ["civsubFactors", [["water_idx", "LIFT"], ["G_EFF_U", "LIFT"]]],
        ["endState", "CONVOY"],
        ["threatHooks", ["INFRASTRUCTURE_SABOTAGE", "ROUTE_AMBUSH"]],
        ["outcomeDeltas", [["W", 1.5], ["G", 1.0]]]
    ],
    [
        ["id", "CIV_INFRA_FUEL_STATION"],
        ["missionSet", "INFRASTRUCTURE"],
        ["subtype", "FUEL_SITE_REPAIR"],
        ["incidentType", "LOGISTICS"],
        ["displayName", "Logistics: Fuel Site Repair Support"],
        ["locations", ["ARC_loc_JaziraOilRefinery", "ARC_loc_PortFarabad"]],
        ["siteTypes", ["FUELSTATION"]],
        ["districts", []],
        ["civsubFactors", [["G_EFF_U", "LIFT"]]],
        ["endState", "CONVOY"],
        ["threatHooks", ["INFRASTRUCTURE_SABOTAGE", "ROUTE_AMBUSH"]],
        ["outcomeDeltas", [["W", 1.0], ["G", 1.0]]]
    ],
    [
        ["id", "CIV_ROUTE_GATE_SECURITY"],
        ["missionSet", "ROUTE_SECURITY"],
        ["subtype", "GATE_CHECKPOINT_CONTROL"],
        ["incidentType", "CHECKPOINT"],
        ["displayName", "Checkpoint: Civic Access Control"],
        ["locations", ["Main_Gate", "North_Gate", "South_Gate", "ARC_m_patrol_01", "ARC_m_patrol_03"]],
        ["siteTypes", []],
        ["districts", []],
        ["civsubFactors", [["fear_idx", "REDUCE"], ["R_EFF_U", "REDUCE"]]],
        ["endState", "HOLD"],
        ["threatHooks", ["VBIED_GATE", "ROUTE_AMBUSH"]],
        ["outcomeDeltas", [["W", 1.5], ["G", 1.0]]]
    ],
    [
        ["id", "CIV_ROUTE_RECON_MSR"],
        ["missionSet", "ROUTE_SECURITY"],
        ["subtype", "MSR_RECON"],
        ["incidentType", "RECON"],
        ["displayName", "Recon: Civic MSR Route Recon"],
        ["locations", ["ARC_m_patrol_01", "ARC_m_patrol_02", "ARC_m_patrol_03"]],
        ["siteTypes", []],
        ["districts", []],
        ["civsubFactors", [["fear_idx", "REDUCE"]]],
        ["endState", "ROUTE_RECON"],
        ["threatHooks", ["IED_ROUTE", "ROUTE_AMBUSH"]],
        ["outcomeDeltas", [["W", 1.0], ["G", 0.5]]]
    ],
    [
        ["id", "CIV_COUNTER_INTIMIDATION_KLE"],
        ["missionSet", "COUNTER_INTIMIDATION"],
        ["subtype", "LOCAL_LEADER_ENGAGEMENT"],
        ["incidentType", "KLE"],
        ["displayName", "KLE: Counter-Intimidation Leader Engagement"],
        ["locations", ["ARC_loc_GrandMosque", "ARC_loc_CityCenter", "ARC_loc_Farabad"]],
        ["siteTypes", []],
        ["districts", ["D01", "D07", "D14"]],
        ["civsubFactors", [["R_EFF_U", "HIGH"], ["fear_idx", "HIGH"]]],
        ["endState", "INTERACT"],
        ["threatHooks", ["LOCAL_LEADER_THREAT"]],
        ["outcomeDeltas", [["W", 2.0], ["R", -2.0], ["G", 1.0]]]
    ]
]

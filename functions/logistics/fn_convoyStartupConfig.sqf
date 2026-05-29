/*
    Server-owned convoy startup configuration extracted from initServer.sqf.
    These keys are consumed by server convoy/runtime systems and are intentionally
    non-replicated to avoid startup broadcast noise.
*/

if (!isServer) exitWith {};

// ============================================================================
// CONVOY FEATURES (do not modify spawn logic here)
// ============================================================================

// VIP escort passengers
missionNamespace setVariable ["ARC_convoyVipPassengersEnabled", true];
missionNamespace setVariable ["ARC_convoyVipGuardCount", 4];

// Authoritative mission-level convoy pools (exact classnames by group key).
missionNamespace setVariable ["ARC_convoyPool_HQ", [
    "rhsusf_m1151_usarmy_d",
    "rhsusf_m1151_mk19crows_usarmy_d",
    "rhsusf_m1151_m2crows_usarmy_d",
    "rhsusf_m1152_sicps_usarmy_d",
    "rhsusf_m1152_usarmy_d",
    "rhsusf_m1165_usarmy_d",
    "rhsusf_m1240a1_usarmy_d",
    "rhsusf_m1240a1_mk19crows_usarmy_d",
    "rhsusf_m1240a1_m2crows_usarmy_d",
    "rhsusf_m998_d_2dr_fulltop",
    "rhsusf_m998_d_2dr_halftop",
    "rhsusf_m998_d_2dr",
    "rhsusf_m998_d_4dr_fulltop",
    "rhsusf_m998_d_4dr_halftop",
    "rhsusf_m998_d_4dr"
]];
missionNamespace setVariable ["ARC_convoyPool_MP", [
    "rhsusf_M1117_D",
    "rhsusf_m1151_usarmy_d",
    "rhsusf_m1151_mk19_v1_usarmy_d",
    "rhsusf_m1151_m2_v1_usarmy_d"
]];
missionNamespace setVariable ["ARC_convoyPool_CAV", [
    "rhsusf_m1151_mk19_v2_usarmy_d",
    "rhsusf_m1151_m2_v2_usarmy_d",
    "rhsusf_m1045_d"
]];
missionNamespace setVariable ["ARC_convoyPool_Security", [
    "rhsusf_m1151_mk19_v2_usarmy_d",
    "rhsusf_m1151_m2_v2_usarmy_d",
    "rhsusf_m1151_mk19_v1_usarmy_d",
    "rhsusf_m1151_m2_v1_usarmy_d",
    "rhsusf_m1240a1_m2_uik_usarmy_d",
    "rhsusf_m1240a1_mk19_usarmy_d",
    "rhsusf_m1240a1_m2_usarmy_d",
    "rhsusf_m966_d"
]];
missionNamespace setVariable ["ARC_convoyPool_Transport", [
    "rhsusf_M1078A1P2_B_D_fmtv_usarmy",
    "rhsusf_M1078A1P2_B_D_flatbed_fmtv_usarmy",
    "rhsusf_M1078A1P2_B_D_CP_fmtv_usarmy",
    "rhsusf_M1083A1P2_B_D_fmtv_usarmy",
    "rhsusf_M1083A1P2_B_D_flatbed_fmtv_usarmy",
    "rhsusf_M1084A1P2_B_D_fmtv_usarmy",
    "rhsusf_m977a4_usarmy_d",
    "B_Truck_01_mover_F",
    "B_Truck_01_cargo_F",
    "B_Truck_01_box_F",
    "B_Truck_01_flatbed_F",
    "B_Truck_01_transport_F",
    "B_Truck_01_covered_F"
]];
missionNamespace setVariable ["ARC_convoyPool_Medical", [
    "B_Truck_01_medical_F",
    "rhsusf_M1232_usarmy_d",
    "rhsusf_M1085A1P2_B_D_Medical_fmtv_usarmy"
]];
missionNamespace setVariable ["ARC_convoyPool_Ammo", [
    "rhsusf_m977a4_ammo_bkit_usarmy_d",
    "rhsusf_m1152_rsv_usarmy_d",
    "B_Truck_01_ammo_F"
]];
missionNamespace setVariable ["ARC_convoyPool_Repair", [
    "rhsusf_m977a4_repair_bkit_usarmy_d",
    "B_Truck_01_Repair_F"
]];
missionNamespace setVariable ["ARC_convoyPool_Fuel", [
    "rhsusf_m978a4_bkit_usarmy_d",
    "B_Truck_01_fuel_F"
]];
missionNamespace setVariable ["ARC_convoyPool_Government", [
    "UK3CB_TKC_B_SUV",
    "UK3CB_TKC_B_SUV_Armoured",
    "UK3CB_TKA_B_SUV_Armoured",
    "d3s_tundra_19_COP",
    "d3s_escalade_20_FSB",
    "d3s_escalade_16_cop"
]];
missionNamespace setVariable ["ARC_convoyPool_PrivateSecurity", [
    "EM_Police_Raptor_UM",
    "EM_Police_Explorer_UM",
    "UK3CB_TKA_B_SUV_Armed"
]];
missionNamespace setVariable ["ARC_convoyPool_PrivateContractors", [
    "d3s_scania_16_30reef",
    "d3s_scania_16_30",
    "d3s_scania_16_t75",
    "d3s_scania_16_t50",
    "d3s_scania_16_t14",
    "d3s_scania_16_t22",
    "d3s_peterbilt_579_tank",
    "d3s_peterbilt_579_dump",
    "d3s_peterbilt_579_dryvan",
    "d3s_peterbilt_579",
    "d3s_SRmh_9500",
    "d3s_SRmh_9500_fuel",
    "d3s_SRmh_9500_cov",
    "d3s_SRlonghorn_4520",
    "d3s_SRlonghorn_4520_fuel",
    "d3s_SRlonghorn_4520_cov",
    "d3s_scania_16",
    "d3s_escalade_16",
    "d3s_raptor_17_3_BIG",
    "d3s_h1_06_A",
    "d3s_h1_06",
    "d3s_h2_02",
    "d3s_h2_02_Black",
    "d3s_cherokee_18_LTD",
    "d3s_cherokee_18",
    "d3s_hiluxarctic_14",
    "d3s_200_16_EX",
    "d3s_200_VX_16",
    "d3s_200_16",
    "d3s_tundra_19",
    "d3s_tundra_19_P"
]];

// Convoy role matrix pools (explicit mission-level overrides).
// Precedence note: fn_execSpawnConvoy resolves role pools first, then _bundleOrLegacy
// substitutes ARC_convoyBundleClassMatrix when a bundle ID matches. These role lists are
// therefore fallback coverage when no bundle-specific class list is found.
missionNamespace setVariable ["ARC_convoyRoleMatrixPoolKeys", [
    ["lead", ["ARC_convoyPool_CAV", "ARC_convoyPool_Security", "ARC_convoyPool_HQ"]],
    ["escort", ["ARC_convoyPool_MP", "ARC_convoyPool_CAV", "ARC_convoyPool_Security", "ARC_convoyPool_PrivateSecurity", "ARC_convoyPool_Government", "ARC_convoyPool_PrivateContractors"]],
    ["logistics", ["ARC_convoyPool_Transport", "ARC_convoyPool_Medical", "ARC_convoyPool_Ammo", "ARC_convoyPool_Repair", "ARC_convoyPool_Fuel", "ARC_convoyPool_HQ", "ARC_convoyPool_MP", "ARC_convoyPool_Government", "ARC_convoyPool_PrivateSecurity", "ARC_convoyPool_PrivateContractors"]]
]];
// Authoritative convoy bundle matrix overrides (exact classnames by bundle ID).
// LOGI_* and ESCORT_* bundles intentionally provide narrower curated class lists that
// override broader ARC_convoyPool_* role pools whenever bundle resolution succeeds.
missionNamespace setVariable ["ARC_convoyBundleClassMatrix", [
    ["LOGI_HEADQUARTERS", [
        "rhsusf_m1085a1p2_b_d_fmtv_usarmy"
    ]],
    ["LOGI_MPS", [
        "UK3CB_TKP_B_Hilux_Open",
        "UK3CB_TKP_B_Hilux_Closed",
        "UK3CB_TKP_B_Offroad",
        "UK3CB_TKP_B_Offroad_M2"
    ]],
    ["LOGI_1_73_CAV", [
        "rhsusf_M1232_M2_usarmy_d",
        "rhsusf_M1232_MK19_usarmy_d"
    ]],
    ["LOGI_CONVOY_SECURITY", [
        "rhsusf_M1232_M2_usarmy_d",
        "rhsusf_M1232_MK19_usarmy_d"
    ]],
    ["LOGI_TRANSPORT", [
        "rhsusf_m1083a1p2_d_fmtv_usarmy",
        "rhsusf_m1083a1p2_d_open_fmtv_usarmy",
        "rhsusf_m977a4_usarmy_d"
    ]],
    ["LOGI_MEDICAL", [
        "rhsusf_m997_ambulance_usarmy_d"
    ]],
    ["LOGI_AMMO", [
        "rhsusf_m977a4_ammo_usarmy_d",
        "rhsusf_m1078a1p2_d_flatbed_fmtv_usarmy"
    ]],
    ["LOGI_REPAIR", [
        "rhsusf_m984a4_usarmy_d",
        "rhsusf_m977a4_repair_bkit_usarmy_d"
    ]],
    ["LOGI_FUEL", [
        "rhsusf_m978a4_usarmy_d",
        "rhsusf_m978a4_bkit_usarmy_d"
    ]],
    ["LOGI_GOVERNMENT", [
        "UK3CB_TKC_B_SUV",
        "UK3CB_TKC_B_SUV_Armoured"
    ]],
    ["LOGI_PRIVATE_SECURITY", [
        "UK3CB_ION_B_Desert_SUV_Armed",
        "UK3CB_ION_B_Desert_SUV_Armoured"
    ]],
    ["LOGI_CONTRACTOR_SECURITY", [
        "d3s_scania_16_30reef",
        "d3s_scania_16_30",
        "d3s_scania_16_t75",
        "d3s_scania_16_t50",
        "d3s_scania_16_t14",
        "d3s_scania_16_t22",
        "d3s_peterbilt_579_tank",
        "d3s_peterbilt_579_dump",
        "d3s_peterbilt_579_dryvan",
        "d3s_peterbilt_579",
        "d3s_SRmh_9500",
        "d3s_SRmh_9500_fuel",
        "d3s_SRmh_9500_cov",
        "d3s_SRlonghorn_4520",
        "d3s_SRlonghorn_4520_fuel",
        "d3s_SRlonghorn_4520_cov",
        "d3s_scania_16",
        "d3s_escalade_16",
        "d3s_raptor_17_3_BIG",
        "d3s_h1_06_A",
        "d3s_h1_06",
        "d3s_h2_02",
        "d3s_h2_02_Black",
        "d3s_cherokee_18_LTD",
        "d3s_cherokee_18",
        "d3s_hiluxarctic_14",
        "d3s_200_16_EX",
        "d3s_200_VX_16",
        "d3s_200_16",
        "d3s_tundra_19",
        "d3s_tundra_19_P"
    ]],
    ["ESCORT_STANDARD", [
        "rhsusf_M1232_M2_usarmy_d",
        "rhsusf_M1232_MK19_usarmy_d",
        "UK3CB_TKP_B_Hilux_Open",
        "UK3CB_TKP_B_Offroad_M2"
    ]],
    ["ESCORT_VIP", [
        "UK3CB_ION_B_Desert_SUV",
        "UK3CB_ION_B_Desert_SUV_Armed",
        "UK3CB_ION_B_Desert_SUV_Armoured"
    ]],
    ["CONVOY_GENERIC", [
        "rhsusf_M1232_M2_usarmy_d",
        "rhsusf_m1083a1p2_d_fmtv_usarmy"
    ]]
]];

// Payload-only bundles: when resolved, the bundle pool ONLY drives the cargo/payload slots.
// Lead and tail vehicles fall back to the legacy security-capable role pools so e.g. a fuel
// convoy does not place a fuel truck as its lead/security vehicle. Mission authors can
// override this list before bootstrap if a bundle should also drive lead/tail.
missionNamespace setVariable ["ARC_convoyBundlePayloadOnly", [
    "LOGI_HEADQUARTERS",
    "LOGI_TRANSPORT",
    "LOGI_MEDICAL",
    "LOGI_AMMO",
    "LOGI_REPAIR",
    "LOGI_FUEL"
]];

// Side/faction policy for allowed convoy classes (crew defaults preserve WEST join safety; vehicle side is open for contractor/government bundles).
missionNamespace setVariable ["ARC_convoyAllowedVehicleSides", []];
missionNamespace setVariable ["ARC_convoyAllowedCrewSides", [1]];
missionNamespace setVariable ["ARC_convoyAllowedVehicleFactions", []];
missionNamespace setVariable ["ARC_convoyAllowedCrewFactions", []];
missionNamespace setVariable ["ARC_convoyEnforceCrewSideWest", true];
missionNamespace setVariable ["ARC_convoyEnforceCrewSide", missionNamespace getVariable ["ARC_convoyEnforceCrewSideWest", true]]; // deprecated legacy mirror

// Bridge handling (assist + stuck recovery)
missionNamespace setVariable ["ARC_convoyBridgeAssistEnabled", true];
missionNamespace setVariable ["ARC_convoyBridgeAssistBypassSec", 14];
missionNamespace setVariable ["ARC_convoyBridgeStuckSec", 22];

// Bridge buffered zones + commit points
missionNamespace setVariable ["ARC_convoyBridgeBufferM", 22];
missionNamespace setVariable ["ARC_convoyBridgeAssistOutsideM", 18];
missionNamespace setVariable ["ARC_convoyBridgeAssistRoadSnapM", 10];

// Tail vehicle bridge assist (prevents convoy splitting)
missionNamespace setVariable ["ARC_convoyBridgeAssistFollowersEnabled", true];
missionNamespace setVariable ["ARC_convoyBridgeAssistFollowerBypassSec", 10];
missionNamespace setVariable ["ARC_convoyBridgeAssistFollowerTtlSec", 90];
missionNamespace setVariable ["ARC_convoyBridgeFollowerRecoveryCooldownSec", 28];
missionNamespace setVariable ["ARC_convoyBridgeFollowerGapTriggerMinM", 160];
missionNamespace setVariable ["ARC_convoyBridgeFollowerDoMoveReissueSec", 3.5];
missionNamespace setVariable ["ARC_convoyBridgeAssistPointRadiusM", 16];

// General follower rejoin tightening (all disruptions, not bridge-only)
missionNamespace setVariable ["ARC_convoyForceFollowEnabled", true];
missionNamespace setVariable ["ARC_convoyForceFollowReissueSec", 4];
missionNamespace setVariable ["ARC_convoyFollowerRecoveryCooldownSec", 50];
missionNamespace setVariable ["ARC_convoyFollowerGapTriggerMinM", 180];
missionNamespace setVariable ["ARC_convoyFollowerDoMoveReissueSec", 5];
missionNamespace setVariable ["ARC_convoyFollowerRejoinOrderTtlSec", 50];
missionNamespace setVariable ["ARC_convoyFollowerRejoinPointRadiusM", 26];

// Contact profile: keep convoy crews mounted and vehicles moving while turrets engage.
missionNamespace setVariable ["ARC_convoyPreventCombatDismount", true];
missionNamespace setVariable ["ARC_convoyContactNoStopEnabled", true];

// Route recon parameters
missionNamespace setVariable ["ARC_routeReconStartOffsetM", 450];
missionNamespace setVariable ["ARC_routeReconEndOffsetM", 650];
missionNamespace setVariable ["ARC_routeReconMinLengthM", 700];
missionNamespace setVariable ["ARC_routeReconRoadSnapM", 140];
missionNamespace setVariable ["ARC_routeReconStartRadiusM", 75];
missionNamespace setVariable ["ARC_routeReconEndRadiusM", 75];

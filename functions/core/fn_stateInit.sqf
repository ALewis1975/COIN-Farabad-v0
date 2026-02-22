/*
    Returns default state as "pairs" array: [[key,value], ...]
    We store as pairs for simple, safe serialization in missionProfileNamespace.

    NOTE: Keep this stable. When adding new keys, append them with safe defaults.
*/

[
    ["version", 7],

    // System control
    ["systemPauseUntil", -1],

    // Sustainment
    // Last time (serverTime) base stocks were decayed.
    ["sustainLastAt", -1],

    // Incident/task tracking
    ["taskCounter", 0],
    ["leadCounter", 0],
    ["threadCounter", 0],
    ["activeTaskId", ""],
    ["activeIncidentType", ""],
    // Zone owning the active incident (used for analysis / reporting / gating)
    ["activeIncidentZone", ""],
    ["activeIncidentMarker", ""],
    ["activeIncidentDisplayName", ""],
    ["activeIncidentCreatedAt", -1],

    // Assignment/acceptance workflow
    ["activeIncidentAccepted", false],
    ["activeIncidentAcceptedAt", -1],
    // Who accepted (audit / deconfliction)
    ["activeIncidentAcceptedBy", ""],
    ["activeIncidentAcceptedByName", ""],
    ["activeIncidentAcceptedByUID", ""],
    ["activeIncidentAcceptedByRoleTag", ""],
    ["activeIncidentAcceptedByGroup", ""],
    ["activeIncidentCivsubDistrictId", ""],
    ["activeIncidentCivsubStartRow", []],
    ["activeIncidentCivsubStartTs", -1],

    // TOC-controlled closure prompt state
    ["activeIncidentCloseReady", false],
    ["activeIncidentSuggestedResult", ""],
    ["activeIncidentCloseReason", ""],
    ["activeIncidentCloseMarkedAt", -1],

    // Some incidents (lead-driven) may not map cleanly to an Eden marker.
    // In those cases we store a direct position and keep marker empty.
    ["activeIncidentPos", []],

    // SITREP gating + capture (persistent)
    ["activeIncidentSitrepSent", false],
    ["activeIncidentSitrepSentAt", -1],
    ["activeIncidentSitrepFrom", ""],
    ["activeIncidentSitrepFromUID", ""],
    ["activeIncidentSitrepFromGroup", ""],
    ["activeIncidentSitrepFromRoleTag", ""],
    ["activeIncidentSitrepSummary", ""],
    ["activeIncidentSitrepDetails", ""],
    ["activeIncidentSitrepAnnexCivsub", ""],

    // Last unit context (used for follow-on orders and dashboards)
    ["lastTaskingGroup", ""],
    ["lastTaskingGroupAt", -1],
    ["lastSitrepFrom", ""],
    ["lastSitrepFromGroup", ""],
    ["lastSitrepAt", -1],

    // Last incident context (for change monitoring / quick TOC reference)
    ["lastIncidentPos", []],
    ["lastIncidentZone", ""],
    ["lastIncidentTaskId", ""],
    ["lastIncidentType", ""],
    ["lastIncidentMarker", ""],

    // Lead/thread context for the active incident ("" when catalog-driven)
    ["activeLeadId", ""],
    ["activeThreadId", ""],
    ["activeLeadTag", ""],
    ["incidentHistory", []],

    // Leads + threads (created lazily, but default keys help versioned merges)
    ["leadPool", []],
    ["leadHistory", []],
    ["threads", []],

    // Deferred cleanup queue (despawn spawned entities after players move on)
    ["cleanupQueue", []],

    // Intel feed (persistent)
    // Each entry: [id, serverTime, category, summary, posATL, metaPairs]
    ["intelCounter", 0],
    ["intelLog", []],

    // Metric snapshots (rolling). Each snapshot: [serverTime, pairs]
    ["metricsLastAt", -1],
    ["metricsSnapshots", []],

    // TOC request queue + follow-on orders
    ["queueCounter", 0],
    ["tocQueue", []],
    ["orderCounter", 0],
    ["tocOrders", []],

    // IEDSUB Phase 4: EOD disposition approvals
    ["eodDispoApprovals", []],

    // Incident execution (end-state) bookkeeping
    ["activeExecTaskId", ""],
    ["activeExecKind", ""],          // HOLD | ARRIVE_HOLD | INTERACT | CONVOY
    ["activeExecPos", []],
    ["activeExecRadius", 0],
    ["activeExecStartedAt", -1],
    ["activeExecDeadlineAt", -1],
    ["activeExecArrivalReq", 0],
    ["activeExecArrived", false],
    ["activeExecHoldReq", 0],
    ["activeExecHoldAccum", 0],
    ["activeExecLastProg", -1],     // HOLD progress bucket milestone (1=25%,2=50%,3=75%)
    ["activeExecLastProgressAt", -1], // serverTime of last meaningful execution progress
    ["activeObjectiveKind", ""],     // RAID_INTEL | IED_DEVICE | CIV_MEET | LOG_DROP | ESCORT_END
    ["activeObjectiveClass", ""],
    ["activeObjectivePos", []],
    ["activeObjectiveNetId", ""],

    // Convoy execution state (LOGISTICS / ESCORT)
    ["activeConvoyNetIds", []],
    ["activeConvoySupplyKind", ""],
	["activeConvoySpawning", false],
	["activeConvoySpawningSince", -1],
	["activeConvoySpawnFailCount", 0],
	["activeConvoyNextSpawnAttemptAt", -1],
	["activeConvoyStartMarker", ""],
	["activeConvoySpacingM", 65],
	["activeConvoySpeedCapKph", -1],
	["activeConvoyIngressPos", []],
	["activeConvoyDestWpPos", []],
	["activeConvoyRoutePoints", []],
	["activeConvoyDeadlineAt", -1],
	["activeConvoyStartHoldUntil", -1],
	["activeConvoyPhase", 0],
	["activeConvoyLinkupPos", []],
	["activeConvoyLinkupReached", false],
	["activeConvoyLinkupTaskId", ""],
	["activeConvoyLinkupTaskName", ""],
	["activeConvoyLinkupTaskDone", false],
    ["activeConvoySpawnPos", []],
    ["activeConvoySpawnDir", -1],
    ["activeConvoyLinkPos", []],
    ["activeConvoyLinkReached", false],
    ["activeConvoyLinkReachedAt", -1],
    ["activeConvoyStartPos", []],
    ["activeConvoyStartDir", -1],
    ["activeConvoySpeedKph", -1],
    ["activeConvoyStartedAt", -1],
    ["activeConvoyArrivedAt", -1],
    ["activeConvoyLastProg", -1],
    ["activeConvoyDetectedAt", -1],
    ["activeConvoyDepartAt", -1],
    ["activeConvoyLastMoveAt", -1],
    ["activeConvoyLastMovePos", []],
    ["activeConvoyLastRecoveryAt", -1],
    ["activeConvoyBypassUntil", -1],
    ["activeConvoyRoadEnforceAt", -1],


    // Strategic / COIN levers (0..1 scale unless noted)
    ["civCasualties", 0],
    ["civSentiment", 0.45],
    ["govLegitimacy", 0.45],
    ["insurgentPressure", 0.35],

    // Political friction / corruption / infiltration
    ["corruption", 0.55],
    ["infiltration", 0.35],

    // Base sustainment (0..1)
    // Start at a moderate baseline so logistics pressure exists without dominating the incident catalog.
    // Startup base supplies: keep above 50% but avoid uniform values to create variety.
    ["baseFuel", 0.68],
    ["baseAmmo", 0.61],
    ["baseMed", 0.57],

    // --- Added in v0.?.? (PATROL routing + SITREP proximity) ---------------
    // Client-side gating: per-task SITREP proximity (dynamic in execInitActive).
    ["activeSitrepProximityM", 350],

    // PATROL on-activation route + contact tracking (safe defaults)
    ["activePatrolRoutePosList", []],
    ["activePatrolRouteMarkerNames", []],
    ["activePatrolContactsSpawned", false],
    ["activePatrolContactsNetIds", []],

    // Local friendly support presence (host-nation forces at infrastructure sites)
    ["activeLocalSupportSpawned", false],
    ["activeLocalSupportNetIds", []],

    // Route recon (RECON tasks that use a start + end point route)
    ["activeReconRouteEnabled", false],
    ["activeReconRouteStartPos", []],
    ["activeReconRouteEndPos", []],
    ["activeReconRouteStartTaskId", ""],
    ["activeReconRouteEndTaskId", ""],
    ["activeReconRouteStartReached", false],
    ["activeReconRouteEndReached", false],
    ["activeReconRouteStartRadius", 60],
    ["activeReconRouteEndRadius", 60],
    // Route support elements (Thunder/TNP/Sheriff at intersections)
    // Spawned on acceptance and can optionally persist in AO like checkpoint compositions.
    ["activeRouteSupportSpawned", false],
    ["activeRouteSupportTaskId", ""],

    ["activeRouteSupportNetIds", []],

    // Threat v0 + IED Phase 1 (server-only persistent state)
    ["threat_v0_enabled", true],
    ["threat_v0_version", 0],
    ["threat_v0_campaign_id", ""],
    ["threat_v0_seq", 0],
    // Records are stored as an array of ThreatRecord objects (pairs arrays) for safe serialization.
    ["threat_v0_records", []],
    // Indexes are stored as arrays of threat_ids (bounded).
    ["threat_v0_open_index", []],
    ["threat_v0_closed_index", []],
    ["threat_v0_closed_max", 200],

    // IED detonation follow-on (legacy key kept for backward compatibility)
    // NOTE: This used to hold a TOC queueId. New code prefers the leadId key below.
    ["activeIedDetonationQueueId", ""],

    // Post-blast follow-on (lead queued on detonation; consumed into next task)
    ["activeIedDetonationResponseLeadId", ""],

    // IED detonation handling (prevents state deadlocks when no Killed EH fires)
    ["activeIedDetonationHandled", false],
    ["activeIedDetonationAt", -1],
    ["activeIedDetonationPos", []],

    // Minimal casualty snapshotting for detonation assessment
    ["activeIedCivSnapshotAt", -1],
    ["activeIedCivSnapshotNetIds", []],
    ["activeIedCivKia", 0],

    // Detailed detonation assessment snapshot (pairs array; server-writer)
    ["activeIedDetonationSnapshot", []],

    // IED Phase 1 (device record + trigger)
    ["activeIedDeviceId", ""],
    ["activeIedDeviceNetId", ""],
    ["activeIedDeviceState", ""],
    ["activeIedDeviceCreatedAt", -1],
    ["activeIedDeviceRecord", []],
    ["activeIedTriggerEnabled", false],
    ["activeIedTriggerRadiusM", 0],


// IED Phase 2 (evidence / scan)
["activeIedDetectedByScan", false],
["activeIedEvidenceNetId", ""],
["activeIedEvidenceCreatedAt", -1],
["activeIedEvidenceCollected", false],
["activeIedEvidenceCollectedAt", -1],
["activeIedEvidenceCollectedBy", ""],
["activeIedEvidenceLeadId", ""],

    // IED Phase 3 (VBIED v1)
    ["activeVbiedDeviceId", ""],
    ["activeVbiedVehicleNetId", ""],
    ["activeVbiedDeviceRecord", []],
    ["activeVbiedTriggerNetId", ""],
    ["activeVbiedTriggerEnabled", false],
    ["activeVbiedTriggerRadiusM", 0],
    ["activeVbiedLastArmedAt", -1],
    ["activeVbiedDetonated", false],
    ["activeVbiedDetonatedAt", -1],

    // Integrated SITREP follow-on request cache (informational only; no TOC queue approval)
    ["activeIncidentFollowOnRequest", []],
    ["activeIncidentFollowOnQueueId", ""],
    ["activeIncidentFollowOnSummary", ""],
    ["activeIncidentFollowOnDetails", ""],
    ["activeIncidentFollowOnFromGroup", ""],
    ["activeIncidentFollowOnAt", -1],

    // Closeout staging (TOC closeout -> unit must accept follow-on order to close incident)
    ["activeIncidentClosePending", false],
    ["activeIncidentClosePendingAt", -1],
    ["activeIncidentClosePendingResult", ""],
    ["activeIncidentClosePendingOrderId", ""],
    ["activeIncidentClosePendingGroup", ""],
    ["activeIncidentClosePendingLeadsGenerated", false],
    ["activeIncidentClosePendingLeadsCreated", 0],

    // TOC backlog (approved leads awaiting incident generation)
    ["tocBacklog", []],
    ["tocLeadApprovals", []],

    // Company command model (server authoritative; inspectable by TOC/S1)
    ["companyCommandNodes", []],
    ["companyCommandTasking", []],
    ["companyCommandCounter", 0],
    ["companyCommandLastTickAt", -1],
    ["companyVirtualOps", []],
    ["companyVirtualOpsCounter", 0],
    ["companyVirtualOpsLastTickAt", -1],
    ["companyVirtualOpsLastRollupAt", -1],

    // Airbase clearance request workflow (server authoritative queue + audit trail)
    ["airbase_v1_clearanceRequests", []],
    ["airbase_v1_clearanceSeq", 0],
    ["airbase_v1_clearanceHistory", []],

    // Airbase compact event stream (bounded, UI-facing tail in ARC_pub_state.airbase)
    ["airbase_v1_events", []]

]

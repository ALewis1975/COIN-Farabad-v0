/*
    ARC_fnc_consoleVmBuild

    Server-side: snapshot all mission state into a structured Console VM v1
    payload and publish it as ARC_consoleVM_payload (replicated to all clients).

    Called from ARC_fnc_publicBroadcastState once per broadcast cycle.

    Payload structure (array-of-pairs, consistent with ARC_pub_state format):
      [
        ["schema",           "ARC_ConsoleVM_v1"],
        ["version",          [1,0,0]],
        ["builtAtServerTime", serverTime],
        ["rev",              _rev],
        ["sections",         [
            ["incident",     [["data", [...]], ["freshness", [["updatedAt", t], ["staleAfterS", 120]]]]],
            ["followOn",     [["data", [...]], ["freshness", [["updatedAt", t], ["staleAfterS", 120]]]]],
            ["ops",          [["data", [...]], ["freshness", [["updatedAt", t], ["staleAfterS", 180]]]]],
            ["stateSummary", [["data", [...]], ["freshness", [["updatedAt", t], ["staleAfterS", 60]]]]],
            ["access",       [["data", [...]], ["freshness", [["updatedAt", t], ["staleAfterS", 300]]]]],
            ["civsub",       [["data", [...]], ["freshness", [["updatedAt", t], ["staleAfterS", 120]]]]]
        ]]
      ]

    Note: migrated tabs (DASH, OPS, CMD, COMMS, INTEL, HQ, BOARDS, HANDOFF) read
    this payload via ARC_fnc_consoleVmAdapterV1 with direct ARC_pub_* reads as
    fallback only. AIR and S1 are documented exceptions (rev-checked direct
    reads — see docs/architecture/Farabad_Console_Refactor_Plan.md §12.3).

    Returns: ARRAY (the payload) or [] on failure
*/

if (!isServer) exitWith {[]};

private _now = serverTime;

// Monotonic rev (reuse from publicBroadcastState rev counter)
private _rev = missionNamespace getVariable ["ARC_consoleVM_rev", 0];
if (!(_rev isEqualType 0)) then { _rev = 0; };

// ---------------------------------------------------------------------------
// Section: incident — active incident snapshot
// ---------------------------------------------------------------------------
private _taskId    = ["activeTaskId",             ""]    call ARC_fnc_stateGet;
private _accepted  = ["activeIncidentAccepted",   false] call ARC_fnc_stateGet;
private _acceptedBy = ["activeIncidentAcceptedByGroup", ""] call ARC_fnc_stateGet;
private _closeReady = ["activeIncidentCloseReady", false] call ARC_fnc_stateGet;
private _incType   = ["activeIncidentType",       ""]    call ARC_fnc_stateGet;
private _incDisp   = ["activeIncidentDisplayName",""]    call ARC_fnc_stateGet;
private _incPos    = ["activeIncidentPos",         []]   call ARC_fnc_stateGet;
private _sitSent   = ["activeIncidentSitrepSent",  false] call ARC_fnc_stateGet;

if (!(_taskId     isEqualType ""))                                          then { _taskId     = ""; };
if (!(_accepted   isEqualType true) && { !(_accepted  isEqualType false) }) then { _accepted   = false; };
if (!(_acceptedBy isEqualType ""))                                          then { _acceptedBy = ""; };
if (!(_closeReady isEqualType true) && { !(_closeReady isEqualType false) }) then { _closeReady = false; };
if (!(_incType    isEqualType ""))                                          then { _incType    = ""; };
if (!(_incDisp    isEqualType ""))                                          then { _incDisp    = ""; };
if (!(_incPos     isEqualType []))                                          then { _incPos     = []; };
if (!(_sitSent    isEqualType true) && { !(_sitSent   isEqualType false) }) then { _sitSent    = false; };

private _incidentData = [
    ["task_id",           _taskId],
    ["accepted",          _accepted],
    ["accepted_by_group", _acceptedBy],
    ["close_ready",       _closeReady],
    ["incident_type",     _incType],
    ["display_name",      _incDisp],
    ["position",          _incPos],
    ["sitrep_sent",       _sitSent]
];

private _incidentUpdatedAt = missionNamespace getVariable ["ARC_incidentLastChangedAt", _now];
if (!(_incidentUpdatedAt isEqualType 0)) then { _incidentUpdatedAt = _now; };

private _incidentSection = [
    ["data",      _incidentData],
    ["freshness", [["updatedAt", _incidentUpdatedAt], ["staleAfterS", 120]]]
];

// ---------------------------------------------------------------------------
// Section: followOn — active follow-on request + lead fields
// ---------------------------------------------------------------------------
private _foReq      = ["activeIncidentFollowOnRequest",   []] call ARC_fnc_stateGet;
private _foSumm     = ["activeIncidentFollowOnSummary",   ""] call ARC_fnc_stateGet;
private _foAt       = ["activeIncidentFollowOnAt",        -1] call ARC_fnc_stateGet;
private _foLeadName = ["activeIncidentFollowOnLeadName",  ""] call ARC_fnc_stateGet;
private _foLeadGrid = ["activeIncidentFollowOnLeadGrid",  ""] call ARC_fnc_stateGet;
private _foLeadPos  = ["activeIncidentFollowOnLeadPos",   []] call ARC_fnc_stateGet;

if (!(_foReq      isEqualType [])) then { _foReq      = []; };
if (!(_foSumm     isEqualType "")) then { _foSumm     = ""; };
if (!(_foAt       isEqualType 0))  then { _foAt       = -1; };
if (!(_foLeadName isEqualType "")) then { _foLeadName = ""; };
if (!(_foLeadGrid isEqualType "")) then { _foLeadGrid = ""; };
if (!(_foLeadPos  isEqualType [])) then { _foLeadPos  = []; };

private _followOnData = [
    ["request",   _foReq],
    ["summary",   _foSumm],
    ["updated_at",_foAt],
    ["lead_name", _foLeadName],
    ["lead_grid", _foLeadGrid],
    ["lead_pos",  _foLeadPos]
];

private _followOnSection = [
    ["data",      _followOnData],
    ["freshness", [["updatedAt", if (_foAt > 0) then {_foAt} else {_now}], ["staleAfterS", 120]]]
];

// ---------------------------------------------------------------------------
// Section: ops — OPS log tail, orders, queue, intel log, and lead pool
// (expanded to cover the full set of fields consumed by migrated tab paints)
// ---------------------------------------------------------------------------
private _pubState = missionNamespace getVariable ["ARC_pub_state", []];
private _opsLog = [];
if (_pubState isEqualType []) then
{
    private _opsIdx = -1;
    { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "opsLog" }) exitWith { _opsIdx = _forEachIndex; }; } forEach _pubState;
    if (_opsIdx >= 0) then { _opsLog = (_pubState select _opsIdx) select 1; };
    if (!(_opsLog isEqualType [])) then { _opsLog = []; };
};

private _queuePending = missionNamespace getVariable ["ARC_pub_queuePending", []];
if (!(_queuePending isEqualType [])) then { _queuePending = []; };

private _orders = missionNamespace getVariable ["ARC_pub_orders", []];
if (!(_orders isEqualType [])) then { _orders = []; };

private _intelLog = missionNamespace getVariable ["ARC_pub_intelLog", []];
if (!(_intelLog isEqualType [])) then { _intelLog = []; };

private _leadPool = missionNamespace getVariable ["ARC_leadPoolPublic", []];
if (!(_leadPool isEqualType [])) then { _leadPool = []; };

private _unitStatuses = missionNamespace getVariable ["ARC_pub_unitStatuses", []];
if (!(_unitStatuses isEqualType [])) then { _unitStatuses = []; };

private _tocBacklog = missionNamespace getVariable ["ARC_pub_tocBacklog", []];
if (!(_tocBacklog isEqualType [])) then { _tocBacklog = []; };

private _opsUpdatedAt = missionNamespace getVariable ["ARC_pub_ordersUpdatedAt", _now];
if (!(_opsUpdatedAt isEqualType 0)) then { _opsUpdatedAt = _now; };

private _opsData = [
    ["log_tail",     if ((count _opsLog) > 5) then { _opsLog select [(count _opsLog) - 5, 5] } else { _opsLog }],
    ["queue_pending", _queuePending],
    ["orders",       _orders],
    ["intel_log",    _intelLog],
    ["lead_pool",    _leadPool],
    ["unit_statuses", _unitStatuses],
    ["toc_backlog",  _tocBacklog]
];

private _opsSection = [
    ["data",      _opsData],
    ["freshness", [["updatedAt", _opsUpdatedAt], ["staleAfterS", 60]]]
];

// ---------------------------------------------------------------------------
// Section: stateSummary — sustainment + pressure indicators + mission score
// ---------------------------------------------------------------------------
private _baseFuel = ["baseFuel",           0.68] call ARC_fnc_stateGet;
private _baseAmmo = ["baseAmmo",           0.61] call ARC_fnc_stateGet;
private _baseMed  = ["baseMed",            0.57] call ARC_fnc_stateGet;
private _insPres  = ["insurgentPressure",  0.35] call ARC_fnc_stateGet;
private _infiltr  = ["infiltration",       0.35] call ARC_fnc_stateGet;
private _civCas   = ["civCasualties",      0]    call ARC_fnc_stateGet;
private _bCas     = ["baseCasualties",     0]    call ARC_fnc_stateGet;

if (!(_baseFuel isEqualType 0)) then { _baseFuel = 0.68; };
if (!(_baseAmmo isEqualType 0)) then { _baseAmmo = 0.61; };
if (!(_baseMed  isEqualType 0)) then { _baseMed  = 0.57; };
if (!(_insPres  isEqualType 0)) then { _insPres  = 0.35; };
if (!(_infiltr  isEqualType 0)) then { _infiltr  = 0.35; };
if (!(_civCas   isEqualType 0)) then { _civCas   = 0; };
if (!(_bCas     isEqualType 0)) then { _bCas     = 0; };

private _baseServices = missionNamespace getVariable ["ARC_pub_baseServices", []];
if (!(_baseServices isEqualType [])) then { _baseServices = []; };

private _missionScore = missionNamespace getVariable ["ARC_pub_missionScore", []];
if (!(_missionScore isEqualType [])) then { _missionScore = []; };

private _missionScoreAt = missionNamespace getVariable ["ARC_pub_missionScoreAt", -1];
if (!(_missionScoreAt isEqualType 0)) then { _missionScoreAt = -1; };

private _statData = [
    ["base_fuel",          _baseFuel],
    ["base_ammo",          _baseAmmo],
    ["base_med",           _baseMed],
    ["insurgent_pressure", _insPres],
    ["infiltration",       _infiltr],
    ["civ_casualties",     _civCas],
    ["base_casualties",    _bCas],
    ["base_services",      _baseServices],
    ["mission_score",      _missionScore],
    ["mission_score_at",   _missionScoreAt]
];

private _stateUpdatedAt = missionNamespace getVariable ["ARC_pub_stateUpdatedAt", -1];
if (!(_stateUpdatedAt isEqualType 0)) then { _stateUpdatedAt = -1; };

private _statSection = [
    ["data",      _statData],
    ["freshness", [["updatedAt", if (_stateUpdatedAt > 0) then { _stateUpdatedAt } else { _now }], ["staleAfterS", 60]]]
];

// ---------------------------------------------------------------------------
// Section: access — role-gating tokens for the console client
// ---------------------------------------------------------------------------
private _omniTokens = missionNamespace getVariable ["ARC_consoleOmniTokens", ["OMNI"]];
if (!(_omniTokens isEqualType [])) then { _omniTokens = ["OMNI"]; };
private _approverTokens = missionNamespace getVariable ["ARC_mobileOpsApproverTokens", []];
if (!(_approverTokens isEqualType [])) then { _approverTokens = []; };

private _accessData = [
    ["omni_tokens",     _omniTokens],
    ["approver_tokens", _approverTokens]
];

private _accessSection = [
    ["data",      _accessData],
    ["freshness", [["updatedAt", _now], ["staleAfterS", 300]]]
];

// ---------------------------------------------------------------------------
// Section: civsub — civilian subsystem summary (only when enabled)
// ---------------------------------------------------------------------------
private _civsubData = [
    ["enabled", missionNamespace getVariable ["civsub_v1_enabled", false]]
];

if (missionNamespace getVariable ["civsub_v1_enabled", false]) then
{
    private _pubCivsub = missionNamespace getVariable ["ARC_pub_civsubState", []];
    if (_pubCivsub isEqualType []) then
    {
        private _sumIdx = -1;
        { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "districtSummaries" }) exitWith { _sumIdx = _forEachIndex; }; } forEach _pubCivsub;
        if (_sumIdx >= 0) then
        {
            _civsubData pushBack ["district_summaries", (_pubCivsub select _sumIdx) select 1];
        };
    };
};

private _civsubSection = [
    ["data",      _civsubData],
    ["freshness", [["updatedAt", _now], ["staleAfterS", 120]]]
];

// ---------------------------------------------------------------------------
// Section: airbase — pass-through of ARC_pub_airbaseUiSnapshot with freshness
// ---------------------------------------------------------------------------
private _airSnapshot = missionNamespace getVariable ["ARC_pub_airbaseUiSnapshot", []];
if (!(_airSnapshot isEqualType [])) then { _airSnapshot = []; };

private _airSnapshotAt = missionNamespace getVariable ["ARC_pub_airbaseUiSnapshotUpdatedAt", -1];
if (!(_airSnapshotAt isEqualType 0)) then { _airSnapshotAt = -1; };

private _airbaseData = [
    ["snapshot", _airSnapshot]
];

private _airbaseSection = [
    ["data",      _airbaseData],
    ["freshness", [["updatedAt", if (_airSnapshotAt > 0) then {_airSnapshotAt} else {_now}], ["staleAfterS", 30]]]
];

// ---------------------------------------------------------------------------
// Section: personnel — S1 registry snapshot (published by ARC_fnc_s1RegistrySnapshot)
// ---------------------------------------------------------------------------
private _s1Snapshot = missionNamespace getVariable ["ARC_pub_s1_registry", []];
if (!(_s1Snapshot isEqualType [])) then { _s1Snapshot = []; };

private _s1SnapshotAt = missionNamespace getVariable ["ARC_pub_s1_registryUpdatedAt", -1];
if (!(_s1SnapshotAt isEqualType 0)) then { _s1SnapshotAt = -1; };

private _personnelData = [
    ["registry", _s1Snapshot]
];

private _personnelSection = [
    ["data",      _personnelData],
    ["freshness", [["updatedAt", if (_s1SnapshotAt > 0) then { _s1SnapshotAt } else { _now }], ["staleAfterS", 60]]]
];

// ---------------------------------------------------------------------------
// Section: handoff — RTB/handoff orders view (sourced from ARC_pub_orders;
// the HANDOFF tab derives its state from accepted RTB orders, there is no
// separate handoff-state publisher)
// ---------------------------------------------------------------------------
private _handoffData = [
    ["orders", _orders]
];

private _handoffSection = [
    ["data",      _handoffData],
    ["freshness", [["updatedAt", _opsUpdatedAt], ["staleAfterS", 120]]]
];

// ---------------------------------------------------------------------------
// Section: intelFeed — intelligence log with publisher freshness
// ---------------------------------------------------------------------------
private _intelLogFeed = missionNamespace getVariable ["ARC_pub_intelLog", []];
if (!(_intelLogFeed isEqualType [])) then { _intelLogFeed = []; };

private _intelFeedAt = missionNamespace getVariable ["ARC_pub_intelUpdatedAt", -1];
if (!(_intelFeedAt isEqualType 0)) then { _intelFeedAt = -1; };

private _intelFeedData = [
    ["log", _intelLogFeed]
];

private _intelFeedSection = [
    ["data",      _intelFeedData],
    ["freshness", [["updatedAt", if (_intelFeedAt > 0) then { _intelFeedAt } else { _now }], ["staleAfterS", 60]]]
];

// ---------------------------------------------------------------------------
// Section: threat — read-only threat surfacing snapshot for TOC/S2/player views
// ---------------------------------------------------------------------------
private _threatSnapshot = missionNamespace getVariable ["ARC_pub_threatUiSnapshot", []];
if (!(_threatSnapshot isEqualType [])) then { _threatSnapshot = []; };

private _threatSnapshotAt = missionNamespace getVariable ["ARC_pub_threatUiSnapshotUpdatedAt", -1];
if (!(_threatSnapshotAt isEqualType 0)) then { _threatSnapshotAt = -1; };

private _threatEconomySnapshot = missionNamespace getVariable ["ARC_pub_threatEconomySnapshot", []];
if (!(_threatEconomySnapshot isEqualType [])) then { _threatEconomySnapshot = []; };

private _threatVirtualPoolSnapshot = missionNamespace getVariable ["ARC_pub_threatVirtualPoolSnapshot", []];
if (!(_threatVirtualPoolSnapshot isEqualType [])) then { _threatVirtualPoolSnapshot = []; };

private _threatData = [
    ["snapshot", _threatSnapshot],
    ["economy", _threatEconomySnapshot],
    ["virtualPool", _threatVirtualPoolSnapshot]
];

private _threatSection = [
    ["data",      _threatData],
    ["freshness", [["updatedAt", if (_threatSnapshotAt > 0) then { _threatSnapshotAt } else { _now }], ["staleAfterS", 30]]]
];

// ---------------------------------------------------------------------------
// Section: medical — ACE/KAT/CASEVAC command snapshot (server-owned)
// ---------------------------------------------------------------------------
private _medicalSnapshot = [];
if (!isNil "ARC_fnc_medicalSnapshot") then
{
    _medicalSnapshot = [] call ARC_fnc_medicalSnapshot;
};
if (!(_medicalSnapshot isEqualType [])) then { _medicalSnapshot = []; };

private _casevacLastId = missionNamespace getVariable ["ARC_casevacLeadLastId", ""];
if (!(_casevacLastId isEqualType "")) then { _casevacLastId = ""; };

private _casevacLastAt = missionNamespace getVariable ["ARC_casevacLeadLastTs", -1];
if (!(_casevacLastAt isEqualType 0)) then { _casevacLastAt = -1; };

private _casevacCooldownS = missionNamespace getVariable ["ARC_casevacLeadCooldownS", 180];
if (!(_casevacCooldownS isEqualType 0)) then { _casevacCooldownS = 180; };
_casevacCooldownS = (_casevacCooldownS max 30) min 600;
private _casevacCooldownRemaining = 0;
if (_casevacLastAt > 0) then
{
    _casevacCooldownRemaining = (_casevacCooldownS - (_now - _casevacLastAt)) max 0;
};

private _activeCasevac = [];
{
    if (!(_x isEqualType []) || { (count _x) < 11 }) then { continue; };
    private _leadType = _x select 1;
    private _tag = _x select 10;
    if (!(_leadType isEqualType "")) then { _leadType = ""; };
    if (!(_tag isEqualType "")) then { _tag = ""; };
    if ((toUpper _leadType) isEqualTo "QRF" && { (toUpper _tag) isEqualTo "CASEVAC" }) then
    {
        _activeCasevac pushBack _x;
    };
} forEach _leadPool;

private _recentMedicalEvents = [];
{
    if (!(_x isEqualType []) || { (count _x) < 6 }) then { continue; };
    private _cat = _x select 2;
    if (!(_cat isEqualType "")) then { _cat = ""; };
    private _meta = _x select 5;
    if (!(_meta isEqualType [])) then { _meta = []; };
    private _event = "";
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "event" }) exitWith
        {
            if ((_x select 1) isEqualType "") then { _event = _x select 1; };
        };
    } forEach _meta;
    if ((toUpper _cat) isEqualTo "MED" || { (toUpper _event) isEqualTo "CASEVAC_REQUEST" }) then
    {
        _recentMedicalEvents pushBack _x;
    };
} forEach _intelLog;
if ((count _recentMedicalEvents) > 5) then
{
    _recentMedicalEvents = _recentMedicalEvents select [((count _recentMedicalEvents) - 5) max 0, 5];
};

private _medicalData = [
    ["snapshot", _medicalSnapshot],
    ["active_casevac", _activeCasevac],
    ["casevac_last_id", _casevacLastId],
    ["casevac_last_at", _casevacLastAt],
    ["casevac_cooldown_remaining", _casevacCooldownRemaining],
    ["recent_events", _recentMedicalEvents]
];

private _medicalSection = [
    ["data",      _medicalData],
    ["freshness", [["updatedAt", if (_casevacLastAt > 0) then { _casevacLastAt } else { _now }], ["staleAfterS", 30]]]
];

// ---------------------------------------------------------------------------
// Section: comms — TFAR/SOI read-only command-and-signal reference
// ---------------------------------------------------------------------------
private _commandNets = missionNamespace getVariable ["ARC_commsCommandNets", [
    ["001", "BCT CMD", "FALCON"],
    ["002", "TF CMD", "REDFALCON"],
    ["003", "BN CMD", "2-325 AIR"],
    ["008", "CAV SQDN CMD", "THUNDER"],
    ["041", "FIRES CMD", "BLACKFALCON"],
    ["043", "ISR UAS OPS", "SHADOW"],
    ["050", "AVIATION CMD", "PEGASUS"],
    ["052", "MEDEVAC AIR", "DUSTOFF"],
    ["060", "MP CMD", "SHERIFF"],
    ["070", "BSB CMD", "GRIFFIN"],
    ["084", "FARABAD TOWER", "TOWER"],
    ["085", "FARABAD GROUND", "GROUND"]
]];
if (!(_commandNets isEqualType [])) then { _commandNets = []; };

private _prc152 = missionNamespace getVariable ["ARC_commsPrc152Plan", [
    "Charlie: 010 1PLT | 011 2PLT | 012 3PLT",
    "Bravo: 020 1PLT | 021 2PLT | 022 3PLT",
    "Alpha: 030 1PLT | 031 2PLT | 032 3PLT",
    "WPN: 040 2-325 TAC",
    "THUNDER: 050/051/052 A/B/C TAC",
    "SHERIFF: 060 TAC",
    "GRIFFIN: 070 CONVOY TAC",
    "SENTRY: 080 TAC"
]];
if (!(_prc152 isEqualType [])) then { _prc152 = []; };

private _shortRange = missionNamespace getVariable ["ARC_commsShortRangeBuckets", missionNamespace getVariable ["ARC_commsPrc343Buckets", [
    "1 C 1PLT | 2 C 2PLT | 3 C 3PLT",
    "4 B 1PLT | 5 B 2PLT | 6 B 3PLT",
    "7 A 1PLT | 8 A 2PLT | 9 A 3PLT",
    "10 WPN | 11 THUNDER A | 12 THUNDER B | 13 THUNDER C",
    "14 SHERIFF MP | 15 GRIFFIN convoys | 16 SENTRY SECFO"
]]];
if (!(_shortRange isEqualType [])) then { _shortRange = []; };

private _commsData = [
    ["tfar_required", isClass (configFile >> "CfgPatches" >> "task_force_radio")],
    ["command_nets", _commandNets],
    ["prc152_plan", _prc152],
    ["short_range_buckets", _shortRange],
    ["radio_crates", ["TFAR_NATO_Radio_Crate"]],
    ["role_hint", "Soft guidance only: use TFAR nets to support TOC workflow; mission state remains server-owned."]
];

private _commsSection = [
    ["data",      _commsData],
    ["freshness", [["updatedAt", _now], ["staleAfterS", 300]]]
];

// ---------------------------------------------------------------------------
// Section: cTab — device/marker interoperability hints, not authoritative state
// ---------------------------------------------------------------------------
private _casevacMarker = missionNamespace getVariable ["ARC_casevacLatestMarker", ""];
if (!(_casevacMarker isEqualType "")) then { _casevacMarker = ""; };

private _activeTaskMarker = missionNamespace getVariable ["ARC_activeIncidentMarker", ""];
if (!(_activeTaskMarker isEqualType "")) then { _activeTaskMarker = ""; };

private _ctabData = [
    ["required_items", missionNamespace getVariable ["ARC_consoleRequiredItems", ["ItemcTab", "ItemAndroid", "ItemcTabHCam", "ItemMicroDAGR", "ACE_DAGR"]]],
    ["active_task_marker", _activeTaskMarker],
    ["casevac_marker", _casevacMarker],
    ["lead_pool", _leadPool],
    ["note", "cTab/map markers are read-only presentation aids; TOC actions still route through validated server functions."]
];

private _ctabSection = [
    ["data",      _ctabData],
    ["freshness", [["updatedAt", _now], ["staleAfterS", 60]]]
];

// ---------------------------------------------------------------------------
// Section: runtimeBoundary — diagnostics-only Runtime Boundary read model
// ---------------------------------------------------------------------------
private _runtimePolicy = missionNamespace getVariable ["ARC_pub_runtimePolicy", []];
if (!(_runtimePolicy isEqualType [])) then { _runtimePolicy = []; };

private _runtimePolicyAt = missionNamespace getVariable ["ARC_pub_runtimePolicyUpdatedAt", -1];
if (!(_runtimePolicyAt isEqualType 0)) then { _runtimePolicyAt = -1; };

private _runtimePolicyMeta = missionNamespace getVariable ["ARC_pub_runtimePolicyMeta", []];
if (!(_runtimePolicyMeta isEqualType [])) then { _runtimePolicyMeta = []; };

private _runtimeBoundaryData = [
    ["snapshot", _runtimePolicy],
    ["meta", _runtimePolicyMeta],
    ["note", "Diagnostics-only Runtime Boundary read model. UI is a consumer only; no gameplay authority."]
];

private _runtimeBoundarySection = [
    ["data",      _runtimeBoundaryData],
    ["freshness", [["updatedAt", if (_runtimePolicyAt > 0) then { _runtimePolicyAt } else { _now }], ["staleAfterS", 60]]]
];

// ---------------------------------------------------------------------------
// Assemble final payload
// ---------------------------------------------------------------------------
[
    ["schema",            "ARC_ConsoleVM_v1"],
    ["version",           [1,0,0]],
    ["builtAtServerTime", _now],
    ["rev",               _rev],
    ["sections", [
        ["incident",     _incidentSection],
        ["followOn",     _followOnSection],
        ["ops",          _opsSection],
        ["stateSummary", _statSection],
        ["access",       _accessSection],
        ["civsub",       _civsubSection],
        ["airbase",      _airbaseSection],
        ["threat",       _threatSection],
        ["personnel",    _personnelSection],
        ["handoff",      _handoffSection],
        ["intelFeed",    _intelFeedSection],
        ["medical",      _medicalSection],
        ["comms",        _commsSection],
        ["ctab",         _ctabSection],
        ["runtimeBoundary", _runtimeBoundarySection]
    ]]
]

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

    Note: existing UI tabs still read ARC_pub_* directly. This payload is the
    contract for future tab migration. Do NOT change existing tab paint behaviour.

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

private _opsUpdatedAt = missionNamespace getVariable ["ARC_pub_ordersUpdatedAt", _now];
if (!(_opsUpdatedAt isEqualType 0)) then { _opsUpdatedAt = _now; };

private _opsData = [
    ["log_tail",     if ((count _opsLog) > 5) then { _opsLog select [(count _opsLog) - 5, 5] } else { _opsLog }],
    ["queue_pending", _queuePending],
    ["orders",       _orders],
    ["intel_log",    _intelLog],
    ["lead_pool",    _leadPool]
];

private _opsSection = [
    ["data",      _opsData],
    ["freshness", [["updatedAt", _opsUpdatedAt], ["staleAfterS", 60]]]
];

// ---------------------------------------------------------------------------
// Section: stateSummary — sustainment + pressure indicators
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

private _statData = [
    ["base_fuel",          _baseFuel],
    ["base_ammo",          _baseAmmo],
    ["base_med",           _baseMed],
    ["insurgent_pressure", _insPres],
    ["infiltration",       _infiltr],
    ["civ_casualties",     _civCas],
    ["base_casualties",    _bCas]
];

private _statSection = [
    ["data",      _statData],
    ["freshness", [["updatedAt", _now], ["staleAfterS", 60]]]
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
        ["civsub",       _civsubSection]
    ]]
]

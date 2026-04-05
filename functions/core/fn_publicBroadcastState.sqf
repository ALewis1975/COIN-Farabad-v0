/*
    Publish a small, JIP-safe "public state snapshot" into missionNamespace.

    Client UI (briefing / TOC screens) should NOT read ARC_state directly.
    Instead it should read these public variables which are designed for presentation.
*/

if (!isServer) exitWith {false};

// Dedicated MP hardening: require valid remoteExec context when invoked remotely.
if (!isNil "remoteExecutedOwner") then
{
    private _reo = remoteExecutedOwner;
    if (_reo > 0) then
    {
        diag_log format ["[ARC][SEC] ARC_fnc_publicBroadcastState: invoked via remoteExec from owner=%1", _reo];
    };
};

private _p = ["insurgentPressure", 0.35] call ARC_fnc_stateGet;
private _c = ["corruption", 0.55] call ARC_fnc_stateGet;
private _i = ["infiltration", 0.35] call ARC_fnc_stateGet;

private _sent = ["civSentiment", 0.55] call ARC_fnc_stateGet;
private _leg  = ["govLegitimacy", 0.45] call ARC_fnc_stateGet;
private _cas  = ["civCasualties", 0] call ARC_fnc_stateGet;

private _fuel = ["baseFuel", 0.38] call ARC_fnc_stateGet;
private _ammo = ["baseAmmo", 0.32] call ARC_fnc_stateGet;
private _med  = ["baseMed",  0.40] call ARC_fnc_stateGet;

// Activity counters (help players see the campaign move)
// NOTE: intelCounter is a monotonic ID generator; it includes OPS items.
// For player-facing counts we only count non-OPS entries.
private _log = ["intelLog", []] call ARC_fnc_stateGet;
if (!(_log isEqualType [])) then { _log = []; };

private _intelCount = count (_log select { (_x isEqualType [] && { (count _x) >= 3 } && { toUpper ((_x select 2)) != "OPS" }) });
private _opsCount   = count (_log select { (_x isEqualType [] && { (count _x) >= 3 } && { toUpper ((_x select 2)) == "OPS" }) });

// Recent incident history tail (for dashboards)
private _hist = ["incidentHistory", []] call ARC_fnc_stateGet;
if (!(_hist isEqualType [])) then { _hist = []; };
private _hCount = count _hist;
private _hStart = (_hCount - 8) max 0;
private _hTail = _hist select [_hStart, _hCount - _hStart];

// Metric snapshot tail (for in-game dashboards / change monitor)
private _snaps = ["metricsSnapshots", []] call ARC_fnc_stateGet;
if (!(_snaps isEqualType [])) then { _snaps = []; };
private _sCount = count _snaps;
private _sMax = missionNamespace getVariable ["ARC_metricsSnapshotsPublicMax", 8];
if (!(_sMax isEqualType 0)) then { _sMax = 8; };
private _sStart = (_sCount - _sMax) max 0;
private _sTail = _snaps select [_sStart, _sCount - _sStart];

// Airbase v1 summary (compact primitives for low-cost UI polling)
private _airQueue = ["airbase_v1_queue", []] call ARC_fnc_stateGet;
if (!(_airQueue isEqualType [])) then { _airQueue = []; };

private _airRecs = ["airbase_v1_records", []] call ARC_fnc_stateGet;
if (!(_airRecs isEqualType [])) then { _airRecs = []; };

private _clrReqs = ["airbase_v1_clearanceRequests", []] call ARC_fnc_stateGet;
if (!(_clrReqs isEqualType [])) then { _clrReqs = []; };

private _clrHist = ["airbase_v1_clearanceHistory", []] call ARC_fnc_stateGet;
if (!(_clrHist isEqualType [])) then { _clrHist = []; };

private _clrSeq = ["airbase_v1_clearanceSeq", 0] call ARC_fnc_stateGet;
if (!(_clrSeq isEqualType 0) || { _clrSeq < 0 }) then { _clrSeq = 0; };


private _airEvents = ["airbase_v1_events", []] call ARC_fnc_stateGet;
if (!(_airEvents isEqualType [])) then { _airEvents = []; };

private _towerStaffing = ["airbase_v1_towerStaffing", []] call ARC_fnc_stateGet;
if (!(_towerStaffing isEqualType [])) then { _towerStaffing = []; };

private _normalizeStaffingLane = {
    params ["_rows", "_laneId"];

    private _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 5 } && { ((_x param [0, ""]) isEqualTo _laneId) }) exitWith { _idx = _forEachIndex; }; } forEach _rows;

    private _base = if (_idx >= 0) then { _rows # _idx } else { [_laneId, "AUTO", "", "", -1] };
    [
        _laneId,
        toUpper (_base param [1, "AUTO"]),
        _base param [2, ""],
        _base param [3, ""],
        _base param [4, -1]
    ]
};

private _towerLane = [_towerStaffing, "tower"] call _normalizeStaffingLane;
private _groundLane = [_towerStaffing, "ground"] call _normalizeStaffingLane;
private _arrivalLane = [_towerStaffing, "arrival"] call _normalizeStaffingLane;
private _staffingView = [_towerLane, _groundLane, _arrivalLane];

private _depQueued = 0;
private _arrQueued = 0;
{
    private _kind = _x param [1, ""];
    if (!(_kind isEqualType "")) then { _kind = ""; };

    if (_kind isEqualTo "DEP") then {
        _depQueued = _depQueued + 1;
    } else {
        if (_kind isEqualTo "ARR") then { _arrQueued = _arrQueued + 1; };
    };
} forEach _airQueue;

private _execActive = missionNamespace getVariable ["airbase_v1_execActive", false];
if (!(_execActive isEqualType true) && !(_execActive isEqualType false)) then { _execActive = false; };

private _execFid = missionNamespace getVariable ["airbase_v1_execFid", ""];
if (!(_execFid isEqualType "")) then { _execFid = ""; };

private _depInProgress = 0;
if (_execActive && { _execFid isNotEqualTo "" }) then {
    private _execRecIdx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 3 } && { ((_x param [0, ""]) isEqualTo _execFid) }) exitWith { _execRecIdx = _forEachIndex; }; } forEach _airRecs;

    if (_execRecIdx >= 0) then {
        private _execKind = (_airRecs # _execRecIdx) param [2, ""];
        if (_execKind isEqualTo "DEP") then { _depInProgress = 1; };
    };
};

private _holdDepartures = ["airbase_v1_holdDepartures", false] call ARC_fnc_stateGet;
if (!(_holdDepartures isEqualType true) && !(_holdDepartures isEqualType false)) then { _holdDepartures = false; };

private _runwayState = missionNamespace getVariable ["airbase_v1_runwayState", "OPEN"];
if (!(_runwayState isEqualType "")) then { _runwayState = "OPEN"; };
if !(_runwayState in ["OPEN", "RESERVED", "OCCUPIED"]) then { _runwayState = "OPEN"; };

private _runwayOwner = missionNamespace getVariable ["airbase_v1_runwayOwner", ""];
if (!(_runwayOwner isEqualType "")) then { _runwayOwner = ""; };

private _runwayUntil = missionNamespace getVariable ["airbase_v1_runwayUntil", -1];
if (!(_runwayUntil isEqualType 0)) then { _runwayUntil = -1; };

private _arrivalWarnAdvisoryM = missionNamespace getVariable ["airbase_v1_arrival_warn_advisory_m", 7000];
if (!(_arrivalWarnAdvisoryM isEqualType 0)) then { _arrivalWarnAdvisoryM = 7000; };
private _arrivalWarnCautionM = missionNamespace getVariable ["airbase_v1_arrival_warn_caution_m", 4500];
if (!(_arrivalWarnCautionM isEqualType 0)) then { _arrivalWarnCautionM = 4500; };
private _arrivalWarnUrgentM = missionNamespace getVariable ["airbase_v1_arrival_warn_urgent_m", 2600];
if (!(_arrivalWarnUrgentM isEqualType 0)) then { _arrivalWarnUrgentM = 2600; };
private _arrivalLandGateM = missionNamespace getVariable ["airbase_v1_arrival_land_gate_m", 2200];
if (!(_arrivalLandGateM isEqualType 0)) then { _arrivalLandGateM = 2200; };
private _arrivalRunwayMarker = missionNamespace getVariable ["airbase_v1_arrival_runway_marker", "L-270 Inbound"];
if (!(_arrivalRunwayMarker isEqualType "")) then { _arrivalRunwayMarker = "L-270 Inbound"; };
private _inboundTaxiMarkers = missionNamespace getVariable ["airbase_v1_inbound_taxi_markers", ["L-270 Inbound", "T-L Egress", "T-L Ingress"]];
if !(_inboundTaxiMarkers isEqualType []) then { _inboundTaxiMarkers = ["L-270 Inbound", "T-L Egress", "T-L Ingress"]; };

private _controllerTimeoutTowerS = missionNamespace getVariable ["airbase_v1_controller_timeout_tower_s", missionNamespace getVariable ["airbase_v1_controller_timeout_s", 90]];
if (!(_controllerTimeoutTowerS isEqualType 0)) then { _controllerTimeoutTowerS = 90; };
private _controllerTimeoutGroundS = missionNamespace getVariable ["airbase_v1_controller_timeout_ground_s", missionNamespace getVariable ["airbase_v1_controller_timeout_s", 90]];
if (!(_controllerTimeoutGroundS isEqualType 0)) then { _controllerTimeoutGroundS = 90; };
private _controllerTimeoutArrivalS = missionNamespace getVariable ["airbase_v1_controller_timeout_arrival_s", missionNamespace getVariable ["airbase_v1_controller_timeout_s", 90]];
if (!(_controllerTimeoutArrivalS isEqualType 0)) then { _controllerTimeoutArrivalS = 90; };
private _autoDelayTowerS = missionNamespace getVariable ["airbase_v1_automation_delay_tower_s", 8];
if (!(_autoDelayTowerS isEqualType 0)) then { _autoDelayTowerS = 8; };
private _autoDelayGroundS = missionNamespace getVariable ["airbase_v1_automation_delay_ground_s", 10];
if (!(_autoDelayGroundS isEqualType 0)) then { _autoDelayGroundS = 10; };
private _autoDelayArrivalS = missionNamespace getVariable ["airbase_v1_automation_delay_arrival_s", 6];
if (!(_autoDelayArrivalS isEqualType 0)) then { _autoDelayArrivalS = 6; };

private _nextCap = missionNamespace getVariable ["airbase_v1_publicPreviewMax", 5];
if (!(_nextCap isEqualType 0) || { _nextCap < 0 }) then { _nextCap = 5; };

private _nextN = _nextCap min (count _airQueue);
private _nextItems = [];
for "_i" from 0 to (_nextN - 1) do
{
    private _it = _airQueue # _i;
    private _routeMeta = _it param [3, []];
    if !(_routeMeta isEqualType []) then { _routeMeta = []; };
    _nextItems pushBack [
        _it param [0, ""],
        _it param [1, ""],
        _it param [2, ""],
        _routeMeta
    ];
};

private _clearancePending = _clrReqs select {
    private _st = toUpper (_x param [6, ""]);
    (_st in ["QUEUED", "PENDING", "AWAITING_TOWER_DECISION"])
};
private _clearanceAwaitingTower = _clearancePending select { (toUpper (_x param [6, ""])) isEqualTo "AWAITING_TOWER_DECISION" };
private _clearanceEmergency = _clearancePending select { ((_x param [5, 0]) >= 100) };

private _clearancePendingView = _clearancePending apply {
    [
        _x param [0, ""],
        _x param [1, ""],
        _x param [3, ""],
        _x param [4, ""],
        _x param [5, 0],
        _x param [6, ""],
        _x param [7, -1],
        _x param [8, -1],
        _x param [9, []],
        (_x param [10, []])
    ]
};

private _clearanceHistoryTail = +_clrHist;
private _clrTailN = missionNamespace getVariable ["airbase_v1_publicClearanceHistoryMax", 10];
if (!(_clrTailN isEqualType 0) || { _clrTailN < 0 }) then { _clrTailN = 10; };
if ((count _clearanceHistoryTail) > _clrTailN) then {
    _clearanceHistoryTail = _clearanceHistoryTail select [(count _clearanceHistoryTail) - _clrTailN, _clrTailN];
};


private _eventsTail = +_airEvents;
private _eventsTailN = missionNamespace getVariable ["airbase_v1_publicEventsMax", 8];
if (!(_eventsTailN isEqualType 0) || { _eventsTailN < 0 }) then { _eventsTailN = 8; };
if ((count _eventsTail) > _eventsTailN) then {
    _eventsTail = _eventsTail select [(count _eventsTail) - _eventsTailN, _eventsTailN];
};

private _eventsView = _eventsTail apply {
    [
        _x param [0, -1],
        _x param [1, ""],
        _x param [2, ""],
        _x param [3, ""],
        _x param [4, ""],
        _x param [5, []]
    ]
};

private _blockedRouteWindow = missionNamespace getVariable ["airbase_v1_publicBlockedRouteWindow", 25];
if (!(_blockedRouteWindow isEqualType 0) || { _blockedRouteWindow < 1 }) then { _blockedRouteWindow = 25; };
private _blockedRouteRecentWindowMin_s = 60;
private _blockedRouteRecentWindow_s = missionNamespace getVariable ["airbase_v1_publicBlockedRouteRecentWindow_s", 1800];
if (!(_blockedRouteRecentWindow_s isEqualType 0) || { _blockedRouteRecentWindow_s < _blockedRouteRecentWindowMin_s }) then { _blockedRouteRecentWindow_s = 1800; };
private _blockedRouteCutoffTs = serverTime - _blockedRouteRecentWindow_s;
// Returns true when a blocked-route row [timestamp, reason, sourceId] falls within the configured recent window.
private _isBlockedRouteRecent = {
    params [["_row", [], [[]]]];
    private _ts = _row param [0, -1];
    (_ts isEqualType 0) && { _ts >= _blockedRouteCutoffTs }
};

private _readReasonFromMeta = {
    params ["_meta"];
    private _reason = "";
    if !(_meta isEqualType []) exitWith { _reason };

    if ((count _meta) > 0) then {
        private _first = _meta # 0;
        if (_first isEqualType "") then {
            _reason = _first;
        } else {
            if (_first isEqualType [] && { (count _first) >= 2 } && { ((_first # 0) isEqualType "") }) then {
                _reason = _first # 1;
            };
        };
    };

    if (_reason isEqualTo "") then {
        private _idxReason = -1;
        { if (_x isEqualType [] && { (count _x) >= 2 } && { toUpper (_x # 0) in ["REASON", "ROUTEVALIDATIONREASON"] }) exitWith { _idxReason = _forEachIndex; }; } forEach _meta;
        if (_idxReason >= 0) then { _reason = (_meta # _idxReason) # 1; };
    };

    if !(_reason isEqualType "") then { _reason = str _reason; };
    toUpper (trim _reason)
};

private _extractBlockedReason = {
    params ["_txt"];
    if !(_txt isEqualType "") exitWith { "" };
    private _t = trim _txt;
    private _open = _t find "(";
    if (_open < 0) exitWith { "" };
    private _out = "";
    private _close = _t find ")";
    if (_close > _open) then { _out = _t select [_open + 1, _close - _open - 1]; };
    toUpper (trim _out)
};

private _extractBlockedSourceId = {
    params ["_txt"];
    if !(_txt isEqualType "") exitWith { "" };
    private _tokens = _txt splitString " :()[]|,.;\t\n\r";
    private _found = "";
    {
        private _t = toUpper (trim _x);
        if (_t isEqualTo "") then { continue; };
        if ((_t find "FLT-") == 0 || { (_t find "CLR-") == 0 } || { (_t find "REQ-") == 0 }) exitWith {
            _found = _t;
        };
    } forEach _tokens;
    _found
};

private _metaValue = {
    params ["_meta", "_key", ["_def", ""]];
    if !(_meta isEqualType []) exitWith { _def };
    private _idx = -1;
    { if (_x isEqualType [] && { (count _x) >= 2 } && { ((_x # 0) isEqualType "") } && { (toUpper (_x # 0)) isEqualTo (toUpper _key) }) exitWith { _idx = _forEachIndex; }; } forEach _meta;
    if (_idx < 0) exitWith { _def };
    (_meta # _idx) # 1
};

private _blockedRouteTail = [];

{
    if !(_x isEqualType []) then { continue; };
    private _kind = toUpper (_x param [1, ""]);
    private _reason = [(_x param [5, []])] call _readReasonFromMeta;
    if ((_kind in ["DENY", "REJECT", "ROUTE_BLOCK"]) && { (_reason find "ROUTE") >= 0 || { (_reason find "MARKER") >= 0 } }) then {
        _blockedRouteTail pushBack [
            _x param [0, -1],
            _reason,
            _x param [2, ""]
        ];
    };
} forEach _airEvents;

{
    if !(_x isEqualType []) then { continue; };
    if ((count _x) < 4) then { continue; };
    private _cat = toUpper (_x param [2, ""]);
    if (_cat isNotEqualTo "OPS") then { continue; };

    private _summary = _x param [3, ""];
    if !(_summary isEqualType "") then { _summary = str _summary; };
    private _summaryU = toUpper _summary;

    private _meta = _x param [5, []];
    if !(_meta isEqualType []) then { _meta = []; };
    private _eventCode = toUpper ([_meta, "event", ""] call _metaValue);
    private _metaReason = toUpper ([_meta, "reason", ""] call _metaValue);

    private _isRouteBlockedSummary = (_summaryU find "AIRBASE ROUTE: BLOCKED") >= 0;
    private _isRouteInvalidClearance =
        (_eventCode isEqualTo "AIRBASE_CLEARANCE_ROUTE_INVALID") ||
        {
            (_summaryU find "AIRBASE CLEARANCE DENIED") >= 0 &&
            {
                (_summaryU find "ROUTE INVALID") >= 0 ||
                { (_metaReason find "ROUTE") >= 0 || { (_metaReason find "MARKER") >= 0 } }
            }
        };
    if !(_isRouteBlockedSummary || _isRouteInvalidClearance) then { continue; };

    private _reason = if (_metaReason isEqualTo "") then { [_summaryU] call _extractBlockedReason } else { _metaReason };
    if (_reason isEqualTo "") then { _reason = "ROUTE_DENIED"; };
    private _sourceId = toUpper ([_meta, "flightId", ""] call _metaValue);
    if (_sourceId isEqualTo "") then { _sourceId = toUpper ([_meta, "requestId", ""] call _metaValue); };
    if (_sourceId isEqualTo "") then { _sourceId = [_summaryU] call _extractBlockedSourceId; };

    _blockedRouteTail pushBack [
        _x param [1, -1],
        _reason,
        _sourceId
    ];
} forEach _log;

// AIR/OPS matches are appended in source order; normalize by timestamp so
// recent-window slicing and latest-reason/source always reflect true recency.
if ((count _blockedRouteTail) > 1) then {
    private _blockedSort = _blockedRouteTail apply {
        [
            _x param [0, -1],
            _x
        ]
    };
    _blockedSort = _blockedSort select { [_x] call _isBlockedRouteRecent };
    _blockedSort sort true;
    _blockedRouteTail = _blockedSort apply { _x param [1, []] };
} else {
    _blockedRouteTail = _blockedRouteTail select { [_x] call _isBlockedRouteRecent };
};

if ((count _blockedRouteTail) > _blockedRouteWindow) then {
    _blockedRouteTail = _blockedRouteTail select [(count _blockedRouteTail) - _blockedRouteWindow, _blockedRouteWindow];
};

private _blockedRouteLatestReason = "-";
private _blockedRouteLatestSourceId = "-";
if ((count _blockedRouteTail) > 0) then {
    private _lastBlocked = _blockedRouteTail # ((count _blockedRouteTail) - 1);
    _blockedRouteLatestReason = _lastBlocked param [1, "-"];
    _blockedRouteLatestSourceId = _lastBlocked param [2, "-"];
    if (_blockedRouteLatestReason isEqualTo "") then { _blockedRouteLatestReason = "-"; };
    if (_blockedRouteLatestSourceId isEqualTo "") then { _blockedRouteLatestSourceId = "-"; };
};

private _blockedTailN = missionNamespace getVariable ["airbase_v1_publicBlockedRouteTailMax", 3];
if (!(_blockedTailN isEqualType 0) || { _blockedTailN < 1 }) then { _blockedTailN = 3; };
private _blockedRouteTailView = +_blockedRouteTail;
if ((count _blockedRouteTailView) > _blockedTailN) then {
    _blockedRouteTailView = _blockedRouteTailView select [(count _blockedRouteTailView) - _blockedTailN, _blockedTailN];
};

private _casreqBundle = missionNamespace getVariable ["ARC_pub_casreqBundle", []];
if !(_casreqBundle isEqualType []) then { _casreqBundle = []; };

private _casreqMeta = [];
private _casreqPayload = [];
{
    if (_x isEqualType [] && { (count _x) >= 2 }) then {
        if ((_x select 0) isEqualTo "meta") then { _casreqMeta = _x select 1; };
        if ((_x select 0) isEqualTo "payload") then { _casreqPayload = _x select 1; };
    };
} forEach _casreqBundle;
if !(_casreqMeta isEqualType []) then { _casreqMeta = []; };
if !(_casreqPayload isEqualType []) then { _casreqPayload = []; };

private _casreqId = "";
private _casreqSnapshot = [];
{
    if (_x isEqualType [] && { (count _x) >= 2 }) then {
        if ((_x select 0) isEqualTo "casreq_id") then { _casreqId = _x select 1; };
        if ((_x select 0) isEqualTo "casreq_snapshot") then { _casreqSnapshot = _x select 1; };
    };
} forEach _casreqPayload;
if !(_casreqSnapshot isEqualType []) then { _casreqSnapshot = []; };

private _casreqPub = [
    ["schemaVersion", missionNamespace getVariable ["casreq_v1_schemaVersion", 1]],
    ["rev", missionNamespace getVariable ["ARC_casreq_rev", 0]],
    ["updatedAt", serverTime],
    ["actor", "PUBLIC_BROADCAST"],
    ["casreq_id", _casreqId],
    ["casreq_snapshot", _casreqSnapshot],
    ["bundleMeta", _casreqMeta]
];

private _airbasePub = [
    ["depQueued", _depQueued],
    ["depInProgress", _depInProgress],
    ["arrQueued", _arrQueued],
    ["totalQueued", count _airQueue],
    ["execActive", _execActive],
    ["execFid", _execFid],
    ["holdDepartures", _holdDepartures],
    ["runwayState", _runwayState],
    ["runwayOwner", _runwayOwner],
    ["runwayUntil", _runwayUntil],
    ["nextItems", _nextItems],
    ["recordsCount", count _airRecs],
    ["clearanceSeq", _clrSeq],
    ["clearancePendingCount", count _clearancePending],
    ["clearanceEmergencyCount", count _clearanceEmergency],
    ["clearanceAwaitingTowerCount", count _clearanceAwaitingTower],
    ["clearancePending", _clearancePendingView],
    ["clearanceControllerPending", _clearancePendingView],
    ["clearanceHistoryTail", _clearanceHistoryTail],
    ["towerStaffing", _staffingView],
    ["recentEvents", _eventsView],
    ["blockedRouteAttemptsRecent", count _blockedRouteTail],
    ["blockedRouteLatestReason", _blockedRouteLatestReason],
    ["blockedRouteLatestSourceId", _blockedRouteLatestSourceId],
    ["blockedRouteTail", _blockedRouteTailView],
    ["arrivalRunwayMarker", _arrivalRunwayMarker],
    ["arrivalLandGateM", _arrivalLandGateM],
    ["arrivalWarnAdvisoryM", _arrivalWarnAdvisoryM],
    ["arrivalWarnCautionM", _arrivalWarnCautionM],
    ["arrivalWarnUrgentM", _arrivalWarnUrgentM],
    ["inboundTaxiMarkers", _inboundTaxiMarkers],
    ["controllerTimeoutTowerS", _controllerTimeoutTowerS],
    ["controllerTimeoutGroundS", _controllerTimeoutGroundS],
    ["controllerTimeoutArrivalS", _controllerTimeoutArrivalS],
    ["automationDelayTowerS", _autoDelayTowerS],
    ["automationDelayGroundS", _autoDelayGroundS],
    ["automationDelayArrivalS", _autoDelayArrivalS]
];

private _pub = [
    ["insurgentPressure", _p],
    ["corruption", _c],
    ["infiltration", _i],
    ["civSentiment", _sent],
    ["govLegitimacy", _leg],
    ["civCasualties", _cas],
    ["baseFuel", _fuel],
    ["baseAmmo", _ammo],
    ["baseMed", _med],
    ["intelCount", _intelCount],
    ["opsCount", _opsCount],
    ["incidentCount", _hCount],
    ["incidentHistoryTail", _hTail],
    ["metricsSnapshotsTail", _sTail],
    ["companyCommandNodes", ["companyCommandNodes", []] call ARC_fnc_stateGet],
    ["companyCommandTasking", ["companyCommandTasking", []] call ARC_fnc_stateGet],
    ["companyVirtualOps", ["companyVirtualOps", []] call ARC_fnc_stateGet],
    ["casreq", _casreqPub],
    ["airbase", _airbasePub]
];

private _didPublish = [_pub, "publicBroadcastState", false, 0.25] call ARC_fnc_statePublishPublic;
if (!_didPublish) exitWith { false };

private _companySnapshot = [
    ["companyCommandNodes", ["companyCommandNodes", []] call ARC_fnc_stateGet],
    ["companyCommandTasking", ["companyCommandTasking", []] call ARC_fnc_stateGet],
    ["companyVirtualOps", ["companyVirtualOps", []] call ARC_fnc_stateGet]
];
missionNamespace setVariable ["ARC_pub_companyCommand", _companySnapshot, true];
missionNamespace setVariable ["ARC_pub_companyCommandUpdatedAt", serverTime, true];

// Optional debug snapshot for the in-game inspector diary.
private _dbgEnabled = missionNamespace getVariable ["ARC_debugInspectorEnabled", false];
if (!(_dbgEnabled isEqualType true)) then { _dbgEnabled = false; };

if (_dbgEnabled) then
{
    // Throttle to avoid rebuilding summaries too frequently (public state can publish often).
    // Uses serverTime for the same reason as ARC_pub_stateUpdatedAt: one authoritative mission clock.
    private _lastDbg = missionNamespace getVariable ["ARC_pub_debugUpdatedAt", -1];
    if (!(_lastDbg isEqualType 0)) then { _lastDbg = -1; };

    if ((_lastDbg < 0) || { (serverTime - _lastDbg) > 5 }) then
    {
        private _cleanupQueue = ["cleanupQueue", []] call ARC_fnc_stateGet;
        if (!(_cleanupQueue isEqualType [])) then { _cleanupQueue = []; };

        private _labelCounts = [];
        {
            private _label = _x param [4, ""];
            if (!(_label isEqualType "")) then { _label = ""; };

            // Group by prefix to keep the list compact (ex: "patrolContact:XYZ" -> "patrolContact").
            private _key = _label;
            private _p = _label find ":";
            if (_p > 0) then { _key = _label select [0, _p]; };
            if (_key isEqualTo "") then { _key = "(none)"; };

            private _idx = -1;
            { if ((_x isEqualType []) && { (count _x) >= 2 } && { ((_x select 0)) isEqualTo _key }) exitWith { _idx = _forEachIndex; }; } forEach _labelCounts;

            if (_idx < 0) then {
                _labelCounts pushBack [_key, 1];
            } else {
                private _pair = _labelCounts select _idx;
                _pair set [1, (_pair select 1) + 1];
                _labelCounts set [_idx, _pair];
            };
        } forEach _cleanupQueue;

        private _tmp = [];
        {
            _tmp pushBack [(_x select 1), (_x select 0)];
        } forEach _labelCounts;  // [count,label]
        _tmp sort false;

        private _cleanupByLabel = _tmp apply { [_x select 1, _x select 0] };

        private _convoyNids = ["activeConvoyNetIds", []] call ARC_fnc_stateGet;
        if (!(_convoyNids isEqualType [])) then { _convoyNids = []; };

        private _localNids = ["activeLocalSupportNetIds", []] call ARC_fnc_stateGet;
        if (!(_localNids isEqualType [])) then { _localNids = []; };

        private _routeNids = ["activeRouteSupportNetIds", []] call ARC_fnc_stateGet;
        if (!(_routeNids isEqualType [])) then { _routeNids = []; };

        private _cpNids = missionNamespace getVariable ["ARC_persistentCheckpointNetIds", []];
        if (!(_cpNids isEqualType [])) then { _cpNids = []; };

        private _cap = 25;

        private _convoyShort = +_convoyNids;
        if ((count _convoyShort) > _cap) then { _convoyShort resize _cap; };

        private _localShort = +_localNids;
        if ((count _localShort) > _cap) then { _localShort resize _cap; };

        private _routeShort = +_routeNids;
        if ((count _routeShort) > _cap) then { _routeShort resize _cap; };

        private _cpShort = +_cpNids;
        if ((count _cpShort) > _cap) then { _cpShort resize _cap; };

        // Threat v0 debug (server-only state; summarized for inspector)
        private _tEnabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
        if (!(_tEnabled isEqualType true) && !(_tEnabled isEqualType false)) then { _tEnabled = true; };

        private _tOpen = ["threat_v0_open_index", []] call ARC_fnc_stateGet;
        if (!(_tOpen isEqualType [])) then { _tOpen = []; };

        private _tClosed = ["threat_v0_closed_index", []] call ARC_fnc_stateGet;
        if (!(_tClosed isEqualType [])) then { _tClosed = []; };

        private _tLast = missionNamespace getVariable ["threat_v0_debug_last_event", []];
        if (!(_tLast isEqualType [])) then { _tLast = []; };

        private _dbg = [
            ["cleanupCount", count _cleanupQueue],
            ["cleanupByLabel", _cleanupByLabel],

            ["netIdCap", _cap],

            ["activeConvoyCount", count _convoyNids],
            ["activeConvoyNetIds", _convoyShort],

            ["activeLocalSupportCount", count _localNids],
            ["activeLocalSupportNetIds", _localShort],

            ["activeRouteSupportCount", count _routeNids],
            ["activeRouteSupportNetIds", _routeShort],

            ["persistentCheckpointCount", count _cpNids],
            ["persistentCheckpointNetIds", _cpShort],

            ["threatEnabled", _tEnabled],
            ["threatOpenCount", count _tOpen],
            ["threatClosedCount", count _tClosed],
            ["threatLast", _tLast],

            // IED Phase 1 (active device/trigger summary)
            ["activeIedDeviceId", ["activeIedDeviceId", ""] call ARC_fnc_stateGet],
            ["activeIedTriggerEnabled", ["activeIedTriggerEnabled", false] call ARC_fnc_stateGet],
            ["activeIedTriggerRadiusM", ["activeIedTriggerRadiusM", 0] call ARC_fnc_stateGet],

["activeIedEvidenceNetId", ["activeIedEvidenceNetId", ""] call ARC_fnc_stateGet],
["activeIedEvidenceCollected", ["activeIedEvidenceCollected", false] call ARC_fnc_stateGet],
["activeIedEvidenceTransportEnabled", ["activeIedEvidenceTransportEnabled", false] call ARC_fnc_stateGet],
["activeIedEvidenceDelivered", ["activeIedEvidenceDelivered", false] call ARC_fnc_stateGet],
["activeIedEvidenceLeadId", ["activeIedEvidenceLeadId", ""] call ARC_fnc_stateGet],
["activeIedDetectedByScan", ["activeIedDetectedByScan", false] call ARC_fnc_stateGet],
            ["iedPhase1RecordsCount", count (missionNamespace getVariable ["ARC_iedPhase1_deviceRecords", []])],

            // VBIED (Phase 3)
            ["activeVbiedTriggerEnabled", ["activeVbiedTriggerEnabled", false] call ARC_fnc_stateGet],
            ["activeVbiedTriggerRadiusM", ["activeVbiedTriggerRadiusM", 0] call ARC_fnc_stateGet],
            ["activeVbiedDeviceId", ["activeVbiedDeviceId", ""] call ARC_fnc_stateGet],
            ["activeVbiedDetonated", ["activeVbiedDetonated", false] call ARC_fnc_stateGet],
            ["activeVbiedSafe", ["activeVbiedSafe", false] call ARC_fnc_stateGet],
            ["activeVbiedDisposed", ["activeVbiedDisposed", false] call ARC_fnc_stateGet],
            ["activeVbiedDestroyedCause", ["activeVbiedDestroyedCause", ""] call ARC_fnc_stateGet],
            ["vbiedPhase3RecordsCount", count (missionNamespace getVariable ["ARC_vbiedPhase3_deviceRecords", []])]
        ];

        // CIVSUB v1 (only when enabled)
        if (missionNamespace getVariable ["civsub_v1_enabled", false]) then
        {
            private _civDbg = [] call ARC_fnc_civsubDebugSnapshot;
            if (_civDbg isEqualType []) then { _dbg append _civDbg; };
        };


        missionNamespace setVariable ["ARC_pub_debug", _dbg, true];
        // Replicated as serverTime so clients can display/compare against a single server clock.
        missionNamespace setVariable ["ARC_pub_debugUpdatedAt", serverTime, true];
    };
};

// ---------------------------------------------------------------------------
// Console VM meta (rev) publish: monotonic rev to stabilize UI refresh ordering
// ---------------------------------------------------------------------------
private _rev = missionNamespace getVariable ["ARC_consoleVM_rev", 0];
if (!(_rev isEqualType 0)) then { _rev = 0; };
_rev = _rev + 1;
missionNamespace setVariable ["ARC_consoleVM_rev", _rev];
missionNamespace setVariable ["ARC_pub_stateSchema", ["ARC_pub_state_v2", 2], true];
missionNamespace setVariable ["ARC_consoleVM_meta", [
    ["schema", "Console_VM_v1"],
    ["schemaVersion", 1],
    ["publicStateSchema", "ARC_pub_state_v2"],
    ["publicStateSchemaVersion", 2],
    ["rev", _rev],
    ["publishedAt", serverTime],
    ["source", "publicBroadcastState"]
], true];

// ---------------------------------------------------------------------------
// Console VM v1 full payload — build and publish (used by future tab migrations)
// ---------------------------------------------------------------------------
private _vmPayload = [] call ARC_fnc_consoleVmBuild;
if (_vmPayload isEqualType [] && { !(_vmPayload isEqualTo []) }) then {
    missionNamespace setVariable ["ARC_consoleVM_payload", _vmPayload, true];
};

// ---------------------------------------------------------------------------
// District influence map markers (S2 heat-map visualization)
// ---------------------------------------------------------------------------
if (!isNil "ARC_fnc_districtMarkersUpdate") then
{
    [] call ARC_fnc_districtMarkersUpdate;
};

true

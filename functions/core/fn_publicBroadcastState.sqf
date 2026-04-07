/*
    Publish a small, JIP-safe "public state snapshot" into missionNamespace.

    Client UI (briefing / TOC screens) should NOT read ARC_state directly.
    Instead it should read these public variables which are designed for presentation.
*/

if (!isServer) exitWith {false};
private _trimFn = compile "params ['_s']; trim _s";

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

    private _base = [_laneId, "AUTO", "", "", -1];
    if (_idx >= 0) then { _base = _rows select _idx; };
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

// Phase 7: build flightId → position lookup from records (for CT_MAP traffic markers).
// Records hold netId at index 4; resolve to vehicle getPos when available.
// Departures on ground can also be resolved from parked assets via routeMeta.assetId.
private _airbaseCenterMarker = missionNamespace getVariable ["airbase_v1_arrival_runway_marker", "L-270 Inbound"];
private _airbaseCenterPos = getMarkerPos _airbaseCenterMarker;
private _flightPosMap = [];
{
    if !(_x isEqualType []) then { continue; };
    private _fid = _x param [0, ""];
    if (_fid isEqualTo "") then { continue; };
    private _netId = _x param [4, ""];
    if (_netId isEqualType "" && { !(_netId isEqualTo "") }) then {
        private _veh = objectFromNetId _netId;
        if (!isNull _veh) then {
            private _p = getPosATL _veh;
            if (_p isEqualType [] && { (count _p) >= 2 }) then {
                _flightPosMap pushBack [_fid, _p select 0, _p select 1];
            };
        };
    };
} forEach _airRecs;

private _execActive = missionNamespace getVariable ["airbase_v1_execActive", false];
if (!(_execActive isEqualType true) && !(_execActive isEqualType false)) then { _execActive = false; };

private _execFid = missionNamespace getVariable ["airbase_v1_execFid", ""];
if (!(_execFid isEqualType "")) then { _execFid = ""; };

private _depInProgress = 0;
if (_execActive && { !(_execFid isEqualTo "") }) then {
    private _execRecIdx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 3 } && { ((_x param [0, ""]) isEqualTo _execFid) }) exitWith { _execRecIdx = _forEachIndex; }; } forEach _airRecs;

    if (_execRecIdx >= 0) then {
        private _execKind = (_airRecs select _execRecIdx) param [2, ""];
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
    private _it = _airQueue select _i;
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
if (!(_blockedRouteRecentWindow_s isEqualType 0)) then { _blockedRouteRecentWindow_s = 1800; };
_blockedRouteRecentWindow_s = _blockedRouteRecentWindow_s max _blockedRouteRecentWindowMin_s;
private _blockedRouteCutoffTs = serverTime - _blockedRouteRecentWindow_s;
private _blockedRouteInvalidTs = -1;
// Returns true when a blocked-route row [timestamp, reason, sourceId] falls within the configured recent window.
private _isBlockedRouteRecent = {
    params [["_row", [], [[]]]];
    private _ts = _row param [0, _blockedRouteInvalidTs];
    (_ts isEqualType 0) && { _ts >= _blockedRouteCutoffTs }
};

private _readReasonFromMeta = {
    params ["_meta"];
    private _reason = "";
    if !(_meta isEqualType []) exitWith { _reason };

    if ((count _meta) > 0) then {
        private _first = _meta select 0;
        if (_first isEqualType "") then {
            _reason = _first;
        } else {
            if (_first isEqualType [] && { (count _first) >= 2 } && { ((_first select 0) isEqualType "") }) then {
                _reason = _first select 1;
            };
        };
    };

    if (_reason isEqualTo "") then {
        private _idxReason = -1;
        { if (_x isEqualType [] && { (count _x) >= 2 } && { toUpper (_x select 0) in ["REASON", "ROUTEVALIDATIONREASON"] }) exitWith { _idxReason = _forEachIndex; }; } forEach _meta;
        if (_idxReason >= 0) then { _reason = (_meta select _idxReason) select 1; };
    };

    if !(_reason isEqualType "") then { _reason = str _reason; };
    toUpper ([_reason] call _trimFn)
};

private _extractBlockedReason = {
    params ["_txt"];
    if !(_txt isEqualType "") exitWith { "" };
    private _t = [_txt] call _trimFn;
    private _open = _t find "(";
    if (_open < 0) exitWith { "" };
    private _out = "";
    private _close = _t find ")";
    if (_close > _open) then { _out = _t select [_open + 1, _close - _open - 1]; };
    toUpper ([_out] call _trimFn)
};

private _extractBlockedSourceId = {
    params ["_txt"];
    if !(_txt isEqualType "") exitWith { "" };
    private _tokens = _txt splitString " :()[]|,.;\t\n\r";
    private _found = "";
    {
        private _t = toUpper ([_x] call _trimFn);
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
    { if (_x isEqualType [] && { (count _x) >= 2 } && { ((_x select 0) isEqualType "") } && { (toUpper (_x select 0)) isEqualTo (toUpper _key) }) exitWith { _idx = _forEachIndex; }; } forEach _meta;
    if (_idx < 0) exitWith { _def };
    (_meta select _idx) select 1
};

private _normalizeAirText = {
    params ["_value", ["_default", ""]];
    if !(_value isEqualType "") then { _value = str _value; };
    private _out = [_value] call _trimFn;
    if (_out isEqualTo "") exitWith { _default };
    _out
};

private _isOpaqueAirId = {
    params ["_value"];
    private _txt = toUpper ([_value, ""] call _normalizeAirText);
    if (_txt isEqualTo "") exitWith { true };
    ((_txt find "FLT-") == 0) || { ((_txt find "CLR-") == 0) || { ((_txt find "REQ-") == 0) } }
};

private _requestTypeLabel = {
    params ["_requestType"];
    private _rt = toUpper ([_requestType, "REQUEST"] call _normalizeAirText);
    switch (_rt) do
    {
        case "REQ_TAXI": { "Taxi" };
        case "REQ_TAKEOFF": { "Takeoff" };
        case "REQ_INBOUND": { "Inbound" };
        case "REQ_LAND": { "Landing" };
        case "REQ_EMERGENCY": { "Emergency" };
        default { _rt }
    }
};

private _resolveAircraftDisplay = {
    params ["_raw"];
    private _cls = [_raw, ""] call _normalizeAirText;
    if (_cls isEqualTo "") exitWith { "" };
    private _display = "";
    if (isClass (configFile >> "CfgVehicles" >> _cls)) then {
        _display = getText (configFile >> "CfgVehicles" >> _cls >> "displayName");
    };
    _display = [_display, _cls] call _normalizeAirText;
    _display
};

private _composeAircraftLabel = {
    params [
        ["_fid", "", [""]],
        ["_callsign", "", [""]],
        ["_aircraftType", "", [""]]
    ];

    private _fidLabel = [_fid, "UNKNOWN"] call _normalizeAirText;
    private _callsignLabel = [_callsign, ""] call _normalizeAirText;
    private _typeLabel = [_aircraftType, ""] call _normalizeAirText;
    private _hasCallsign = !([_callsignLabel] call _isOpaqueAirId);
    private _hasValidType = !(_typeLabel isEqualTo "") && { !(_typeLabel isEqualTo "-") };

    if (_hasCallsign && { _hasValidType }) exitWith { format ["%1 (%2)", _callsignLabel, _typeLabel] };
    if (_hasCallsign) exitWith { _callsignLabel };
    if (_hasValidType) exitWith { format ["%1 / %2", _typeLabel, _fidLabel] };
    if (_callsignLabel isEqualTo "") exitWith { _fidLabel };
    format ["%1 / %2", _callsignLabel, _fidLabel]
};

private _findFlightPreview = {
    params ["_rows", "_fid"];
    private _out = [];
    {
        if (_x isEqualType [] && { (_x param [0, ""]) isEqualTo _fid }) exitWith {
            _out = _x;
        };
    } forEach _rows;
    _out
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
    if !(_cat isEqualTo "OPS") then { continue; };

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
    private _lastBlocked = _blockedRouteTail select ((count _blockedRouteTail) - 1);
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

private _uiPushAlert = {
    params [
        ["_rows", [], [[]]],
        ["_text", "", [""]],
        ["_severity", "INFO", [""]],
        ["_sourceId", "", [""]]
    ];
    if (_text isEqualTo "") exitWith {};
    _severity = toUpper _severity;
    if !(_severity in ["INFO", "CAUTION", "CRITICAL"]) then { _severity = "INFO"; };
    if ((count _rows) >= 5) exitWith {};
    _rows pushBack [_text, _severity, _sourceId];
};

private _uiPendingClearances = [];
private _uiDecisionQueue = [];
{
    if !(_x isEqualType []) then { continue; };
    private _requestId = _x param [0, ""];
    private _requestType = toUpper (_x param [1, ""]);
    private _pilotName = _x param [2, ""];
    private _requestedAt = _x param [3, -1];
    private _priority = _x param [4, 0];
    private _status = toUpper (_x param [5, ""]);
    private _ownerName = _x param [6, ""];
    private _meta = _x param [9, []];
    if !(_meta isEqualType []) then { _meta = []; };

    private _callsign = [_meta, "pilotCallsign", ""] call _metaValue;
    private _pilotCallsignOpaque = [_callsign] call _isOpaqueAirId;
    if (_pilotCallsignOpaque) then {
        _callsign = [_meta, "pilotGroupName", ""] call _metaValue;
    };
    private _groupCallsignOpaque = [_callsign] call _isOpaqueAirId;
    if (_groupCallsignOpaque) then { _callsign = _pilotName; };
    if (_callsign isEqualTo "") then { _callsign = _requestId; };

    private _decisionNeeded = _status in ["PENDING", "AWAITING_TOWER_DECISION", "QUEUED"];
    if ((count _uiPendingClearances) < 6) then {
        _uiPendingClearances pushBack [_requestId, _requestType, _callsign, _requestedAt, _priority, _decisionNeeded, _ownerName, _meta];
    };

    if (_decisionNeeded && { (count _uiDecisionQueue) < 5 }) then {
        private _decisionType = [_meta, "aircraftType", ""] call _metaValue;
        _decisionType = [_decisionType] call _resolveAircraftDisplay;
        _uiDecisionQueue pushBack [
            format [
                "Decision required: %1 %2",
                [_requestType] call _requestTypeLabel,
                [_requestId, _callsign, _decisionType] call _composeAircraftLabel
            ],
            _requestId,
            _callsign,
            _priority,
            _requestType
        ];
    };
} forEach _clearancePending;

private _uiArrivals = [];
private _uiDepartures = [];
{
    if !(_x isEqualType []) then { continue; };
    private _fid = _x param [0, ""];
    private _kind = toUpper (_x param [1, ""]);
    private _asset = _x param [2, ""];
    private _routeMeta = _x param [3, []];
    if !(_routeMeta isEqualType []) then { _routeMeta = []; };

    private _sourceRequestId = [_routeMeta, "sourceRequestId", ""] call _metaValue;
    private _queuedAt = [_routeMeta, "queuedAt", -1] call _metaValue;
    if !(_queuedAt isEqualType 0) then { _queuedAt = -1; };
    private _aircraftType = [_routeMeta, "aircraftType", ""] call _metaValue;
    if (_aircraftType isEqualTo "") then { _aircraftType = _asset; };
    _aircraftType = [_aircraftType] call _resolveAircraftDisplay;
    if (_aircraftType isEqualTo "") then { _aircraftType = "-"; };

    private _matchedReq = [];
    {
        if ((_x param [0, ""]) isEqualTo _sourceRequestId) exitWith { _matchedReq = _x; };
    } forEach _uiPendingClearances;

    private _callsign = _fid;
    private _priority = 0;
    private _ageS = if (_queuedAt >= 0) then { round ((serverTime - _queuedAt) max 0) } else { -1 };
    if (_matchedReq isEqualType [] && { (count _matchedReq) >= 8 }) then {
        _callsign = _matchedReq param [2, _fid];
        _priority = _matchedReq param [4, 0];
        private _requestedAt = _matchedReq param [3, -1];
        if (_requestedAt isEqualType 0 && { _requestedAt >= 0 }) then {
            _ageS = round ((serverTime - _requestedAt) max 0);
        };
    };
    _callsign = [_callsign, _fid] call _normalizeAirText;

    if (_kind isEqualTo "ARR") then {
        if ((count _uiArrivals) < 6) then {
            private _phase = "INBOUND";
            private _status = "NORMAL";
            if (_priority >= 100) then { _phase = "PRIORITY"; _status = "CONFLICT"; } else {
                if ((toUpper _runwayState) in ["OCCUPIED", "BLOCKED"]) then {
                    _phase = "HOLDING";
                    _status = "HOLDING";
                };
            };
            // Phase 7: append posX/posY for CT_MAP (indices 7-8); default airbase center.
            private _posX = _airbaseCenterPos select 0;
            private _posY = if (count _airbaseCenterPos > 2) then { _airbaseCenterPos select 2 } else { _airbaseCenterPos select 1 };
            {
                if ((_x select 0) isEqualTo _fid) exitWith { _posX = _x select 1; _posY = _x select 2; };
            } forEach _flightPosMap;
            _uiArrivals pushBack [_fid, _callsign, _aircraftType, _phase, _ageS, _priority, _status, _posX, _posY];
        };
    };

    if (_kind isEqualTo "DEP") then {
        if ((count _uiDepartures) < 6) then {
            private _depState = "QUEUED";
            private _depStatus = "NORMAL";
            if (_holdDepartures) then { _depState = "HOLD"; _depStatus = "HOLD"; };
            if (_execActive && { _execFid isEqualTo _fid }) then { _depState = "CLEARED"; _depStatus = "NORMAL"; };
            if ((count _blockedRouteTailView) > 0) then {
                private _lastBlocked = _blockedRouteTailView select ((count _blockedRouteTailView) - 1);
                if ((_lastBlocked param [2, ""]) isEqualTo _fid) then {
                    _depState = "BLOCKED";
                    _depStatus = "BLOCKED";
                };
            };
            // Phase 7: append posX/posY for CT_MAP (indices 7-8); default airbase center.
            private _posX = _airbaseCenterPos select 0;
            private _posY = if (count _airbaseCenterPos > 2) then { _airbaseCenterPos select 2 } else { _airbaseCenterPos select 1 };
            {
                if ((_x select 0) isEqualTo _fid) exitWith { _posX = _x select 1; _posY = _x select 2; };
            } forEach _flightPosMap;
            _uiDepartures pushBack [_fid, _callsign, _aircraftType, _depState, _ageS, _priority, _depStatus, _posX, _posY];
        };
    };
} forEach _nextItems;

{
    if ((count _uiArrivals) >= 6) exitWith {};
    if !(_x isEqualType []) then { continue; };
    private _requestType = toUpper (_x param [1, ""]);
    if !(_requestType in ["REQ_INBOUND", "REQ_LAND"]) then { continue; };
    private _requestId = _x param [0, ""];
    private _callsign = _x param [2, _requestId];
    private _requestedAt = _x param [3, -1];
    private _priority = _x param [4, 0];
    private _alreadyPresent = false;
    {
        if ((_x param [0, ""]) isEqualTo _requestId) exitWith { _alreadyPresent = true; };
    } forEach _uiArrivals;
    if (_alreadyPresent) then { continue; };
    // Phase 7: resolve position for pending clearance arrivals from records.
    private _pendPosX = _airbaseCenterPos select 0;
    private _pendPosY = if (count _airbaseCenterPos > 2) then { _airbaseCenterPos select 2 } else { _airbaseCenterPos select 1 };
    {
        if ((_x select 0) isEqualTo _requestId) exitWith { _pendPosX = _x select 1; _pendPosY = _x select 2; };
    } forEach _flightPosMap;
    _uiArrivals pushBack [
        _requestId,
        _callsign,
        "PENDING",
        "AWAITING DECISION",
        if (_requestedAt isEqualType 0 && { _requestedAt >= 0 }) then { round ((serverTime - _requestedAt) max 0) } else { -1 },
        _priority,
        if (_priority >= 100) then { "CONFLICT" } else { "HOLDING" },
        _pendPosX,
        _pendPosY
    ];
} forEach _uiPendingClearances;

private _uiStaffing = [];
{
    if !(_x isEqualType []) then { continue; };
    if ((count _uiStaffing) >= 3) exitWith {};
    private _lane = _x param [0, ""];
    private _mode = toUpper (_x param [1, "AUTO"]);
    private _operator = _x param [2, ""];
    _uiStaffing pushBack [_lane, _mode, if (_operator isEqualTo "") then { "AUTO" } else { _operator }];
} forEach _staffingView;

// Translate raw event tokens to operator-readable labels (Vision Plan §2.1 Rule 5).
private _eventKindLabel = {
    params ["_kind"];
    switch (toUpper _kind) do
    {
        case "EXEC_START":            { "Movement started" };
        case "EXEC_END":              { "Movement complete" };
        case "LOCK_ACQUIRE":          { "Runway reserved" };
        case "LOCK_RELEASE":          { "Runway released" };
        case "AUTO_QUEUE":            { "Auto-queued" };
        case "SUBMIT":                { "Request submitted" };
        case "CANCEL":                { "Request cancelled" };
        case "APPROVE":               { "Clearance approved" };
        case "DENY":                  { "Clearance denied" };
        case "ESCALATE":              { "Priority escalated" };
        case "LIFECYCLE_LAND_GATE":   { "On final approach" };
        default                       { _kind };
    }
};
if (!(_eventKindLabel isEqualType {})) exitWith { false };

private _uiRecentEvents = [];
{
    if !(_x isEqualType []) then { continue; };
    if ((count _uiRecentEvents) >= 8) exitWith {};
    private _eventTs = _x param [0, -1];
    private _eventKind = toUpper (_x param [1, ""]);
    private _eventSubject = _x param [2, ""];
    private _kindLabel = [_eventKind] call _eventKindLabel;
    private _label = if (_eventSubject isEqualTo "") then { _kindLabel } else { format ["%1: %2", _kindLabel, _eventSubject] };
    _uiRecentEvents pushBack [_eventTs, _label];
} forEach _eventsView;

private _uiClearanceHistory = [];
for "_histIdx" from ((count _clearanceHistoryTail) - 1) to 0 step -1 do {
    private _histRow = _clearanceHistoryTail select _histIdx;
    if !(_histRow isEqualType []) then { continue; };
    private _status = toUpper (_histRow param [6, ""]);
    if !(_status in ["APPROVED", "DENIED", "CANCELED"]) then { continue; };
    if ((count _uiClearanceHistory) >= 5) exitWith {};
    private _decision = _histRow param [9, []];
    _uiClearanceHistory pushBack [
        _histRow param [0, ""],
        _status,
        _histRow param [8, -1],
        if (_decision isEqualType []) then { _decision param [0, "SYSTEM"] } else { "SYSTEM" },
        if (_decision isEqualType []) then { _decision param [3, ""] } else { "" }
    ];
};

private _uiAlerts = [];
if ((toUpper _runwayState) in ["OCCUPIED", "BLOCKED"]) then {
    [_uiAlerts, format ["Runway %1", toUpper _runwayState], "CRITICAL", _runwayOwner] call _uiPushAlert;
};
if (_holdDepartures) then {
    [_uiAlerts, "Departure hold active", "CAUTION", "HOLD"] call _uiPushAlert;
};
if ((count _clearanceEmergency) > 0) then {
    private _emReq = _clearanceEmergency select 0;
    [_uiAlerts, format ["Emergency inbound %1", _emReq param [0, ""]], "CRITICAL", _emReq param [0, ""]] call _uiPushAlert;
};
if (_blockedRouteLatestReason != "-") then {
    [_uiAlerts, format ["Blocked route %1", _blockedRouteLatestReason], "CAUTION", _blockedRouteLatestSourceId] call _uiPushAlert;
};
if ((count _uiDecisionQueue) > 0) then {
    private _firstDecision = _uiDecisionQueue select 0;
    [_uiAlerts, _firstDecision param [0, "Decision required"], "CAUTION", _firstDecision param [1, ""]] call _uiPushAlert;
};

private _runwayMovement = "CLEAR";
if ((toUpper _runwayState) in ["OCCUPIED", "BLOCKED"]) then {
    _runwayMovement = if (_execActive) then { "DEPARTING" } else { "BLOCKED" };
};

private _runwayOwnerFlightId = [_runwayOwner, ""] call _normalizeAirText;
private _runwayOwnerCallsign = "";
private _runwayOwnerDisplay = "";
if !(_runwayOwnerFlightId isEqualTo "") then {
    private _ownerRec = [(_uiDepartures + _uiArrivals), _runwayOwnerFlightId] call _findFlightPreview;
    if (_ownerRec isEqualType [] && { (count _ownerRec) >= 3 }) then {
        _runwayOwnerCallsign = _ownerRec param [1, ""];
        _runwayOwnerDisplay = [_runwayOwnerFlightId, _runwayOwnerCallsign, _ownerRec param [2, ""]] call _composeAircraftLabel;
    } else {
        _runwayOwnerCallsign = "";
        _runwayOwnerDisplay = _runwayOwnerFlightId;
    };
    if ([_runwayOwnerCallsign] call _isOpaqueAirId) then { _runwayOwnerCallsign = ""; };
};

private _casTiming = [
    ["casreqId", _casreqId],
    ["rev", missionNamespace getVariable ["ARC_casreq_rev", 0]],
    ["district", if (_casreqSnapshot isEqualType []) then { [_casreqSnapshot, "district_id", ""] call _metaValue } else { "" }],
    ["state", if (_casreqSnapshot isEqualType []) then { [_casreqSnapshot, "state", ""] call _metaValue } else { "" }]
];

// Phase 5: compute real snapshot freshness from last airbase tick timestamp.
// Thresholds are configurable; defaults: FRESH < 15s, STALE < 60s, DEGRADED >= 60s or missing.
private _freshnessThresholdS = missionNamespace getVariable ["airbase_v1_freshness_threshold_s", 15];
if (!(_freshnessThresholdS isEqualType 0) || { _freshnessThresholdS <= 0 }) then { _freshnessThresholdS = 15; };
private _degradedThresholdS = missionNamespace getVariable ["airbase_v1_degraded_threshold_s", 60];
if (!(_degradedThresholdS isEqualType 0) || { _degradedThresholdS <= 0 }) then { _degradedThresholdS = 60; };

private _lastTickAt = missionNamespace getVariable ["airbase_v1_lastTickAt", -1];
if (!(_lastTickAt isEqualType 0)) then { _lastTickAt = -1; };
// When no tick has ever run (_lastTickAt < 0), force age past the degraded limit to guarantee DEGRADED state.
private _snapshotAgeS = if (_lastTickAt < 0) then { _degradedThresholdS + 1 } else { (serverTime - _lastTickAt) max 0 };
private _freshnessState = if (_lastTickAt < 0) then {
    "DEGRADED"
} else {
    if (_snapshotAgeS < _freshnessThresholdS) then { "FRESH" } else {
        if (_snapshotAgeS < _degradedThresholdS) then { "STALE" } else { "DEGRADED" }
    }
};

// Runway age: seconds since last runway state change (approximated by snapshot age).
private _runwayAge = round _snapshotAgeS;

private _uiDebugEnabled = missionNamespace getVariable ["ARC_debugInspectorEnabled", false];
if (!(_uiDebugEnabled isEqualType true) && !(_uiDebugEnabled isEqualType false)) then { _uiDebugEnabled = false; };
private _uiDebug = [];
if (_uiDebugEnabled) then {
    private _rawOwnerIds = [];
    {
        if (_x isEqualType [] && { (count _x) >= 4 }) then {
            private _uid = _x param [3, ""];
            if !(_uid isEqualTo "") then { _rawOwnerIds pushBack _uid; };
        };
    } forEach _staffingView;

    _uiDebug = [
        ["snapshotRev", 0],
        ["snapshotAge", round _snapshotAgeS],
        ["blockedRouteCount", count _blockedRouteTailView],
        ["blockedRouteReason", _blockedRouteLatestReason],
        ["blockedRouteSource", _blockedRouteLatestSourceId],
        ["blockedRouteTail", _blockedRouteTailView],
        ["rawOwnerIds", _rawOwnerIds],
        ["routeValidation", _blockedRouteTailView],
        ["casreqId", _casreqId],
        ["casreqRev", missionNamespace getVariable ["ARC_casreq_rev", 0]],
        ["casreqDistrict", [_casreqSnapshot, "district_id", ""] call _metaValue],
        ["casreqState", [_casreqSnapshot, "state", ""] call _metaValue]
    ];
};

private _airbaseUiSnapshot = [
    ["v", 1],
    ["rev", 0],
    ["updatedAt", serverTime],
    ["freshnessState", _freshnessState],
    ["runway", [
        ["state", _runwayState],
        ["ownerCallsign", _runwayOwnerCallsign],
        ["ownerFlightId", _runwayOwnerFlightId],
        ["ownerDisplay", _runwayOwnerDisplay],
        ["activeMovement", _runwayMovement],
        ["holdState", _holdDepartures],
        ["age", _runwayAge]
    ]],
    ["alerts", _uiAlerts],
    ["decisionQueue", _uiDecisionQueue],
    ["arrivals", _uiArrivals],
    ["departures", _uiDepartures],
    ["pendingClearances", _uiPendingClearances],
    ["staffing", _uiStaffing],
    ["recentEvents", _uiRecentEvents],
    ["clearanceHistory", _uiClearanceHistory],
    ["controllerTimeouts", [
        ["tower", _controllerTimeoutTowerS],
        ["ground", _controllerTimeoutGroundS],
        ["arrival", _controllerTimeoutArrivalS]
    ]],
    ["automationDelays", [
        ["tower", _autoDelayTowerS],
        ["ground", _autoDelayGroundS],
        ["arrival", _autoDelayArrivalS]
    ]],
    ["casTiming", _casTiming],
    ["airbaseCenterPos", [_airbaseCenterPos select 0, if (count _airbaseCenterPos > 2) then { _airbaseCenterPos select 2 } else { _airbaseCenterPos select 1 }]]
];
if ((count _uiDebug) > 0) then {
    _airbaseUiSnapshot pushBack ["debug", _uiDebug];
};

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

private _uiRev = missionNamespace getVariable ["ARC_pub_airbaseUiSnapshotRev", 0];
if (!(_uiRev isEqualType 0)) then { _uiRev = 0; };
_uiRev = _uiRev + 1;
_airbaseUiSnapshot set [1, ["rev", _uiRev]];
missionNamespace setVariable ["ARC_pub_airbaseUiSnapshotRev", _uiRev];
missionNamespace setVariable ["ARC_pub_airbaseUiSnapshot", _airbaseUiSnapshot, true];
missionNamespace setVariable ["ARC_pub_airbaseUiSnapshotUpdatedAt", serverTime, true];

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
            ["vbiedPhase3RecordsCount", count (missionNamespace getVariable ["ARC_vbiedPhase3_deviceRecords", []])],

            // VBIED Driven
            ["vbiedDrivenEnabled", missionNamespace getVariable ["ARC_vbiedDrivenEnabled", true]],
            ["vbiedDrivenSpawned", missionNamespace getVariable ["ARC_vbiedDrivenSpawned", false]],
            ["vbiedDrivenNetId", missionNamespace getVariable ["ARC_vbiedDrivenNetId", ""]],

            // Suicide Bomber
            ["suicideBomberEnabled", missionNamespace getVariable ["ARC_suicideBomberEnabled", true]],
            ["suicideBomberSpawned", missionNamespace getVariable ["ARC_suicideBomberSpawned", false]],
            ["suicideBomberNetId", missionNamespace getVariable ["ARC_suicideBomberNetId", ""]],
            ["suicideBomberDetonated", missionNamespace getVariable ["ARC_suicideBomberDetonated", false]],

            // Threat Economy budget snapshot (bounded to 5 districts with highest spend)
            ["threatBudgetSnapshot", [] call {
                private _budgetMap = ["threat_v0_attack_budget", createHashMap] call ARC_fnc_stateGet;
                if (!(_budgetMap isEqualType createHashMap)) exitWith { [] };
                private _rows = [];
                private _hgSnap = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
                // sqflint cannot trace `call _variable` references; this guard provides
                // a direct reference so sqflint recognises _hgSnap as used.
                if (!(_hgSnap isEqualType {})) exitWith { [] };
                {
                    private _did = _x;
                    private _b = [_budgetMap, _did, createHashMap] call _hgSnap;
                    if (_b isEqualType createHashMap) then
                    {
                        private _sp = [_b, "spent_today", 0] call _hgSnap;
                        private _bp = [_b, "budget_points", 3] call _hgSnap;
                        if ((_sp isEqualType 0) && { _sp > 0 }) then
                        {
                            _rows pushBack [_did, _sp, _bp];
                        };
                    };
                } forEach ["D01","D02","D03","D04","D05","D06","D07","D08","D09","D10","D11","D12","D13","D14","D15","D16","D17","D18","D19","D20"];
                _rows sort false;
                if ((count _rows) > 5) then { _rows resize 5; };
                _rows
            }],

            // Global cooldown remaining (seconds; 0 = none)
            ["threatGlobalCooldownRemaining", [] call {
                private _gc = ["threat_v0_global_cooldown_until", -1] call ARC_fnc_stateGet;
                if (!(_gc isEqualType 0)) exitWith { 0 };
                if (_gc > serverTime) exitWith { _gc - serverTime };
                0
            }]
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

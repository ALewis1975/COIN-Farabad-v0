/*
    File: functions/ambiance/fn_airbaseBuildRouteDecision.sqf
    Author: ARC / Ambient Airbase Subsystem
    Description:
      Resolves runway/lane routing + lock windows and validates marker chain legality.

    Params:
      0: STRING opKind (DEP|ARR)
      1: STRING context (AMBIENT|PLAYER)
      2: STRING sourceId (flight id, request id, etc.)

    Returns:
      [BOOL ok, ARRAY decisionMetaPairs, STRING reason]
*/

if (!isServer) exitWith {[false, [], "SERVER_ONLY"]};

params [
    ["_opKind", "", [""]],
    ["_context", "AMBIENT", [""]],
    ["_sourceId", "", [""]]
];

_opKind = toUpperANSI (trim _opKind);
_context = toUpperANSI (trim _context);
if !(_opKind in ["DEP", "ARR"]) exitWith {[false, [], "UNSUPPORTED_OP_KIND"]};
if (_context isEqualTo "") then { _context = "AMBIENT"; };

private _runwayMarker = if (_opKind isEqualTo "DEP") then {
    missionNamespace getVariable ["airbase_v1_depart_runway_marker", "R-270 Outbound"]
} else {
    missionNamespace getVariable ["airbase_v1_arrival_runway_marker", "L-270 Inbound"]
};
if (!(_runwayMarker isEqualType "") || { _runwayMarker isEqualTo "" }) then {
    _runwayMarker = if (_opKind isEqualTo "DEP") then { "R-270 Outbound" } else { "L-270 Inbound" };
};

private _ingressMarker = if (_opKind isEqualTo "DEP") then {
    missionNamespace getVariable ["airbase_v1_depart_taxi_ingress_marker", "T-R Ingress"]
} else {
    missionNamespace getVariable ["airbase_v1_arrival_taxi_ingress_marker", "T-L Ingress"]
};
private _egressMarker = if (_opKind isEqualTo "DEP") then {
    missionNamespace getVariable ["airbase_v1_depart_taxi_egress_marker", "T-R Egress"]
} else {
    missionNamespace getVariable ["airbase_v1_arrival_taxi_egress_marker", "T-L Egress"]
};

private _connectors = missionNamespace getVariable ["airbase_v1_taxi_center_connectors", ["mkr_airbaseCenter"]];
if !(_connectors isEqualType []) then { _connectors = ["mkr_airbaseCenter"]; };
private _connectorValid = _connectors select { (_x isEqualType "") && { _x isNotEqualTo "" } && { (markerShape _x) isNotEqualTo "" } };
if ((count _connectorValid) == 0) then {
    _connectorValid = ["mkr_airbaseCenter"];
};

private _pathMarkers = if (_opKind isEqualTo "DEP") then {
    [_connectorValid # 0, _ingressMarker, _runwayMarker, _egressMarker]
} else {
    [_runwayMarker, _egressMarker, _connectorValid # 0, _ingressMarker]
};

private _missing = _pathMarkers select { (_x isEqualType "") && { _x isNotEqualTo "" } && { (markerShape _x) isEqualTo "" } };
if ((count _missing) > 0) exitWith {
    [false, [["routeMissingMarkers", _missing]], "MISSING_ROUTE_MARKERS"]
};

private _laneDecision = if (_opKind isEqualTo "DEP") then { "DEPARTURE_RIGHT" } else { "APPROACH_LEFT" };
private _reserveWindow = if (_opKind isEqualTo "DEP") then {
    missionNamespace getVariable ["airbase_v1_runwayReserveWindow_dep_s", missionNamespace getVariable ["airbase_v1_runwayReserveWindow_s", 120]]
} else {
    missionNamespace getVariable ["airbase_v1_runwayReserveWindow_arr_s", missionNamespace getVariable ["airbase_v1_runwayReserveWindow_s", 120]]
};
private _occupyWindow = if (_opKind isEqualTo "DEP") then {
    missionNamespace getVariable ["airbase_v1_runwayOccupyTimeout_dep_s", missionNamespace getVariable ["airbase_v1_runwayOccupyTimeout_s", 900]]
} else {
    missionNamespace getVariable ["airbase_v1_runwayOccupyTimeout_arr_s", missionNamespace getVariable ["airbase_v1_runwayOccupyTimeout_s", 900]]
};

if (!(_reserveWindow isEqualType 0) || { _reserveWindow < 30 }) then { _reserveWindow = 120; };
if (!(_occupyWindow isEqualType 0) || { _occupyWindow < 60 }) then { _occupyWindow = 900; };

[true, [
    ["routeValid", true],
    ["routeValidationReason", "OK"],
    ["routeContext", _context],
    ["routeSourceId", _sourceId],
    ["runwayAssignmentKind", _opKind],
    ["runwayLaneDecision", _laneDecision],
    ["runwayMarker", _runwayMarker],
    ["taxiIngressMarker", _ingressMarker],
    ["taxiEgressMarker", _egressMarker],
    ["routeMarkerChain", _pathMarkers],
    ["routeCenterConnectors", _connectorValid],
    ["runwayReserveWindowS", _reserveWindow],
    ["runwayOccupyWindowS", _occupyWindow]
], "OK"]


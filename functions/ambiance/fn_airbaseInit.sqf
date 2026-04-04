/*
    File: functions/ambiance/fn_airbaseInit.sqf
    Author: ARC / Ambient Airbase Subsystem
    Description:
      Initializes airbase ambient flights. Loads taxi path capture files and builds asset runtime config.
*/

if (!isServer) exitWith {};

if (!(["airbaseInit"] call ARC_fnc_airbaseRuntimeEnabled)) exitWith {false};

private _debug = missionNamespace getVariable ["airbase_v1_debug", false];
if (!(_debug isEqualType true) && !(_debug isEqualType false)) then { _debug = false; };
missionNamespace setVariable ["airbase_v1_debug", _debug];

private _debugOps = missionNamespace getVariable ["airbase_v1_debugOpsLog", false];
if (!(_debugOps isEqualType true) && !(_debugOps isEqualType false)) then { _debugOps = false; };
missionNamespace setVariable ["airbase_v1_debugOpsLog", _debugOps];

// OPS logging (separate from debugOps). Keep this enabled by default so the Ops Log UI has airbase entries.
private _opsLogEnabled = missionNamespace getVariable ["airbase_v1_opsLogEnabled", true];
if (!(_opsLogEnabled isEqualType true) && !(_opsLogEnabled isEqualType false)) then { _opsLogEnabled = true; };
missionNamespace setVariable ["airbase_v1_opsLogEnabled", _opsLogEnabled];

// OPS log periodic status cadence (seconds)
// Default requested cadence: 2 minutes
private _opsStatusInterval = missionNamespace getVariable ["airbase_v1_opsStatusInterval_s", 120];
if (!(_opsStatusInterval isEqualType 0) || { _opsStatusInterval < 30 }) then { _opsStatusInterval = 120; };
missionNamespace setVariable ["airbase_v1_opsStatusInterval_s", _opsStatusInterval, true];

// Clearance arbitration tuning
private _controllerTimeoutS = missionNamespace getVariable ["airbase_v1_controller_timeout_s", 90];
if (!(_controllerTimeoutS isEqualType 0) || { _controllerTimeoutS < 5 }) then { _controllerTimeoutS = 90; };
missionNamespace setVariable ["airbase_v1_controller_timeout_s", _controllerTimeoutS, true];

private _controllerTimeoutTowerS = missionNamespace getVariable ["airbase_v1_controller_timeout_tower_s", _controllerTimeoutS];
if (!(_controllerTimeoutTowerS isEqualType 0) || { _controllerTimeoutTowerS < 5 }) then { _controllerTimeoutTowerS = _controllerTimeoutS; };
missionNamespace setVariable ["airbase_v1_controller_timeout_tower_s", _controllerTimeoutTowerS, true];

private _controllerTimeoutGroundS = missionNamespace getVariable ["airbase_v1_controller_timeout_ground_s", _controllerTimeoutS];
if (!(_controllerTimeoutGroundS isEqualType 0) || { _controllerTimeoutGroundS < 5 }) then { _controllerTimeoutGroundS = _controllerTimeoutS; };
missionNamespace setVariable ["airbase_v1_controller_timeout_ground_s", _controllerTimeoutGroundS, true];

private _controllerTimeoutArrivalS = missionNamespace getVariable ["airbase_v1_controller_timeout_arrival_s", _controllerTimeoutS];
if (!(_controllerTimeoutArrivalS isEqualType 0) || { _controllerTimeoutArrivalS < 5 }) then { _controllerTimeoutArrivalS = _controllerTimeoutS; };
missionNamespace setVariable ["airbase_v1_controller_timeout_arrival_s", _controllerTimeoutArrivalS, true];

private _autoDelayTowerS = missionNamespace getVariable ["airbase_v1_automation_delay_tower_s", 8];
if (!(_autoDelayTowerS isEqualType 0) || { _autoDelayTowerS < 1 }) then { _autoDelayTowerS = 8; };
missionNamespace setVariable ["airbase_v1_automation_delay_tower_s", _autoDelayTowerS, true];

private _autoDelayGroundS = missionNamespace getVariable ["airbase_v1_automation_delay_ground_s", 10];
if (!(_autoDelayGroundS isEqualType 0) || { _autoDelayGroundS < 1 }) then { _autoDelayGroundS = 10; };
missionNamespace setVariable ["airbase_v1_automation_delay_ground_s", _autoDelayGroundS, true];

private _autoDelayArrivalS = missionNamespace getVariable ["airbase_v1_automation_delay_arrival_s", 6];
if (!(_autoDelayArrivalS isEqualType 0) || { _autoDelayArrivalS < 1 }) then { _autoDelayArrivalS = 6; };
missionNamespace setVariable ["airbase_v1_automation_delay_arrival_s", _autoDelayArrivalS, true];

private _controllerFallbackEnabled = missionNamespace getVariable ["airbase_v1_controller_fallback_enabled", true];
if (!(_controllerFallbackEnabled isEqualType true) && !(_controllerFallbackEnabled isEqualType false)) then { _controllerFallbackEnabled = true; };
missionNamespace setVariable ["airbase_v1_controller_fallback_enabled", _controllerFallbackEnabled, true];

// Arrival request lifecycle + warning gates (distance to runway marker, meters)
private _arrivalRunwayMarker = missionNamespace getVariable ["airbase_v1_arrival_runway_marker", "L-270 Inbound"];
if (!(_arrivalRunwayMarker isEqualType "") || { _arrivalRunwayMarker isEqualTo "" }) then { _arrivalRunwayMarker = "L-270 Inbound"; };
missionNamespace setVariable ["airbase_v1_arrival_runway_marker", _arrivalRunwayMarker, true];

private _arrivalLandGateM = missionNamespace getVariable ["airbase_v1_arrival_land_gate_m", 2200];
if (!(_arrivalLandGateM isEqualType 0) || { _arrivalLandGateM < 200 }) then { _arrivalLandGateM = 2200; };
missionNamespace setVariable ["airbase_v1_arrival_land_gate_m", _arrivalLandGateM, true];

private _inboundStaleEscalateS = missionNamespace getVariable ["airbase_v1_inbound_stale_escalate_s", 45];
if (!(_inboundStaleEscalateS isEqualType 0) || { _inboundStaleEscalateS < 10 }) then { _inboundStaleEscalateS = 45; };
missionNamespace setVariable ["airbase_v1_inbound_stale_escalate_s", _inboundStaleEscalateS, true];

private _warnAdvisoryM = missionNamespace getVariable ["airbase_v1_arrival_warn_advisory_m", 7000];
if (!(_warnAdvisoryM isEqualType 0) || { _warnAdvisoryM < 500 }) then { _warnAdvisoryM = 7000; };
private _warnCautionM = missionNamespace getVariable ["airbase_v1_arrival_warn_caution_m", 4500];
if (!(_warnCautionM isEqualType 0) || { _warnCautionM < 300 }) then { _warnCautionM = 4500; };
private _warnUrgentM = missionNamespace getVariable ["airbase_v1_arrival_warn_urgent_m", 2600];
if (!(_warnUrgentM isEqualType 0) || { _warnUrgentM < 200 }) then { _warnUrgentM = 2600; };
if (_warnAdvisoryM < _warnCautionM) then { _warnAdvisoryM = _warnCautionM + 1000; };
if (_warnCautionM < _warnUrgentM) then { _warnCautionM = _warnUrgentM + 500; };
missionNamespace setVariable ["airbase_v1_arrival_warn_advisory_m", _warnAdvisoryM, true];
missionNamespace setVariable ["airbase_v1_arrival_warn_caution_m", _warnCautionM, true];
missionNamespace setVariable ["airbase_v1_arrival_warn_urgent_m", _warnUrgentM, true];

private _departRunwayMarker = missionNamespace getVariable ["airbase_v1_depart_runway_marker", "R-270 Outbound"];
if (!(_departRunwayMarker isEqualType "") || { _departRunwayMarker isEqualTo "" }) then { _departRunwayMarker = "R-270 Outbound"; };
missionNamespace setVariable ["airbase_v1_depart_runway_marker", _departRunwayMarker, true];

private _departTaxiEgress = missionNamespace getVariable ["airbase_v1_depart_taxi_egress_marker", "T-R Egress"];
if (!(_departTaxiEgress isEqualType "") || { _departTaxiEgress isEqualTo "" }) then { _departTaxiEgress = "T-R Egress"; };
missionNamespace setVariable ["airbase_v1_depart_taxi_egress_marker", _departTaxiEgress, true];

private _departTaxiIngress = missionNamespace getVariable ["airbase_v1_depart_taxi_ingress_marker", "T-R Ingress"];
if (!(_departTaxiIngress isEqualType "") || { _departTaxiIngress isEqualTo "" }) then { _departTaxiIngress = "T-R Ingress"; };
missionNamespace setVariable ["airbase_v1_depart_taxi_ingress_marker", _departTaxiIngress, true];

private _arrivalTaxiEgress = missionNamespace getVariable ["airbase_v1_arrival_taxi_egress_marker", "T-L Egress"];
if (!(_arrivalTaxiEgress isEqualType "") || { _arrivalTaxiEgress isEqualTo "" }) then { _arrivalTaxiEgress = "T-L Egress"; };
missionNamespace setVariable ["airbase_v1_arrival_taxi_egress_marker", _arrivalTaxiEgress, true];

private _arrivalTaxiIngress = missionNamespace getVariable ["airbase_v1_arrival_taxi_ingress_marker", "T-L Ingress"];
if (!(_arrivalTaxiIngress isEqualType "") || { _arrivalTaxiIngress isEqualTo "" }) then { _arrivalTaxiIngress = "T-L Ingress"; };
missionNamespace setVariable ["airbase_v1_arrival_taxi_ingress_marker", _arrivalTaxiIngress, true];

private _taxiConnectors = missionNamespace getVariable ["airbase_v1_taxi_center_connectors", ["mkr_airbaseCenter"]];
if !(_taxiConnectors isEqualType []) then { _taxiConnectors = ["mkr_airbaseCenter"]; };
private _taxiConnectorsNorm = [];
{
    if (_x isEqualType "" && { !(_x isEqualTo "") }) then { _taxiConnectorsNorm pushBackUnique _x; };
} forEach _taxiConnectors;
if ((count _taxiConnectorsNorm) == 0) then { _taxiConnectorsNorm = ["mkr_airbaseCenter"]; };
missionNamespace setVariable ["airbase_v1_taxi_center_connectors", _taxiConnectorsNorm, true];

private _reserveDepS = missionNamespace getVariable ["airbase_v1_runwayReserveWindow_dep_s", missionNamespace getVariable ["airbase_v1_runwayReserveWindow_s", 120]];
if (!(_reserveDepS isEqualType 0) || { _reserveDepS < 30 }) then { _reserveDepS = 120; };
missionNamespace setVariable ["airbase_v1_runwayReserveWindow_dep_s", _reserveDepS, true];

private _reserveArrS = missionNamespace getVariable ["airbase_v1_runwayReserveWindow_arr_s", missionNamespace getVariable ["airbase_v1_runwayReserveWindow_s", 120]];
if (!(_reserveArrS isEqualType 0) || { _reserveArrS < 30 }) then { _reserveArrS = 120; };
missionNamespace setVariable ["airbase_v1_runwayReserveWindow_arr_s", _reserveArrS, true];

private _occupyDepS = missionNamespace getVariable ["airbase_v1_runwayOccupyTimeout_dep_s", missionNamespace getVariable ["airbase_v1_runwayOccupyTimeout_s", 900]];
if (!(_occupyDepS isEqualType 0) || { _occupyDepS < 60 }) then { _occupyDepS = 900; };
missionNamespace setVariable ["airbase_v1_runwayOccupyTimeout_dep_s", _occupyDepS, true];

private _occupyArrS = missionNamespace getVariable ["airbase_v1_runwayOccupyTimeout_arr_s", missionNamespace getVariable ["airbase_v1_runwayOccupyTimeout_s", 900]];
if (!(_occupyArrS isEqualType 0) || { _occupyArrS < 60 }) then { _occupyArrS = 900; };
missionNamespace setVariable ["airbase_v1_runwayOccupyTimeout_arr_s", _occupyArrS, true];

private _inboundTaxiMarkers = missionNamespace getVariable ["airbase_v1_inbound_taxi_markers", ["L-270 Inbound", "T-L Egress", "T-L Ingress"]];
if !(_inboundTaxiMarkers isEqualType []) then { _inboundTaxiMarkers = ["L-270 Inbound", "T-L Egress", "T-L Ingress"]; };
private _inboundTaxiMarkersNorm = [];
{
    if (_x isEqualType "" && { !(_x isEqualTo "") }) then { _inboundTaxiMarkersNorm pushBackUnique _x; };
} forEach _inboundTaxiMarkers;
if ((count _inboundTaxiMarkersNorm) == 0) then { _inboundTaxiMarkersNorm = ["L-270 Inbound", "T-L Egress", "T-L Ingress"]; };
missionNamespace setVariable ["airbase_v1_inbound_taxi_markers", _inboundTaxiMarkersNorm, true];

// Debug-only test mode: bypass tower-controller detection and force AI arbitration.
private _forceAiOnly = missionNamespace getVariable ["airbase_v1_debug_forceAiOnly", false];
if (!(_forceAiOnly isEqualType true) && !(_forceAiOnly isEqualType false)) then { _forceAiOnly = false; };
missionNamespace setVariable ["airbase_v1_debug_forceAiOnly", _forceAiOnly, true];

private _towerStaffing = ["airbase_v1_towerStaffing", []] call ARC_fnc_stateGet;
if (!(_towerStaffing isEqualType [])) then { _towerStaffing = []; };

private _normalizeLane = {
    params ["_rows", "_lane"];
    private _idx = -1;
    private _idxFound = false;
    {
        if (!_idxFound && { (_x isEqualType []) && { (count _x) >= 5 } && { ((_x param [0, ""]) isEqualTo _lane) } }) then
        {
            _idx = _forEachIndex;
            _idxFound = true;
        };
    } forEach _rows;
    if (_idx < 0) then {
        _rows pushBack [_lane, "AUTO", "", "", -1];
    };
};

[_towerStaffing, "tower"] call _normalizeLane;
[_towerStaffing, "ground"] call _normalizeLane;
[_towerStaffing, "arrival"] call _normalizeLane;
["airbase_v1_towerStaffing", _towerStaffing] call ARC_fnc_stateSet;

// Departure runway markers (fixed-wing)
// RW departures already use airbase_v1_rw_depart_outbound_marker / _clear_marker.
// FW uses its own vars so we can split later if needed.
private _fwOut = missionNamespace getVariable ["airbase_v1_fw_depart_outbound_marker", "AEON_Right_270_Outbound"];
if (!(_fwOut isEqualType "") || { _fwOut isEqualTo "" }) then { _fwOut = "AEON_Right_270_Outbound"; };
missionNamespace setVariable ["airbase_v1_fw_depart_outbound_marker", _fwOut, true];

private _fwClr = missionNamespace getVariable ["airbase_v1_fw_depart_outbound_clear_marker", "AEON_Right_270_Outbound_Clear"];
if (!(_fwClr isEqualType "") || { _fwClr isEqualTo "" }) then { _fwClr = "AEON_Right_270_Outbound_Clear"; };
missionNamespace setVariable ["airbase_v1_fw_depart_outbound_clear_marker", _fwClr, true];

// Fallback runway run distance (meters) if the "..._Clear" marker doesn't exist yet.
private _fwFallback = missionNamespace getVariable ["airbase_v1_fw_depart_outbound_clear_fallback_m", 1400];
if (!(_fwFallback isEqualType 0) || { _fwFallback < 200 }) then { _fwFallback = 1400; };
missionNamespace setVariable ["airbase_v1_fw_depart_outbound_clear_fallback_m", _fwFallback, true];

// Rotary-wing departure tuning
private _rwHoverM = missionNamespace getVariable ["airbase_v1_rw_taxi_hover_m", 1.5];
if (!(_rwHoverM isEqualType 0) || { _rwHoverM < 0 }) then { _rwHoverM = 1.5; };
missionNamespace setVariable ["airbase_v1_rw_taxi_hover_m", _rwHoverM];

private _rwAltLow = missionNamespace getVariable ["airbase_v1_rw_takeoff_alt_low_m", 3];
if (!(_rwAltLow isEqualType 0) || { _rwAltLow < 0 }) then { _rwAltLow = 3; };
missionNamespace setVariable ["airbase_v1_rw_takeoff_alt_low_m", _rwAltLow];

private _rwAltCruise = missionNamespace getVariable ["airbase_v1_rw_depart_alt_m", 152];
if (!(_rwAltCruise isEqualType 0) || { _rwAltCruise < 20 }) then { _rwAltCruise = 152; };
missionNamespace setVariable ["airbase_v1_rw_depart_alt_m", _rwAltCruise];

// Helo runway climb trigger distance (meters) from outbound marker before we force the climb.
private _rwClimbTrig = missionNamespace getVariable ["airbase_v1_rw_climb_trigger_dist_m", 15];
if (!(_rwClimbTrig isEqualType 0) || { _rwClimbTrig < 3 }) then { _rwClimbTrig = 15; };
missionNamespace setVariable ["airbase_v1_rw_climb_trigger_dist_m", _rwClimbTrig];

private _rwMkrOut = missionNamespace getVariable ["airbase_v1_rw_outbound_marker", "AEON_Right_270_Outbound"]; 
if (!(_rwMkrOut isEqualType "")) then { _rwMkrOut = "AEON_Right_270_Outbound"; };
missionNamespace setVariable ["airbase_v1_rw_outbound_marker", _rwMkrOut];

private _rwMkrClear = missionNamespace getVariable ["airbase_v1_rw_outbound_clear_marker", "AEON_Right_270_Outbound_Clear"]; 
if (!(_rwMkrClear isEqualType "")) then { _rwMkrClear = "AEON_Right_270_Outbound_Clear"; };
missionNamespace setVariable ["airbase_v1_rw_outbound_clear_marker", _rwMkrClear];

private _turnMin = missionNamespace getVariable ["airbase_v1_turnaroundMin_s", 1200];
if (!(_turnMin isEqualType 0) || { _turnMin < 0 }) then { _turnMin = 1200; };
missionNamespace setVariable ["airbase_v1_turnaroundMin_s", _turnMin];

private _turnJit = missionNamespace getVariable ["airbase_v1_turnaroundJit_s", 1200];
if (!(_turnJit isEqualType 0) || { _turnJit < 0 }) then { _turnJit = 1200; };
missionNamespace setVariable ["airbase_v1_turnaroundJit_s", _turnJit];

// Return-flight probability (0..1). Most arrivals should be RANDOM; keep RETURN flights rare.
private _pReturn = missionNamespace getVariable ["airbase_v1_p_return", 0.15];
if (!(_pReturn isEqualType 0) || { _pReturn < 0 } || { _pReturn > 1 }) then { _pReturn = 0.15; };
missionNamespace setVariable ["airbase_v1_p_return", _pReturn, true];

// Diary tracking (client): create/update an "Airbase" diary subject with queue snapshots
private _diaryEnabled = missionNamespace getVariable ["airbase_v1_diaryEnabled", true];
if (!(_diaryEnabled isEqualType true) && !(_diaryEnabled isEqualType false)) then { _diaryEnabled = true; };
missionNamespace setVariable ["airbase_v1_diaryEnabled", _diaryEnabled, true];

// Tunables (retain existing variables so older mission params still work)
private _tickS = missionNamespace getVariable ["airbase_v1_tick_s", 2];
if (!(_tickS isEqualType 0) || { _tickS < 0.25 }) then { _tickS = 2; };
missionNamespace setVariable ["airbase_v1_tick_s", _tickS];

private _pDepartFW = missionNamespace getVariable ["airbase_v1_p_depart_hour_fw", 0.25];
private _pArriveFW = missionNamespace getVariable ["airbase_v1_p_arrive_hour_fw", 0.40];
private _pDepartRW = missionNamespace getVariable ["airbase_v1_p_depart_hour_rw", 0.30];
private _pArriveRW = missionNamespace getVariable ["airbase_v1_p_arrive_hour_rw", 0.45];
missionNamespace setVariable ["airbase_v1_p_depart_hour_fw", _pDepartFW];
missionNamespace setVariable ["airbase_v1_p_arrive_hour_fw", _pArriveFW];
missionNamespace setVariable ["airbase_v1_p_depart_hour_rw", _pDepartRW];
missionNamespace setVariable ["airbase_v1_p_arrive_hour_rw", _pArriveRW];

private _cdDep = missionNamespace getVariable ["airbase_v1_depart_cooldown_s", 900];
private _cdArr = missionNamespace getVariable ["airbase_v1_arrive_cooldown_s", 1200];
missionNamespace setVariable ["airbase_v1_depart_cooldown_s", _cdDep];
missionNamespace setVariable ["airbase_v1_arrive_cooldown_s", _cdArr];

private _firstDelay = missionNamespace getVariable ["airbase_v1_firstDepartureDelayS", missionNamespace getVariable ["airbase_v1_firstDepartureDelay_s", 300]];
missionNamespace setVariable ["airbase_v1_firstDepartureDelayS", _firstDelay, true];
missionNamespace setVariable ["airbase_v1_firstDepartureDelay_s", _firstDelay, true];

// Markers (do not hard-fail if missing; tick will just no-op)
missionNamespace setVariable ["airbase_v1_plane_despawn_marker", "plane_despawn"];

// Load taxi path files into missionNamespace variables
private _pathFiles = [
    "data\paths\taxiPath.sqf",
    "data\paths\taxiPath_plane2.sqf",
    "data\paths\taxiPath_plane3.sqf",
    "data\paths\attackTaxiPath_plane4.sqf",
    "data\paths\attackTaxiPath_plane5.sqf",
    "data\paths\taxiPath_plane7.sqf",
    "data\paths\towPath_plane4.sqf",
    "data\paths\towPath_plane5.sqf",
    // Rotary-wing taxi paths
    "data\paths\taxiPath_AH_64D_01.sqf",
    "data\paths\taxiPath_CH_47F_01.sqf",
    "data\paths\taxiPath_UH_60M_01.sqf"
];

{
    private _path = _x;
    if (_debug) then { diag_log format ["[AIRBASESUB] Loading path: %1", _path]; };
    call compile preprocessFileLineNumbers _path;
} forEach _pathFiles;

// Build asset definitions
// [id, category, vehVar, crewVars[], taxiPathVar, pathFile, requiresTow, towVehVar, towCrewVar, towPathVar, towReleaseMarker, towReturnMarker]
private _assetDefs = [
    ["FW-C17-REACH101",   "FW", "plane1", ["plane1D","plane1G"], "taxiPathData",        "data\paths\taxiPath.sqf",        false, "",     "",     "",                   "",              ""],
    ["FW-KC135-SHELL101", "FW", "plane2", ["plane2D","plane2G"], "taxiPathData_plane2", "data\paths\taxiPath_plane2.sqf", false, "",     "",     "",                   "",              ""],
    ["FW-C130J-JAKAL101", "FW", "plane3", ["plane3D","plane3G"], "taxiPathData_plane3", "data\paths\taxiPath_plane3.sqf", false, "",     "",     "",                   "",              ""],
    ["FW-A10-WARTHOG11",  "FW", "plane4", ["plane4D"], "taxiPathData_plane4", "data\paths\attackTaxiPath_plane4.sqf", true,  "tug4", "tug4D", "towPathData_plane4", "", ""],
    ["FW-A10-WARTHOG12",  "FW", "plane5", ["plane5D"], "taxiPathData_plane5", "data\paths\attackTaxiPath_plane5.sqf", true,  "tug5", "tug5D", "towPathData_plane5","", ""],
    ["FW-EC130-SNITCH11", "FW", "plane7", ["plane7D","plane7G"], "taxiPathData_plane7", "data\paths\taxiPath_plane7.sqf", false, "",     "",     "",                   "",              ""],

    // Rotary-wing (treat the same as fixed-wing for scheduling + return arrivals)
    ["RW-AH64D-01",       "RW", "AH_64D_01", ["AH_64D_01D","AH_64D_01G"], "taxiPathData_AH_64D_01", "data\paths\taxiPath_AH_64D_01.sqf", false, "", "", "", "", ""],
    ["RW-CH47F-01",       "RW", "CH_47F_01", ["CH_47F_01D","CH_47F_01CP","CH_47F_01CC","CH_47F_01DD"], "taxiPathData_CH_47F_01", "data\paths\taxiPath_CH_47F_01.sqf", false, "", "", "", "", ""],
    ["RW-UH60M-01",       "RW", "UH_60M_01", ["UH_60M_01D","UH_60M_01CP","UH_60M_01CC","UH_60M_01DG"], "taxiPathData_UH_60M_01", "data\paths\taxiPath_UH_60M_01.sqf", false, "", "", "", "", ""]
];

private _assets = [];

{
    _x params ["_id", "_category", "_vehVar", "_crewVars", "_taxiPathVar", "", "_requiresTow", "_towVehVar", "_towCrewVar", "_towPathVar", "_towReleaseMarker", "_towReturnMarker"];

    private _veh = missionNamespace getVariable [_vehVar, objNull];
    if (isNull _veh) then {
        if (_debug) then { diag_log format ["[AIRBASESUB] Asset %1 missing vehicle var %2", _id, _vehVar]; };
        continue;
    };

    private _crewResolved = [];
    private _crewTemplates = [];
    private _crewStartPos = [];
    private _crewStartDir = [];
    private _crewSide = west;

    {
        private _cv = _x;
        private _u = missionNamespace getVariable [_cv, objNull];
        _crewResolved pushBack _u;

        if (!isNull _u) then {
            _crewSide = side (group _u);
            _crewTemplates pushBack [_cv, typeOf _u, getUnitLoadout _u, getPosATL _u, getDir _u];
            _crewStartPos pushBack (getPosATL _u);
            _crewStartDir pushBack (getDir _u);
        } else {
            // Missing crew var in Eden. Do not create a spawn template here (prevents origin spawns on return).
            if (_debug) then { diag_log format ["[AIRBASESUB] Asset %1 missing crew var %2", _id, _cv]; };

            // Keep arrays aligned with crewVars (use vehicle start as a harmless placeholder).
            _crewStartPos pushBack (getPosATL _veh);
            _crewStartDir pushBack (getDir _veh);
        };
    } forEach _crewVars;

    private _towVeh = objNull;
    private _towCrew = objNull;
    private _towStartPos = [0,0,0];
    private _towStartDir = 0;
    private _towCrewStartPos = [0,0,0];
    private _towCrewStartDir = 0;

    if (_requiresTow) then {
        _towVeh = missionNamespace getVariable [_towVehVar, objNull];
        _towCrew = missionNamespace getVariable [_towCrewVar, objNull];
        if (!isNull _towCrew) then {
            _towCrewStartPos = getPosATL _towCrew;
            _towCrewStartDir = getDir _towCrew;
        };
        if (!isNull _towVeh) then {
            _towStartPos = getPosATL _towVeh;
            _towStartDir = getDir _towVeh;
        };
    };

    private _asset = createHashMap;
    _asset set ["id", _id];
    _asset set ["category", _category];
    _asset set ["vehVar", _vehVar];
    _asset set ["veh", _veh];
    _asset set ["crewVars", _crewVars];
    _asset set ["crew", _crewResolved];
    _asset set ["crewSide", _crewSide];
    _asset set ["crewTemplates", _crewTemplates];
    _asset set ["crewStartPos", _crewStartPos];
    _asset set ["crewStartDir", _crewStartDir];

    _asset set ["taxiPathVar", _taxiPathVar];
    _asset set ["requiresTow", _requiresTow];
    _asset set ["towVehVar", _towVehVar];
    _asset set ["towVeh", _towVeh];
    _asset set ["towCrewVar", _towCrewVar];
    _asset set ["towCrew", _towCrew];
    _asset set ["towPathVar", _towPathVar];
    _asset set ["towReleaseMarker", _towReleaseMarker];
    _asset set ["towReturnMarker", _towReturnMarker];
    _asset set ["towStartPos", _towStartPos];
    _asset set ["towStartDir", _towStartDir];
    _asset set ["towCrewStartPos", _towCrewStartPos];
    _asset set ["towCrewStartDir", _towCrewStartDir];

    _asset set ["state", "PARKED"];
    _asset set ["activeFlight", ""];
    _asset set ["availableAt", 0];

    _asset set ["startVehType", typeOf _veh];
    _asset set ["startPos", getPosATL _veh];
    _asset set ["startDir", getDir _veh];
    _asset set ["startVecUp", vectorUp _veh];

    // Disable assets with missing/empty taxi paths (prevents the scheduler from selecting them)
    private _taxiData = missionNamespace getVariable [_taxiPathVar, []];
    if (!(_taxiData isEqualType []) || { (count _taxiData) == 0 }) then {
        _asset set ["state", "DISABLED"];
        if (_opsLogEnabled || _debugOps) then {
            ["OPS", format ["AIRBASE: disabled %1 (empty taxi path var: %2)", _id, _taxiPathVar], getPosATL _veh, getDir _veh, [
                ["assetId", _id],
                ["taxiPathVar", _taxiPathVar]
            ]] call ARC_fnc_intelLog;
        };
    };

    // Start idle animations on visible flightline staff
    [_crewResolved] call ARC_fnc_airbaseCrewIdleStart;
    if (!isNull _towCrew) then { [[_towCrew]] call ARC_fnc_airbaseCrewIdleStart; };

    _assets pushBack _asset;
} forEach _assetDefs;

// Runtime config (server authoritative)
private _rt = createHashMap;
_rt set ["initialized", true];
_rt set ["startTs", serverTime];
_rt set ["lastTickTs", -1];
_rt set ["bubbleActive", false];
_rt set ["bubbleCenter", getMarkerPos "mkr_airbaseCenter"];
_rt set ["bubbleRadius", 2500];

_rt set ["lastDepartTs", -1e9];
_rt set ["lastArriveTs", -1e9];
_rt set ["firstDepartureDone", false];

_rt set ["turnaroundMinS", _turnMin];
_rt set ["turnaroundJitS", _turnJit];

// Arrivals config
_rt set ["airportId", 0];
_rt set ["arrivalSpawnMarker", "mkr_arrivalSpawn"];
_rt set ["arrivalRunwayStartMarker", "mkr_arrivalRunwayStart"];
_rt set ["arrivalRunwayStopMarker", "mkr_arrivalRunwayStop"];
_rt set ["arrivalRunwayTaxiOutMarker", "mkr_arrivalRunwayTaxiOut"];
_rt set ["inboundTaxiMarkers", missionNamespace getVariable ["airbase_v1_inbound_taxi_markers", ["L-270 Inbound", "T-L Egress", "T-L Ingress"]]];
_rt set ["arrivalRunwayMarker", missionNamespace getVariable ["airbase_v1_arrival_runway_marker", "L-270 Inbound"]];
_rt set ["runwayStateContract", ["OPEN", "RESERVED", "OCCUPIED"]];

_rt set ["assets", _assets];

missionNamespace setVariable ["airbase_v1_rt", _rt, true];
missionNamespace setVariable ["airbase_v1_execActive", false, true];
missionNamespace setVariable ["airbase_v1_execFid", "", true];

// Server-authored runway lock state.
missionNamespace setVariable ["airbase_v1_runwayState", "OPEN", true];
missionNamespace setVariable ["airbase_v1_runwayOwner", "", true];
missionNamespace setVariable ["airbase_v1_runwayUntil", -1, true];

// State store init (records/queue/seq)
["airbase_v1_records", []] call ARC_fnc_stateSet;
["airbase_v1_queue", []] call ARC_fnc_stateSet;
["airbase_v1_seq", 0] call ARC_fnc_stateSet;
["airbase_v1_holdDepartures", false] call ARC_fnc_stateSet;
["airbase_v1_manualPriority", []] call ARC_fnc_stateSet;

// ---------------------------------------------------------------------------
// Departure seed: queue initial departures visible on first console load.
// Only runs when queue is currently empty (fresh init; guards against rehydrated state).
// ---------------------------------------------------------------------------
private _initSeedQueue = ["airbase_v1_queue", []] call ARC_fnc_stateGet;
if (!(_initSeedQueue isEqualType [])) then { _initSeedQueue = []; };

if ((count _initSeedQueue) == 0) then
{
    // HashMap field accessor (compile-wrapped so sqflint does not flag map `get` calls)
    private _hmGet = compile "params ['_h','_k','_d']; private _v = _h get _k; if (isNil '_v') exitWith {_d}; _v";

    private _nowTs = serverTime;
    private _initSeq = ["airbase_v1_seq", 0] call ARC_fnc_stateGet;
    if (!(_initSeq isEqualType 0)) then { _initSeq = 0; };
    private _initRecs = ["airbase_v1_records", []] call ARC_fnc_stateGet;
    if (!(_initRecs isEqualType [])) then { _initRecs = []; };

    // FID generator – mirrors fn_airbaseTick.sqf _fn_nextId logic.
    private _fnInitId = {
        _initSeq = _initSeq + 1;
        ["airbase_v1_seq", _initSeq] call ARC_fnc_stateSet;
        private _s = str _initSeq;
        while { (count _s) < 4 } do { _s = "0" + _s; };
        format ["FLT-%1", _s]
    };

    // Filter: PARKED assets only (state "PARKED" excludes "DISABLED" and in-flight states).
    private _parkedAssets = _assets select {
        ([_x, "state", "PARKED"] call _hmGet) isEqualTo "PARKED"
    };

    // Bias: for seed departures, avoid tow-required assets and EC-130 (plane7) if alternatives exist.
    private _preferAssets = _parkedAssets select {
        !([_x, "requiresTow", false] call _hmGet) && { !(([_x, "vehVar", ""] call _hmGet) isEqualTo "plane7") }
    };
    if ((count _preferAssets) > 0) then { _parkedAssets = _preferAssets; };

    // Select up to 2 FW and 1 RW from the filtered pool.
    private _fwPool = _parkedAssets select { ([_x, "category", "FW"] call _hmGet) isEqualTo "FW" };
    private _rwPool = _parkedAssets select { ([_x, "category", "FW"] call _hmGet) isEqualTo "RW" };

    private _seedAssets = [];
    private _fwRemaining = + _fwPool; // shallow copy so we can remove picked entries without modifying the original pool
    private _fwPicked = 0;
    while { _fwPicked < 2 && { (count _fwRemaining) > 0 } } do {
        private _pick = selectRandom _fwRemaining;
        _seedAssets pushBack _pick;
        _fwPicked = _fwPicked + 1;
        private _pickId = [_pick, "id", ""] call _hmGet;
        _fwRemaining = _fwRemaining select { !(([_x, "id", ""] call _hmGet) isEqualTo _pickId) };
    };

    if ((count _rwPool) > 0) then
    {
        _seedAssets pushBack (selectRandom _rwPool);
    };

    private _seedDepCount = 0;
    {
        private _seedAsset = _x;
        private _fid = call _fnInitId;
        private _cat = [_seedAsset, "category", "FW"] call _hmGet;
        private _aid = [_seedAsset, "id", ""] call _hmGet;
        private _startVehType = [_seedAsset, "startVehType", ""] call _hmGet;

        private _routeDecision = ["DEP", "AMBIENT", _fid] call ARC_fnc_airbaseBuildRouteDecision;
        private _routeOk = _routeDecision param [0, false];
        private _routeMeta = _routeDecision param [1, []];

        if (!_routeOk) then
        {
            diag_log format ["[AIRBASESUB] Seed: route decision failed for %1 (%2).", _fid, _aid];
        }
        else
        {
            private _rec = [
                _fid, _nowTs,
                "DEP", _cat,
                _aid,
                "QUEUED",
                _nowTs,
                [["mode", "DEPART"], ["assetId", _aid], ["vehType", _startVehType], ["source", "INIT_SEED"]]
            ];
            _initRecs pushBack _rec;
            _initSeedQueue pushBack [_fid, "DEP", _aid, _routeMeta];
            _seedDepCount = _seedDepCount + 1;
            diag_log format ["[AIRBASESUB] Seed departure queued: %1 (%2)", _fid, _aid];
        };
    } forEach _seedAssets;

    if (_seedDepCount > 0) then
    {
        ["airbase_v1_queue", _initSeedQueue] call ARC_fnc_stateSet;
        ["airbase_v1_records", _initRecs] call ARC_fnc_stateSet;
        ["airbase_v1_seq", _initSeq] call ARC_fnc_stateSet;
        _rt set ["firstDepartureDone", true];
        missionNamespace setVariable ["airbase_v1_rt", _rt, true];
    };
};

if (_opsLogEnabled || _debugOps) then {
    ["OPS", format ["AIRBASE: init complete (%1 assets)", count _assets], getMarkerPos "mkr_airbaseCenter", 0, [
        ["tick_s", _tickS],
        ["turnMin_s", _turnMin],
        ["turnJit_s", _turnJit]
    ]] call ARC_fnc_intelLog;
};

// Start the ticking loop
[] spawn {
    private _tick = missionNamespace getVariable ["airbase_v1_tick_s", 2];
    while { true } do {
        [] call ARC_fnc_airbaseTick;
        sleep _tick;
        _tick = missionNamespace getVariable ["airbase_v1_tick_s", 2];
    };
};

/*
    ARC_fnc_uiConsoleAirPaint

    Paint AIR / TOWER from ARC_pub_airbaseUiSnapshot.
*/

if (!hasInterface) exitWith {false};

params [
    ["_display", displayNull, [displayNull]],
    ["_rebuild", false, [true]]
];
if (isNull _display) exitWith {false};

private _ctrlList = _display displayCtrl 78011;
private _ctrlDetails = _display displayCtrl 78012;
private _btnPrimary = _display displayCtrl 78021;
private _btnSecondary = _display displayCtrl 78022;
if (isNull _ctrlList || { isNull _ctrlDetails }) exitWith {false};

private _owner = uiNamespace getVariable ["ARC_console_mainListOwner", ""];
if (!(_owner isEqualType "")) then { _owner = ""; };
_owner = toUpper _owner;
if !(_owner isEqualTo "AIR") then { _rebuild = true; };
if ((lbSize _ctrlList) <= 0) then { _rebuild = true; };
uiNamespace setVariable ["ARC_console_mainListOwner", "AIR"];

private _getPair = {
    params ["_pairs", "_k", "_def"];
    private _v = _def;
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { ((_x select 0)) isEqualTo _k }) exitWith {
            _v = _x select 1;
        };
    } forEach _pairs;
    _v
};

private _metaGet = {
    params ["_meta", "_k", "_def"];
    private _v = _def;
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { ((_x select 0)) isEqualTo _k }) exitWith {
            _v = _x select 1;
        };
    } forEach _meta;
    _v
};

private _findById = {
    params ["_rows", "_id"];
    private _out = [];
    {
        if (_x isEqualType [] && { (_x param [0, ""]) isEqualTo _id }) exitWith { _out = _x; };
    } forEach _rows;
    _out
};

private _trimFn = compile "params ['_s']; trim _s";

private _fmtAgo = {
    params ["_t"];
    if (!(_t isEqualType 0) || { _t < 0 }) exitWith { "-" };
    private _age = (serverTime - _t) max 0;
    if (_age < 5) exitWith { "just now" };
    if (_age < 60) exitWith { format ["%1s ago", round _age] };
    format ["%1m %2s ago", floor (_age / 60), (round _age) mod 60]
};

private _fmtSeconds = {
    params ["_v"];
    if (!(_v isEqualType 0) || { _v < 0 }) exitWith { "-" };
    if (_v < 60) exitWith { format ["%1s", round _v] };
    format ["%1m %2s", floor (_v / 60), (round _v) mod 60]
};

private _cleanAirText = {
    params ["_value", ["_default", ""]];
    if !(_value isEqualType "") then { _value = str _value; };
    private _out = [_value] call _trimFn;
    if (_out isEqualTo "") exitWith { _default };
    _out
};

private _isOpaqueAirId = {
    params ["_value"];
    private _txt = toUpper ([_value, ""] call _cleanAirText);
    if (_txt isEqualTo "") exitWith { true };
    ((_txt find "FLT-") == 0) || { ((_txt find "CLR-") == 0) || { ((_txt find "REQ-") == 0) } }
};

private _flightLabel = {
    params [
        ["_fid", "", [""]],
        ["_callsign", "", [""]],
        ["_category", "", [""]]
    ];

    private _fidLabel = [_fid, "UNKNOWN"] call _cleanAirText;
    private _callsignLabel = [_callsign, ""] call _cleanAirText;
    private _categoryLabel = [_category, ""] call _cleanAirText;
    private _hasCallsign = !([_callsignLabel] call _isOpaqueAirId);
    private _hasValidCategory = !(_categoryLabel isEqualTo "") && { !(_categoryLabel isEqualTo "-") };

    if (_hasCallsign && { _hasValidCategory }) exitWith {
        format ["%1 (%2)", _callsignLabel, _categoryLabel]
    };
    if (_hasCallsign) exitWith { _callsignLabel };
    if (_hasValidCategory) exitWith {
        format ["%1 / %2", _categoryLabel, _fidLabel]
    };
    if (_callsignLabel isEqualTo "") exitWith { _fidLabel };
    format ["%1 / %2", _callsignLabel, _fidLabel]
};

private _requestTypeLabel = {
    params ["_requestType"];
    private _rt = toUpper ([_requestType, "REQUEST"] call _cleanAirText);
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

private _modeSummary = {
    params ["_mode"];
    switch (toUpper _mode) do
    {
        case "CLEARANCES": { "Clearance decisions" };
        case "DEBUG": { "Debug telemetry" };
        default { "Airfield operations" };
    }
};

private _modeGuidance = {
    params ["_mode"];
    switch (toUpper _mode) do
    {
        case "CLEARANCES": { "Approve or deny requests, manage departures, and assign controller lanes." };
        case "DEBUG": { "Snapshot internals, route failures, and controller telemetry." };
        default { "Runway status, inbound and outbound traffic, and immediate risks at a glance." };
    }
};

private _statusColor = {
    params ["_status"];
    private _s = toUpper _status;
    if (_s in ["CRITICAL", "CONFLICT", "BLOCKED", "HOLD", "OCCUPIED", "RED", "DEGRADED"]) exitWith { "#E74C3C" };
    if (_s in ["CAUTION", "HOLDING", "RESERVED", "PRIORITY", "STALE", "AMBER", "DELAYED"]) exitWith { "#F5A623" };
    "#4CAF50"
};

private _cycleModes = {
    params ["_current", "_canControl", "_debugEnabled"];
    private _modes = ["AIRFIELD_OPS"];
    if (_canControl) then { _modes pushBack "CLEARANCES"; };
    if (_debugEnabled) then { _modes pushBack "DEBUG"; };
    private _idx = _modes find _current;
    if (_idx < 0) exitWith { _modes select 0 };
    _modes select ((_idx + 1) mod (count _modes))
};

private _snapshot = missionNamespace getVariable ["ARC_pub_airbaseUiSnapshot", []];
if (!(_snapshot isEqualType [])) then { _snapshot = []; };
private _stateUpdatedAt = missionNamespace getVariable ["ARC_pub_airbaseUiSnapshotUpdatedAt", -1];
if (!(_stateUpdatedAt isEqualType 0)) then { _stateUpdatedAt = -1; };
private _lastStateUpdatedAt = uiNamespace getVariable ["ARC_console_airLastStateUpdatedAt", -2];
if (!(_lastStateUpdatedAt isEqualType 0)) then { _lastStateUpdatedAt = -2; };
if (_stateUpdatedAt != _lastStateUpdatedAt) then { _rebuild = true; };

private _prevSelData = "";
if (_rebuild) then {
    private _prevSel = lbCurSel _ctrlList;
    if (_prevSel >= 0) then {
        _prevSelData = _ctrlList lbData _prevSel;
        if (!(_prevSelData isEqualType "")) then { _prevSelData = ""; };
    };
};

private _runway = [_snapshot, "runway", []] call _getPair;
if (!(_runway isEqualType [])) then { _runway = []; };
private _alerts = [_snapshot, "alerts", []] call _getPair;
if (!(_alerts isEqualType [])) then { _alerts = []; };
private _decisionQueue = [_snapshot, "decisionQueue", []] call _getPair;
if (!(_decisionQueue isEqualType [])) then { _decisionQueue = []; };
private _arrivals = [_snapshot, "arrivals", []] call _getPair;
if (!(_arrivals isEqualType [])) then { _arrivals = []; };
private _departures = [_snapshot, "departures", []] call _getPair;
if (!(_departures isEqualType [])) then { _departures = []; };
private _pendingClearances = [_snapshot, "pendingClearances", []] call _getPair;
if (!(_pendingClearances isEqualType [])) then { _pendingClearances = []; };
private _staffing = [_snapshot, "staffing", []] call _getPair;
if (!(_staffing isEqualType [])) then { _staffing = []; };
private _recentEvents = [_snapshot, "recentEvents", []] call _getPair;
if (!(_recentEvents isEqualType [])) then { _recentEvents = []; };
private _clearanceHistory = [_snapshot, "clearanceHistory", []] call _getPair;
if (!(_clearanceHistory isEqualType [])) then { _clearanceHistory = []; };
private _timeouts = [_snapshot, "controllerTimeouts", []] call _getPair;
if (!(_timeouts isEqualType [])) then { _timeouts = []; };
private _delays = [_snapshot, "automationDelays", []] call _getPair;
if (!(_delays isEqualType [])) then { _delays = []; };
private _casTiming = [_snapshot, "casTiming", []] call _getPair;
if (!(_casTiming isEqualType [])) then { _casTiming = []; };
private _debug = [_snapshot, "debug", []] call _getPair;
if (!(_debug isEqualType [])) then { _debug = []; };

private _runwayState = [_runway, "state", "UNKNOWN"] call _getPair;
private _runwayOwner = [_runway, "ownerCallsign", ""] call _getPair;
private _runwayOwnerFlightId = [_runway, "ownerFlightId", ""] call _getPair;
private _runwayOwnerDisplay = [_runway, "ownerDisplay", ""] call _getPair;
private _activeMovement = [_runway, "activeMovement", "CLEAR"] call _getPair;
private _holdDepartures = [_runway, "holdState", false] call _getPair;
if (!(_holdDepartures isEqualType true) && !(_holdDepartures isEqualType false)) then { _holdDepartures = false; };
private _hasRunwayOwnerData = !(_runwayOwnerFlightId isEqualTo "") || { !(_runwayOwner isEqualTo "") };
if (_runwayOwnerDisplay isEqualTo "" && { _hasRunwayOwnerData }) then {
    _runwayOwnerDisplay = [_runwayOwnerFlightId, _runwayOwner, ""] call _flightLabel;
};
uiNamespace setVariable ["ARC_console_airHoldDepartures", _holdDepartures];

private _canAirHold = ["ARC_console_airCanHold", false] call ARC_fnc_uiNsGetBool;
private _canAirRelease = ["ARC_console_airCanRelease", false] call ARC_fnc_uiNsGetBool;
private _canAirHoldRelease = ["ARC_console_airCanHoldRelease", false] call ARC_fnc_uiNsGetBool;
private _canAirQueueManage = ["ARC_console_airCanQueueManage", false] call ARC_fnc_uiNsGetBool;
private _canAirStaff = ["ARC_console_airCanStaff", false] call ARC_fnc_uiNsGetBool;
private _canAirRead = ["ARC_console_airCanRead", false] call ARC_fnc_uiNsGetBool;
private _canAirPilot = ["ARC_console_airCanPilot", false] call ARC_fnc_uiNsGetBool;
private _canAirControl = ["ARC_console_airCanControl", false] call ARC_fnc_uiNsGetBool;

private _debugAir = missionNamespace getVariable ["ARC_debugInspectorEnabled", false];
if (!(_debugAir isEqualType true) && !(_debugAir isEqualType false)) then { _debugAir = false; };

private _airMode = ["ARC_console_airMode", if (_canAirPilot && !_canAirControl) then {"PILOT"} else {"TOWER"}] call ARC_fnc_uiNsGetString;
_airMode = toUpper ([_airMode] call _trimFn);
if !(_airMode in ["TOWER", "PILOT"]) then { _airMode = if (_canAirPilot && !_canAirControl) then {"PILOT"} else {"TOWER"}; };
if ((_airMode isEqualTo "PILOT") && !_canAirPilot) then { _airMode = "TOWER"; };
uiNamespace setVariable ["ARC_console_airMode", _airMode];

private _airSubmode = ["ARC_console_airSubmode", "AIRFIELD_OPS"] call ARC_fnc_uiNsGetString;
_airSubmode = toUpper ([_airSubmode] call _trimFn);
if !(_airSubmode in ["AIRFIELD_OPS", "CLEARANCES", "DEBUG"]) then { _airSubmode = "AIRFIELD_OPS"; };
if (!_canAirControl && { _airSubmode isEqualTo "CLEARANCES" }) then { _airSubmode = "AIRFIELD_OPS"; };
if (!_debugAir && { _airSubmode isEqualTo "DEBUG" }) then { _airSubmode = "AIRFIELD_OPS"; };
uiNamespace setVariable ["ARC_console_airSubmode", _airSubmode];

private _nextMode = [_airSubmode, _canAirControl, _debugAir] call _cycleModes;
private _freshnessText = if (_stateUpdatedAt < 0) then { "Snapshot unavailable" } else { format ["Updated %1", [_stateUpdatedAt] call _fmtAgo] };

// Phase 5: read freshnessState once — reused for warning text and tower chip below.
private _freshnessState = [_snapshot, "freshnessState", "UNKNOWN"] call _getPair;
if (!(_freshnessState isEqualType "")) then { _freshnessState = "UNKNOWN"; };
if (toUpper _freshnessState isEqualTo "DEGRADED") then {
    _freshnessText = _freshnessText + " — DEGRADED: data may be unreliable";
} else {
    if (toUpper _freshnessState isEqualTo "STALE") then {
        _freshnessText = _freshnessText + " — STALE";
    };
};


// -----------------------------------------------------------------------
// Phase 1 scaffold: populate AIR-dedicated status strip controls (78131–78136)
// These run every paint cycle regardless of rebuild.
// -----------------------------------------------------------------------
private _airChipRunway = _display displayCtrl 78131;
private _airChipArrivals = _display displayCtrl 78132;
private _airChipDepartures = _display displayCtrl 78133;
private _airChipTowerMode = _display displayCtrl 78134;
private _airChipAlerts = _display displayCtrl 78135;
private _airDecBand = _display displayCtrl 78136;

// --- Runway chip ---
private _rwyChipColor = [_runwayState] call _statusColor;
private _rwyChipText = format ["<t size='0.85' color='%1'>&#x25CF;</t> <t size='0.85'>RWY: %2</t>", _rwyChipColor, _runwayState];
if (!isNull _airChipRunway) then { _airChipRunway ctrlSetStructuredText parseText _rwyChipText; };

// --- Arrivals chip ---
// Snapshot Contract v1 tuple indices: [flightId(0), callsign(1), category(2), phase(3), ageS(4), priority(5), status(6)]
private _IDX_FLIGHT_STATUS = 6;
// Priority thresholds (shared between arrivals + departures)
private _PRIO_EMERGENCY = 100;
private _PRIO_ELEVATED = 1;
private _arrCount = count _arrivals;
private _arrStatus = "NORMAL";
{
    if (_x isEqualType [] && { (count _x) > _IDX_FLIGHT_STATUS }) then {
        private _rowStatus = _x select _IDX_FLIGHT_STATUS;
        if (_rowStatus isEqualType "" && { toUpper _rowStatus in ["CRITICAL", "CONFLICT", "RED"] }) exitWith { _arrStatus = "CONFLICT"; };
        if (_rowStatus isEqualType "" && { toUpper _rowStatus in ["HOLDING", "PRIORITY", "AMBER", "CAUTION"] }) then { _arrStatus = "HOLDING"; };
    };
} forEach _arrivals;
if (_arrCount == 0) then { _arrStatus = "NORMAL"; };
private _arrChipColor = [_arrStatus] call _statusColor;
private _arrChipLabel = if (_arrCount == 0) then { "NONE" } else { format ["%1", _arrCount] };
private _arrChipText = format ["<t size='0.85' color='%1'>&#x25CF;</t> <t size='0.85'>ARR: %2</t>", _arrChipColor, _arrChipLabel];
if (!isNull _airChipArrivals) then { _airChipArrivals ctrlSetStructuredText parseText _arrChipText; };

// --- Departures chip ---
// Same tuple layout: [flightId(0), callsign(1), category(2), state(3), ageS(4), priority(5), status(6)]
private _depCount = count _departures;
private _depStatus = if (_holdDepartures) then { "HOLD" } else { "NORMAL" };
{
    if (_x isEqualType [] && { (count _x) > _IDX_FLIGHT_STATUS }) then {
        private _rowStatus = _x select _IDX_FLIGHT_STATUS;
        if (_rowStatus isEqualType "" && { toUpper _rowStatus in ["CRITICAL", "BLOCKED", "RED"] }) exitWith { _depStatus = "BLOCKED"; };
    };
} forEach _departures;
private _depChipColor = [_depStatus] call _statusColor;
private _depChipLabel = if (_depCount == 0) then { "NONE" } else { format ["%1", _depCount] };
if (_holdDepartures) then { _depChipLabel = _depChipLabel + " HOLD"; };
private _depChipText = format ["<t size='0.85' color='%1'>&#x25CF;</t> <t size='0.85'>DEP: %2</t>", _depChipColor, _depChipLabel];
if (!isNull _airChipDepartures) then { _airChipDepartures ctrlSetStructuredText parseText _depChipText; };

// --- Tower Mode chip --- (uses _freshnessState from Phase 5 block above)
private _towerModeStatus = switch (toUpper _freshnessState) do {
    case "FRESH": { "GREEN" };
    case "STALE": { "AMBER" };
    case "DEGRADED": { "RED" };
    default { "AMBER" };
};
private _towerModeLabel = if (_freshnessState isEqualTo "UNKNOWN") then { "UNKNOWN" } else { _freshnessState };
private _towerChipColor = [_towerModeStatus] call _statusColor;
private _towerChipText = format ["<t size='0.85' color='%1'>&#x25CF;</t> <t size='0.85'>TWR: %2</t>", _towerChipColor, _towerModeLabel];
if (!isNull _airChipTowerMode) then { _airChipTowerMode ctrlSetStructuredText parseText _towerChipText; };

// --- Alerts chip ---
// Alert tuple: [text(0), severity(1), sourceId(2)]
private _IDX_ALERT_SEVERITY = 1;
private _alertCount = count _alerts;
private _alertSeverity = "NONE";
{
    if (_x isEqualType [] && { (count _x) > _IDX_ALERT_SEVERITY }) then {
        private _sev = _x select _IDX_ALERT_SEVERITY;
        if (_sev isEqualType "" && { toUpper _sev isEqualTo "CRITICAL" }) exitWith { _alertSeverity = "CRITICAL"; };
        if (_sev isEqualType "" && { toUpper _sev isEqualTo "CAUTION" } && { !(_alertSeverity isEqualTo "CRITICAL") }) then { _alertSeverity = "CAUTION"; };
    };
} forEach _alerts;
private _alertChipColor = [_alertSeverity] call _statusColor;
private _alertChipLabel = if (_alertCount == 0) then { "NONE" } else { format ["%1", _alertCount] };
private _alertChipText = format ["<t size='0.85' color='%1'>&#x25CF;</t> <t size='0.85'>ALT: %2</t>", _alertChipColor, _alertChipLabel];
if (!isNull _airChipAlerts) then { _airChipAlerts ctrlSetStructuredText parseText _alertChipText; };

// --- Decision band ---
private _decCount = count _decisionQueue;
if (_decCount > 0 && { !isNull _airDecBand }) then {
    private _topDec = _decisionQueue select 0;
    private _decText = if (_topDec isEqualType [] && { (count _topDec) >= 1 }) then { _topDec select 0 } else { "Decision required" };
    if (!(_decText isEqualType "")) then { _decText = "Decision required"; };
    _airDecBand ctrlSetStructuredText parseText format ["<t size='0.90' color='#FFB833'>&#x26A0; %1</t>", _decText];
    _airDecBand ctrlShow true;
} else {
    if (!isNull _airDecBand) then { _airDecBand ctrlShow false; };
};

if (_rebuild) then {
    lbClear _ctrlList;

    if (_airMode isEqualTo "PILOT") then {
        private _hdrPilot = _ctrlList lbAdd "-- PILOT ACTIONS --";
        _ctrlList lbSetData [_hdrPilot, "HDR|PACT"];
        {
            private _row = _ctrlList lbAdd (_x select 0);
            _ctrlList lbSetData [_row, format ["PACT|%1", _x select 1]];
        } forEach [
            ["Request Taxi", "REQ_TAXI"],
            ["Request Takeoff", "REQ_TAKEOFF"],
            ["Request Inbound", "REQ_INBOUND"],
            ["Declare Emergency", "REQ_EMERGENCY"],
            ["Cancel Request", "CANCEL"]
        ];

        private _uidPilot = getPlayerUID player;
        private _myArrivals = [];
        {
            if (!(_x isEqualType [])) then { continue; };
            private _meta = _x param [7, []];
            if !(_meta isEqualType []) then { _meta = []; };
            private _pilotUid = [_meta, "pilotUid", ""] call _metaGet;
            private _rtype = toUpper (_x param [1, ""]);
            if ((_pilotUid isEqualTo _uidPilot) && { _rtype in ["REQ_INBOUND", "REQ_LAND"] }) then {
                _myArrivals pushBack _x;
            };
        } forEach _pendingClearances;
        if ((count _myArrivals) > 0) then {
            private _hdrWarn = _ctrlList lbAdd "-- PILOT ATC WARNINGS --";
            _ctrlList lbSetData [_hdrWarn, "HDR|PWRN"];
            {
                private _rid = _x param [0, ""];
                private _rtype = _x param [1, ""];
                private _prio = _x param [4, 0];
                private _status = if (_prio >= 100) then { "PRIORITY" } else { "AWAITING DECISION" };
                private _row = _ctrlList lbAdd format ["%1 %2 (%3)", _rid, _rtype, _status];
                _ctrlList lbSetData [_row, format ["PWRN|%1", _rid]];
            } forEach _myArrivals;
        };
    } else {
        // AIRFIELD_OPS: mode row goes at bottom (operational data leads).
        // CLEARANCES / DEBUG: mode row stays at top (specialist views).
        if (_airSubmode != "AIRFIELD_OPS") then {
            private _modeRow = _ctrlList lbAdd format [
                "%1  |  %2",
                _airSubmode,
                [_airSubmode] call _modeSummary
            ];
            _ctrlList lbSetData [_modeRow, format ["MODE|%1", _airSubmode]];
        };

        switch (_airSubmode) do
        {
            case "CLEARANCES":
            {
                private _guideRow = _ctrlList lbAdd ([ _airSubmode ] call _modeGuidance);
                _ctrlList lbSetData [_guideRow, "CSTATUS|GUIDE"];

                private _summaryRow = _ctrlList lbAdd format [
                    "Pending %1  |  Queue %2  |  Timers T/G/A %3/%4/%5  |  Auto %6/%7/%8",
                    count _pendingClearances,
                    count _departures,
                    [ [_timeouts, "tower", 0] call _getPair ] call _fmtSeconds,
                    [ [_timeouts, "ground", 0] call _getPair ] call _fmtSeconds,
                    [ [_timeouts, "arrival", 0] call _getPair ] call _fmtSeconds,
                    [ [_delays, "tower", 0] call _getPair ] call _fmtSeconds,
                    [ [_delays, "ground", 0] call _getPair ] call _fmtSeconds,
                    [ [_delays, "arrival", 0] call _getPair ] call _fmtSeconds
                ];
                _ctrlList lbSetData [_summaryRow, "CSTATUS|SUMMARY"];

                private _hdrReq = _ctrlList lbAdd "-- PENDING CLEARANCES --";
                _ctrlList lbSetData [_hdrReq, "HDR|REQ"];
                if ((count _pendingClearances) == 0) then {
                    private _noneReq = _ctrlList lbAdd "No pending clearances";
                    _ctrlList lbSetData [_noneReq, "REQ|NONE"];
                } else {
                    {
                        if (!(_x isEqualType [])) then { continue; };
                        private _rid = _x param [0, ""];
                        private _rtype = _x param [1, ""];
                        private _callsign = _x param [2, _rid];
                        private _meta = _x param [7, []];
                        if !(_meta isEqualType []) then { _meta = []; };
                        private _aircraftType = [_meta, "aircraftType", ""] call _metaGet;
                        private _trackLabel = [_rid, _callsign, _aircraftType] call _flightLabel;
                        private _prio = _x param [4, 0];
                        private _lbl = format ["%1  |  %2  |  %3", _trackLabel, [_rtype] call _requestTypeLabel, _rid];
                        if (_prio >= 100) then { _lbl = _lbl + "  |  !EMERGENCY!"; };
                        private _row = _ctrlList lbAdd _lbl;
                        _ctrlList lbSetData [_row, format ["REQ|%1|%2|%3|%4", _rid, _rtype, _callsign, _prio]];
                    } forEach _pendingClearances;
                };

                private _hdrFlt = _ctrlList lbAdd "-- DEPARTURE QUEUE --";
                _ctrlList lbSetData [_hdrFlt, "HDR|FLT"];
                if ((count _departures) == 0) then {
                    private _noneF = _ctrlList lbAdd "No departures queued";
                    _ctrlList lbSetData [_noneF, "FLT|NONE"];
                } else {
                    {
                        private _fid = _x param [0, ""];
                        private _callsign = _x param [1, _fid];
                        private _aircraftType = _x param [2, ""];
                        private _state = _x param [3, "QUEUED"];
                        private _trackLabel = [_fid, _callsign, _aircraftType] call _flightLabel;
                        private _row = _ctrlList lbAdd format ["%1  |  %2", _trackLabel, _state];
                        _ctrlList lbSetData [_row, format ["FLT|%1|%2|%3", _fid, _callsign, _state]];
                    } forEach _departures;
                };

                private _hdrLane = _ctrlList lbAdd "-- LANE STAFFING --";
                _ctrlList lbSetData [_hdrLane, "HDR|LANE"];
                {
                    if !(_x isEqualType []) then { continue; };
                    private _lane = _x param [0, ""];
                    private _mode = _x param [1, "AUTO"];
                    private _operator = _x param [2, "AUTO"];
                    private _row = _ctrlList lbAdd format ["%1: %2", toUpper _lane, _operator];
                    _ctrlList lbSetData [_row, format ["LANE|%1|%2|%3", _lane, _mode, _operator]];
                } forEach _staffing;

                private _hdrDec = _ctrlList lbAdd "-- RECENT DECISIONS --";
                _ctrlList lbSetData [_hdrDec, "HDR|DEC"];
                if ((count _clearanceHistory) == 0) then {
                    private _noneD = _ctrlList lbAdd "No recent decisions";
                    _ctrlList lbSetData [_noneD, "DEC|NONE"];
                } else {
                    {
                        if !(_x isEqualType []) then { continue; };
                        private _rid = _x param [0, ""];
                        private _status = _x param [1, ""];
                        private _by = _x param [3, "SYSTEM"];
                        private _ts = _x param [2, -1];
                        private _row = _ctrlList lbAdd format ["%1 %2 by %3 (%4)", _rid, _status, _by, [_ts] call _fmtAgo];
                        _ctrlList lbSetData [_row, format ["DEC|%1|%2|%3|%4", _rid, _status, _ts, _by]];
                    } forEach _clearanceHistory;
                };
            };

            case "DEBUG":
            {
                private _hdrDbg = _ctrlList lbAdd "-- DEBUG OVERLAY --";
                _ctrlList lbSetData [_hdrDbg, "HDR|DBG"];
                if ((count _debug) == 0) then {
                    private _noneDbg = _ctrlList lbAdd "Debug overlay unavailable";
                    _ctrlList lbSetData [_noneDbg, "DBG|NONE"];
                } else {
                    {
                        if !(_x isEqualType []) then { continue; };
                        private _key = _x param [0, ""];
                        private _value = _x param [1, ""];
                        private _rowText = format ["%1: %2", _key, str _value];
                        private _row = _ctrlList lbAdd _rowText;
                        _ctrlList lbSetData [_row, format ["DBG|%1", _key]];
                    } forEach _debug;
                };
            };

            default
            {
                // ---------------------------------------------------------------
                // Phase 2: AIRFIELD_OPS operational board layout
                // Vision Plan §4.4 — Arrivals → Runway → Departures
                // Status strip + decision band are handled by Phase 1 controls.
                // Default focus lands on first operational row (not metadata).
                // ---------------------------------------------------------------

                // --- Arrivals block ---
                private _hdrArr = _ctrlList lbAdd "ARRIVALS";
                _ctrlList lbSetData [_hdrArr, "HDR|ARR"];
                if ((count _arrivals) == 0) then {
                    private _noneA = _ctrlList lbAdd "No arrivals inbound";
                    _ctrlList lbSetData [_noneA, "ARR|NONE"];
                } else {
                    {
                        private _fid = _x param [0, ""];
                        private _callsign = _x param [1, _fid];
                        private _aircraftType = _x param [2, ""];
                        private _phase = _x param [3, "INBOUND"];
                        private _prio = _x param [5, 0];
                        private _status = _x param [6, "NORMAL"];
                        private _trackLabel = [_fid, _callsign, _aircraftType] call _flightLabel;
                        private _prioTag = if (_prio >= _PRIO_EMERGENCY) then { " !EMERGENCY!" } else { if (_prio >= _PRIO_ELEVATED) then { " [PRI]" } else { "" } };
                        private _row = _ctrlList lbAdd format ["%1  |  %2  |  %3%4", _trackLabel, _phase, _status, _prioTag];
                        _ctrlList lbSetData [_row, format ["ARR|%1|%2|%3|%4", _fid, _callsign, _phase, _status]];
                    } forEach _arrivals;
                };

                // --- Runway / active movement block ---
                private _holdTag = if (_holdDepartures) then { "HOLD ACTIVE" } else { _activeMovement };
                private _rwyOwnerTag = if (_runwayOwnerDisplay isEqualTo "") then { "none" } else { _runwayOwnerDisplay };
                private _runwayRow = _ctrlList lbAdd format ["RUNWAY %1  |  %2  |  %3", _runwayState, _rwyOwnerTag, _holdTag];
                _ctrlList lbSetData [_runwayRow, format ["RWY|%1|%2|%3", _runwayState, _runwayOwnerFlightId, _activeMovement]];

                // --- Departures block ---
                private _hdrDep = _ctrlList lbAdd "DEPARTURES";
                _ctrlList lbSetData [_hdrDep, "HDR|DEP"];
                if ((count _departures) == 0) then {
                    private _noneDep = _ctrlList lbAdd "No departures queued";
                    _ctrlList lbSetData [_noneDep, "DEP|NONE"];
                } else {
                    {
                        private _fid = _x param [0, ""];
                        private _callsign = _x param [1, _fid];
                        private _aircraftType = _x param [2, ""];
                        private _state = _x param [3, "QUEUED"];
                        private _prio = _x param [5, 0];
                        private _status = _x param [6, "NORMAL"];
                        private _trackLabel = [_fid, _callsign, _aircraftType] call _flightLabel;
                        private _prioTag = if (_prio >= _PRIO_EMERGENCY) then { " !EMERGENCY!" } else { if (_prio >= _PRIO_ELEVATED) then { " [PRI]" } else { "" } };
                        private _row = _ctrlList lbAdd format ["%1  |  %2  |  %3%4", _trackLabel, _state, _status, _prioTag];
                        _ctrlList lbSetData [_row, format ["DEP|%1|%2|%3|%4", _fid, _callsign, _state, _status]];
                    } forEach _departures;
                };

                // --- Lower priority sections (below operational board) ---
                if ((count _recentEvents) > 0) then {
                    private _hdrEvt = _ctrlList lbAdd "RECENT EVENTS";
                    _ctrlList lbSetData [_hdrEvt, "HDR|EVT"];
                    {
                        private _eventTs = _x param [0, -1];
                        private _eventLabel = _x param [1, ""];
                        private _row = _ctrlList lbAdd format ["%1 (%2)", _eventLabel, [_eventTs] call _fmtAgo];
                        _ctrlList lbSetData [_row, format ["EVT|%1|%2", _eventTs, _eventLabel]];
                    } forEach _recentEvents;
                };

                if ((count _staffing) > 0) then {
                    private _hdrLane = _ctrlList lbAdd "STAFFING";
                    _ctrlList lbSetData [_hdrLane, "HDR|LANE"];
                    {
                        if !(_x isEqualType []) then { continue; };
                        private _lane = _x param [0, ""];
                        private _mode = _x param [1, "AUTO"];
                        private _operator = _x param [2, "AUTO"];
                        private _row = _ctrlList lbAdd format ["%1: %2", toUpper _lane, _operator];
                        _ctrlList lbSetData [_row, format ["LANE|%1|%2|%3", _lane, _mode, _operator]];
                    } forEach _staffing;
                };

                if ((count _clearanceHistory) > 0) then {
                    private _hdrHist = _ctrlList lbAdd "CLEARANCE HISTORY";
                    _ctrlList lbSetData [_hdrHist, "HDR|DEC"];
                    {
                        if !(_x isEqualType []) then { continue; };
                        private _rid = _x param [0, ""];
                        private _status = _x param [1, ""];
                        private _ts = _x param [2, -1];
                        private _by = _x param [3, "SYSTEM"];
                        private _row = _ctrlList lbAdd format ["%1 %2 by %3 (%4)", _rid, _status, _by, [_ts] call _fmtAgo];
                        _ctrlList lbSetData [_row, format ["DEC|%1|%2|%3", _rid, _status, _ts]];
                    } forEach _clearanceHistory;
                };
            };
        };

        // AIRFIELD_OPS: view indicator at bottom — keeps operational data first
        if (_airSubmode isEqualTo "AIRFIELD_OPS") then {
            private _modeRowBottom = _ctrlList lbAdd format [
                "[%1]",
                [_airSubmode] call _modeSummary
            ];
            _ctrlList lbSetData [_modeRowBottom, format ["MODE|%1", _airSubmode]];
        };
    };

    if ((lbSize _ctrlList) > 0) then {
        private _restoreSel = -1;
        if (_prevSelData != "") then {
            for "_iSel" from 0 to ((lbSize _ctrlList) - 1) do {
                if ((_ctrlList lbData _iSel) isEqualTo _prevSelData) exitWith { _restoreSel = _iSel; };
            };
        };
        if (_restoreSel < 0) then {
            for "_iFirst" from 0 to ((lbSize _ctrlList) - 1) do {
                private _d = _ctrlList lbData _iFirst;
                private _pfx = if (_d isEqualType "") then { toUpper ((_d splitString "|") param [0, ""]) } else { "" };
                if !(_pfx isEqualTo "HDR") exitWith { _restoreSel = _iFirst; };
            };
        };
        if (_restoreSel < 0) then { _restoreSel = 0; };
        _ctrlList lbSetCurSel _restoreSel;
    };
};

private _sel = lbCurSel _ctrlList;
if (_sel < 0 && { (lbSize _ctrlList) > 0 }) then { _sel = 0; _ctrlList lbSetCurSel 0; };

private _selData = if (_sel >= 0) then { _ctrlList lbData _sel } else { "" };
if (!(_selData isEqualType "")) then { _selData = ""; };
private _parts = _selData splitString "|";
private _rowType = toUpper (_parts param [0, ""]);
private _selectedFid = if (_rowType in ["DEP", "ARR", "FLT"]) then { _parts param [1, ""] } else { "" };
uiNamespace setVariable ["ARC_console_airSelectedFid", _selectedFid];
uiNamespace setVariable ["ARC_console_airSelectedRow", _parts];
uiNamespace setVariable ["ARC_console_airSelectedRowType", _rowType];

// Phase 7: paint traffic map markers and optionally center on selected flight.
private _ctrlMap = _display displayCtrl 78137;
if (!isNull _ctrlMap) then {
    if (_airSubmode isEqualTo "AIRFIELD_OPS") then {
        _ctrlMap ctrlShow true;
        [_display, _selectedFid] call ARC_fnc_uiConsoleAirMapPaint;
    } else {
        _ctrlMap ctrlShow false;
    };
};

private _primaryLabel = "READ-ONLY";
private _secondaryLabel = "REFRESH";
private _primaryEnabled = false;
private _secondaryEnabled = true;
private _primaryTooltip = "No action available.";
private _secondaryTooltip = "Refresh AIR view.";

if (!_canAirRead && !_canAirControl && !_canAirPilot) then {
    _secondaryEnabled = false;
};

if (_airMode isEqualTo "PILOT") then {
    _primaryLabel = "SEND REQUEST";
    _primaryEnabled = _canAirPilot;
    _primaryTooltip = "Submit the selected pilot request.";
    if (_canAirControl) then {
        _secondaryLabel = "MODE: TOWER";
        _secondaryTooltip = "Switch to tower control mode.";
    };
} else {
    switch (_airSubmode) do
    {
        case "CLEARANCES":
        {
            switch (_rowType) do
            {
                case "REQ": {
                    _primaryLabel = "APPROVE";
                    _secondaryLabel = "DENY";
                    _primaryEnabled = _canAirQueueManage;
                    _secondaryEnabled = _canAirQueueManage;
                    _primaryTooltip = "Approve selected clearance request.";
                    _secondaryTooltip = "Deny selected clearance request.";
                };
                case "FLT": {
                    _primaryLabel = "EXPEDITE";
                    _secondaryLabel = "CANCEL";
                    _primaryEnabled = _canAirQueueManage;
                    _secondaryEnabled = _canAirQueueManage;
                    _primaryTooltip = "Expedite selected queued flight.";
                    _secondaryTooltip = "Cancel selected queued flight.";
                };
                case "LANE": {
                    _primaryLabel = "CLAIM";
                    _secondaryLabel = "RELEASE";
                    _primaryEnabled = _canAirStaff;
                    _secondaryEnabled = _canAirStaff;
                    _primaryTooltip = "Claim selected lane.";
                    _secondaryTooltip = "Release selected lane.";
                };
                default {
                    // Phase 3 safety: HDR rows are always inert.
                    if (_rowType isEqualTo "HDR") then {
                        _primaryLabel = "READ-ONLY";
                        _primaryEnabled = false;
                        _primaryTooltip = "Header row — no action available.";
                    } else {
                        _primaryLabel = if (_holdDepartures) then {"RELEASE"} else {"HOLD"};
                        _primaryEnabled = if (_holdDepartures) then { _canAirRelease } else { _canAirHold };
                        if (!_canAirHoldRelease) then {
                            _primaryLabel = "READ-ONLY";
                            _primaryEnabled = false;
                        };
                    };
                    _secondaryLabel = if (_nextMode isEqualTo _airSubmode) then {"REFRESH"} else { format ["VIEW: %1", _nextMode] };
                    _secondaryTooltip = if (_nextMode isEqualTo _airSubmode) then { "Refresh AIR view." } else { format ["Switch to %1.", _nextMode] };
                };
            };
        };
        case "DEBUG":
        {
            _primaryLabel = "READ-ONLY";
            _primaryEnabled = false;
            _secondaryLabel = if (_nextMode isEqualTo _airSubmode) then {"REFRESH"} else { format ["VIEW: %1", _nextMode] };
            _secondaryTooltip = if (_nextMode isEqualTo _airSubmode) then { "Refresh AIR view." } else { format ["Switch to %1.", _nextMode] };
        };
        default
        {
            // Phase 3 safety: HDR rows are always inert.
            if (_rowType isEqualTo "HDR") then {
                _primaryLabel = "READ-ONLY";
                _primaryEnabled = false;
                _primaryTooltip = "Header row — no action available.";
            } else {
                _primaryLabel = if (_holdDepartures) then {"RELEASE"} else {"HOLD"};
                _primaryEnabled = if (_holdDepartures) then { _canAirRelease } else { _canAirHold };
                if (!_canAirHoldRelease) then {
                    _primaryLabel = "READ-ONLY";
                    _primaryEnabled = false;
                };
            };
            _secondaryLabel = if (_nextMode isEqualTo _airSubmode) then {"REFRESH"} else { format ["VIEW: %1", _nextMode] };
            _secondaryTooltip = if (_nextMode isEqualTo _airSubmode) then { "Refresh AIR view." } else { format ["Switch to %1.", _nextMode] };
        };
    };
};

// Phase 4: if a confirmation is pending, override primary button label.
private _confirmPending = uiNamespace getVariable ["ARC_console_airConfirmPending", ""];
if (!(_confirmPending isEqualType "")) then { _confirmPending = ""; };
if (_confirmPending != "") then {
    _primaryLabel = format ["CONFIRM: %1", _confirmPending];
    _primaryEnabled = true;
    _primaryTooltip = uiNamespace getVariable ["ARC_console_airConfirmLabel", "Press again to confirm."];
    if (!(_primaryTooltip isEqualType "")) then { _primaryTooltip = "Press again to confirm."; };
};

if (!isNull _btnPrimary) then {
    _btnPrimary ctrlSetText _primaryLabel;
    _btnPrimary ctrlEnable _primaryEnabled;
    _btnPrimary ctrlSetTooltip _primaryTooltip;
};
if (!isNull _btnSecondary) then {
    _btnSecondary ctrlSetText _secondaryLabel;
    _btnSecondary ctrlEnable _secondaryEnabled;
    _btnSecondary ctrlSetTooltip _secondaryTooltip;
};

private _selectionHeading = "AIR / TOWER";
private _detailLines = [];

switch (_rowType) do
{
    case "MODE":
    {
        _selectionHeading = "View Control";
        _detailLines = [
            format ["Current view: <t color='#FFFFFF'>%1</t>", _airSubmode],
            format ["<t color='#FFFFFF'>%1</t>", [_airSubmode] call _modeGuidance],
            format ["Snapshot: <t color='#FFFFFF'>%1</t>", _freshnessText]
        ];
    };
    case "CSTATUS":
    {
        _selectionHeading = "Clearances";
        _detailLines = [
            format ["Purpose: <t color='#FFFFFF'>%1</t>", ["CLEARANCES"] call _modeGuidance],
            format ["Pending requests: <t color='#FFFFFF'>%1</t>", count _pendingClearances],
            format ["Queued departures: <t color='#FFFFFF'>%1</t>", count _departures],
            format ["Controller timers T/G/A: <t color='#FFFFFF'>%1 / %2 / %3</t>",
                [[_timeouts, "tower", 0] call _getPair] call _fmtSeconds,
                [[_timeouts, "ground", 0] call _getPair] call _fmtSeconds,
                [[_timeouts, "arrival", 0] call _getPair] call _fmtSeconds
            ]
        ];
    };
    case "DECISION":
    {
        private _rid = _parts param [1, ""];
        private _rec = [_decisionQueue, _rid] call _findById;
        private _reqRec = [_pendingClearances, _rid] call _findById;
        private _reqMeta = if (_reqRec isEqualType []) then { _reqRec param [7, []] } else { [] };
        if !(_reqMeta isEqualType []) then { _reqMeta = []; };
        private _decisionLabel = [
            _rid,
            if (_reqRec isEqualType []) then { _reqRec param [2, _parts param [2, ""]] } else { _parts param [2, ""] },
            [_reqMeta, "aircraftType", ""] call _metaGet
        ] call _flightLabel;
        _selectionHeading = "Decision Required";
        _detailLines = [
            format ["Request id: <t color='#FFFFFF'>%1</t>", _rid],
            format ["Aircraft: <t color='#FFFFFF'>%1</t>", _decisionLabel],
            format ["Priority: <t color='#FFFFFF'>%1</t>", if (_rec isEqualType []) then { _rec param [3, 0] } else { 0 }],
            format ["Guidance: <t color='#FFFFFF'>Use CLEARANCES view to decide this request.</t>"]
        ];
    };
    case "ARR":
    {
        private _fid = _parts param [1, ""];
        private _rec = [_arrivals, _fid] call _findById;
        if (_fid isEqualTo "NONE") then {
            _selectionHeading = "Arrivals";
            _detailLines = ["<t color='#FFFFFF'>No arrivals inbound.</t>"];
        } else {
            private _trackLabel = [_fid, _rec param [1, _fid], _rec param [2, ""]] call _flightLabel;
            _selectionHeading = format ["Arrival %1", _trackLabel];
            _detailLines = [
                format ["Aircraft: <t color='#FFFFFF'>%1</t>", _trackLabel],
                format ["Flight ID: <t color='#FFFFFF'>%1</t>", _fid],
                format ["Type: <t color='#FFFFFF'>%1</t>", _rec param [2, "-"]],
                format ["Phase: <t color='#FFFFFF'>%1</t>", _rec param [3, "INBOUND"]],
                format ["Age: <t color='#FFFFFF'>%1</t>", [(_rec param [4, -1])] call _fmtSeconds],
                format ["Priority: <t color='#FFFFFF'>%1</t>", _rec param [5, 0]],
                format ["Status: <t color='%1'>%2</t>", [(_rec param [6, "NORMAL"])] call _statusColor, _rec param [6, "NORMAL"]]
            ];
        };
    };
    case "RWY":
    {
        _selectionHeading = "Runway";
        _detailLines = [
            format ["State: <t color='%1'>%2</t>", [_runwayState] call _statusColor, _runwayState],
            format ["Active aircraft: <t color='#FFFFFF'>%1</t>", if (_runwayOwnerDisplay isEqualTo "") then {"-"} else {_runwayOwnerDisplay}],
            format ["Flight ID: <t color='#FFFFFF'>%1</t>", if (_runwayOwnerFlightId isEqualTo "") then {"-"} else {_runwayOwnerFlightId}],
            format ["Active movement: <t color='#FFFFFF'>%1</t>", _activeMovement],
            format ["Hold state: <t color='#FFFFFF'>%1</t>", if (_holdDepartures) then {"HOLD ACTIVE"} else {"OPEN"}]
        ];
    };
    case "DEP":
    {
        private _fid = _parts param [1, ""];
        private _rec = [_departures, _fid] call _findById;
        if (_fid isEqualTo "NONE") then {
            _selectionHeading = "Departures";
            _detailLines = ["<t color='#FFFFFF'>No departures queued.</t>"];
        } else {
            private _trackLabel = [_fid, _rec param [1, _fid], _rec param [2, ""]] call _flightLabel;
            _selectionHeading = format ["Departure %1", _trackLabel];
            _detailLines = [
                format ["Aircraft: <t color='#FFFFFF'>%1</t>", _trackLabel],
                format ["Flight ID: <t color='#FFFFFF'>%1</t>", _fid],
                format ["Type: <t color='#FFFFFF'>%1</t>", _rec param [2, "-"]],
                format ["State: <t color='#FFFFFF'>%1</t>", _rec param [3, "QUEUED"]],
                format ["Age: <t color='#FFFFFF'>%1</t>", [(_rec param [4, -1])] call _fmtSeconds],
                format ["Priority: <t color='#FFFFFF'>%1</t>", _rec param [5, 0]],
                format ["Status: <t color='%1'>%2</t>", [(_rec param [6, "NORMAL"])] call _statusColor, _rec param [6, "NORMAL"]]
            ];
        };
    };
    case "REQ":
    {
        private _rid = _parts param [1, ""];
        private _rec = [_pendingClearances, _rid] call _findById;
        if (_rid isEqualTo "NONE") then {
            _selectionHeading = "Pending Clearances";
            _detailLines = ["<t color='#FFFFFF'>No pending clearances.</t>"];
        } else {
            private _meta = _rec param [7, []];
            if !(_meta isEqualType []) then { _meta = []; };
            private _aircraftType = [_meta, "aircraftType", ""] call _metaGet;
            private _trackLabel = [_rid, _rec param [2, "-"], _aircraftType] call _flightLabel;
            _selectionHeading = format ["Clearance %1", _rid];
            _detailLines = [
                format ["Request: <t color='#FFFFFF'>%1</t>", [(_rec param [1, "-"])] call _requestTypeLabel],
                format ["Aircraft: <t color='#FFFFFF'>%1</t>", _trackLabel],
                format ["Requested: <t color='#FFFFFF'>%1</t>", [(_rec param [3, -1])] call _fmtAgo],
                format ["Priority: <t color='#FFFFFF'>%1</t>", _rec param [4, 0]],
                format ["Decision needed: <t color='#FFFFFF'>%1</t>", if (_rec param [5, false]) then {"YES"} else {"NO"}],
                format ["Current owner: <t color='#FFFFFF'>%1</t>", if ((_rec param [6, ""]) isEqualTo "") then {"UNCLAIMED"} else {_rec param [6, ""]}],
                format ["Fallback timers T/G/A: <t color='#FFFFFF'>%1 / %2 / %3</t>",
                    [[_timeouts, "tower", 0] call _getPair] call _fmtSeconds,
                    [[_timeouts, "ground", 0] call _getPair] call _fmtSeconds,
                    [[_timeouts, "arrival", 0] call _getPair] call _fmtSeconds
                ]
            ];
        };
    };
    case "FLT":
    {
        private _fid = _parts param [1, ""];
        private _rec = [_departures, _fid] call _findById;
        if (_fid isEqualTo "NONE") then {
            _selectionHeading = "Departure Queue";
            _detailLines = ["<t color='#FFFFFF'>No departures queued.</t>"];
        } else {
            private _trackLabel = [_fid, _rec param [1, _fid], _rec param [2, ""]] call _flightLabel;
            _selectionHeading = format ["Queued Flight %1", _trackLabel];
            _detailLines = [
                format ["Aircraft: <t color='#FFFFFF'>%1</t>", _trackLabel],
                format ["Flight ID: <t color='#FFFFFF'>%1</t>", _fid],
                format ["Type: <t color='#FFFFFF'>%1</t>", _rec param [2, "-"]],
                format ["State: <t color='#FFFFFF'>%1</t>", _rec param [3, "QUEUED"]],
                format ["Age: <t color='#FFFFFF'>%1</t>", [(_rec param [4, -1])] call _fmtSeconds],
                format ["Priority: <t color='#FFFFFF'>%1</t>", _rec param [5, 0]]
            ];
        };
    };
    case "LANE":
    {
        _selectionHeading = format ["Lane %1", toUpper (_parts param [1, ""])];
        _detailLines = [
            format ["Mode: <t color='#FFFFFF'>%1</t>", _parts param [2, "AUTO"]],
            format ["Operator: <t color='#FFFFFF'>%1</t>", _parts param [3, "AUTO"]],
            "Use CLEARANCES view to claim or release staffing for this lane."
        ];
    };
    case "EVT":
    {
        _selectionHeading = "Recent Event";
        _detailLines = [
            format ["Event: <t color='#FFFFFF'>%1</t>", _parts param [2, ""]],
            format ["Observed: <t color='#FFFFFF'>%1</t>", [parseNumber (_parts param [1, "-1"])] call _fmtAgo]
        ];
    };
    case "DEC":
    {
        _selectionHeading = "Decision History";
        _detailLines = [
            format ["Request: <t color='#FFFFFF'>%1</t>", _parts param [1, ""]],
            format ["Status: <t color='#FFFFFF'>%1</t>", _parts param [2, ""]],
            format ["When: <t color='#FFFFFF'>%1</t>", [parseNumber (_parts param [3, "-1"])] call _fmtAgo]
        ];
    };
    case "DBG":
    {
        private _k = _parts param [1, ""];
        private _rec = [_debug, _k] call _findById;
        _selectionHeading = format ["Debug %1", _k];
        _detailLines = [
            format ["Value: <t color='#FFFFFF'>%1</t>", if (_rec isEqualType [] && { (count _rec) >= 2 }) then { str (_rec select 1) } else { "-" }],
            format ["Snapshot: <t color='#FFFFFF'>%1</t>", _freshnessText],
            format ["CAS timing: <t color='#FFFFFF'>%1 / %2</t>", [_casTiming, "casreqId", "-"] call _getPair, [_casTiming, "state", "-"] call _getPair]
        ];
    };
    case "PACT":
    {
        _selectionHeading = "Pilot Action";
        _detailLines = [
            format ["Action: <t color='#FFFFFF'>%1</t>", _parts param [1, ""]],
            format ["Primary: <t color='#FFFFFF'>SEND REQUEST</t>"],
            format ["Secondary: <t color='#FFFFFF'>%1</t>", if (_canAirControl) then {"MODE: TOWER"} else {"REFRESH"}]
        ];
    };
    case "PWRN":
    {
        _selectionHeading = "Pilot Warning";
        _detailLines = [
            format ["Request: <t color='#FFFFFF'>%1</t>", _parts param [1, ""]],
            "<t color='#FFFFFF'>Tower still owes a decision on your inbound request.</t>"
        ];
    };
    default
    {
        _selectionHeading = "AIR / TOWER";
        _detailLines = [
            format ["View: <t color='#FFFFFF'>%1</t>", if (_airMode isEqualTo "PILOT") then {"PILOT"} else {_airSubmode}],
            format ["Snapshot: <t color='#FFFFFF'>%1</t>", _freshnessText],
            format ["Runway: <t color='%1'>%2</t>", [_runwayState] call _statusColor, _runwayState]
        ];
    };
};

private _detailHtml = format ["<t size='1.05' color='#B89B6B'>%1</t>", _selectionHeading];
{
    _detailHtml = _detailHtml + format ["<br/><t color='#CFCFCF'>%1</t>", _x];
} forEach _detailLines;

if (_airMode != "PILOT" && { _airSubmode != "DEBUG" }) then {
    _detailHtml = _detailHtml
        + format ["<br/><br/><t size='0.85' color='#888888'>%1</t>", _freshnessText];
};

if (_airSubmode isEqualTo "DEBUG") then {
    _detailHtml = _detailHtml
        + "<br/><br/><t size='1.05' color='#B89B6B'>Debug Surface</t>"
        + format ["<br/>Blocked-route count: <t color='#FFFFFF'>%1</t>", [_debug, "blockedRouteCount", 0] call _getPair]
        + format ["<br/>Latest blocked route: <t color='#FFFFFF'>%1</t>", [_debug, "blockedRouteReason", "-"] call _getPair]
        + format ["<br/>Source id: <t color='#FFFFFF'>%1</t>", [_debug, "blockedRouteSource", "-"] call _getPair];
};

_ctrlDetails ctrlSetStructuredText parseText _detailHtml;

private _defaultPosAir = uiNamespace getVariable ["ARC_console_airDetailsDefaultPos", []];
if (!(_defaultPosAir isEqualType []) || { (count _defaultPosAir) < 4 }) then
{
    _defaultPosAir = ctrlPosition _ctrlDetails;
    uiNamespace setVariable ["ARC_console_airDetailsDefaultPos", +_defaultPosAir];
};
[_ctrlDetails] call BIS_fnc_ctrlFitToTextHeight;
private _airGrp = _display displayCtrl 78016;
private _airMinH = if (!isNull _airGrp) then { (ctrlPosition _airGrp) select 3 } else { 0.74 };
private _airP = ctrlPosition _ctrlDetails;
_airP set [0, _defaultPosAir select 0];

// Phase 7: when map is visible (AIRFIELD_OPS), shift detail pane below map.
private _mapVisible = false;
private _ctrlMapCheck = _display displayCtrl 78137;
if (!isNull _ctrlMapCheck) then {
    _mapVisible = ctrlShown _ctrlMapCheck;
};
if (_mapVisible) then {
    // Map ends at 0.082 + 0.40 = 0.482 of safeZoneH. Detail starts just below with small gap.
    _airP set [1, 0.005 + (0.40 * ((ctrlPosition _airGrp) select 3))];
} else {
    _airP set [1, _defaultPosAir select 1];
};

_airP set [2, _defaultPosAir select 2];
_airP set [3, (_airP select 3) max _airMinH];
_ctrlDetails ctrlSetPosition _airP;
_ctrlDetails ctrlCommit 0;

uiNamespace setVariable ["ARC_console_airLastStateUpdatedAt", _stateUpdatedAt];
true

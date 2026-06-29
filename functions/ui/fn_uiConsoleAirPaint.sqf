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
        case "REQ_TAXI": { "Taxi clearance" };
        case "REQ_TAKEOFF": { "Departure clearance" };
        case "REQ_INBOUND": { "Inbound report" };
        case "REQ_LAND": { "Landing clearance" };
        case "REQ_EMERGENCY": { "Emergency recovery" };
        default { _rt }
    }
};

private _modeTitle = {
    params ["_mode"];
    switch (toUpper _mode) do
    {
        case "CLEARANCES": { "Clearance Desk" };
        case "RAMP": { "Ramp Control" };
        case "DEBUG": { "Diagnostics" };
        default { "Airfield Status Board" };
    }
};

private _modeSummary = {
    params ["_mode"];
    switch (toUpper _mode) do
    {
        case "CLEARANCES": { "Approve, deny, and route aircraft requests." };
        case "RAMP": { "View parked aircraft and queue them for departure." };
        case "DEBUG": { "Snapshot health, routing faults, and timing telemetry." };
        default { "Inbound traffic, runway status, and outbound traffic." };
    }
};

private _modeGuidance = {
    params ["_mode"];
    switch (toUpper _mode) do
    {
        case "CLEARANCES": { "Approve or deny pilot requests, manage the departure lineup, and staff tower positions." };
        case "RAMP": { "Select a parked aircraft and press QUEUE DEPARTURE to add it to the departure lineup." };
        case "DEBUG": { "Review snapshot health, route failures, and controller timing telemetry." };
        default { "Track inbound aircraft, runway use, and outbound departures at a glance." };
    }
};

private _phaseLabel = {
    params ["_phase"];
    switch (toUpper ([_phase, "INBOUND"] call _cleanAirText)) do
    {
        case "HOLDING": { "Holding outside the airfield" };
        case "PRIORITY": { "Priority recovery" };
        default { "Inbound to the airfield" };
    }
};

private _departureStateLabel = {
    params ["_state"];
    switch (toUpper ([_state, "QUEUED"] call _cleanAirText)) do
    {
        case "HOLD": { "Held for runway release" };
        case "CLEARED": { "Departing now" };
        case "BLOCKED": { "Blocked by route or runway issue" };
        default { "Awaiting runway release" };
    }
};

private _trafficStatusLabel = {
    params ["_status"];
    switch (toUpper ([_status, "NORMAL"] call _cleanAirText)) do
    {
        case "CONFLICT": { "Priority traffic" };
        case "HOLDING": { "Holding" };
        case "HOLD": { "Departures held" };
        case "BLOCKED": { "Blocked" };
        default { "Normal" };
    }
};

private _priorityLabel = {
    params ["_priority"];
    if (_priority >= 100) exitWith { "Emergency" };
    if (_priority >= 1) exitWith { "Priority" };
    "Routine"
};

private _laneLabel = {
    params ["_lane"];
    switch (toLower ([_lane, ""] call _cleanAirText)) do
    {
        case "tower": { "Tower Control" };
        case "ground": { "Ground Control" };
        case "arrival": { "Arrival Control" };
        default { toUpper _lane };
    }
};

private _laneModeLabel = {
    params ["_mode"];
    if (toUpper ([_mode, "AUTO"] call _cleanAirText) isEqualTo "MANNED") exitWith { "Staffed" };
    "Automatic"
};

private _movementLabel = {
    params ["_movement"];
    switch (toUpper ([_movement, "CLEAR"] call _cleanAirText)) do
    {
        case "DEPARTING": { "Departure rolling" };
        case "BLOCKED": { "Runway blocked" };
        default { "No active movement" };
    }
};

private _modeButtonLabel = {
    params ["_mode"];
    switch (toUpper _mode) do
    {
        case "CLEARANCES": { "CLEARANCE DESK" };
        case "RAMP": { "RAMP" };
        case "DEBUG": { "DIAGNOSTICS" };
        default { "STATUS BOARD" };
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
    if (_canControl) then { _modes pushBack "RAMP"; };
    if (_debugEnabled) then { _modes pushBack "DEBUG"; };
    private _idx = _modes find _current;
    if (_idx < 0) exitWith { _modes select 0 };
    _modes select ((_idx + 1) mod (count _modes))
};

private _snapshot = missionNamespace getVariable ["ARC_pub_airbaseUiSnapshot", []];
if (!(_snapshot isEqualType [])) then { _snapshot = []; };
private _snapshotRev = [_snapshot, "rev", -1] call _getPair;
if (!(_snapshotRev isEqualType 0)) then { _snapshotRev = -1; };
private _lastRev = uiNamespace getVariable ["ARC_console_airLastRev", -2];
if (!(_lastRev isEqualType 0)) then { _lastRev = -2; };
if (_snapshotRev != _lastRev) then { _rebuild = true; };
private _stateUpdatedAt = missionNamespace getVariable ["ARC_pub_airbaseUiSnapshotUpdatedAt", -1];
if (!(_stateUpdatedAt isEqualType 0)) then { _stateUpdatedAt = -1; };

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

// Runtime block exposes airbase ambiance state + UI tuning so the AIR/TOWER
// idle summary stays informative even when no traffic is queued.
private _runtime = [_snapshot, "runtime", []] call _getPair;
if (!(_runtime isEqualType [])) then { _runtime = []; };
private _runtimeEnabled = [_runtime, "enabled", false] call _getPair;
if (!(_runtimeEnabled isEqualType true) && !(_runtimeEnabled isEqualType false)) then { _runtimeEnabled = false; };
private _runtimeDepQueued = [_runtime, "depQueued", 0] call _getPair;
if (!(_runtimeDepQueued isEqualType 0)) then { _runtimeDepQueued = 0; };
private _runtimeArrQueued = [_runtime, "arrQueued", 0] call _getPair;
if (!(_runtimeArrQueued isEqualType 0)) then { _runtimeArrQueued = 0; };
private _runtimeTotalQueued = [_runtime, "totalQueued", 0] call _getPair;
if (!(_runtimeTotalQueued isEqualType 0)) then { _runtimeTotalQueued = 0; };
private _runtimeListMax = [_runtime, "listMax", 0] call _getPair;
if (!(_runtimeListMax isEqualType 0)) then { _runtimeListMax = 0; };
private _runtimeArrSlot = [_runtime, "arrSlotSpacingS", 0] call _getPair;
if (!(_runtimeArrSlot isEqualType 0)) then { _runtimeArrSlot = 0; };
private _runtimeDepSlot = [_runtime, "depSlotSpacingS", 0] call _getPair;
if (!(_runtimeDepSlot isEqualType 0)) then { _runtimeDepSlot = 0; };
private _runtimePublishInterval = [_runtime, "publishIntervalS", 0] call _getPair;
if (!(_runtimePublishInterval isEqualType 0)) then { _runtimePublishInterval = 0; };
private _runtimeEnabledLabel = if (_runtimeEnabled) then { "ENABLED" } else { "DISABLED" };

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
if !(_airSubmode in ["AIRFIELD_OPS", "CLEARANCES", "RAMP", "DEBUG"]) then { _airSubmode = "AIRFIELD_OPS"; };
if (!_canAirControl && { _airSubmode isEqualTo "CLEARANCES" }) then { _airSubmode = "AIRFIELD_OPS"; };
if (!_canAirControl && { _airSubmode isEqualTo "RAMP" }) then { _airSubmode = "AIRFIELD_OPS"; };
if (!_debugAir && { _airSubmode isEqualTo "DEBUG" }) then { _airSubmode = "AIRFIELD_OPS"; };
uiNamespace setVariable ["ARC_console_airSubmode", _airSubmode];

private _nextMode = [_airSubmode, _canAirControl, _debugAir] call _cycleModes;
private _freshnessText = if (_stateUpdatedAt < 0) then { "Snapshot unavailable" } else { format ["Updated %1", [_stateUpdatedAt] call _fmtAgo] };

// Phase 5: read freshnessState once — reused for warning text and tower chip below.
private _freshnessState = [_snapshot, "freshnessState", "UNKNOWN"] call _getPair;
if (!(_freshnessState isEqualType "")) then { _freshnessState = "UNKNOWN"; };
if (_stateUpdatedAt >= 0) then {
    private _snapAge = (serverTime - _stateUpdatedAt) max 0;
    // Age-based proposed state; only ever escalate the server-supplied value so a
    // server-classified DEGRADED snapshot can never be silently downgraded by client age math.
    private _proposed = "";
    if (_snapAge > 90) then { _proposed = "DEGRADED"; } else {
        if (_snapAge > 30) then { _proposed = "STALE"; };
    };
    if !(_proposed isEqualTo "") then {
        private _rank = {
            params ["_s"];
            switch (toUpper _s) do {
                case "DEGRADED": { 3 };
                case "STALE":    { 2 };
                case "OK":       { 1 };
                default          { 0 };
            }
        };
        if (([_proposed] call _rank) > ([_freshnessState] call _rank)) then {
            _freshnessState = _proposed;
        };
    };
};
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

// --- Runway chip --- (abbreviated labels per Refactor Plan §PR3.4)
private _rwyChipHtml = ["RUNWAY", _runwayState, _runwayState] call ARC_fnc_uiConsoleFormatStatusChip;
if (!isNull _airChipRunway) then { _airChipRunway ctrlSetStructuredText parseText _rwyChipHtml; };

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
private _arrChipLabel = if (_arrCount == 0) then { "0" } else { str _arrCount };
private _arrChipHtml = ["ARRIVALS", _arrChipLabel, _arrStatus] call ARC_fnc_uiConsoleFormatStatusChip;
if (!isNull _airChipArrivals) then { _airChipArrivals ctrlSetStructuredText parseText _arrChipHtml; };

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
private _depChipLabel = if (_depCount == 0) then { "0" } else { str _depCount };
if (_holdDepartures) then { _depChipLabel = _depChipLabel + " HOLD"; };
private _depChipHtml = ["DEPARTURES", _depChipLabel, _depStatus] call ARC_fnc_uiConsoleFormatStatusChip;
if (!isNull _airChipDepartures) then { _airChipDepartures ctrlSetStructuredText parseText _depChipHtml; };

// --- Tower Mode chip --- (uses _freshnessState from Phase 5 block above)
private _towerModeStatus = switch (toUpper _freshnessState) do {
    case "FRESH": { "GREEN" };
    case "STALE": { "AMBER" };
    case "DEGRADED": { "RED" };
    default { "AMBER" };
};
private _towerModeLabel = if (_freshnessState isEqualTo "UNKNOWN") then { "UNKNOWN" } else { _freshnessState };
private _towerChipHtml = ["DATA", _towerModeLabel, _towerModeStatus] call ARC_fnc_uiConsoleFormatStatusChip;
if (!isNull _airChipTowerMode) then { _airChipTowerMode ctrlSetStructuredText parseText _towerChipHtml; };

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
private _alertChipLabel = if (_alertCount == 0) then { "NONE" } else { str _alertCount };
private _alertChipHtml = ["ALERTS", _alertChipLabel, _alertSeverity] call ARC_fnc_uiConsoleFormatStatusChip;
if (!isNull _airChipAlerts) then { _airChipAlerts ctrlSetStructuredText parseText _alertChipHtml; };

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
                private _row = _ctrlList lbAdd format ["Request %1  |  %2  |  %3", _rid, [_rtype] call _requestTypeLabel, _status];
                _ctrlList lbSetData [_row, format ["PWRN|%1", _rid]];
            } forEach _myArrivals;
        };
    } else {
        // AIRFIELD_OPS: mode row goes at bottom (operational data leads).
        // CLEARANCES / DEBUG: mode row stays at top (specialist views).
        if (_airSubmode != "AIRFIELD_OPS") then {
            private _modeRow = _ctrlList lbAdd format [
                "%1  |  %2",
                [_airSubmode] call _modeTitle,
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
                    "Awaiting decision %1  |  Departure lineup %2  |  Tower/Ground/Arrival timers %3/%4/%5  |  Automation %6/%7/%8",
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
                    [_ctrlList, "No pending clearances"] call ARC_fnc_uiConsoleFormatEmptyState;
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
                        private _autoEta = [_meta, "automationEtaS", -1] call _metaGet;
                        if (!(_autoEta isEqualType 0)) then { _autoEta = -1; };
                        private _lbl = format ["%1  |  %2  |  Request %3", _trackLabel, [_rtype] call _requestTypeLabel, _rid];
                        if (_autoEta >= 0) then { _lbl = _lbl + format ["  |  AUTO %1", [_autoEta] call _fmtSeconds]; };
                        if (_prio >= 100) then { _lbl = _lbl + "  |  !EMERGENCY!"; };
                        private _row = _ctrlList lbAdd _lbl;
                        _ctrlList lbSetData [_row, format ["REQ|%1|%2|%3|%4", _rid, _rtype, _callsign, _prio]];
                    } forEach _pendingClearances;
                };

                private _hdrFlt = _ctrlList lbAdd "-- DEPARTURE QUEUE --";
                _ctrlList lbSetData [_hdrFlt, "HDR|FLT"];
                if ((count _departures) == 0) then {
                    [_ctrlList, "No departures queued"] call ARC_fnc_uiConsoleFormatEmptyState;
                } else {
                    {
                        private _fid = _x param [0, ""];
                        private _callsign = _x param [1, _fid];
                        private _aircraftType = _x param [2, ""];
                        private _state = _x param [3, "QUEUED"];
                        private _trackLabel = [_fid, _callsign, _aircraftType] call _flightLabel;
                        private _row = _ctrlList lbAdd format ["%1  |  %2", _trackLabel, [_state] call _departureStateLabel];
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
                    private _row = _ctrlList lbAdd format ["%1: %2 (%3)", [_lane] call _laneLabel, _operator, [_mode] call _laneModeLabel];
                    _ctrlList lbSetData [_row, format ["LANE|%1|%2|%3", _lane, _mode, _operator]];
                } forEach _staffing;

                private _hdrDec = _ctrlList lbAdd "-- RECENT DECISIONS --";
                _ctrlList lbSetData [_hdrDec, "HDR|DEC"];
                if ((count _clearanceHistory) == 0) then {
                    [_ctrlList, "No recent decisions"] call ARC_fnc_uiConsoleFormatEmptyState;
                } else {
                    {
                        if !(_x isEqualType []) then { continue; };
                        private _rid = _x param [0, ""];
                        private _status = _x param [1, ""];
                        private _by = _x param [3, "SYSTEM"];
                        private _ts = _x param [2, -1];
                        private _row = _ctrlList lbAdd format ["Request %1 %2 by %3 (%4)", _rid, toLower _status, _by, [_ts] call _fmtAgo];
                        _ctrlList lbSetData [_row, format ["DEC|%1|%2|%3|%4", _rid, _status, _ts, _by]];
                    } forEach _clearanceHistory;
                };
            };

            case "RAMP":
            {
                private _guideRow = _ctrlList lbAdd (["RAMP"] call _modeGuidance);
                _ctrlList lbSetData [_guideRow, "RAMP_HDR|RAMP"];

                private _parkedAssets = [_snapshot, "parkedAssets", []] call _getPair;
                if (!(_parkedAssets isEqualType [])) then { _parkedAssets = []; };

                private _hdrRamp = _ctrlList lbAdd format ["-- RAMP: PARKED AIRCRAFT (%1) --", count _parkedAssets];
                _ctrlList lbSetData [_hdrRamp, "HDR|RAMP"];

                if ((count _parkedAssets) == 0) then {
                    [_ctrlList, "No parked aircraft available for departure"] call ARC_fnc_uiConsoleFormatEmptyState;
                } else {
                    {
                        if (!(_x isEqualType [])) then { continue; };
                        private _pAid = _x param [0, ""];
                        private _pCat = _x param [1, "FW"];
                        private _pVehType = _x param [2, ""];
                        private _pTow = _x param [3, false];
                        if ((!(_pTow isEqualType true)) && (!(_pTow isEqualType false))) then { _pTow = false; };
                        private _towTag = if (_pTow) then { " [TOW]" } else { "" };
                        private _displayName = [_pVehType] call _resolveAircraftDisplay;
                        private _label = if (_displayName isEqualTo "") then { _pAid } else { format ["%1 (%2)", _pAid, _displayName] };
                        private _row = _ctrlList lbAdd format ["%1  |  %2  |  PARKED%3", _label, _pCat, _towTag];
                        _ctrlList lbSetData [_row, format ["ASSET|%1|%2|%3|%4", _pAid, _pCat, _pVehType, if (_pTow) then {"1"} else {"0"}]];
                    } forEach _parkedAssets;
                };
            };

            case "DEBUG":
            {
                private _hdrDbg = _ctrlList lbAdd "-- DEBUG OVERLAY --";
                _ctrlList lbSetData [_hdrDbg, "HDR|DBG"];
                if ((count _debug) == 0) then {
                    [_ctrlList, "Debug overlay unavailable"] call ARC_fnc_uiConsoleFormatEmptyState;
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
                    [_ctrlList, "No arrivals inbound"] call ARC_fnc_uiConsoleFormatEmptyState;
                    private _arrHintBits = [format ["Runtime %1", _runtimeEnabledLabel], format ["Movement %1", [_activeMovement] call _movementLabel]];
                    if (_runtimeListMax > 0) then { _arrHintBits pushBack format ["Capacity %1", _runtimeListMax]; };
                    if (_runtimeArrSlot > 0) then { _arrHintBits pushBack format ["Slot %1s", _runtimeArrSlot]; };
                    [_ctrlList, _arrHintBits joinString " · "] call ARC_fnc_uiConsoleFormatEmptyState;
                } else {
                    {
                        private _fid = _x param [0, ""];
                        private _callsign = _x param [1, _fid];
                        private _aircraftType = _x param [2, ""];
                        private _phase = _x param [3, "INBOUND"];
                        private _prio = _x param [5, 0];
                        private _status = _x param [6, "NORMAL"];
                        private _etaS = _x param [9, -1];
                        private _trackLabel = [_fid, _callsign, _aircraftType] call _flightLabel;
                        private _prioTag = if (_prio >= _PRIO_EMERGENCY) then { " !EMERGENCY!" } else { if (_prio >= _PRIO_ELEVATED) then { " [PRI]" } else { "" } };
                        private _etaTag = if (_etaS isEqualType 0 && { _etaS >= 0 }) then { format ["  |  ETA %1", [_etaS] call _fmtSeconds] } else { "" };
                        private _row = _ctrlList lbAdd format ["%1  |  %2  |  %3%4%5", _trackLabel, [_phase] call _phaseLabel, [_status] call _trafficStatusLabel, _etaTag, _prioTag];
                        _ctrlList lbSetData [_row, format ["ARR|%1|%2|%3|%4", _fid, _callsign, _phase, _status]];
                    } forEach _arrivals;
                };

                // --- Runway block ---
                private _hdrRwy = _ctrlList lbAdd "RUNWAY";
                _ctrlList lbSetData [_hdrRwy, "HDR|RWY"];
                private _holdTag = if (_holdDepartures) then { "Departures held" } else { [_activeMovement] call _movementLabel };
                private _rwyOwnerTag = if (_runwayOwnerDisplay isEqualTo "") then { "none" } else { _runwayOwnerDisplay };
                // Append runtime indicator so operators see ambiance ENABLED/DISABLED
                // and current movement (IDLE vs. ACTIVE) on the runway row itself,
                // even when no traffic is queued (idle visibility).
                private _runtimeRowTag = format ["Runtime %1 · %2", _runtimeEnabledLabel, [_activeMovement] call _movementLabel];
                private _runwayRow = _ctrlList lbAdd format ["%1  |  Current aircraft %2  |  %3  |  %4", _runwayState, _rwyOwnerTag, _holdTag, _runtimeRowTag];
                _ctrlList lbSetData [_runwayRow, format ["RWY|%1|%2|%3", _runwayState, _runwayOwnerFlightId, _activeMovement]];

                // --- Departures block ---
                private _hdrDep = _ctrlList lbAdd "DEPARTURES";
                _ctrlList lbSetData [_hdrDep, "HDR|DEP"];
                if ((count _departures) == 0) then {
                    [_ctrlList, "No departures queued"] call ARC_fnc_uiConsoleFormatEmptyState;
                    private _depHintBits = [format ["Runtime %1", _runtimeEnabledLabel]];
                    if (_holdDepartures) then { _depHintBits pushBack "Hold ACTIVE"; };
                    if (_runtimeListMax > 0) then { _depHintBits pushBack format ["Capacity %1", _runtimeListMax]; };
                    if (_runtimeDepSlot > 0) then { _depHintBits pushBack format ["Slot %1s", _runtimeDepSlot]; };
                    [_ctrlList, _depHintBits joinString " · "] call ARC_fnc_uiConsoleFormatEmptyState;
                } else {
                    {
                        private _fid = _x param [0, ""];
                        private _callsign = _x param [1, _fid];
                        private _aircraftType = _x param [2, ""];
                        private _state = _x param [3, "QUEUED"];
                        private _prio = _x param [5, 0];
                        private _status = _x param [6, "NORMAL"];
                        private _etaS = _x param [9, -1];
                        private _trackLabel = [_fid, _callsign, _aircraftType] call _flightLabel;
                        private _prioTag = if (_prio >= _PRIO_EMERGENCY) then { " !EMERGENCY!" } else { if (_prio >= _PRIO_ELEVATED) then { " [PRI]" } else { "" } };
                        private _etaTag = if (_etaS isEqualType 0 && { _etaS >= 0 }) then { format ["  |  ETD %1", [_etaS] call _fmtSeconds] } else { "" };
                        private _row = _ctrlList lbAdd format ["%1  |  %2  |  %3%4%5", _trackLabel, [_state] call _departureStateLabel, [_status] call _trafficStatusLabel, _etaTag, _prioTag];
                        _ctrlList lbSetData [_row, format ["DEP|%1|%2|%3|%4", _fid, _callsign, _state, _status]];
                    } forEach _departures;
                };

            };
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
private _secondaryTooltip = "Refresh the airfield picture.";

if (!_canAirRead && !_canAirControl && !_canAirPilot) then {
    _secondaryEnabled = false;
};

// Helper: build secondary label based on available view switching.
private _nextViewLabel = if (_nextMode isEqualTo _airSubmode) then {"REFRESH"} else { [_nextMode] call _modeButtonLabel };
private _nextViewTooltip = if (_nextMode isEqualTo _airSubmode) then { "Refresh the airfield picture." } else { format ["Switch to the %1 view.", [_nextMode] call _modeTitle] };

if (_airMode isEqualTo "PILOT") then {
    _primaryLabel = "SEND REQUEST";
    _primaryEnabled = _canAirPilot;
    _primaryTooltip = "Send the selected request to the tower.";
    if (_canAirControl) then {
        _secondaryLabel = "SWITCH TO TOWER";
        _secondaryTooltip = "Switch from pilot tools to tower control.";
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
                        _primaryLabel = if (_holdDepartures) then {"RELEASE DEPARTURES"} else {"HOLD DEPARTURES"};
                        _primaryEnabled = if (_holdDepartures) then { _canAirRelease } else { _canAirHold };
                        if (!_canAirHoldRelease) then {
                            _primaryLabel = "READ-ONLY";
                            _primaryEnabled = false;
                        };
                    };
                    _secondaryLabel = _nextViewLabel;
                    _secondaryTooltip = _nextViewTooltip;
                };
            };
        };
        case "DEBUG":
        {
            _primaryLabel = "READ-ONLY";
            _primaryEnabled = false;
            _secondaryLabel = _nextViewLabel;
            _secondaryTooltip = _nextViewTooltip;
        };
        case "RAMP":
        {
            switch (_rowType) do
            {
                case "ASSET": {
                    _primaryLabel = "QUEUE DEPARTURE";
                    _primaryEnabled = _canAirQueueManage;
                    _primaryTooltip = "Add selected parked aircraft to the departure queue.";
                };
                default {
                    _primaryLabel = "READ-ONLY";
                    _primaryEnabled = false;
                    _primaryTooltip = "Select a parked aircraft to queue.";
                };
            };
            _secondaryLabel = _nextViewLabel;
            _secondaryTooltip = _nextViewTooltip;
        };
        default
        {
            // Phase 3 safety: HDR rows are always inert.
            if (_rowType isEqualTo "HDR") then {
                _primaryLabel = "READ-ONLY";
                _primaryEnabled = false;
                _primaryTooltip = "Header row — no action available.";
            } else {
                _primaryLabel = if (_holdDepartures) then {"RELEASE DEPARTURES"} else {"HOLD DEPARTURES"};
                _primaryEnabled = if (_holdDepartures) then { _canAirRelease } else { _canAirHold };
                if (!_canAirHoldRelease) then {
                    _primaryLabel = "READ-ONLY";
                    _primaryEnabled = false;
                };
            };
            _secondaryLabel = _nextViewLabel;
            _secondaryTooltip = _nextViewTooltip;
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
            format ["Current view: <t color='#FFFFFF'>%1</t>", [_airSubmode] call _modeTitle],
            format ["<t color='#FFFFFF'>%1</t>", [_airSubmode] call _modeGuidance],
            format ["Snapshot: <t color='#FFFFFF'>%1</t>", _freshnessText]
        ];
    };
    case "CSTATUS":
    {
        _selectionHeading = "Clearances Overview";
        _detailLines = [
            format ["<t color='#FFFFFF'>%1</t>", ["CLEARANCES"] call _modeGuidance],
            format ["Pending requests: <t color='#FFFFFF'>%1</t>", count _pendingClearances],
            format ["Queued departures: <t color='#FFFFFF'>%1</t>", count _departures]
        ];
        if (_canAirQueueManage) then {
            _detailLines pushBack "Select a request below to approve or deny.";
        };
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
        private _decPrio = if (_rec isEqualType []) then { _rec param [3, 0] } else { 0 };
        private _decPrioLabel = if (_decPrio >= _PRIO_EMERGENCY) then {"EMERGENCY"} else { if (_decPrio >= _PRIO_ELEVATED) then {"PRIORITY"} else {"Normal"} };
        _selectionHeading = "Decision Required";
        _detailLines = [
            format ["Aircraft: <t color='#FFFFFF'>%1</t>", _decisionLabel],
            format ["Priority: <t color='#FFFFFF'>%1</t>", _decPrioLabel]
        ];
        if (_canAirQueueManage) then {
            _detailLines pushBack "Switch to the Clearance Desk to approve or deny this request.";
        } else {
            _detailLines pushBack "A tower controller needs to decide this request.";
        };
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
            private _phase = _rec param [3, "INBOUND"];
            private _prio = _rec param [5, 0];
            private _status = _rec param [6, "NORMAL"];
            _selectionHeading = format ["Arrival: %1", _trackLabel];
            _detailLines = [
                format ["Aircraft: <t color='#FFFFFF'>%1</t>", _trackLabel],
                format ["Flight phase: <t color='#FFFFFF'>%1</t>", [_phase] call _phaseLabel],
                format ["Time tracked: <t color='#FFFFFF'>%1</t>", [(_rec param [4, -1])] call _fmtSeconds],
                format ["ETA: <t color='#FFFFFF'>%1</t>", [(_rec param [9, -1])] call _fmtSeconds],
                format ["Priority: <t color='#FFFFFF'>%1</t>", [_prio] call _priorityLabel],
                format ["Status: <t color='%1'>%2</t>", [_status] call _statusColor, [_status] call _trafficStatusLabel]
            ];
            // Constraints and action context
            if (_holdDepartures) then {
                _detailLines pushBack "<t color='#F5A623'>Departures on HOLD — runway priority for arrivals.</t>";
            };
            if (_prio >= _PRIO_EMERGENCY) then {
                _detailLines pushBack "<t color='#E74C3C'>EMERGENCY traffic — all other movement yields.</t>";
            };
            if (_canAirControl) then {
                _detailLines pushBack "Action: Use the Clearance Desk to manage this arrival.";
            };
        };
    };
    case "RWY":
    {
        _selectionHeading = "Runway";
        private _holdLabel = if (_holdDepartures) then {"Departures held"} else {"Open for departures"};
        private _holdColor = if (_holdDepartures) then {"#E74C3C"} else {"#4CAF50"};
        private _runtimeColor = if (_runtimeEnabled) then {"#4CAF50"} else {"#E74C3C"};
        _detailLines = [
            format ["State: <t color='%1'>%2</t>", [_runwayState] call _statusColor, _runwayState],
            format ["Current aircraft: <t color='#FFFFFF'>%1</t>", if (_runwayOwnerDisplay isEqualTo "") then {"None"} else {_runwayOwnerDisplay}],
            format ["Movement: <t color='#FFFFFF'>%1</t>", [_activeMovement] call _movementLabel],
            format ["Departure hold: <t color='%1'>%2</t>", _holdColor, _holdLabel],
            format ["Runtime: <t color='%1'>%2</t>", _runtimeColor, _runtimeEnabledLabel]
        ];
        // Constraints
        if (_holdDepartures && { _canAirHoldRelease }) then {
            _detailLines pushBack "Action: Press RELEASE to reopen departures.";
        };
        if (!_holdDepartures && { _canAirHoldRelease }) then {
            _detailLines pushBack "Action: Press HOLD to pause departures.";
        };
        if (!_canAirHoldRelease) then {
            _detailLines pushBack "Read-only: no hold/release authority on this account.";
        };
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
            private _state = _rec param [3, "QUEUED"];
            private _prio = _rec param [5, 0];
            private _status = _rec param [6, "NORMAL"];
            _selectionHeading = format ["Departure: %1", _trackLabel];
            _detailLines = [
                format ["Aircraft: <t color='#FFFFFF'>%1</t>", _trackLabel],
                format ["Departure state: <t color='#FFFFFF'>%1</t>", [_state] call _departureStateLabel],
                format ["Time in queue: <t color='#FFFFFF'>%1</t>", [(_rec param [4, -1])] call _fmtSeconds],
                format ["ETD: <t color='#FFFFFF'>%1</t>", [(_rec param [9, -1])] call _fmtSeconds],
                format ["Priority: <t color='#FFFFFF'>%1</t>", [_prio] call _priorityLabel],
                format ["Status: <t color='%1'>%2</t>", [_status] call _statusColor, [_status] call _trafficStatusLabel]
            ];
            if (_holdDepartures) then {
                _detailLines pushBack "<t color='#F5A623'>Departures on HOLD — this aircraft is waiting.</t>";
            };
            if (_canAirControl) then {
                _detailLines pushBack "Action: Use the Clearance Desk to move this flight forward or cancel it.";
            };
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
            private _prio = _rec param [4, 0];
            _selectionHeading = format ["Clearance: %1", _trackLabel];
            _detailLines = [
                format ["Request: <t color='#FFFFFF'>%1</t>", [(_rec param [1, "-"])] call _requestTypeLabel],
                format ["Aircraft: <t color='#FFFFFF'>%1</t>", _trackLabel],
                format ["Requested: <t color='#FFFFFF'>%1</t>", [(_rec param [3, -1])] call _fmtAgo],
                format ["Priority: <t color='#FFFFFF'>%1</t>", [_prio] call _priorityLabel],
                format ["Decision needed: <t color='#FFFFFF'>%1</t>", if (_rec param [5, false]) then {"YES"} else {"NO"}],
                format ["Automation: <t color='#FFFFFF'>%1</t>", [_meta, "automationStatus", "Awaiting controller/automation"] call _metaGet],
                format ["Auto ETA: <t color='#FFFFFF'>%1</t>", [[_meta, "automationEtaS", -1] call _metaGet] call _fmtSeconds],
                format ["Assigned to: <t color='#FFFFFF'>%1</t>", if ((_rec param [6, ""]) isEqualTo "") then {"Unassigned"} else {_rec param [6, ""]}]
            ];
            if (_prio >= _PRIO_EMERGENCY) then {
                _detailLines pushBack "<t color='#E74C3C'>EMERGENCY — requires immediate decision.</t>";
            };
            if (_canAirQueueManage) then {
                _detailLines pushBack "Action: APPROVE or DENY this request.";
            } else {
                _detailLines pushBack "Read-only: no clearance authority on this account.";
            };
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
            private _state = _rec param [3, "QUEUED"];
            private _prio = _rec param [5, 0];
            _selectionHeading = format ["Queued: %1", _trackLabel];
            _detailLines = [
                format ["Aircraft: <t color='#FFFFFF'>%1</t>", _trackLabel],
                format ["Departure state: <t color='#FFFFFF'>%1</t>", [_state] call _departureStateLabel],
                format ["Time in queue: <t color='#FFFFFF'>%1</t>", [(_rec param [4, -1])] call _fmtSeconds],
                format ["ETD: <t color='#FFFFFF'>%1</t>", [(_rec param [9, -1])] call _fmtSeconds],
                format ["Priority: <t color='#FFFFFF'>%1</t>", [_prio] call _priorityLabel]
            ];
            if (_holdDepartures) then {
                _detailLines pushBack "<t color='#F5A623'>Departures on HOLD — this aircraft is waiting.</t>";
            };
            if (_canAirQueueManage) then {
                _detailLines pushBack "Action: EXPEDITE or CANCEL this flight.";
            };
        };
    };
    case "LANE":
    {
        _selectionHeading = format ["Lane %1", toUpper (_parts param [1, ""])];
        _detailLines = [
            format ["Control position: <t color='#FFFFFF'>%1</t>", [(_parts param [1, ""])] call _laneLabel],
            format ["Mode: <t color='#FFFFFF'>%1</t>", [(_parts param [2, "AUTO"])] call _laneModeLabel],
            format ["Operator: <t color='#FFFFFF'>%1</t>", _parts param [3, "AUTO"]],
            "Use the Clearance Desk to claim or release staffing for this control position."
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
    case "ASSET":
    {
        private _pAid = _parts param [1, ""];
        private _pCat = _parts param [2, "FW"];
        private _pVehType = _parts param [3, ""];
        private _towFlag = _parts param [4, "0"];
        private _requiresTow = (_towFlag isEqualTo "1");
        private _displayName = [_pVehType] call _resolveAircraftDisplay;
        private _label = if (_displayName isEqualTo "") then { _pAid } else { format ["%1 (%2)", _pAid, _displayName] };
        _selectionHeading = format ["Parked: %1", _label];
        _detailLines = [
            format ["Asset ID: <t color='#FFFFFF'>%1</t>", _pAid],
            format ["Category: <t color='#FFFFFF'>%1</t>", _pCat],
            format ["Aircraft type: <t color='#FFFFFF'>%1</t>", if (_displayName isEqualTo "") then { "-" } else { _displayName }],
            format ["Tow required: <t color='#FFFFFF'>%1</t>", if (_requiresTow) then { "Yes" } else { "No" }],
            "Status: <t color='#4CAF50'>PARKED — available for departure</t>"
        ];
        if (_canAirQueueManage) then {
            _detailLines pushBack "Action: Press QUEUE DEPARTURE to add this aircraft to the departure lineup.";
        } else {
            _detailLines pushBack "Read-only: no ramp queue authority on this account.";
        };
    };
    case "RAMP_HDR":
    {
        _selectionHeading = "Ramp Control";
        private _parkedCount = count ([_snapshot, "parkedAssets", []] call _getPair);
        _detailLines = [
            format ["<t color='#FFFFFF'>%1</t>", ["RAMP"] call _modeGuidance],
            format ["Parked and available: <t color='#FFFFFF'>%1</t>", _parkedCount],
            format ["Snapshot: <t color='#FFFFFF'>%1</t>", _freshnessText]
        ];
        if (_canAirQueueManage) then {
            _detailLines pushBack "Select an aircraft below to queue it for departure.";
        } else {
            _detailLines pushBack "Read-only: no ramp queue authority on this account.";
        };
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
            "Press primary button to send this request to tower."
        ];
        if (_canAirControl) then {
            _detailLines pushBack "You also have tower authority — use secondary button to switch.";
        };
    };
    case "PWRN":
    {
        _selectionHeading = "Pilot Warning";
        _detailLines = [
            format ["Request: <t color='#FFFFFF'>%1</t>", [(_parts param [1, ""])] call _requestTypeLabel],
            "<t color='#FFFFFF'>Tower still owes a decision on your inbound request.</t>"
        ];
    };
    default
    {
        _selectionHeading = "AIR / TOWER";
        private _runtimeColor = if (_runtimeEnabled) then {"#4CAF50"} else {"#E74C3C"};
        _detailLines = [
            format ["View: <t color='#FFFFFF'>%1</t>", if (_airMode isEqualTo "PILOT") then {"Pilot Request Tools"} else {[_airSubmode] call _modeTitle}],
            format ["Snapshot: <t color='#FFFFFF'>%1</t>", _freshnessText],
            format ["Runway: <t color='%1'>%2</t>", [_runwayState] call _statusColor, _runwayState],
            format ["Runtime: <t color='%1'>%2</t>", _runtimeColor, _runtimeEnabledLabel],
            format ["Current movement: <t color='#FFFFFF'>%1</t>", [_activeMovement] call _movementLabel],
            format ["Queue: <t color='#FFFFFF'>ARR %1 / DEP %2 / Total %3</t>", _runtimeArrQueued, _runtimeDepQueued, _runtimeTotalQueued],
            format ["Inbound: <t color='#FFFFFF'>%1</t>", count _arrivals],
            format ["Outbound: <t color='#FFFFFF'>%1</t>", count _departures],
            format ["Decisions pending: <t color='#FFFFFF'>%1</t>", count _decisionQueue],
            format ["Recent events: <t color='#FFFFFF'>%1</t>", count _recentEvents],
            format ["Staffing lanes: <t color='#FFFFFF'>%1</t>", count _staffing],
            format ["Clearance history: <t color='#FFFFFF'>%1</t>", count _clearanceHistory]
        ];
        private _capacityBits = [];
        if (_runtimeListMax > 0) then { _capacityBits pushBack format ["List %1", _runtimeListMax]; };
        if (_runtimeArrSlot > 0) then { _capacityBits pushBack format ["ARR slot %1s", _runtimeArrSlot]; };
        if (_runtimeDepSlot > 0) then { _capacityBits pushBack format ["DEP slot %1s", _runtimeDepSlot]; };
        if (_runtimePublishInterval > 0) then { _capacityBits pushBack format ["Refresh %1s", _runtimePublishInterval]; };
        if ((count _capacityBits) > 0) then {
            _detailLines pushBack format ["Capacity: <t color='#8FA8C0'>%1</t>", _capacityBits joinString " · "];
        };
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

_airP set [1, _defaultPosAir select 1];

_airP set [2, _defaultPosAir select 2];
_airP set [3, (_airP select 3) max _airMinH];
_ctrlDetails ctrlSetPosition _airP;
_ctrlDetails ctrlCommit 0;

uiNamespace setVariable ["ARC_console_airLastStateUpdatedAt", _stateUpdatedAt];
uiNamespace setVariable ["ARC_console_airLastRev", _snapshotRev];
true

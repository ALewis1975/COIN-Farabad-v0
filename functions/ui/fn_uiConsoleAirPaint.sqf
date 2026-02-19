/*
    ARC_fnc_uiConsoleAirPaint

    Paint AIR tab list/details from ARC_pub_state airbase snapshot.

    Params:
      0: DISPLAY
      1: BOOL rebuild list (default false)
*/

if (!hasInterface) exitWith {false};

params [
    ["_display", displayNull, [displayNull]],
    ["_rebuild", false, [true]]
];
if (isNull _display) exitWith {false};

private _ctrlList = _display displayCtrl 78011;
private _ctrlDetails = _display displayCtrl 78012;
private _btnPrimary = _display displayCtrl 78002;
private _btnSecondary = _display displayCtrl 78003;
if (isNull _ctrlList || { isNull _ctrlDetails }) exitWith {false};

private _owner = uiNamespace getVariable ["ARC_console_mainListOwner", ""];
if (!(_owner isEqualType "")) then { _owner = ""; };
_owner = toUpper _owner;
if (!(_owner isEqualTo "AIR")) then { _rebuild = true; };
uiNamespace setVariable ["ARC_console_mainListOwner", "AIR"];

private _pub = missionNamespace getVariable ["ARC_pub_state", []];
if (!(_pub isEqualType [])) then { _pub = []; };

private _getPub = {
    params ["_pairs", "_k", "_def"];

    private _val = _def;
    {
        if ((_x isEqualType []) && { (count _x) >= 2 }) then {
            if (((_x select 0)) isEqualTo _k) exitWith {
                _val = (_x select 1);
            };
        };
    } forEach _pairs;

    _val
};

private _metaGet = {
    params ["_rows", "_k", "_def"];
    private _v = _def;
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { ((_x # 0)) isEqualTo _k }) exitWith { _v = _x # 1; };
    } forEach _rows;
    _v
};

private _warnBadgeMeta = {
    params ["_meta"];
    private _wl = toUpperANSI ([_meta, "arrivalWarnLevel", "NONE"] call _metaGet);
    private _dist = [_meta, "arrivalDistanceM", -1] call _metaGet;
    private _distTxt = if (_dist isEqualType 0 && { _dist >= 0 }) then { format ["%1m", round _dist] } else { "-" };
    switch (_wl) do {
        case "URGENT": { format ["[URGENT %1]", _distTxt] };
        case "CAUTION": { format ["[CAUTION %1]", _distTxt] };
        case "ADVISORY": { format ["[ADVISORY %1]", _distTxt] };
        default { "" };
    }
};

private _fmtTime = {
    params ["_t"];
    if (!(_t isEqualType 0) || { _t < 0 }) exitWith {"-"};

    private _v = floor _t;
    private _m = floor (_v / 60);
    private _s = _v mod 60;
    format ["%1m %2s", _m, _s]
};

private _air = [_pub, "airbase", []] call _getPub;
if (!(_air isEqualType [])) then { _air = []; };

private _depQueued = [_air, "depQueued", 0] call _getPub;
if (!(_depQueued isEqualType 0)) then { _depQueued = 0; };

private _arrQueued = [_air, "arrQueued", 0] call _getPub;
if (!(_arrQueued isEqualType 0)) then { _arrQueued = 0; };

private _totalQueued = [_air, "totalQueued", 0] call _getPub;
if (!(_totalQueued isEqualType 0)) then { _totalQueued = 0; };

private _execActive = [_air, "execActive", false] call _getPub;
if (!(_execActive isEqualType true) && !(_execActive isEqualType false)) then { _execActive = false; };

private _execFid = [_air, "execFid", ""] call _getPub;
if (!(_execFid isEqualType "")) then { _execFid = ""; };

private _runwayState = [_air, "runwayState", "UNKNOWN"] call _getPub;
if (!(_runwayState isEqualType "")) then { _runwayState = "UNKNOWN"; };

private _runwayOwner = [_air, "runwayOwner", ""] call _getPub;
if (!(_runwayOwner isEqualType "")) then { _runwayOwner = ""; };

private _runwayUntil = [_air, "runwayUntil", -1] call _getPub;
if (!(_runwayUntil isEqualType 0)) then { _runwayUntil = -1; };

private _holdDepartures = [_air, "holdDepartures", false] call _getPub;
if (!(_holdDepartures isEqualType true) && !(_holdDepartures isEqualType false)) then { _holdDepartures = false; };
uiNamespace setVariable ["ARC_console_airHoldDepartures", _holdDepartures];

private _nextItems = [_air, "nextItems", []] call _getPub;
if (!(_nextItems isEqualType [])) then { _nextItems = []; };

private _clearancePending = [_air, "clearanceControllerPending", []] call _getPub;
if (!(_clearancePending isEqualType [])) then { _clearancePending = []; };

private _clearanceHistoryTail = [_air, "clearanceHistoryTail", []] call _getPub;
if (!(_clearanceHistoryTail isEqualType [])) then { _clearanceHistoryTail = []; };

private _awaitingCount = [_air, "clearanceAwaitingTowerCount", 0] call _getPub;
if (!(_awaitingCount isEqualType 0)) then { _awaitingCount = 0; };

private _towerStaffing = [_air, "towerStaffing", []] call _getPub;
if (!(_towerStaffing isEqualType [])) then { _towerStaffing = []; };

private _staffLaneRec = {
    params ["_rows", "_lane"];
    private _idx = _rows findIf {
        (_x isEqualType []) &&
        { (count _x) >= 5 } &&
        { ((_x param [0, ""]) isEqualTo _lane) }
    };
    if (_idx < 0) exitWith { [_lane, "AUTO", "", "", -1] };
    _rows # _idx
};

private _towerLane = [_towerStaffing, "tower"] call _staffLaneRec;
private _groundLane = [_towerStaffing, "ground"] call _staffLaneRec;
private _arrivalLane = [_towerStaffing, "arrival"] call _staffLaneRec;

private _stateUpdatedAt = missionNamespace getVariable ["ARC_pub_stateUpdatedAt", -1];
if (!(_stateUpdatedAt isEqualType 0)) then { _stateUpdatedAt = -1; };

private _airModeList = ["ARC_console_airMode", "TOWER"] call ARC_fnc_uiNsGetString;
_airModeList = toUpperANSI (trim _airModeList);
if !(_airModeList in ["TOWER", "PILOT"]) then { _airModeList = "TOWER"; };

if (_rebuild) then {
    lbClear _ctrlList;

    if (_airModeList isEqualTo "PILOT") then {
        private _hdrPilot = _ctrlList lbAdd "-- PILOT ACTIONS --";
        _ctrlList lbSetData [_hdrPilot, "HDR|PACT"];
        {
            private _row = _ctrlList lbAdd (_x # 0);
            _ctrlList lbSetData [_row, format ["PACT|%1", _x # 1]];
        } forEach [
            ["Request Taxi", "REQ_TAXI"],
            ["Request Takeoff", "REQ_TAKEOFF"],
            ["Request Inbound", "REQ_INBOUND"],
            ["Declare Emergency", "REQ_EMERGENCY"],
            ["Cancel Request", "CANCEL"]
        ];

        private _uidPilot = getPlayerUID player;
        private _myArrivals = _clearancePending select {
            private _meta = _x param [9, []];
            private _pid = [_meta, "pilotUid", ""] call _metaGet;
            private _rtype = toUpperANSI (_x param [1, ""]);
            (_pid isEqualTo _uidPilot) && (_rtype in ["REQ_INBOUND", "REQ_LAND"])
        };
        if ((count _myArrivals) > 0) then {
            private _hdrWarn = _ctrlList lbAdd "-- PILOT ATC WARNINGS --";
            _ctrlList lbSetData [_hdrWarn, "HDR|PWARN"];
            {
                private _rid = _x param [0, ""];
                private _rtype = _x param [1, ""];
                private _status = toUpperANSI (_x param [5, ""]);
                private _meta = _x param [9, []];
                private _badge = [_meta] call _warnBadgeMeta;
                if (_badge isEqualTo "") then { _badge = "[NONE]"; };
                private _row = _ctrlList lbAdd format ["%1 %2 %3 (%4)", _rid, _rtype, _badge, _status];
                _ctrlList lbSetData [_row, format ["PWRN|%1", _rid]];
            } forEach _myArrivals;
        };

        if ((lbSize _ctrlList) > 1) then { _ctrlList lbSetCurSel 1; };
    } else {

    private _hdrReq = _ctrlList lbAdd "-- PENDING CLEARANCES --";
    _ctrlList lbSetData [_hdrReq, "HDR|REQ"];

    if ((count _clearancePending) == 0) then {
        private _noneReq = _ctrlList lbAdd "(none)";
        _ctrlList lbSetData [_noneReq, "REQ|NONE"];
    } else {
        {
            if !(_x isEqualType []) then { continue; };

            private _rid = _x param [0, ""];
            private _rtype = _x param [1, ""];
            private _pilot = _x param [2, ""];
            private _prio = _x param [4, 0];
            private _status = toUpperANSI (_x param [5, ""]);
            private _updated = _x param [7, -1];
            private _decision = _x param [8, []];
            private _meta = _x param [9, []];
            private _groupName = [_meta, "pilotGroupName", ""] call _metaGet;
            private _callsign = [_meta, "pilotCallsign", ""] call _metaGet;
            private _acType = [_meta, "aircraftType", ""] call _metaGet;
            private _decBy = "";
            if (_decision isEqualType [] && { (count _decision) >= 1 }) then { _decBy = _decision param [0, ""]; };

            private _pilotLabel = if (_callsign isEqualTo "") then { _pilot } else { _callsign };
            if (_groupName isNotEqualTo "") then { _pilotLabel = format ["%1 | %2", _pilotLabel, _groupName]; };
            private _warnBadge = [_meta] call _warnBadgeMeta;
            private _lbl = format ["%1 [%2] %3 (%4)", _rid, _rtype, _pilotLabel, _status];
            if (_warnBadge isNotEqualTo "") then { _lbl = format ["%1 %2", _lbl, _warnBadge]; };
            if (_acType isNotEqualTo "") then { _lbl = format ["%1 <%2>", _lbl, _acType]; };
            if ((_prio isEqualType 0) && { _prio >= 100 }) then { _lbl = format ["%1 !EMERGENCY!", _lbl]; };

            private _row = _ctrlList lbAdd _lbl;
            _ctrlList lbSetData [_row, format ["REQ|%1|%2|%3|%4|%5|%6", _rid, _rtype, _pilot, _status, _updated, _decBy]];
        } forEach _clearancePending;
    };

    private _hdrFlt = _ctrlList lbAdd "-- SCHEDULED FLIGHTS --";
    _ctrlList lbSetData [_hdrFlt, "HDR|FLT"];

    if ((count _nextItems) == 0) then {
        private _noneF = _ctrlList lbAdd "(none)";
        _ctrlList lbSetData [_noneF, "FLT|NONE"];
    } else {
        {
            if !(_x isEqualType []) then { continue; };
            private _fid = _x param [0, ""];
            private _kind = _x param [1, ""];
            private _asset = _x param [2, ""];
            private _routeMeta = _x param [3, []];
            if !(_routeMeta isEqualType []) then { _routeMeta = []; };
            private _laneDecision = [_routeMeta, "runwayLaneDecision", "-"] call _metaGet;

            private _lbl = format ["%1  [%2] %3 lane=%4", _fid, _kind, _asset, _laneDecision];
            private _row = _ctrlList lbAdd _lbl;
            _ctrlList lbSetData [_row, format ["FLT|%1|%2|%3", _fid, _kind, _asset]];
        } forEach _nextItems;
    };

    private _hdrLane = _ctrlList lbAdd "-- ATC STAFFING --";
    _ctrlList lbSetData [_hdrLane, "HDR|LANE"];

    {
        private _lane = _x param [0, ""];
        private _status = toUpperANSI (_x param [1, "AUTO"]);
        private _op = _x param [2, ""];
        private _uid = _x param [3, ""];
        private _ts = _x param [4, -1];
        private _who = if (_status isEqualTo "MANNED" && { _op isNotEqualTo "" }) then { _op } else { "AUTO" };
        private _lbl = format ["%1: %2", toUpperANSI _lane, _who];
        private _row = _ctrlList lbAdd _lbl;
        _ctrlList lbSetData [_row, format ["LANE|%1|%2|%3|%4|%5", _lane, _status, _op, _uid, _ts]];
    } forEach [_towerLane, _groundLane, _arrivalLane];

    private _hdrRwy = _ctrlList lbAdd "-- RUNWAY LOCK STATUS --";
    _ctrlList lbSetData [_hdrRwy, "HDR|RWY"];
    private _runwayLbl = format ["State %1 | Owner %2", _runwayState, if (_runwayOwner isEqualTo "") then {"-"} else {_runwayOwner}];
    private _runwayRow = _ctrlList lbAdd _runwayLbl;
    _ctrlList lbSetData [_runwayRow, format ["RWY|%1|%2|%3", _runwayState, _runwayOwner, _runwayUntil]];

    private _hdrDec = _ctrlList lbAdd "-- RECENT DECISIONS --";
    _ctrlList lbSetData [_hdrDec, "HDR|DEC"];

    private _decisions = _clearanceHistoryTail select {
        private _s = toUpperANSI (_x param [6, ""]);
        _s in ["APPROVED", "DENIED", "CANCELED"]
    };

    if ((count _decisions) == 0) then {
        private _noneD = _ctrlList lbAdd "(none)";
        _ctrlList lbSetData [_noneD, "DEC|NONE"];
    } else {
        private _take = 5 min (count _decisions);
        for "_i" from 0 to (_take - 1) do {
            private _rec = _decisions select ((count _decisions) - 1 - _i);
            private _rid = _rec param [0, ""];
            private _status = toUpperANSI (_rec param [6, ""]);
            private _upd = _rec param [8, -1];
            private _dec = _rec param [9, []];
            private _by = if (_dec isEqualType []) then { _dec param [0, ""] } else { "" };
            private _action = if (_dec isEqualType []) then { _dec param [3, ""] } else { "" };

            private _row = _ctrlList lbAdd format ["%1 %2 by %3", _rid, _status, if (_by isEqualTo "") then {"UNKNOWN"} else {_by}];
            _ctrlList lbSetData [_row, format ["DEC|%1|%2|%3|%4", _rid, _status, _upd, _action]];
        };
    };

    if ((lbSize _ctrlList) > 0) then { _ctrlList lbSetCurSel 0; };
    };
};

private _sel = lbCurSel _ctrlList;
if (_sel < 0 && { (lbSize _ctrlList) > 0 }) then { _sel = 0; _ctrlList lbSetCurSel 0; };

private _selData = if (_sel >= 0) then { _ctrlList lbData _sel } else { "" };
if (!(_selData isEqualType "")) then { _selData = ""; };

private _parts = _selData splitString "|";
private _rowType = if ((count _parts) > 0) then { _parts select 0 } else { "" };
private _selectedFid = if (_rowType isEqualTo "FLT") then { _parts param [1, ""] } else { "" };
uiNamespace setVariable ["ARC_console_airSelectedFid", _selectedFid];
uiNamespace setVariable ["ARC_console_airSelectedRow", _parts];
uiNamespace setVariable ["ARC_console_airSelectedRowType", _rowType];

private _canAirHoldRelease = ["ARC_console_airCanHoldRelease", false] call ARC_fnc_uiNsGetBool;
private _canAirQueueManage = ["ARC_console_airCanQueueManage", false] call ARC_fnc_uiNsGetBool;
private _canAirStaff = ["ARC_console_airCanStaff", false] call ARC_fnc_uiNsGetBool;
private _canAirRead = ["ARC_console_airCanRead", false] call ARC_fnc_uiNsGetBool;
private _canAirControl = _canAirHoldRelease || _canAirQueueManage || _canAirStaff;
private _canAirPilot = ["ARC_console_airCanPilot", false] call ARC_fnc_uiNsGetBool;
private _airMode = ["ARC_console_airMode", if (_canAirPilot && !_canAirControl) then {"PILOT"} else {"TOWER"}] call ARC_fnc_uiNsGetString;
_airMode = toUpperANSI (trim _airMode);
if !(_airMode in ["TOWER", "PILOT"]) then { _airMode = "TOWER"; };
if ((_airMode isEqualTo "PILOT") && !_canAirPilot) then { _airMode = "TOWER"; };
uiNamespace setVariable ["ARC_console_airMode", _airMode];

private _canText = if (_airMode isEqualTo "PILOT") then {
    format ["SUBMODE: PILOT | REQUEST PERMISSION %1", if (_canAirPilot) then {"YES"} else {"NO"}]
} else {
    if (_canAirControl) then {
        format [
            "SUBMODE: TOWER | HOLD/RELEASE %1 | EXPEDITE/CANCEL %2",
            if (_canAirHoldRelease) then {"YES"} else {"NO"},
            if (_canAirQueueManage) then {"YES"} else {"NO"}
        ]
    } else {
        if (_canAirRead) then { "SUBMODE: TOWER | READ-ONLY" } else { "SUBMODE: TOWER | NO ACCESS" }
    }
};

private _nextActionOwner = "TOWER";
private _selectedState = "NONE";
private _selectedUpdated = -1;
private _selectedDetail = "Select a row.";
private _selectedRouteDetail = "-";

private _primaryLabel = "HOLD";
private _secondaryLabel = "RELEASE";
private _primaryTooltip = "Global control: HOLD departures.";
private _secondaryTooltip = "Global control: RELEASE departures.";
private _primaryEnabled = _canAirHoldRelease;
private _secondaryEnabled = _canAirHoldRelease;

switch (_rowType) do {
    case "REQ": {
        private _rid = _parts param [1, ""];
        if (_rid isEqualTo "NONE") then {
            _selectedState = "NO_PENDING_REQUESTS";
            _nextActionOwner = "SYSTEM";
            _selectedDetail = "No pending clearance requests.";
            _primaryLabel = "APPROVE (N/A)";
            _secondaryLabel = "DENY (N/A)";
            _primaryEnabled = false;
            _secondaryEnabled = false;
            _primaryTooltip = "No request selected.";
            _secondaryTooltip = "No request selected.";
        } else {
            _selectedState = _parts param [4, "PENDING"];
            _selectedUpdated = parseNumber (_parts param [5, "-1"]);
            _nextActionOwner = "TOWER_CONTROLLER";
            _selectedDetail = format ["Request %1 (%2) from %3", _rid, _parts param [2, ""], _parts param [3, ""]];
            private _reqIdx = _clearancePending findIf { (_x param [0, ""]) isEqualTo _rid };
            if (_reqIdx >= 0) then {
                private _reqRec = _clearancePending # _reqIdx;
                private _reqMeta = _reqRec param [9, []];
                private _laneDecision = [_reqMeta, "runwayLaneDecision", "-"] call _metaGet;
                private _runwayMarker = [_reqMeta, "runwayMarker", "-"] call _metaGet;
                private _chain = [_reqMeta, "routeMarkerChain", []] call _metaGet;
                if !(_chain isEqualType []) then { _chain = []; };
                _selectedRouteDetail = format ["%1 via %2 (%3)", _laneDecision, _runwayMarker, if ((count _chain) > 0) then { _chain joinString " -> " } else { "no-chain" }];
            };
            _primaryLabel = "APPROVE";
            _secondaryLabel = "DENY";
            _primaryEnabled = _canAirQueueManage;
            _secondaryEnabled = _canAirQueueManage;
            _primaryTooltip = if (_canAirQueueManage) then { "Approve selected clearance request." } else { "Disabled: no queue authorization." };
            _secondaryTooltip = if (_canAirQueueManage) then { "Deny selected clearance request." } else { "Disabled: no queue authorization." };
        };
    };

    case "FLT": {
        private _fid = _parts param [1, ""];
        if (_fid isEqualTo "NONE") then {
            _selectedState = "NO_QUEUED_FLIGHTS";
            _nextActionOwner = "SYSTEM";
            _selectedDetail = "No queued flights available.";
            _primaryLabel = "EXPEDITE (N/A)";
            _secondaryLabel = "CANCEL (N/A)";
            _primaryEnabled = false;
            _secondaryEnabled = false;
            _primaryTooltip = "No flight selected.";
            _secondaryTooltip = "No flight selected.";
        } else {
            _selectedState = "QUEUED";
            _selectedUpdated = _stateUpdatedAt;
            _nextActionOwner = "TOWER_CONTROLLER";
            _selectedDetail = format ["Flight %1 [%2] %3", _fid, _parts param [2, ""], _parts param [3, ""]];
            private _fltIdx = _nextItems findIf { (_x param [0, ""]) isEqualTo _fid };
            if (_fltIdx >= 0) then {
                private _fltMeta = (_nextItems # _fltIdx) param [3, []];
                if !(_fltMeta isEqualType []) then { _fltMeta = []; };
                private _laneDecision = [_fltMeta, "runwayLaneDecision", "-"] call _metaGet;
                private _runwayMarker = [_fltMeta, "runwayMarker", "-"] call _metaGet;
                private _chain = [_fltMeta, "routeMarkerChain", []] call _metaGet;
                if !(_chain isEqualType []) then { _chain = []; };
                _selectedRouteDetail = format ["%1 via %2 (%3)", _laneDecision, _runwayMarker, if ((count _chain) > 0) then { _chain joinString " -> " } else { "no-chain" }];
            };
            _primaryLabel = "EXPEDITE";
            _secondaryLabel = "CANCEL";
            _primaryEnabled = _canAirQueueManage;
            _secondaryEnabled = _canAirQueueManage;
            _primaryTooltip = if (_canAirQueueManage) then { "Expedite selected queued flight." } else { "Disabled: no queue authorization." };
            _secondaryTooltip = if (_canAirQueueManage) then { "Cancel selected queued flight." } else { "Disabled: no queue authorization." };
        };
    };

    case "LANE": {
        private _lane = _parts param [1, "tower"];
        private _status = toUpperANSI (_parts param [2, "AUTO"]);
        private _op = _parts param [3, ""];
        _selectedState = format ["LANE_%1_%2", toUpperANSI _lane, _status];
        _selectedUpdated = parseNumber (_parts param [5, "-1"]);
        _nextActionOwner = "TOWER_CONTROLLER";
        _selectedDetail = format ["%1 lane controller: %2", toUpperANSI _lane, if (_op isEqualTo "") then {"AUTO"} else {_op}];
        _primaryLabel = "CLAIM";
        _secondaryLabel = "RELEASE";
        _primaryEnabled = _canAirStaff;
        _secondaryEnabled = _canAirStaff;
        _primaryTooltip = if (_canAirStaff) then { "Assign selected lane to yourself." } else { "Disabled: no staffing authorization." };
        _secondaryTooltip = if (_canAirStaff) then { "Release selected lane back to AUTO." } else { "Disabled: no staffing authorization." };
    };

    case "RWY": {
        _selectedState = _parts param [1, "UNKNOWN"];
        _selectedUpdated = _stateUpdatedAt;
        _nextActionOwner = "TOWER_CONTROLLER";
        _selectedDetail = format ["Runway lock state %1 (owner %2)", _parts param [1, ""], if ((_parts param [2, ""]) isEqualTo "") then {"-"} else {_parts param [2, ""]}];
        _primaryLabel = "HOLD";
        _secondaryLabel = "RELEASE";
        _primaryEnabled = _canAirHoldRelease;
        _secondaryEnabled = _canAirHoldRelease;
        _primaryTooltip = if (_canAirHoldRelease) then { "Global hold on departures." } else { "Disabled: no hold/release authorization." };
        _secondaryTooltip = if (_canAirHoldRelease) then { "Global release departures." } else { "Disabled: no hold/release authorization." };
    };

    case "PACT": {
        _selectedState = "PILOT_ACTION";
        _nextActionOwner = "PILOT";
        _selectedUpdated = _stateUpdatedAt;
        _selectedDetail = format ["Pilot action selected: %1", _parts param [1, ""]];
        _primaryLabel = "SEND REQUEST";
        _secondaryLabel = if (_canAirControl) then {"MODE: TOWER"} else {"REFRESH"};
        _primaryEnabled = _canAirPilot;
        _secondaryEnabled = _canAirPilot || _canAirControl;
        _primaryTooltip = "Submit selected pilot request to tower queue.";
        _secondaryTooltip = if (_canAirControl) then {"Switch to tower control submode."} else {"Refresh pilot queue snapshot."};
    };

    case "DEC": {
        _selectedState = _parts param [2, "UNKNOWN"];
        _selectedUpdated = parseNumber (_parts param [3, "-1"]);
        _nextActionOwner = "AUDIT";
        _selectedDetail = format ["Decision record %1 (%2)", _parts param [1, ""], _parts param [4, ""]];
        _primaryLabel = "HOLD";
        _secondaryLabel = "RELEASE";
        _primaryEnabled = _canAirHoldRelease;
        _secondaryEnabled = _canAirHoldRelease;
        _primaryTooltip = if (_canAirHoldRelease) then { "Global hold on departures." } else { "Disabled: no hold/release authorization." };
        _secondaryTooltip = if (_canAirHoldRelease) then { "Global release departures." } else { "Disabled: no hold/release authorization." };
    };

    default {
        _selectedState = "OVERVIEW";
        _selectedUpdated = _stateUpdatedAt;
        _nextActionOwner = "TOWER_CONTROLLER";
        _selectedDetail = "AIR overview.";
        _primaryLabel = "HOLD";
        _secondaryLabel = "RELEASE";
        _primaryEnabled = _canAirHoldRelease;
        _secondaryEnabled = _canAirHoldRelease;
        _primaryTooltip = if (_canAirHoldRelease) then { "Global hold on departures." } else { "Disabled: no hold/release authorization." };
        _secondaryTooltip = if (_canAirHoldRelease) then { "Global release departures." } else { "Disabled: no hold/release authorization." };
    };
};

if (!_canAirRead && !_canAirControl && !_canAirPilot) then {
    _primaryEnabled = false;
    _secondaryEnabled = false;
    _primaryLabel = "NO ACCESS";
    _secondaryLabel = "NO ACCESS";
    _primaryTooltip = "No AIR permissions.";
    _secondaryTooltip = "No AIR permissions.";
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

private _details = format [
    "<t size='1.05' color='#B89B6B'>AIRBASE SNAPSHOT</t>"
    + "<br/><t color='#CFCFCF'>%1</t>"
    + "<br/><br/><t color='#B89B6B'>Queue Summary</t>"
    + "<br/>Departures queued: <t color='#FFFFFF'>%2</t>"
    + "<br/>Arrivals queued: <t color='#FFFFFF'>%3</t>"
    + "<br/>Total queued: <t color='#FFFFFF'>%4</t>"
    + "<br/><br/><t color='#B89B6B'>Runway</t>"
    + "<br/>State: <t color='#FFFFFF'>%5</t> | Owner: <t color='#FFFFFF'>%6</t>"
    + "<br/>Hold departures: <t color='#FFFFFF'>%7</t>"
    + "<br/>Tower: <t color='#FFFFFF'>%8</t> | Ground: <t color='#FFFFFF'>%9</t> | Arrival: <t color='#FFFFFF'>%10</t>"
    + "<br/>Execution: <t color='#FFFFFF'>%11</t>"
    + "<br/><br/><t color='#B89B6B'>Selection</t>"
    + "<br/>State: <t color='#FFFFFF'>%12</t>"
    + "<br/>Last update: <t color='#FFFFFF'>%13</t>"
    + "<br/>Next action owner: <t color='#FFFFFF'>%14</t>"
    + "<br/><t color='#CFCFCF'>%15</t>"
    + "<br/>Route decision: <t color='#FFFFFF'>%16</t>"
    + "<br/><br/><t color='#B89B6B'>Pending/Awaiting</t>"
    + "<br/>Awaiting tower decision: <t color='#FFFFFF'>%17</t>"
    + "<br/>Arrival warnings (A/C/U): <t color='#FFFFFF'>%18/%19/%20m</t>",
    _canText,
    _depQueued,
    _arrQueued,
    _totalQueued,
    _runwayState,
    if (_runwayOwner isEqualTo "") then {"-"} else {_runwayOwner},
    if (_holdDepartures) then {"HOLD ACTIVE"} else {"OPEN"},
    if ((toUpperANSI (_towerLane param [1, "AUTO"])) isEqualTo "MANNED") then { _towerLane param [2, "AUTO"] } else { "AUTO" },
    if ((toUpperANSI (_groundLane param [1, "AUTO"])) isEqualTo "MANNED") then { _groundLane param [2, "AUTO"] } else { "AUTO" },
    if ((toUpperANSI (_arrivalLane param [1, "AUTO"])) isEqualTo "MANNED") then { _arrivalLane param [2, "AUTO"] } else { "AUTO" },
    if (_execActive) then { format ["%1", _execFid] } else { "none" },
    _selectedState,
    [_selectedUpdated] call _fmtTime,
    _nextActionOwner,
    _selectedDetail,
    _selectedRouteDetail,
    _awaitingCount,
    [_air, "arrivalWarnAdvisoryM", 7000] call _getPub,
    [_air, "arrivalWarnCautionM", 4500] call _getPub,
    [_air, "arrivalWarnUrgentM", 2600] call _getPub
];

_ctrlDetails ctrlSetStructuredText parseText _details;
true

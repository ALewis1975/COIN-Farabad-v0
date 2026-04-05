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
private _btnPrimary = _display displayCtrl 78021;
private _btnSecondary = _display displayCtrl 78022;
if (isNull _ctrlList || { isNull _ctrlDetails }) exitWith {false};

private _owner = uiNamespace getVariable ["ARC_console_mainListOwner", ""];
if (!(_owner isEqualType "")) then { _owner = ""; };
_owner = toUpper _owner;
if (!(_owner isEqualTo "AIR")) then { _rebuild = true; };
if ((lbSize _ctrlList) <= 0) then { _rebuild = true; };
uiNamespace setVariable ["ARC_console_mainListOwner", "AIR"];

private _pub = missionNamespace getVariable ["ARC_pub_state", []];
if (!(_pub isEqualType [])) then { _pub = []; };

private _stateUpdatedAt = missionNamespace getVariable ["ARC_pub_stateUpdatedAt", -1];
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
        if (_x isEqualType [] && { (count _x) >= 2 } && { ((_x select 0)) isEqualTo _k }) exitWith { _v = _x select 1; };
    } forEach _rows;
    _v
};

private _warnBadgeMeta = {
    params ["_meta"];
    private _wl = toUpper ([_meta, "arrivalWarnLevel", "NONE"] call _metaGet);
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

// sqflint 0.3.2 compat: wrap trim via compile so the linter does not error on unknown operator.
private _trimFn = compile "params ['_s']; trim _s";

// Human-readable relative time ("just now", "30s ago", "2m 15s ago").
// Uses serverTime so timestamps from airbase events are comparable on clients.
private _fmtAgo = {
    params ["_t"];
    if (!(_t isEqualType 0) || { _t < 0 }) exitWith { "-" };
    private _age = (serverTime - _t) max 0;
    if (_age < 5)  exitWith { "just now" };
    if (_age < 60) exitWith { format ["%1s ago", round _age] };
    format ["%1m %2s ago", floor (_age / 60), (round _age) mod 60]
};

// Human-readable label for a single event record from recentEvents.
// Event structure (after eventsView normalization): [ts, kind, rid, actorUid, targetUid, meta]
private _fmtEventRow = {
    params ["_ev"];
    private _ts   = _ev param [0, -1];
    private _kind = toUpper (_ev param [1, ""]);
    private _rid  = _ev param [2, ""];
    private _meta = _ev param [5, []];
    if !(_meta isEqualType []) then { _meta = []; };
    private _ago  = [_ts] call _fmtAgo;

    private _lbl = format ["%1 %2 (%3)", _kind, _rid, _ago];
    if (_kind isEqualTo "EXEC_START") then {
        private _acKind = toUpper (_meta param [0, ""]);
        private _dir = if (_acKind isEqualTo "ARR") then { "ARRIVING" } else { "DEPARTING" };
        _lbl = format [">>> %1 %2 (%3)", _rid, _dir, _ago];
    };
    if (_kind isEqualTo "EXEC_END") then {
        private _outcome = toUpper (_meta param [0, "FAILED"]);
        if (_outcome isEqualTo "COMPLETE") then {
            _lbl = format ["<<< %1 COMPLETE (%2)", _rid, _ago];
        } else {
            _lbl = format ["!!! %1 ABORTED (%2)", _rid, _ago];
        };
    };
    if (_kind isEqualTo "APPROVE")              then { _lbl = format ["CLR: %1 APPROVED (%2)",   _rid, _ago]; };
    if (_kind isEqualTo "AUTO_QUEUE")           then { _lbl = format ["AUTO: %1 QUEUED (%2)",    _rid, _ago]; };
    if (_kind isEqualTo "LIFECYCLE_LAND_GATE")  then { _lbl = format ["LAND GATE: %1 (%2)",      _rid, _ago]; };
    if (_kind isEqualTo "ESCALATE")             then { _lbl = format ["ALERT: %1 ESCALATED (%2)", _rid, _ago]; };
    _lbl
};

private _air = [_pub, "airbase", []] call _getPub;
if (!(_air isEqualType [])) then { _air = []; };

private _casreqPub = [_pub, "casreq", []] call _getPub;
if (!(_casreqPub isEqualType [])) then { _casreqPub = []; };

private _casreqId = [_casreqPub, "casreq_id", ""] call _getPub;
if (!(_casreqId isEqualType "")) then { _casreqId = ""; };

private _casreqSnapshot = [_casreqPub, "casreq_snapshot", []] call _getPub;
if (!(_casreqSnapshot isEqualType [])) then { _casreqSnapshot = []; };

private _casreqState = [_casreqSnapshot, "state", "-"] call _getPub;
if (!(_casreqState isEqualType "")) then { _casreqState = "-"; };

private _casreqDistrict = [_casreqSnapshot, "district_id", "-"] call _getPub;
if (!(_casreqDistrict isEqualType "")) then { _casreqDistrict = "-"; };

private _casreqRev = [_casreqPub, "rev", 0] call _getPub;
if (!(_casreqRev isEqualType 0)) then { _casreqRev = 0; };

uiNamespace setVariable ["ARC_console_casreqSnapshot", _casreqSnapshot];
uiNamespace setVariable ["ARC_console_casreqId", _casreqId];

private _depQueued = [_air, "depQueued", 0] call _getPub;
if (!(_depQueued isEqualType 0)) then { _depQueued = 0; };

private _arrQueued = [_air, "arrQueued", 0] call _getPub;
if (!(_arrQueued isEqualType 0)) then { _arrQueued = 0; };

private _depInProgress = [_air, "depInProgress", 0] call _getPub;
if (!(_depInProgress isEqualType 0) || { _depInProgress < 0 }) then { _depInProgress = 0; };
if (_depInProgress > 1) then { _depInProgress = 1; };

private _effectiveDepartures = (0 max _depQueued) + _depInProgress;

private _totalQueued = [_air, "totalQueued", ((0 max _depQueued) + (0 max _arrQueued))] call _getPub;
if (!(_totalQueued isEqualType 0)) then { _totalQueued = (0 max _depQueued) + (0 max _arrQueued); };

private _blockedRouteAttemptsRecent = [_air, "blockedRouteAttemptsRecent", 0] call _getPub;
if (!(_blockedRouteAttemptsRecent isEqualType 0) || { _blockedRouteAttemptsRecent < 0 }) then { _blockedRouteAttemptsRecent = 0; };

private _blockedRouteLatestReason = [_air, "blockedRouteLatestReason", "-"] call _getPub;
if (!(_blockedRouteLatestReason isEqualType "")) then { _blockedRouteLatestReason = "-"; };
if (_blockedRouteLatestReason isEqualTo "") then { _blockedRouteLatestReason = "-"; };

private _blockedRouteLatestSourceId = [_air, "blockedRouteLatestSourceId", "-"] call _getPub;
if (!(_blockedRouteLatestSourceId isEqualType "")) then { _blockedRouteLatestSourceId = "-"; };
if (_blockedRouteLatestSourceId isEqualTo "") then { _blockedRouteLatestSourceId = "-"; };

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

private _recentEvents = [_air, "recentEvents", []] call _getPub;
if (!(_recentEvents isEqualType [])) then { _recentEvents = []; };

private _awaitingCount = [_air, "clearanceAwaitingTowerCount", 0] call _getPub;
if (!(_awaitingCount isEqualType 0)) then { _awaitingCount = 0; };

private _towerStaffing = [_air, "towerStaffing", []] call _getPub;
if (!(_towerStaffing isEqualType [])) then { _towerStaffing = []; };

private _staffLaneRec = {
    params ["_rows", "_lane"];
    // sqflint 0.3.2 does not understand findIf; replaced with equivalent forEach loop.
    private _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 5 } && { ((_x param [0, ""]) isEqualTo _lane) }) exitWith { _idx = _forEachIndex; }; } forEach _rows;
    if (_idx < 0) exitWith { [_lane, "AUTO", "", "", -1] };
    _rows select _idx
};

private _towerLane = [_towerStaffing, "tower"] call _staffLaneRec;
private _groundLane = [_towerStaffing, "ground"] call _staffLaneRec;
private _arrivalLane = [_towerStaffing, "arrival"] call _staffLaneRec;

private _airModeList = ["ARC_console_airMode", "TOWER"] call ARC_fnc_uiNsGetString;
_airModeList = toUpper ([_airModeList] call _trimFn);
if !(_airModeList in ["TOWER", "PILOT"]) then { _airModeList = "TOWER"; };

if (_rebuild) then {
    lbClear _ctrlList;

    if (_airModeList isEqualTo "PILOT") then {
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
        private _myArrivals = _clearancePending select {
            private _meta = _x param [9, []];
            private _pid = [_meta, "pilotUid", ""] call _metaGet;
            private _rtype = toUpper (_x param [1, ""]);
            (_pid isEqualTo _uidPilot) && (_rtype in ["REQ_INBOUND", "REQ_LAND"])
        };
        if ((count _myArrivals) > 0) then {
            private _hdrWarn = _ctrlList lbAdd "-- PILOT ATC WARNINGS --";
            _ctrlList lbSetData [_hdrWarn, "HDR|PWARN"];
            {
                private _rid = _x param [0, ""];
                private _rtype = _x param [1, ""];
                private _status = toUpper (_x param [5, ""]);
                private _meta = _x param [9, []];
                private _badge = [_meta] call _warnBadgeMeta;
                if (_badge isEqualTo "") then { _badge = "[NONE]"; };
                private _row = _ctrlList lbAdd format ["%1 %2 %3 (%4)", _rid, _rtype, _badge, _status];
                _ctrlList lbSetData [_row, format ["PWRN|%1", _rid]];
            } forEach _myArrivals;
        };

    } else {

    // -----------------------------------------------------------------------
    // AIRSPACE STATUS — always-visible top row giving a quick situation summary.
    // -----------------------------------------------------------------------
    private _hdrStatus = _ctrlList lbAdd "-- AIRSPACE STATUS --";
    _ctrlList lbSetData [_hdrStatus, "HDR|STATUS"];

    private _rwyLabel = "RUNWAY: OPEN";
    if ((toUpper _runwayState) isEqualTo "OCCUPIED") then { _rwyLabel = "RUNWAY: OCCUPIED"; };
    if ((toUpper _runwayState) isEqualTo "RESERVED") then { _rwyLabel = "RUNWAY: RESERVED"; };
    private _holdLabel  = if (_holdDepartures) then { "HOLD ACTIVE" } else { "DEP OPEN" };
    private _execLabel  = if (_execActive && { !(_execFid isEqualTo "") }) then { format ["EXEC: %1", _execFid] } else { "STANDBY" };
    private _statusLbl  = format ["%1  |  %2  |  %3", _rwyLabel, _holdLabel, _execLabel];
    private _statusRow  = _ctrlList lbAdd _statusLbl;
    _ctrlList lbSetData [_statusRow, format ["STATUS|%1|%2|%3|%4", _runwayState, _holdDepartures, _execActive, _execFid]];

    // -----------------------------------------------------------------------
    // ACTIVE DEPARTURE — visible only while a flight is executing on the runway.
    // -----------------------------------------------------------------------
    if (_execActive && { !(_execFid isEqualTo "") }) then {
        private _hdrExec = _ctrlList lbAdd "-- ACTIVE DEPARTURE --";
        _ctrlList lbSetData [_hdrExec, "HDR|EXEC"];

        private _execAsset = "";
        {
            if ((_x isEqualType []) && { (_x param [0, ""]) isEqualTo _execFid }) exitWith {
                _execAsset = _x param [2, ""];
            };
        } forEach _nextItems;

        private _execLbl = if (_execAsset isEqualTo "") then {
            format [">>> %1  |  DEPARTING NOW", _execFid]
        } else {
            format [">>> %1  |  %2  |  DEPARTING NOW", _execFid, _execAsset]
        };
        private _execRow = _ctrlList lbAdd _execLbl;
        _ctrlList lbSetData [_execRow, format ["EXEC|%1|%2", _execFid, _execAsset]];
    };

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
            private _status = toUpper (_x param [5, ""]);
            private _updated = _x param [7, -1];
            private _decision = _x param [8, []];
            private _meta = _x param [9, []];
            private _groupName = [_meta, "pilotGroupName", ""] call _metaGet;
            private _callsign = [_meta, "pilotCallsign", ""] call _metaGet;
            private _acType = [_meta, "aircraftType", ""] call _metaGet;
            private _decBy = "";
            if (_decision isEqualType [] && { (count _decision) >= 1 }) then { _decBy = _decision param [0, ""]; };

            private _pilotLabel = if (_callsign isEqualTo "") then { _pilot } else { _callsign };
            if (_groupName != "") then { _pilotLabel = format ["%1 | %2", _pilotLabel, _groupName]; };
            private _warnBadge = [_meta] call _warnBadgeMeta;
            private _lbl = format ["%1 [%2] %3 (%4)", _rid, _rtype, _pilotLabel, _status];
            if (_warnBadge != "") then { _lbl = format ["%1 %2", _lbl, _warnBadge]; };
            if (_acType != "") then { _lbl = format ["%1 <%2>", _lbl, _acType]; };
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

            private _dirIcon  = if (_kind isEqualTo "DEP") then { "^" } else { if (_kind isEqualTo "ARR") then { "v" } else { "?" } };
            private _kindName = if (_kind isEqualTo "DEP") then { "DEPARTURE" } else { if (_kind isEqualTo "ARR") then { "ARRIVAL" } else { toUpper _kind } };
            private _lbl = format ["%1 #%2 %3  |  %4  |  lane: %5", _dirIcon, _forEachIndex + 1, _kindName, _asset, _laneDecision];
            private _row = _ctrlList lbAdd _lbl;
            _ctrlList lbSetData [_row, format ["FLT|%1|%2|%3", _fid, _kind, _asset]];
        } forEach _nextItems;
    };

    // -----------------------------------------------------------------------
    // RECENT EVENTS — last 5 airbase events, newest first. Provides dynamic
    // feedback as aircraft depart, arrive, and clearances are decided.
    // (Filters LOCK_ACQUIRE/LOCK_RELEASE which are too granular for the BC view.)
    // -----------------------------------------------------------------------
    private _hdrEvt = _ctrlList lbAdd "-- RECENT EVENTS --";
    _ctrlList lbSetData [_hdrEvt, "HDR|EVT"];

    private _evtFiltered = _recentEvents select {
        private _evKind = toUpper (_x param [1, ""]);
        !(_evKind in ["LOCK_ACQUIRE", "LOCK_RELEASE"])
    };
    private _evtCount = count _evtFiltered;
    if (_evtCount == 0) then {
        private _noneEvt = _ctrlList lbAdd "(no events yet)";
        _ctrlList lbSetData [_noneEvt, "EVT|NONE"];
    } else {
        private _evtShow = 5 min _evtCount;
        private _evtStart = _evtCount - _evtShow;
        for "_ei" from (_evtCount - 1) to _evtStart step -1 do {
            private _ev = _evtFiltered select _ei;
            if !(_ev isEqualType []) then { continue; };
            private _evLbl = [_ev] call _fmtEventRow;
            private _evRow = _ctrlList lbAdd _evLbl;
            _ctrlList lbSetData [_evRow, format ["EVT|%1|%2", _ev param [1, ""], _ev param [2, ""]]];
        };
    };

    private _hdrLane = _ctrlList lbAdd "-- ATC STAFFING --";
    _ctrlList lbSetData [_hdrLane, "HDR|LANE"];

    {
        private _lane = _x param [0, ""];
        private _status = toUpper (_x param [1, "AUTO"]);
        private _op = _x param [2, ""];
        private _uid = _x param [3, ""];
        private _ts = _x param [4, -1];
        private _who = if (_status isEqualTo "MANNED" && { _op != "" }) then { _op } else { "AUTO" };
        private _lbl = format ["%1: %2", toUpper _lane, _who];
        private _row = _ctrlList lbAdd _lbl;
        _ctrlList lbSetData [_row, format ["LANE|%1|%2|%3|%4|%5", _lane, _status, _op, _uid, _ts]];
    } forEach [_towerLane, _groundLane, _arrivalLane];

    private _hdrRwy = _ctrlList lbAdd "-- RUNWAY & HOLD --";
    _ctrlList lbSetData [_hdrRwy, "HDR|RWY"];
    private _runwayLbl = format ["State: %1  |  Owner: %2  |  Hold: %3", _runwayState, if (_runwayOwner isEqualTo "") then {"-"} else {_runwayOwner}, if (_holdDepartures) then {"HOLD ACTIVE"} else {"OPEN"}];
    private _runwayRow = _ctrlList lbAdd _runwayLbl;
    _ctrlList lbSetData [_runwayRow, format ["RWY|%1|%2|%3", _runwayState, _runwayOwner, _runwayUntil]];

    private _hdrDec = _ctrlList lbAdd "-- RECENT DECISIONS --";
    _ctrlList lbSetData [_hdrDec, "HDR|DEC"];

    private _decisions = _clearanceHistoryTail select {
        private _s = toUpper (_x param [6, ""]);
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
            private _status = toUpper (_rec param [6, ""]);
            private _upd = _rec param [8, -1];
            private _dec = _rec param [9, []];
            private _by = if (_dec isEqualType []) then { _dec param [0, ""] } else { "" };
            private _action = if (_dec isEqualType []) then { _dec param [3, ""] } else { "" };

            private _agoStr = [_upd] call _fmtAgo;
            private _row = _ctrlList lbAdd format ["%1 %2 by %3 (%4)", _rid, _status, if (_by isEqualTo "") then {"SYSTEM"} else {_by}, _agoStr];
            _ctrlList lbSetData [_row, format ["DEC|%1|%2|%3|%4", _rid, _status, _upd, _action]];
        };
    };

    if ((lbSize _ctrlList) > 0) then {
        private _restoreSel = -1;
        if (_prevSelData != "") then {
            for "_iSel" from 0 to ((lbSize _ctrlList) - 1) do {
                private _d = _ctrlList lbData _iSel;
                if (_d isEqualTo _prevSelData) exitWith { _restoreSel = _iSel; };
            };
        };

        if (_restoreSel < 0) then {
            for "_iFirst" from 0 to ((lbSize _ctrlList) - 1) do {
                private _d2 = _ctrlList lbData _iFirst;
                private _pfx = if ((_d2 isEqualType "") && { (count _d2) >= 3 }) then { toUpper (_d2 select [0, 3]) } else { "" };
                if (_pfx != "HDR") then {
                    private _parts2 = _d2 splitString "|";
                    private _rowType2 = if ((count _parts2) > 0) then { _parts2 select 0 } else { "" };
                    private _rowId2 = toUpper (_parts2 param [1, ""]);
                    private _isPlaceholderNone = (_rowType2 in ["REQ", "FLT", "DEC", "EVT"]) && { _rowId2 isEqualTo "NONE" };
                    if (!_isPlaceholderNone) exitWith { _restoreSel = _iFirst; };
                };
            };
        };

        if (_restoreSel < 0) then {
            for "_iFirstFallback" from 0 to ((lbSize _ctrlList) - 1) do {
                private _d3 = _ctrlList lbData _iFirstFallback;
                private _pfxFallback = if ((_d3 isEqualType "") && { (count _d3) >= 3 }) then { toUpper (_d3 select [0, 3]) } else { "" };
                if (_pfxFallback != "HDR") exitWith { _restoreSel = _iFirstFallback; };
            };
        };

        if (_restoreSel < 0) then { _restoreSel = 0; };
        _ctrlList lbSetCurSel _restoreSel;
    };
    };
};

private _sel = lbCurSel _ctrlList;
if (_sel < 0 && { (lbSize _ctrlList) > 0 }) then { _sel = 0; _ctrlList lbSetCurSel 0; };

private _selData = if (_sel >= 0) then { _ctrlList lbData _sel } else { "" };
if (!(_selData isEqualType "")) then { _selData = ""; };

private _parts = _selData splitString "|";
private _rowType = if ((count _parts) > 0) then { _parts select 0 } else { "" };
if ((count _parts) <= 1) then {
    private _legacyParts = _selData splitString ":";
    if ((count _legacyParts) > 0) then {
        private _legacyType = toUpper (_legacyParts param [0, ""]);
        switch (_legacyType) do {
            case "Q": { _rowType = "FLT"; };
            case "CLR": { _rowType = "REQ"; };
            case "LANE": { _rowType = "LANE"; };
            default {};
        };
    };
};
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
_airMode = toUpper ([_airMode] call _trimFn);
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
private _selectionHeading = "Selection Detail";
private _selectionLines = [
    "Pick a queued flight, clearance, or lane row to inspect contextual metadata."
];

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
            _selectionHeading = format ["Clearance %1", _rid];
            _selectionLines = [];
            private _reqIdx = -1;
            { if ((_x param [0, ""]) isEqualTo _rid) exitWith { _reqIdx = _forEachIndex; }; } forEach _clearancePending;
            if (_reqIdx >= 0) then {
                private _reqRec = _clearancePending select _reqIdx;
                private _reqType = toUpper (_reqRec param [1, "UNKNOWN"]);
                private _reqPilot = _reqRec param [2, "-"];
                private _reqCreated = _reqRec param [3, -1];
                private _reqPrio = _reqRec param [4, 0];
                private _reqStatus = toUpper (_reqRec param [5, "PENDING"]);
                private _reqOwner = _reqRec param [6, ""];
                private _reqUpdated = _reqRec param [7, -1];
                private _reqDecision = _reqRec param [8, []];
                private _reqMeta = _reqRec param [9, []];
                if !(_reqMeta isEqualType []) then { _reqMeta = []; };
                private _pilotCallsign = [_reqMeta, "pilotCallsign", ""] call _metaGet;
                private _pilotGroup = [_reqMeta, "pilotGroupName", ""] call _metaGet;
                private _laneDecision = [_reqMeta, "runwayLaneDecision", "-"] call _metaGet;
                private _laneReason = [_reqMeta, "runwayLaneDecisionReason", "-"] call _metaGet;
                private _chain = [_reqMeta, "routeMarkerChain", []] call _metaGet;
                if !(_chain isEqualType []) then { _chain = []; };
                private _decisionBy = if (_reqDecision isEqualType []) then { _reqDecision param [0, "-"] } else { "-" };
                private _decisionAction = if (_reqDecision isEqualType []) then { toUpper (_reqDecision param [3, "PENDING"]) } else { "PENDING" };
                private _pilotLabel = if (_pilotCallsign isEqualTo "") then { _reqPilot } else { _pilotCallsign };
                if (_pilotGroup != "") then { _pilotLabel = format ["%1 | %2", _pilotLabel, _pilotGroup]; };

                _selectionLines = [
                    format ["Request id: <t color='#FFFFFF'>%1</t> | Type: <t color='#FFFFFF'>%2</t>", _rid, _reqType],
                    format ["Pilot: <t color='#FFFFFF'>%1</t> | Current owner: <t color='#FFFFFF'>%2</t>", _pilotLabel, if (_reqOwner isEqualTo "") then {"UNCLAIMED"} else {_reqOwner}],
                    format ["Status: <t color='#FFFFFF'>%1</t> | Priority: <t color='#FFFFFF'>%2</t>", _reqStatus, _reqPrio],
                    format ["Lane decision: <t color='#FFFFFF'>%1</t> | Reason: <t color='#FFFFFF'>%2</t>", _laneDecision, _laneReason],
                    format ["Created/Updated: <t color='#FFFFFF'>%1 / %2</t>", [_reqCreated] call _fmtTime, [_reqUpdated] call _fmtTime],
                    format ["Last decision: <t color='#FFFFFF'>%1 by %2</t>", _decisionAction, _decisionBy],
                    format ["Action hint: <t color='#FFFFFF'>%1</t>", if (_canAirQueueManage) then {"Use APPROVE or DENY; verify lane reason before confirming."} else {"Read-only: coordinate with tower controller for decision."}]
                ];
            } else {
                _selectionLines = [
                    format ["Request id: <t color='#FFFFFF'>%1</t>", _rid],
                    "Request metadata unavailable in current snapshot.",
                    "Action hint: Refresh AIR tab to re-sync pending clearance records."
                ];
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
            _selectionHeading = format ["Queued Flight %1", _fid];
            _selectionLines = [];
            private _fltIdx = -1;
            { if ((_x param [0, ""]) isEqualTo _fid) exitWith { _fltIdx = _forEachIndex; }; } forEach _nextItems;
            if (_fltIdx >= 0) then {
                private _fltRec = _nextItems select _fltIdx;
                private _flightKind = _fltRec param [1, "-"];
                private _flightAsset = _fltRec param [2, "-"];
                private _fltMeta = (_nextItems select _fltIdx) param [3, []];
                if !(_fltMeta isEqualType []) then { _fltMeta = []; };
                private _laneDecision = [_fltMeta, "runwayLaneDecision", "-"] call _metaGet;
                private _laneReason = [_fltMeta, "runwayLaneDecisionReason", "-"] call _metaGet;
                private _chain = [_fltMeta, "routeMarkerChain", []] call _metaGet;
                private _sourceRid = [_fltMeta, "sourceRequestId", "-"] call _metaGet;
                private _queueTs = [_fltMeta, "queuedAt", -1] call _metaGet;
                private _owner = [_fltMeta, "owner", "AUTO"] call _metaGet;
                if !(_chain isEqualType []) then { _chain = []; };
                _selectionLines = [
                    format ["Flight id: <t color='#FFFFFF'>%1</t> | Kind: <t color='#FFFFFF'>%2</t>", _fid, _flightKind],
                    format ["Asset: <t color='#FFFFFF'>%1</t> | Source request: <t color='#FFFFFF'>%2</t>", _flightAsset, _sourceRid],
                    format ["Queue owner: <t color='#FFFFFF'>%1</t> | Queued at: <t color='#FFFFFF'>%2</t>", _owner, [_queueTs] call _fmtTime],
                    format ["Lane decision: <t color='#FFFFFF'>%1</t> | Reason: <t color='#FFFFFF'>%2</t>", _laneDecision, _laneReason],
                    format ["Route chain: <t color='#FFFFFF'>%1</t>", if ((count _chain) > 0) then { _chain joinString " -> " } else { "no-chain" }],
                    format ["Action hint: <t color='#FFFFFF'>%1</t>", if (_canAirQueueManage) then {"Use EXPEDITE for priority handling, CANCEL if route/intent is invalid."} else {"Read-only: report flight id to queue manager for action."}]
                ];
            } else {
                _selectionLines = [
                    format ["Flight id: <t color='#FFFFFF'>%1</t>", _fid],
                    "Queue metadata unavailable in current snapshot.",
                    "Action hint: Refresh AIR tab to re-sync scheduled flight records."
                ];
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
        private _status = toUpper (_parts param [2, "AUTO"]);
        private _op = _parts param [3, ""];
        private _laneUid = _parts param [4, ""];
        _selectedState = format ["LANE_%1_%2", toUpper _lane, _status];
        _selectedUpdated = parseNumber (_parts param [5, "-1"]);
        _nextActionOwner = "TOWER_CONTROLLER";
        _selectedDetail = format ["%1 lane controller: %2", toUpper _lane, if (_op isEqualTo "") then {"AUTO"} else {_op}];
        _selectionHeading = format ["Lane %1", toUpper _lane];
        _selectionLines = [
            format ["Lane: <t color='#FFFFFF'>%1</t> | Status: <t color='#FFFFFF'>%2</t>", toUpper _lane, _status],
            format ["Current owner: <t color='#FFFFFF'>%1</t>", if (_op isEqualTo "") then {"AUTO"} else {_op}],
            format ["Owner uid: <t color='#FFFFFF'>%1</t>", if (_laneUid isEqualTo "") then {"-"} else {_laneUid}],
            format ["Last staffing update: <t color='#FFFFFF'>%1</t>", [_selectedUpdated] call _fmtTime],
            format ["Action hint: <t color='#FFFFFF'>%1</t>", if (_canAirStaff) then {"CLAIM to take controller ownership, RELEASE to return lane to AUTO."} else {"Read-only: staffing updates require air staffing authorization."}]
        ];
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

    case "STATUS": {
        _selectedState = format ["RWY_%1", toUpper _runwayState];
        _selectedUpdated = _stateUpdatedAt;
        _nextActionOwner = "SYSTEM";
        _selectedDetail = format ["Airspace status: runway %1, hold %2, exec %3", _runwayState, if (_holdDepartures) then {"HOLD ACTIVE"} else {"OPEN"}, if (_execActive) then {_execFid} else {"none"}];
        _selectionHeading = "Airspace Status";
        _selectionLines = [
            format ["Runway state: <t color='#FFFFFF'>%1</t>  |  Owner: <t color='#FFFFFF'>%2</t>", _runwayState, if (_runwayOwner isEqualTo "") then {"-"} else {_runwayOwner}],
            format ["Hold departures: <t color='#FFFFFF'>%1</t>", if (_holdDepartures) then {"HOLD ACTIVE"} else {"OPEN"}],
            format ["Active execution: <t color='#FFFFFF'>%1</t>", if (_execActive) then {_execFid} else {"none"}],
            format ["Departures queued: <t color='#FFFFFF'>%1</t>  |  In-progress: <t color='#FFFFFF'>%2</t>", _depQueued, _depInProgress],
            format ["Arrivals queued: <t color='#FFFFFF'>%1</t>  |  Awaiting tower: <t color='#FFFFFF'>%2</t>", _arrQueued, _awaitingCount]
        ];
        _primaryLabel = "HOLD";
        _secondaryLabel = "RELEASE";
        _primaryEnabled = _canAirHoldRelease;
        _secondaryEnabled = _canAirHoldRelease;
        _primaryTooltip = if (_canAirHoldRelease) then { "Global hold on departures." } else { "Disabled: no hold/release authorization." };
        _secondaryTooltip = if (_canAirHoldRelease) then { "Global release departures." } else { "Disabled: no hold/release authorization." };
    };

    case "EXEC": {
        private _eFid   = _parts param [1, ""];
        private _eAsset = _parts param [2, ""];
        _selectedState = "EXECUTING";
        _selectedUpdated = _stateUpdatedAt;
        _nextActionOwner = "SYSTEM";
        _selectedDetail = format ["Active departure: %1 (%2)", _eFid, if (_eAsset isEqualTo "") then {"-"} else {_eAsset}];
        _selectionHeading = format ["Active Departure: %1", _eFid];
        _selectionLines = [
            format ["Flight id: <t color='#FFFFFF'>%1</t>", _eFid],
            format ["Aircraft: <t color='#FFFFFF'>%1</t>", if (_eAsset isEqualTo "") then {"-"} else {_eAsset}],
            format ["Runway state: <t color='#FFFFFF'>%1</t>", _runwayState],
            "Status: <t color='#FFFFFF'>DEPARTING NOW — runway occupied</t>",
            "<t color='#CFCFCF'>Next departure will queue once runway clears.</t>"
        ];
        _primaryLabel = "HOLD";
        _secondaryLabel = "RELEASE";
        _primaryEnabled = _canAirHoldRelease;
        _secondaryEnabled = _canAirHoldRelease;
        _primaryTooltip = if (_canAirHoldRelease) then { "Global hold on departures." } else { "Disabled: no hold/release authorization." };
        _secondaryTooltip = if (_canAirHoldRelease) then { "Global release departures." } else { "Disabled: no hold/release authorization." };
    };

    case "EVT": {
        private _evKind = _parts param [1, ""];
        private _evRid  = _parts param [2, ""];
        _selectedState = format ["EVENT_%1", toUpper _evKind];
        _selectedUpdated = _stateUpdatedAt;
        _nextActionOwner = "AUDIT";
        _selectedDetail = format ["Airbase event: %1 — %2", _evKind, if (_evRid isEqualTo "") then {"-"} else {_evRid}];
        _selectionHeading = format ["Event: %1", _evKind];
        _selectionLines = [
            format ["Event type: <t color='#FFFFFF'>%1</t>", _evKind],
            format ["Subject: <t color='#FFFFFF'>%1</t>", if (_evRid isEqualTo "") then {"-"} else {_evRid}],
            "<t color='#CFCFCF'>Event log entry — for situational awareness only.</t>"
        ];
        _primaryLabel = "HOLD";
        _secondaryLabel = "RELEASE";
        _primaryEnabled = _canAirHoldRelease;
        _secondaryEnabled = _canAirHoldRelease;
        _primaryTooltip = if (_canAirHoldRelease) then { "Global hold on departures." } else { "Disabled: no hold/release authorization." };
        _secondaryTooltip = if (_canAirHoldRelease) then { "Global release departures." } else { "Disabled: no hold/release authorization." };
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

private _selectionDetailHtml = "";
{
    _selectionDetailHtml = _selectionDetailHtml + format ["<br/><t color='#CFCFCF'>%1</t>", _x];
} forEach _selectionLines;

private _details = format [
    "<t size='1.05' color='#B89B6B'>SELECTION DETAIL</t>"
    + "<br/><t color='#FFFFFF'>%1</t>"
    + "<br/>State: <t color='#FFFFFF'>%2</t> | Updated: <t color='#FFFFFF'>%3</t> | Next owner: <t color='#FFFFFF'>%4</t>"
    + "<br/><t color='#CFCFCF'>%5</t>"
    + "%6"
    + "<br/><br/><t size='1.05' color='#B89B6B'>AIRBASE SNAPSHOT</t>"
    + "<br/><t color='#CFCFCF'>%7</t>"
    + "<br/><br/><t color='#B89B6B'>Queue Summary</t>"
    + "<br/>Departures queued (backlog): <t color='#FFFFFF'>%8</t>"
    + "<br/>Departure executing (runway): <t color='#FFFFFF'>%9</t>"
    + "<br/>Effective departures (queued + executing): <t color='#FFFFFF'>%10</t>"
    + "<br/>Arrivals queued (backlog): <t color='#FFFFFF'>%11</t>"
    + "<br/>Total queued (backlog only): <t color='#FFFFFF'>%12</t>"
    + "<br/><br/><t color='#B89B6B'>Route Validation</t>"
    + "<br/>Blocked-route attempts (recent): <t color='#FFFFFF'>%13</t> <t color='#CFCFCF'>(non-queued telemetry)</t>"
    + "<br/>Latest reason: <t color='#FFFFFF'>%14</t>"
    + "<br/>Latest source id: <t color='#FFFFFF'>%15</t>"
    + "<br/><t color='#CFCFCF'>Blocked-route events do not enter queue.</t>"
    + "<br/><br/><t color='#B89B6B'>Runway</t>"
    + "<br/>State: <t color='#FFFFFF'>%16</t> | Owner: <t color='#FFFFFF'>%17</t>"
    + "<br/>Hold departures: <t color='#FFFFFF'>%18</t>"
    + "<br/>Tower: <t color='#FFFFFF'>%19</t> | Ground: <t color='#FFFFFF'>%20</t> | Arrival: <t color='#FFFFFF'>%21</t>"
    + "<br/>Execution: <t color='#FFFFFF'>%22</t>"
    + "<br/><br/><t color='#B89B6B'>Pending/Awaiting</t>"
    + "<br/>Awaiting tower decision: <t color='#FFFFFF'>%23</t>"
    + "<br/>Arrival warnings (A/C/U): <t color='#FFFFFF'>%24/%25/%26m</t>"
    + "<br/><br/><t color='#B89B6B'>CASREQ Snapshot Contract</t>"
    + "<br/>CASREQ id: <t color='#FFFFFF'>%27</t> | Rev: <t color='#FFFFFF'>%28</t>"
    + "<br/>District: <t color='#FFFFFF'>%29</t> | State: <t color='#FFFFFF'>%30</t>"
    + "<br/><t color='#CFCFCF'>AIR UI reads only ARC_pub_state.casreq.casreq_snapshot (no local history inference).</t>",
    _selectionHeading,
    _selectedState,
    [_selectedUpdated] call _fmtTime,
    _nextActionOwner,
    _selectedDetail,
    _selectionDetailHtml,
    _canText,
    _depQueued,
    _depInProgress,
    _effectiveDepartures,
    _arrQueued,
    _totalQueued,
    _blockedRouteAttemptsRecent,
    _blockedRouteLatestReason,
    _blockedRouteLatestSourceId,
    _runwayState,
    if (_runwayOwner isEqualTo "") then {"-"} else {_runwayOwner},
    if (_holdDepartures) then {"HOLD ACTIVE"} else {"OPEN"},
    if ((toUpper (_towerLane param [1, "AUTO"])) isEqualTo "MANNED") then { _towerLane param [2, "AUTO"] } else { "AUTO" },
    if ((toUpper (_groundLane param [1, "AUTO"])) isEqualTo "MANNED") then { _groundLane param [2, "AUTO"] } else { "AUTO" },
    if ((toUpper (_arrivalLane param [1, "AUTO"])) isEqualTo "MANNED") then { _arrivalLane param [2, "AUTO"] } else { "AUTO" },
    if (_execActive) then { format ["%1", _execFid] } else { "none" },
    _awaitingCount,
    [_air, "arrivalWarnAdvisoryM", 7000] call _getPub,
    [_air, "arrivalWarnCautionM", 4500] call _getPub,
    [_air, "arrivalWarnUrgentM", 2600] call _getPub,
    if (_casreqId isEqualTo "") then {"-"} else {_casreqId},
    _casreqRev,
    _casreqDistrict,
    _casreqState
];

_ctrlDetails ctrlSetStructuredText parseText _details;

// Auto-fit + clamp to viewport so the right-pane group can scroll when needed.
// Pin x/y/w to the designed inset so BIS_fnc_ctrlFitToTextHeight does not
// inherit a stretched width from prior paint passes and cause horizontal overflow.
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
true

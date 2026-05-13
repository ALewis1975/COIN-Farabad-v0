/*
    Client-side read-only threat diary refresh.

    Consumes the replicated threat UI snapshot and renders an operator-facing
    threat picture with explicit stale/no-data handling.
*/

if (!hasInterface) exitWith { false };
if (isNull player) exitWith { false };

private _kvGet = {
    params ["_pairs", "_key", "_default"];
    if (!(_pairs isEqualType [])) exitWith { _default };

    private _idx = -1;
    {
        if ((_x isEqualType []) && { (count _x) >= 2 } && { ((_x select 0) isEqualTo _key) }) exitWith {
            _idx = _forEachIndex;
        };
    } forEach _pairs;

    if (_idx < 0) exitWith { _default };

    private _entry = _pairs select _idx;
    private _value = _entry select 1;
    if (isNil "_value") exitWith { _default };
    _value
};

private _fmtAgo = {
    params ["_ts"];
    if (!(_ts isEqualType 0) || { _ts < 0 }) exitWith { "n/a" };
    private _delta = serverTime - _ts;
    if (!(_delta isEqualType 0)) exitWith { "n/a" };
    if (_delta < 0) then { _delta = 0; };
    if (_delta < 60) exitWith { format ["%1s ago", floor _delta] };
    if (_delta < 3600) exitWith { format ["%1m ago", floor (_delta / 60)] };
    format ["%1h ago", floor (_delta / 3600)]
};

private _renderThreatRows = {
    params ["_rows", "_showNote"];

    if (!(_rows isEqualType []) || { (count _rows) == 0 }) exitWith {
        if (_showNote) then {
            "<t color='#AAAAAA'>No rows in this view.</t><br/>"
        } else {
            ""
        }
    };

    private _html = "";
    {
        private _threatId = [_x, "threat_id", ""] call _kvGet;
        private _stateLabel = [_x, "state_label", "Unknown"] call _kvGet;
        private _typeLabel = [_x, "type_label", "Other"] call _kvGet;
        private _districtId = [_x, "district_id", "D00"] call _kvGet;
        private _grid = [_x, "grid", ""] call _kvGet;
        private _taskId = [_x, "task_id", ""] call _kvGet;
        private _updatedAt = [_x, "updated_at", -1] call _kvGet;
        private _spawned = [_x, "world_spawned", false] call _kvGet;
        private _objectCount = [_x, "world_object_count", 0] call _kvGet;

        private _line = format [
            "<t color='#FFD166'>%1</t> — %2 / %3 / %4",
            if (_threatId isEqualTo "") then { "(unknown)" } else { _threatId },
            _stateLabel,
            _typeLabel,
            _districtId
        ];

        private _detail = format ["Grid %1 | Task %2 | Updated %3", if (_grid isEqualTo "") then { "-" } else { _grid }, if (_taskId isEqualTo "") then { "-" } else { _taskId }, [_updatedAt] call _fmtAgo];
        if (_spawned isEqualType true && { _spawned }) then {
            _detail = _detail + format [" | World objs %1", _objectCount];
        };

        _html = _html + _line + "<br/>";
        _html = _html + format ["<t color='#A0A0A0'>%1</t><br/><br/>", _detail];
    } forEach _rows;

    _html
};

private _renderEventRows = {
    params ["_rows"];

    if (!(_rows isEqualType []) || { (count _rows) == 0 }) exitWith {
        "<t color='#AAAAAA'>No threat events yet.</t><br/>"
    };

    private _html = "";
    {
        private _label = [_x, "label", "Updated"] call _kvGet;
        private _summary = [_x, "summary", "Updated"] call _kvGet;
        private _districtId = [_x, "district_id", "D00"] call _kvGet;
        private _ts = [_x, "ts", -1] call _kvGet;

        _html = _html + format ["<t color='#FFD166'>%1</t> — %2<br/>", _label, [_ts] call _fmtAgo];
        _html = _html + format ["<t color='#A0A0A0'>%1 | %2</t><br/><br/>", _districtId, _summary];
    } forEach _rows;

    _html
};

private _subjId = "ARC_THREAT";
if !(player diarySubjectExists _subjId) then {
    player createDiarySubject [_subjId, "THREAT", ""];
};

private _snapshot = missionNamespace getVariable ["ARC_pub_threatUiSnapshot", []];
if (!(_snapshot isEqualType [])) then { _snapshot = []; };

private _text = "<t size='1.2'>Threat Picture</t><br/>";
_text = _text + "<t color='#A0A0A0'>Read-only operator surface. Clients are read-only and cannot modify threat state.</t><br/><br/>";

if ((count _snapshot) == 0) then {
    _text = _text + "<t color='#FF7A7A'>No data yet.</t><br/>";
    _text = _text + "<t color='#DDDDDD'>Waiting for the first server-published threat snapshot. Keep the last known picture elsewhere and do not infer write authority from this client view.</t><br/>";
    private _oldText = player getVariable ["ARC_diary_rec_threat_lastText", ""];
    if (_text isEqualTo _oldText) exitWith { true };

    private _record = player createDiaryRecord [_subjId, ["Threat Picture", _text]];
    player setVariable ["ARC_diary_rec_threat", _record];
    player setVariable ["ARC_diary_rec_threat_lastText", _text];
    true
} else {
    private _summary = [_snapshot, "summary", []] call _kvGet;
    private _list = [_snapshot, "list", []] call _kvGet;
    private _events = [_snapshot, "events", []] call _kvGet;
    private _emptyState = [_snapshot, "emptyState", []] call _kvGet;
    private _errorState = [_snapshot, "errorState", []] call _kvGet;
    private _roleBoundaries = [_snapshot, "roleBoundaries", []] call _kvGet;

    private _updatedAt = [_snapshot, "updatedAt", -1] call _kvGet;
    private _staleAfterS = [_snapshot, "staleAfterS", 30] call _kvGet;
    if (!(_staleAfterS isEqualType 0) || { _staleAfterS < 1 }) then { _staleAfterS = 30; };

    private _age = -1;
    if (_updatedAt isEqualType 0 && { _updatedAt >= 0 }) then { _age = serverTime - _updatedAt; };
    private _isStale = (_age isEqualType 0) && { _age > _staleAfterS };

    private _openRows = [_list, "open", []] call _kvGet;
    private _followOnRows = [_list, "follow_on", []] call _kvGet;
    private _closedRows = [_list, "recently_closed", []] call _kvGet;

    private _openCount = [_summary, "open_count", 0] call _kvGet;
    private _closedCount = [_summary, "closed_count", 0] call _kvGet;
    private _followOnCount = [_summary, "follow_on_count", 0] call _kvGet;
    private _lastEventLabel = [_summary, "last_event_label", "No event"] call _kvGet;
    private _lastEventAt = [_summary, "last_event_at", -1] call _kvGet;
    private _enabled = [_summary, "enabled", true] call _kvGet;

    private _statusColor = "#9FE870";
    private _statusLabel = "FRESH";
    if (_isStale) then {
        _statusColor = "#FFD166";
        _statusLabel = "STALE";
    };
    if (!(_enabled isEqualType true) || { !_enabled }) then {
        _statusColor = "#FF7A7A";
        _statusLabel = "OFFLINE";
    };

    _text = _text + format [
        "<t color='%1'>%2</t> | Updated %3 | Last event %4 (%5)<br/><br/>",
        _statusColor,
        _statusLabel,
        [_updatedAt] call _fmtAgo,
        _lastEventLabel,
        [_lastEventAt] call _fmtAgo
    ];

    _text = _text + "<t size='1.05'>Threat Board</t><br/>";
    _text = _text + format ["Open: %1 | Follow-on watch: %2 | Recently closed: %3<br/>", _openCount, _followOnCount, _closedCount];
    _text = _text + "<t color='#A0A0A0'>Default sort: updated_at DESC. Available views: OPEN / FOLLOW_ON / RECENTLY_CLOSED / EVENT_FEED.</t><br/><br/>";

    if (_isStale) then {
        _text = _text + format [
            "<t color='#FFD166'>Stale handling:</t> Keep the last known threat picture visible, request a TOC/S2 refresh if needed, and wait for the next server publish (TTL %1s).<br/><br/>",
            _staleAfterS
        ];
    };

    if ((count _openRows) == 0) then {
        _text = _text + format [
            "<t color='#FFD166'>%1</t><br/><t color='#DDDDDD'>%2</t><br/><br/>",
            [_emptyState, "title", "No active threat data"] call _kvGet,
            [_emptyState, "body", "No threat rows are currently available."] call _kvGet
        ];
    } else {
        _text = _text + "<t size='1.02'>Open queue</t><br/>";
        _text = _text + ([_openRows, true] call _renderThreatRows);
    };

    _text = _text + "<t size='1.02'>Follow-on watch</t><br/>";
    _text = _text + ([_followOnRows, true] call _renderThreatRows);

    _text = _text + "<t size='1.02'>Recently closed / cleaned</t><br/>";
    _text = _text + ([_closedRows, true] call _renderThreatRows);

    _text = _text + "<t size='1.02'>Event feed</t><br/>";
    _text = _text + ([_events] call _renderEventRows);

    _text = _text + "<t size='1.02'>Operator triage checklist</t><br/>";
    _text = _text + "1. Check freshness and stale badge before trusting the board.<br/>";
    _text = _text + "2. Review OPEN rows by district/state, then confirm FOLLOW_ON cues for escalation or verification.<br/>";
    _text = _text + "3. Use existing TOC/S2 request paths for lead/intel follow-up; this surface is read-only.<br/>";
    _text = _text + "4. Before clearing attention, verify RECENTLY_CLOSED rows and the EVENT_FEED for cleanup/follow-on outcomes.<br/><br/>";

    _text = _text + "<t size='1.02'>Authority boundary</t><br/>";
    _text = _text + format [
        "<t color='#A0A0A0'>Read-only:</t> %1<br/><t color='#A0A0A0'>Operator actions:</t> %2<br/><t color='#A0A0A0'>Admin hooks:</t> %3<br/><br/>",
        str ([_roleBoundaries, "read_only", []] call _kvGet),
        str ([_roleBoundaries, "operator_actions", []] call _kvGet),
        str ([_roleBoundaries, "admin_hooks", []] call _kvGet)
    ];

    _text = _text + format [
        "<t color='#A0A0A0'>Error state:</t> %1 — %2",
        [_errorState, "title", "Threat snapshot unavailable"] call _kvGet,
        [_errorState, "body", "Wait for the next server publish."] call _kvGet
    ];

    private _oldText = player getVariable ["ARC_diary_rec_threat_lastText", ""];
    if (_text isEqualTo _oldText) exitWith { true };

    private _record = player createDiaryRecord [_subjId, ["Threat Picture", _text]];
    player setVariable ["ARC_diary_rec_threat", _record];
    player setVariable ["ARC_diary_rec_threat_lastText", _text];
    true
}

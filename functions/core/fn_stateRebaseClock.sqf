/*
    Pure persistence clock v1 translation. Freeze offline progression.
    Params: pairs payload, exact saved serverTime, new serverTime.
    Returns a deep copy; never mutates the profile payload (including HashMaps).
    This is an explicit field/tuple manifest, not a suffix-based timestamp guess.
*/
params [["_state", [], [[]]], ["_savedAt", 0, [0]], ["_now", 0, [0]]];
private _delta = _now - _savedAt;
private _hget = compile "params ['_h','_k']; (_h) get _k";
private _hkeys = compile "params ['_h']; keys _h";
private _shift = {
    params ["_value", "_mode"];
    if !(_value isEqualType 0) exitWith {_value};
    if (_mode isEqualTo "HISTORY") exitWith {_value + _delta};
    if (_mode isEqualTo "DEADLINE") exitWith {
        if (_value <= 0) then {_value} else {(_now + ((_value - _savedAt) max 0)) max 0.001}
    };
    if (_value isEqualTo -1) exitWith {-1};
    if (_mode isEqualTo "TICK") exitWith {_now};
    if (_mode isEqualTo "ANCHOR") exitWith {(_value + _delta) max 0};
    _value + _delta
};
private _deadlines = [
    "systemPauseUntil", "autoIncidentSuspendUntil", "activeExecDeadlineAt",
    "activeConvoyDeadlineAt", "activeConvoyStartHoldUntil", "activeConvoyNextSpawnAttemptAt",
    "activeConvoyDepartAt", "activeConvoyBypassUntil", "activeConvoyContactUntil",
    "activeConvoyBridgeFallbackUntil", "activeConvoyBridgeRecoverCooldownUntil",
    "threat_v0_global_cooldown_until", "threat_v0_budget_next_reset_ts",
    "cooldown_until", "disruption_penalty_until", "latent_expires_ts",
    "expiresAt", "expires_at", "expires_ts", "availableAt", "cooldownUntil"
];
private _ticks = [
    "sustainLastAt", "metricsLastAt", "companyCommandLastTickAt",
    "companyVirtualOpsLastTickAt", "companyVirtualOpsLastRollupAt",
    "supply_v1_last_ambient_tick", "threat_v0_scheduler_last_ts"
];
private _anchors = [
    "activeIncidentCreatedAt", "activeIncidentAcceptedAt", "activeIncidentCloseMarkedAt",
    "activeIncidentClosePendingAt", "activeIncidentSitrepSentAt", "activeIncidentFollowOnAt",
    "activeIncidentCivsubStartTs", "activeExecStartedAt", "activeExecActivatedAt",
    "activeExecLastProgressAt", "activeConvoySpawningSince", "activeConvoyStartedAt",
    "activeConvoyArrivedAt", "activeConvoyDetectedAt", "activeConvoyLinkReachedAt",
    "activeConvoyLastMoveAt", "activeConvoyLastRecoveryAt", "activeConvoyRoadEnforceAt",
    "activeConvoyContactScanAt", "activeConvoyGunnerSectorScanAt", "activeConvoyOrphanBlockedNoticeAt",
    "activeConvoyDismountStartedAt", "activeConvoyFileFormedAt",
    "activeIedDetonationAt", "activeIedCivSnapshotAt", "activeIedDeviceCreatedAt",
    "activeIedEvidenceCreatedAt", "activeIedEvidenceCollectedAt", "activeIedEvidenceRtbRequestedAt",
    "activeVbiedLastArmedAt", "activeVbiedDetonatedAt", "activeVbiedAlertAt",
    "activeVbiedPauseSince", "activeVbiedTowRequestedAt"
];
private _stamps = [
    "lastTaskingGroupAt", "lastSitrepAt", "lastStartdispAt", "s1RegistryUpdatedAt", "leadDecayStartedAt",
    "createdAt", "updatedAt", "acceptedAt", "completedAt", "canceledAt", "failedAt",
    "issuedAt", "requestedAt", "submittedAt", "queuedAt", "decidedAt", "closedAt",
    "created_at", "updated_at", "closed_at", "computed_at",
    "created_ts", "updated_ts", "reported_ts", "assessed_ts", "last_attack_ts", "last_reset_ts",
    "spawned_at", "spawn_intent_ts", "cleanup_ts", "lastMoved", "lastSpawnAt", "lastDespawnAt",
    "lastUpdate", "lastTickAt", "startTs", "spawnTs", "connectTs", "at", "ts",
    "lifecycle_submit_at", "lifecycle_queued_at", "lifecycle_approved_at",
    "lifecycle_denied_at", "lifecycle_complete_at", "routeValidatedAtDecision"
];
// These record fields always denote a real event, so -1 after rebasing is a
// valid historical time, not an unset sentinel on the next restart.
private _historyStamps = ["leadDecayStartedAt", "created_at", "updated_at", "created_ts", "updated_ts", "at", "ts"];
private _walk = {
    params ["_value", ["_key", ""], ["_parent", ""]];
    if (_key in _deadlines) exitWith {[_value, "DEADLINE"] call _shift};
    if (_key in _ticks) exitWith {[_value, "TICK"] call _shift};
    if (_key in _anchors) exitWith {[_value, "ANCHOR"] call _shift};
    if (_key in _historyStamps && {_value isEqualType 0}) exitWith {[_value, "HISTORY"] call _shift};
    if (_key in _stamps && {_value isEqualType 0}) exitWith {[_value, "STAMP"] call _shift};
    if (_parent isEqualTo "state_ts" && {_value isEqualType 0}) exitWith {[_value, "ANCHOR"] call _shift};
    if (_value isEqualType createHashMap) exitWith {
        private _copy = createHashMap;
        { _copy set [_x, [[_value, _x] call _hget, _x, _key] call _walk]; } forEach ([_value] call _hkeys);
        _copy
    };
    if !(_value isEqualType []) exitWith {_value};
    private _copy = [];
    {
        if (_x isEqualType [] && {count _x == 2} && {(_x select 0) isEqualType ""}) then {
            _copy pushBack [_x select 0, [_x select 1, _x select 0, _key] call _walk];
        } else {
            _copy pushBack ([_x, "", _key] call _walk);
        };
    } forEach _value;
    _copy
};
private _out = [_state] call _walk;
private _get = {
    params ["_key", "_default"];
    private _i = -1;
    { if (_x isEqualType [] && {count _x >= 2} && {(_x select 0) isEqualTo _key}) exitWith { _i = _forEachIndex; }; } forEach _out;
    if (_i < 0) exitWith {_default};
    (_out select _i) select 1
};
private _set = {
    params ["_key", "_value"];
    private _i = -1;
    { if (_x isEqualType [] && {count _x >= 2} && {(_x select 0) isEqualTo _key}) exitWith { _i = _forEachIndex; }; } forEach _out;
    if (_i < 0) then {_out pushBack [_key, _value]} else {_out set [_i, [_key, _value]]};
};
private _rows = {
    params ["_key", "_slots"];
    private _records = [_key, []] call _get;
    if !(_records isEqualType []) exitWith {};
    {
        private _row = _x;
        if (_row isEqualType []) then {
            {
                _x params ["_slot", "_mode"];
                if (count _row > _slot) then {_row set [_slot, [_row select _slot, _mode] call _shift]};
            } forEach _slots;
        };
    } forEach _records;
};
// Positional records: only these documented slots represent uptime.
[
    ["leadPool", [[5,"HISTORY"],[6,"DEADLINE"]]],
    ["leadHistory", [[2,"HISTORY"]]],
    ["incidentHistory", [[5,"HISTORY"],[6,"HISTORY"]]],
    ["intelLog", [[1,"HISTORY"]]],
    ["metricsSnapshots", [[0,"HISTORY"]]],
    ["tocQueue", [[1,"HISTORY"]]],
    ["tocOrders", [[1,"HISTORY"]]],
    ["tocLeadApprovals", [[1,"HISTORY"]]],
    ["eodDispoApprovals", [[3,"HISTORY"],[5,"DEADLINE"]]],
    ["cleanupQueue", [[3,"DEADLINE"]]],
    ["companyCommandNodes", [[9,"STAMP"]]],
    ["companyCommandTasking", [[1,"HISTORY"]]],
    ["companyVirtualOps", [[1,"HISTORY"],[2,"HISTORY"]]],
    ["airbase_v1_records", [[1,"HISTORY"],[6,"HISTORY"]]],
    ["airbase_v1_clearanceRequests", [[7,"HISTORY"],[8,"HISTORY"]]],
    ["airbase_v1_clearanceHistory", [[7,"HISTORY"],[8,"HISTORY"]]],
    ["airbase_v1_events", [[0,"HISTORY"]]]
] apply {_x call _rows};
private _lastLead = ["lastLeadCreated", []] call _get;
if (_lastLead isEqualType [] && {count _lastLead >= 7}) then {
    _lastLead set [5, [_lastLead select 5, "HISTORY"] call _shift];
    _lastLead set [6, [_lastLead select 6, "DEADLINE"] call _shift];
};
private _threads = ["threads", []] call _get;
if (_threads isEqualType []) then {
    {
        if (_x isEqualType [] && {count _x >= 14}) then {
            private _thread = _x;
            _thread set [10, [_thread select 10, "HISTORY"] call _shift];
            _thread set [11, [_thread select 11, "DEADLINE"] call _shift];
            _thread set [12, [_thread select 12, "ANCHOR"] call _shift];
            private _evidence = _thread select 7;
            if (_evidence isEqualType []) then {
                {if (_x isEqualType [] && {count _x >= 5}) then {_x set [0, [_x select 0, "HISTORY"] call _shift]}} forEach _evidence;
            };
        };
    } forEach _threads;
};
// The execution consumer uses startedAt >= 0 as its "accepted" flag. Preserve
// remaining ARRIVE_HOLD budget when its old start lies before the new clock.
private _oldStartIndex = -1;
{ if (_x isEqualType [] && {count _x >= 2} && {(_x select 0) isEqualTo "activeExecStartedAt"}) exitWith { _oldStartIndex = _forEachIndex; }; } forEach _state;
if (_oldStartIndex >= 0) then {
    private _oldStart = (_state select _oldStartIndex) select 1;
    private _arrival = ["activeExecArrivalReq", 0] call _get;
    if (_oldStart isEqualType 0 && {_oldStart >= 0} && {_arrival isEqualType 0} && {_arrival > 0}) then {
        private _start = ["activeExecStartedAt", _now] call _get;
        ["activeExecArrivalReq", (((_arrival - ((_savedAt - _oldStart) max 0)) max 0) + (_now - _start)) max 0.001] call _set;
    };
};
private _clock = ["persistenceClock", []] call _get;
// VBIED pause/start sentinels must stay nonnegative. Carry the elapsed portion
// lost by clamping their anchors as a duration, including an in-progress pause.
private _sourceGet = {
    params ["_key", "_default"];
    private _value = _default;
    {if (_x isEqualType [] && {count _x >= 2} && {(_x select 0) isEqualTo _key}) exitWith {_value = _x select 1}} forEach _state;
    _value
};
private _oldAlert = ["activeVbiedAlertAt", -1] call _sourceGet;
if (_oldAlert isEqualType 0 && {_oldAlert >= 0} && {["activeVbiedAlerted", false] call _get}) then {
    private _newAlert = ["activeVbiedAlertAt", _now] call _get;
    private _lost = ((_savedAt - _oldAlert) max 0) - ((_now - _newAlert) max 0);
    private _oldPause = ["activeVbiedPauseSince", -1] call _sourceGet;
    if (_oldPause isEqualType 0 && {_oldPause >= 0}) then {
        private _newPause = ["activeVbiedPauseSince", _now] call _get;
        _lost = _lost - (((_savedAt - _oldPause) max 0) - ((_now - _newPause) max 0));
    };
    private _carry = ["activeVbiedElapsedBeforeLoad", 0] call _get;
    if !(_carry isEqualType 0) then {_carry = 0};
    ["activeVbiedElapsedBeforeLoad", (_carry + _lost) max 0] call _set;
};
if !(_clock isEqualType []) then {_clock = []};
["persistenceClock", [1, _now, _clock param [2, []], "FREEZE_OFFLINE"]] call _set;
_out

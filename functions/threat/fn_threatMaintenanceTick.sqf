/* Server-only record maintenance; runs inside the existing rate-limited scheduler. */
if (!isServer) exitWith {[0,0]};
private _get = {
    params ["_pairs", "_key", "_fallback"];
    if !(_pairs isEqualType []) exitWith {_fallback};
    private _i = -1;
    { if (_x isEqualType [] && {count _x >= 2} && {(_x select 0) isEqualTo _key}) exitWith { _i = _forEachIndex; }; } forEach _pairs;
    if (_i < 0) exitWith {_fallback};
    (_pairs select _i) select 1
};
private _set = {
    params ["_pairs", "_key", "_value"];
    private _i = -1;
    { if (_x isEqualType [] && {count _x >= 2} && {(_x select 0) isEqualTo _key}) exitWith { _i = _forEachIndex; }; } forEach _pairs;
    if (_i < 0) then {_pairs pushBack [_key,_value]} else {_pairs set [_i,[_key,_value]]};
    _pairs
};
private _now = serverTime;
private _ttl = missionNamespace getVariable ["ARC_threatLatentTtlS", 3600];
if !(_ttl isEqualType 0) then {_ttl = 3600};
_ttl = (_ttl max 300) min 21600;
private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
private _expire = [];
private _reconcile = [];
{
    private _rec = _x;
    private _tid = [_rec,"threat_id",""] call _get;
    if (!(([_rec,"type",""] call _get) isEqualTo "VIRTUAL_OPFOR") && {!(_tid isEqualTo "")}) then {
    private _state = toUpper ([_rec,"state",""] call _get);
    private _links = [_rec,"links",[]] call _get;
    private _world = [_rec,"world",[]] call _get;
    if (_state in ["CLOSED","EXPIRED"] && {count _reconcile < 20}) then {_reconcile pushBack _tid};
    private _classification = [_rec,"classification",[]] call _get;
    // Legacy scheduler rows are identifiable by economy metadata and no task/incident.
    private _schedulerOwned = ([_rec,"lifecycle_v",0] call _get) isEqualTo 1 || {([_classification,"budget_cost",-1] call _get) >= 0};
    if (_schedulerOwned && {_state isEqualTo "CREATED"} && {([_links,"task_id",""] call _get) isEqualTo ""} && {([_links,"incident_id",""] call _get) isEqualTo ""} && {!([_world,"spawned",false] call _get)}) then {
        private _deadline = [_rec,"latent_expires_ts",-1] call _get;
        if !(_deadline isEqualType 0) then {_deadline = -1};
        if (_deadline < 0) then {
            private _created = [_rec,"created_ts",_now] call _get;
            if !(_created isEqualType 0) then {_created = _now};
            // Negative creation stamps are valid after rebasing an old campaign.
            _deadline = (_created + _ttl) max 0.001;
            _rec = [_rec,"lifecycle_v",1] call _set;
            _rec = [_rec,"latent_expires_ts",_deadline] call _set;
            _rec = [_rec,"rev",([_rec,"rev",1] call _get) + 1] call _set;
            _records set [_forEachIndex,_rec];
        };
        if (_now >= _deadline && {count _expire < 20}) then {_expire pushBack _tid};
    };
    };
} forEach _records;
["threat_v0_records",_records] call ARC_fnc_stateSet;
private _expired = 0;
{
    if ([_x,"EXPIRED","LATENT_TTL"] call ARC_fnc_threatUpdateState) then {
        _expired = _expired + 1;
        [_x,"LATENT_TTL"] call ARC_fnc_threatIedCleanupSync;
    };
} forEach _expire;
{ [_x,"TERMINAL_RECONCILE"] call ARC_fnc_threatIedCleanupSync; } forEach _reconcile;

// Preserve current consumer references, including nested lead/queue metadata.
private _protected = [["activeIedThreatId",""] call ARC_fnc_stateGet];
private _collectRefs = {
    params ["_data",["_depth",0]];
    if !(_data isEqualType [] && {_depth < 12}) exitWith {};
    if (count _data >= 2 && {(_data select 0) isEqualTo "threat_id"} && {(_data select 1) isEqualType ""}) then {_protected pushBackUnique (_data select 1)};
    { if (_x isEqualType []) then {[_x,_depth + 1] call _collectRefs}; } forEach _data;
};
{ [[_x,[]] call ARC_fnc_stateGet] call _collectRefs; } forEach ["leadPool","tocQueue","activeIncidentMissionMeta"];
private _activeTask = ["activeTaskId",""] call ARC_fnc_stateGet;
private _open = ["threat_v0_open_index",[]] call ARC_fnc_stateGet;
_protected append _open;
_records = ["threat_v0_records",[]] call ARC_fnc_stateGet;
private _eligible = [];
{
    private _rec = _x;
    private _tid = [_rec,"threat_id",""] call _get;
    private _world = [_rec,"world",[]] call _get;
    private _task = [[_rec,"links",[]] call _get,"task_id",""] call _get;
    if (([_rec,"state",""] call _get) isEqualTo "CLEANED" && {!(([_rec,"type",""] call _get) isEqualTo "VIRTUAL_OPFOR")} && {!(_tid in _protected)} && {_task isEqualTo "" || {!(_task isEqualTo _activeTask)}} && {!([_world,"spawned",false] call _get)} && {([_world,"objects_net_ids",[]] call _get) isEqualTo []} && {([_world,"units_net_ids",[]] call _get) isEqualTo []} && {([_world,"groups_net_ids",[]] call _get) isEqualTo []}) then {
        _eligible pushBack [[_rec,"updated_ts",0] call _get,_tid];
    };
} forEach _records;
private _cap = ["threat_v0_closed_max",200] call ARC_fnc_stateGet;
if !(_cap isEqualType 0 && {_cap >= 50}) then {_cap = 200};
_cap = _cap min 2000;
_eligible sort true;
private _remove = (_eligible select [0,((count _eligible) - _cap) max 0]) apply {_x select 1};
if !(_remove isEqualTo []) then {
    _records = _records select {!(([_x,"threat_id",""] call _get) in _remove)};
    ["threat_v0_records",_records] call ARC_fnc_stateSet;
    private _closed = ["threat_v0_closed_index",[]] call ARC_fnc_stateGet;
    ["threat_v0_closed_index",_closed - _remove] call ARC_fnc_stateSet;
    diag_log format ["[ARC][THREAT] HISTORY_PRUNED time=%1 actor=SYSTEM count=%2 ids=%3",_now,count _remove,_remove];
};
[_expired,count _remove]

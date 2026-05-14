/*
    Threat v0 hook: AO activation -> create/activate threat records (idempotent).

    Expected call site:
        ["AO_ACTIVATED", _aoContextPairs] call ARC_fnc_threatOnAOActivated;

    This is a recordkeeping hook only (no pacing changes).
*/

if (!isServer) exitWith {false};

params [
    ["_event", ""],
    ["_ctx", []]
];

if (!(toUpper _event isEqualTo "AO_ACTIVATED")) exitWith {false};

private _enabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {false};

private _trimFn = compile "params ['_s']; trim _s";

// Small helper for "pairs arrays"
private _kvGet = {
    params ["_pairs", "_key", "_default"];
    if (!(_pairs isEqualType [])) exitWith {_default};
    private _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _idx = _forEachIndex; }; } forEach _pairs;
    if (_idx < 0) exitWith {_default};
    private _entry = _pairs select _idx;
    private _v = _entry select 1;
    if (isNil "_v") exitWith {_default};
    _v
};

private _taskId = [_ctx, "task_id", ""] call _kvGet;
if (_taskId isEqualTo "") then
{
    private _tasks = [_ctx, "task_ids_activated", []] call _kvGet;
    if (_tasks isEqualType [] && { (count _tasks) > 0 }) then { _taskId = _tasks select 0; };
};
if (_taskId isEqualTo "") exitWith {false};

private _incType = toUpper ([_ctx, "incident_type", ""] call _kvGet);

// v0 scope: create threats only for IED incidents (Phase 1 package)
if (!(_incType isEqualTo "IED")) exitWith {true};

// Ensure minimal area context exists
private _pos = [_ctx, "pos", [0,0,0]] call _kvGet;
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = [0,0,0]; };
_pos = +_pos; _pos resize 3;

private _radius = [_ctx, "radius_m", 0] call _kvGet;
if (!(_radius isEqualType 0) || { _radius < 0 }) then { _radius = 0; };

private _objKindForSubtype = toUpper (["activeObjectiveKind", ""] call ARC_fnc_stateGet);
private _subtype = switch (_objKindForSubtype) do
{
    case "VBIED_VEHICLE": { "VBIED" };
    case "VBIED_DRIVEN_CHECKPOINT": { "VBIED_DRIVEN_CHECKPOINT" };
    case "VBIED_DRIVEN_GATE": { "VBIED_DRIVEN_GATE" };
    case "SB_MARKET_APPROACH": { "SUICIDE_BOMBER_MARKET" };
    case "SB_CHECKPOINT_APPROACH": { "SUICIDE_BOMBER_CHECKPOINT" };
    case "SB_SHURA_APPROACH": { "SUICIDE_BOMBER_SHURA" };
    default { "IED_SUSPICIOUS_OBJECT" };
};

// Create (idempotent)
private _tid = [_taskId, "IED", _subtype, _ctx] call ARC_fnc_threatCreateFromTask;
if (_tid isEqualTo "") exitWith {false};

["activeIedThreatId", _tid] call ARC_fnc_stateSet;
missionNamespace setVariable ["ARC_activeIedThreatId", _tid, true];

// Attempt to link the currently active objective object as the "manifestation" (Phase 1).
// Guard against duplicate spawn via idempotency token before writing world.spawned.
private _linked = false;
    private _objKind = ["activeObjectiveKind", ""] call ARC_fnc_stateGet;
    private _objNid = ["activeObjectiveNetId", ""] call ARC_fnc_stateGet;

    if (
        (!(_objNid isEqualTo ""))
        && { (toUpper _objKind) in ["IED_DEVICE", "VBIED_VEHICLE"] }
    ) then
{
    // Request spawn token (idempotency guard).
    private _spawnResult = [_tid] call ARC_fnc_threatIedSpawnRequest;
    private _spawnToken = _spawnResult select 0;
    private _spawnGranted = _spawnResult select 1;
    private _spawnDenyReason = _spawnResult select 2;

    if (!_spawnGranted) then
    {
        diag_log format ["[ARC][WARN] ARC_fnc_threatOnAOActivated: spawn link denied threat_id=%1 token=%2 reason=%3", _tid, _spawnToken, _spawnDenyReason];
    }
    else
    {
        // Update record world fields (best-effort)
        private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
        if (_records isEqualType []) then
        {
            private _idxRec = -1;
            { if (([_x, "threat_id", ""] call _kvGet) isEqualTo _tid) exitWith { _idxRec = _forEachIndex; }; } forEach _records;
            if (_idxRec >= 0) then
            {
                private _rec = _records select _idxRec;

                private _world = [_rec, "world", []] call _kvGet;

                private _objs = [_world, "objects_net_ids", []] call _kvGet;
                if (!(_objs isEqualType [])) then { _objs = []; };

                _objs pushBackUnique _objNid;

                private _label = format ["THREAT:IED:%1", _tid];

                private _kvSet = {
                    params ["_pairs", "_key", "_value"];
                    if (!(_pairs isEqualType [])) then { _pairs = []; };
                    private _i = -1;
                    { if ((_x isEqualType []) && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _i = _forEachIndex; }; } forEach _pairs;
                    if (_i < 0) then { _pairs pushBack [_key, _value]; } else { _pairs set [_i, [_key, _value]]; };
                    _pairs
                };

                _world = [_world, "spawned", true] call _kvSet;
                _world = [_world, "spawned_at", serverTime] call _kvSet;
                _world = [_world, "objects_net_ids", _objs] call _kvSet;
                _world = [_world, "cleanup_label", _label] call _kvSet;

                _rec = [_rec, "world", _world] call _kvSet;

                _records set [_idxRec, _rec];
                ["threat_v0_records", _records] call ARC_fnc_stateSet;

                // Tag the object for debugging/traceability
                private _obj = objectFromNetId _objNid;
                if (!isNull _obj) then
                {
                    _obj setVariable ["ARC_threatId", _tid, true];
                    _obj setVariable ["ARC_threatCleanupLabel", _label, true];
                    _obj setVariable ["ARC_threatSpawnToken", _spawnToken, true];
                };

                _linked = true;
            };
        };
    };
};

// Activate (but do NOT downgrade; if a player already discovered/neutralized it, keep that state)
private _note = if (_linked) then { "AO_ACTIVATED+SPAWNED" } else { "AO_ACTIVATED" };

private _cur = "CREATED";
private _recs2 = ["threat_v0_records", []] call ARC_fnc_stateGet;
if (_recs2 isEqualType []) then
{
    private _i2 = -1;
    { if (([_x, "threat_id", ""] call _kvGet) isEqualTo _tid) exitWith { _i2 = _forEachIndex; }; } forEach _recs2;
    if (_i2 >= 0) then
    {
        _cur = [_recs2 select _i2, "state", ""] call _kvGet;
    };
};

if (!(_cur isEqualType "")) then { _cur = ""; };
_cur = toUpper ([_cur] call _trimFn);

if (_cur in ["", "CREATED"]) then
{
    [_tid, "ACTIVE", _note] call ARC_fnc_threatUpdateState;
};

true

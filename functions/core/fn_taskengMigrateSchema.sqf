/*
    ARC_fnc_taskengMigrateSchema

    Versioned schema migration for TASKENG persistent data.
    Idempotent: safe to call on every server start.

    Migration table (per docs/projectFiles/Farabad_TASKENG_Migration_Baseline_v0.md):
      Rev 1: taskeng_v0_active_incident_refs  (default: [])
      Rev 2: taskeng_v0_lead_linkage          (default: createHashMap)
      Rev 3: taskeng_v0_generation_buffers    (default: createHashMap)
      Rev 4: taskeng_v0_thread_store          (default: createHashMap)

    Returns:
      NUMBER - current schema rev after migration
*/

if (!isServer) exitWith { 0 };

private _rev = ["taskeng_v0_schema_rev", 0] call ARC_fnc_stateGet;
if (!(_rev isEqualType 0)) then { _rev = 0; };

private _target = 4;
if (_rev >= _target) exitWith {
    diag_log format ["[ARC][INFO] ARC_fnc_taskengMigrateSchema: TASKENG_MIGRATE_NOOP rev=%1 target=%2", _rev, _target];
    _rev
};

diag_log format ["[ARC][INFO] ARC_fnc_taskengMigrateSchema: TASKENG_MIGRATE_APPLY rev=%1 target=%2", _rev, _target];

// Rev 1: ensure active_incident_refs exists
if (_rev < 1) then {
    private _existing = ["taskeng_v0_active_incident_refs", []] call ARC_fnc_stateGet;
    if (!(_existing isEqualType [])) then {
        ["taskeng_v0_active_incident_refs", []] call ARC_fnc_stateSet;
    };
    _rev = 1;
    ["taskeng_v0_schema_rev", _rev] call ARC_fnc_stateSet;
    diag_log format ["[ARC][INFO] ARC_fnc_taskengMigrateSchema: migrated to rev=%1 (active_incident_refs)", _rev];
};

// Rev 2: ensure lead_linkage hashmap exists
if (_rev < 2) then {
    private _existing = ["taskeng_v0_lead_linkage", createHashMap] call ARC_fnc_stateGet;
    if (!(_existing isEqualType createHashMap)) then {
        ["taskeng_v0_lead_linkage", createHashMap] call ARC_fnc_stateSet;
    };
    _rev = 2;
    ["taskeng_v0_schema_rev", _rev] call ARC_fnc_stateSet;
    diag_log format ["[ARC][INFO] ARC_fnc_taskengMigrateSchema: migrated to rev=%1 (lead_linkage)", _rev];
};

// Rev 3: ensure generation_buffers hashmap exists
if (_rev < 3) then {
    private _existing = ["taskeng_v0_generation_buffers", createHashMap] call ARC_fnc_stateGet;
    if (!(_existing isEqualType createHashMap)) then {
        ["taskeng_v0_generation_buffers", createHashMap] call ARC_fnc_stateSet;
    };
    _rev = 3;
    ["taskeng_v0_schema_rev", _rev] call ARC_fnc_stateSet;
    diag_log format ["[ARC][INFO] ARC_fnc_taskengMigrateSchema: migrated to rev=%1 (generation_buffers)", _rev];
};

// Rev 4: ensure thread_store hashmap exists and seed from existing threads array
if (_rev < 4) then {
    private _store = ["taskeng_v0_thread_store", createHashMap] call ARC_fnc_stateGet;
    if (!(_store isEqualType createHashMap)) then {
        _store = createHashMap;
    };

    // Seed thread_store from legacy threads[] array if store is empty
    if ((count _store) isEqualTo 0) then {
        private _threads = ["threads", []] call ARC_fnc_stateGet;
        if (!(_threads isEqualType [])) then { _threads = []; };

        {
            private _thr = [_x] call ARC_fnc_threadNormalizeRecord;
            if (!(_thr isEqualTo [])) then {
                private _thrId = _thr select 0;
                private _thrType = _thr select 1;
                private _conf = _thr select 4;
                private _heat = _thr select 5;
                private _parentTaskId = _thr select 13;

                if (!(_thrId isEqualTo "")) then {
                    private _rec = createHashMap;
                    _rec set ["thread_id", _thrId];
                    _rec set ["type", _thrType];
                    _rec set ["confidence", _conf];
                    _rec set ["heat", _heat];
                    _rec set ["parent_task_id", _parentTaskId];
                    _store set [_thrId, _rec];
                };
            };
        } forEach _threads;
    };

    ["taskeng_v0_thread_store", _store] call ARC_fnc_stateSet;
    _rev = 4;
    ["taskeng_v0_schema_rev", _rev] call ARC_fnc_stateSet;
    diag_log format ["[ARC][INFO] ARC_fnc_taskengMigrateSchema: migrated to rev=%1 (thread_store seeded=%2)", _rev, count _store];
};

_rev

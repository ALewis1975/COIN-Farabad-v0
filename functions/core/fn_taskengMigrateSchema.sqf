/*
    ARC_fnc_taskengMigrateSchema

    Server-only: migrate TASKENG state from any prior schema revision to the
    current canonical schema (rev 4).

    Called once at bootstrap, after ARC_fnc_stateLoad and before
    ARC_fnc_incidentSeedQueue.

    Migration path:
      rev 0 → rev 1 : ensure HASHMAP keys exist (first-run / fresh install)
      rev 1 → rev 2 : (reserved — bump only)
      rev 2 → rev 3 : (reserved — bump only)
      rev 3 → rev 4 : populate taskeng_v0_thread_store HASHMAP from threads array
      rev 4          : no-op (already current)

    After migration the canonical store is taskeng_v0_thread_store. The legacy
    threads array is preserved as a deprecated fallback read for one release cycle
    so that in-progress saves are not lost before the next breaking change.

    Returns: NUMBER — the schema rev after migration
*/

if (!isServer) exitWith {0};

private _rev = ["taskeng_v0_schema_rev", 0] call ARC_fnc_stateGet;
if (!(_rev isEqualType 0) || { _rev < 0 }) then { _rev = 0; };

if (_rev >= 4) exitWith
{
    diag_log format ["[ARC][TASKENG] taskengMigrateSchema: already at rev %1, no migration needed.", _rev];
    _rev
};

diag_log format ["[ARC][TASKENG] taskengMigrateSchema: starting migration from rev %1 to rev 4.", _rev];

// Rev 0 → 1: ensure HASHMAP state keys are initialised
if (_rev < 1) then
{
    private _store = ["taskeng_v0_thread_store", createHashMap] call ARC_fnc_stateGet;
    if (!(_store isEqualType createHashMap)) then { _store = createHashMap; };
    ["taskeng_v0_thread_store", _store] call ARC_fnc_stateSet;

    private _linkage = ["taskeng_v0_lead_linkage", createHashMap] call ARC_fnc_stateGet;
    if (!(_linkage isEqualType createHashMap)) then { _linkage = createHashMap; };
    ["taskeng_v0_lead_linkage", _linkage] call ARC_fnc_stateSet;

    private _buffers = ["taskeng_v0_generation_buffers", createHashMap] call ARC_fnc_stateGet;
    if (!(_buffers isEqualType createHashMap)) then { _buffers = createHashMap; };
    ["taskeng_v0_generation_buffers", _buffers] call ARC_fnc_stateSet;

    _rev = 1;
    diag_log "[ARC][TASKENG] taskengMigrateSchema: rev 0 → 1 (HASHMAP keys initialised).";
};

// Rev 1 → 2: reserved bump
if (_rev < 2) then
{
    _rev = 2;
    diag_log "[ARC][TASKENG] taskengMigrateSchema: rev 1 → 2 (reserved bump).";
};

// Rev 2 → 3: reserved bump
if (_rev < 3) then
{
    _rev = 3;
    diag_log "[ARC][TASKENG] taskengMigrateSchema: rev 2 → 3 (reserved bump).";
};

// Rev 3 → 4: populate taskeng_v0_thread_store from threads array
if (_rev < 4) then
{
    private _threads = ["threads", []] call ARC_fnc_stateGet;
    if (!(_threads isEqualType [])) then { _threads = []; };

    private _store = ["taskeng_v0_thread_store", createHashMap] call ARC_fnc_stateGet;
    if (!(_store isEqualType createHashMap)) then { _store = createHashMap; };

    private _migrated = 0;
    private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
    {
        if (!(_x isEqualType []) || { (count _x) < 1 }) then { continue; };
        private _id = _x select 0;
        if (!(_id isEqualType "") || { _id isEqualTo "" }) then { continue; };

        private _existing = [_store, _id, nil] call _hg;
        if (isNil "_existing") then
        {
            _store set [_id, _x];
            _migrated = _migrated + 1;
        };
    } forEach _threads;

    ["taskeng_v0_thread_store", _store] call ARC_fnc_stateSet;

    _rev = 4;
    diag_log format ["[ARC][TASKENG] taskengMigrateSchema: rev 3 → 4 (migrated %1 thread(s) to HASHMAP store).", _migrated];
};

["taskeng_v0_schema_rev", _rev] call ARC_fnc_stateSet;
diag_log format ["[ARC][TASKENG] taskengMigrateSchema: migration complete, schema rev = %1.", _rev];

_rev

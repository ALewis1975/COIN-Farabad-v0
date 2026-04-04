/*
    ARC_fnc_sitePopStateInit

    Server: load persistent SitePop site state from ARC_state into the server-local
    ARC_sitePopSiteStates HashMap. Initialises a default record for any registered
    site that is not yet present in the persisted store.

    MUST be called AFTER ARC_fnc_stateLoad so that sitepop_v1_site_states is
    available in ARC_state. It is called from ARC_fnc_bootstrapServer immediately
    after ARC_fnc_taskengMigrateSchema.

    State written (server missionNamespace, NOT broadcast, NOT replicated):
        ARC_sitePopSiteStates (HASHMAP)
            key   : siteId (STRING)
            value : site-state HASHMAP with the keys listed below.

    Site-state schema per siteId:
        visitCount          NUMBER  — total spawn activations across all sessions
        lastSpawnAt         NUMBER  — serverTime of last spawn (-1 = never)
        lastDespawnAt       NUMBER  — serverTime of last despawn (-1 = never)
        roleStats           HASHMAP — roleTag → killed count across all visits
        lastIncidentType    STRING  — most recent incident class ("" = none)
        lastPosture         STRING  — last observed district posture ("NORMAL" default)
        districtSnapshot    HASHMAP — snapshot of district state at last despawn
        adaptationLevel     NUMBER  — 0=baseline … 3=maximum hardening
        escapeCount         NUMBER  — prisoner escapes attributed to this site
        riotCount           NUMBER  — internal disorder events at this site
        externalBreachCount NUMBER  — externally-assisted breakout events
        guardCasualties     NUMBER  — cumulative guard deaths observed at despawn

    Returns: BOOLEAN — true on success.
*/

if (!isServer) exitWith { false };

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

// ---------------------------------------------------------------------------
// 1. Read persisted store from ARC_state
// ---------------------------------------------------------------------------
private _persisted = ["sitepop_v1_site_states", createHashMap] call ARC_fnc_stateGet;
if (!(_persisted isEqualType createHashMap)) then
{
    diag_log "[ARC][SITEPOP][WARN] ARC_fnc_sitePopStateInit: sitepop_v1_site_states was not a HASHMAP; initialising empty store.";
    _persisted = createHashMap;
};

// ---------------------------------------------------------------------------
// 2. Ensure a default record exists for every registered site
// ---------------------------------------------------------------------------
private _siteIds = missionNamespace getVariable ["ARC_sitePopSiteIds", []];
if (!(_siteIds isEqualType [])) then { _siteIds = []; };

{
    private _sid = _x;
    if (!(_sid isEqualTo "")) then
    {
        private _existing = [_persisted, _sid, createHashMap] call _hg;
        // A real stored record always has "visitCount" (≥ 0).
        // A fresh-default empty HashMap returns the sentinel -999, indicating no record.
        private _visits = [_existing, "visitCount", -999] call _hg;
        if (!(_visits isEqualType 0) || { _visits isEqualTo -999 }) then
        {
            private _defaultState = createHashMap;
            _defaultState set ["visitCount",          0];
            _defaultState set ["lastSpawnAt",         -1];
            _defaultState set ["lastDespawnAt",       -1];
            _defaultState set ["roleStats",           createHashMap];
            _defaultState set ["lastIncidentType",    ""];
            _defaultState set ["lastPosture",         "NORMAL"];
            _defaultState set ["districtSnapshot",    createHashMap];
            _defaultState set ["adaptationLevel",     0];
            _defaultState set ["escapeCount",         0];
            _defaultState set ["riotCount",           0];
            _defaultState set ["externalBreachCount", 0];
            _defaultState set ["guardCasualties",     0];
            _persisted set [_sid, _defaultState];
        };
    };
} forEach _siteIds;

// ---------------------------------------------------------------------------
// 3. Publish into server-local missionNamespace (NOT broadcast to clients)
// ---------------------------------------------------------------------------
missionNamespace setVariable ["ARC_sitePopSiteStates", _persisted];

diag_log format ["[ARC][SITEPOP][INFO] ARC_fnc_sitePopStateInit: site states loaded for %1 site(s).", count _siteIds];

true

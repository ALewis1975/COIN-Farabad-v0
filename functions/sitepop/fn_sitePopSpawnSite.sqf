/*
    ARC_fnc_sitePopSpawnSite

    Server: spawn all population groups for a registered site.

    Resolves the site template from ARC_sitePopRegistry, calls
    ARC_fnc_sitePopBuildGroup for each population group definition, and records
    the spawned groups in ARC_sitePopActive.

    No-ops silently if the site is already active.

    Params:
        0: STRING — siteId (must exist in ARC_sitePopRegistry)

    Returns: BOOLEAN — true on success, false if site unknown or already active.
*/

if (!isServer) exitWith {false};

params [["_siteId", "", [""]]];
if (_siteId isEqualTo "") exitWith {false};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _registry = missionNamespace getVariable ["ARC_sitePopRegistry", createHashMap];
private _active   = missionNamespace getVariable ["ARC_sitePopActive",   createHashMap];

// Guard: already active (non-empty sentinel)
private _existing = [_active, _siteId, []] call _hg;
if ((count _existing) > 0) exitWith
{
    diag_log format ["[ARC][SITEPOP][INFO] ARC_fnc_sitePopSpawnSite: '%1' already active — no-op.", _siteId];
    true
};

// Resolve template
private _tmpl = [_registry, _siteId, []] call _hg;
if (!(_tmpl isEqualType []) || { (count _tmpl) < 7 }) exitWith
{
    diag_log format ["[ARC][SITEPOP][WARN] ARC_fnc_sitePopSpawnSite: no template found for siteId '%1'.", _siteId];
    false
};

// Extract only the fields needed by the spawner.
// Full template format: [siteId, marker, trigR, despawnR, graceS, groups, sitePos]
private _groups  = _tmpl select 5;
private _sitePos = _tmpl select 6;

if (!(_groups isEqualType [])) then { _groups = []; };
if (!(_sitePos isEqualType [])) then { _sitePos = []; };

if ((count _groups) isEqualTo 0) exitWith
{
    diag_log format ["[ARC][SITEPOP][WARN] ARC_fnc_sitePopSpawnSite: '%1' has no population groups — aborting.", _siteId];
    false
};

diag_log format ["[ARC][SITEPOP][INFO] ARC_fnc_sitePopSpawnSite: spawning site '%1' (%2 group definition(s)).", _siteId, count _groups];

// ---------------------------------------------------------------------------
// Build spawn-context modifiers from site history + profile (PSI v1).
// Gracefully no-ops if fn_sitePopGetSpawnModifiers or site state is unavailable.
// ---------------------------------------------------------------------------
private _spawnCtx = createHashMap;
if (!isNil "ARC_fnc_sitePopGetSpawnModifiers") then
{
    _spawnCtx = [_siteId] call ARC_fnc_sitePopGetSpawnModifiers;
    if (!(_spawnCtx isEqualType createHashMap)) then { _spawnCtx = createHashMap; };
};

// Record this spawn in persistent site state (visitCount + lastSpawnAt).
if (!isNil { missionNamespace getVariable "ARC_sitePopSiteStates" }) then
{
    private _siteStates = missionNamespace getVariable ["ARC_sitePopSiteStates", createHashMap];
    if (_siteStates isEqualType createHashMap) then
    {
        private _siteState = [_siteStates, _siteId, createHashMap] call _hg;
        if (!(_siteState isEqualType createHashMap)) then { _siteState = createHashMap; };

        private _visits = [_siteState, "visitCount", 0] call _hg;
        if (!(_visits isEqualType 0)) then { _visits = 0; };
        _siteState set ["visitCount",  _visits + 1];
        _siteState set ["lastSpawnAt", serverTime];
        _siteStates set [_siteId, _siteState];
    };
};

private _spawnedGroups = [];

{
    private _grp = [_siteId, _sitePos, _x, _spawnCtx] call ARC_fnc_sitePopBuildGroup;
    if (!isNull _grp) then
    {
        _spawnedGroups pushBack _grp;
    };
} forEach _groups;

// Register as active.
// Record format: [spawnedGroups, emptyAt]
//   emptyAt = -1  → players currently present (grace period not started)
_active set [_siteId, [_spawnedGroups, -1]];

diag_log format ["[ARC][SITEPOP][INFO] ARC_fnc_sitePopSpawnSite: site '%1' active — %2 group(s) spawned.", _siteId, count _spawnedGroups];

true

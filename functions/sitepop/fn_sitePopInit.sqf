/*
    ARC_fnc_sitePopInit

    Server bootstrap for the Site Population (SitePop) subsystem.

    Must be called AFTER ARC_fnc_worldScanBuildingSlots (so ARC_worldBuildingSlots
    is populated) and AFTER ARC_fnc_worldScanPatrolWaypoints (so ARC_worldPatrolRings
    is populated). Both are called from ARC_fnc_worldInit before this function.

    Loads site templates from data\farabad_site_templates.sqf, resolves each site's
    world position from ARC_worldNamedLocations, builds the registry HashMap, and
    spawns the proximity-tick loop.

    State written (server missionNamespace, NOT replicated, NOT persisted):
        ARC_sitePopRegistry  (HashMap)
            key   : siteId (STRING)
            value : [siteId, markerName, triggerRadiusM, despawnRadiusM,
                     gracePeriodS, popGroups, resolvedPos]

        ARC_sitePopSiteIds   (ARRAY)
            Ordered list of registered siteIds; used by tick loop to avoid
            iterating HashMap keys.

        ARC_sitePopActive    (HashMap)
            key   : siteId (STRING)
            value : [spawnedGroups (ARRAY of GROUPs), emptyAt (NUMBER, -1 if players present)]
            An empty-array sentinel [] means "not currently active".

        ARC_sitePopLockout   (HashMap)
            key   : siteId (STRING)
            value : lockoutExpiry (NUMBER — game time in seconds)

    Returns: BOOLEAN — true on success, false on setup error.
*/

if (!isServer) exitWith {false};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

// ---------------------------------------------------------------------------
// 1. Build position lookup from ARC_worldNamedLocations
// ---------------------------------------------------------------------------
private _namedLocs = missionNamespace getVariable ["ARC_worldNamedLocations", []];
if (!(_namedLocs isEqualType [])) then { _namedLocs = []; };

private _posMap = createHashMap;
{
    if (!(_x isEqualType []) || { (count _x) < 3 }) then { continue; };
    private _id  = _x select 0;
    private _pos = _x select 2;
    if (!(_id isEqualType "") || { _id isEqualTo "" }) then { continue; };
    _posMap set [_id, _pos];
} forEach _namedLocs;

// ---------------------------------------------------------------------------
// 2. Load templates
// ---------------------------------------------------------------------------
private _templates = call compile preprocessFileLineNumbers "data\farabad_site_templates.sqf";

if (!(_templates isEqualType [])) exitWith
{
    diag_log "[ARC][SITEPOP][ERROR] ARC_fnc_sitePopInit: farabad_site_templates.sqf did not return an ARRAY — subsystem inactive.";
    false
};

if ((count _templates) isEqualTo 0) exitWith
{
    diag_log "[ARC][SITEPOP][WARN] ARC_fnc_sitePopInit: no templates loaded — subsystem inactive.";
    false
};

// ---------------------------------------------------------------------------
// 3. Build registry; resolve each site's world position
// ---------------------------------------------------------------------------
private _registry = createHashMap;
private _siteIds  = [];

{
    _x params [
        ["_siteId",   "", [""]],
        ["_marker",   "", [""]],
        ["_trigR",    600, [0]],
        ["_despawnR", 900, [0]],
        ["_graceS",   120, [0]],
        ["_groups",   [], [[]]]
    ];

    if (_siteId isEqualTo "") then { continue; };
    if (!(_groups isEqualType [])) then { continue; };

    private _posRaw = [_posMap, _siteId, []] call _hg;
    if (!(_posRaw isEqualType []) || { (count _posRaw) < 2 }) then
    {
        diag_log format ["[ARC][SITEPOP][WARN] ARC_fnc_sitePopInit: siteId '%1' not found in ARC_worldNamedLocations — skipped.", _siteId];
        continue;
    };

    private _p3 = +_posRaw;
    if ((count _p3) < 3) then { _p3 pushBack 0; };

    // Store augmented record: original fields plus resolved world position appended.
    _registry set [_siteId, [_siteId, _marker, _trigR, _despawnR, _graceS, _groups, _p3]];
    _siteIds pushBack _siteId;

} forEach _templates;

if ((count _siteIds) isEqualTo 0) exitWith
{
    diag_log "[ARC][SITEPOP][WARN] ARC_fnc_sitePopInit: no valid templates after position resolution — subsystem inactive.";
    false
};

// ---------------------------------------------------------------------------
// 4. Publish state containers (server-local only; no broadcast)
// ---------------------------------------------------------------------------
missionNamespace setVariable ["ARC_sitePopRegistry", _registry];
missionNamespace setVariable ["ARC_sitePopSiteIds",  _siteIds];
missionNamespace setVariable ["ARC_sitePopActive",   createHashMap];
missionNamespace setVariable ["ARC_sitePopLockout",  createHashMap];
missionNamespace setVariable ["ARC_sitePopGroupCounter", 0];

// ---------------------------------------------------------------------------
// 5. Load site profiles (PSI metadata: districtId, siteType, owner, policy)
// ---------------------------------------------------------------------------
private _profilesRaw = call compile preprocessFileLineNumbers "data\farabad_site_profiles.sqf";
if (_profilesRaw isEqualType createHashMap) then
{
    missionNamespace setVariable ["ARC_sitePopSiteProfiles", _profilesRaw];
    diag_log format ["[ARC][SITEPOP][INFO] ARC_fnc_sitePopInit: site profiles loaded (%1 site(s)).", count _profilesRaw];
}
else
{
    missionNamespace setVariable ["ARC_sitePopSiteProfiles", createHashMap];
    diag_log "[ARC][SITEPOP][WARN] ARC_fnc_sitePopInit: farabad_site_profiles.sqf did not return a HASHMAP — profiles unavailable.";
};

// ---------------------------------------------------------------------------
// 6. Spawn proximity tick loop
// ---------------------------------------------------------------------------
[] spawn ARC_fnc_sitePopTick;

diag_log format ["[ARC][SITEPOP][INFO] ARC_fnc_sitePopInit: subsystem active — %1 site(s) registered: %2.", count _siteIds, _siteIds];

true

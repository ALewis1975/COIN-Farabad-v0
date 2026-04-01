/*
    ARC_fnc_sitePopActivateSite

    Server: task-triggered site activation, bypassing proximity and lockout checks.

    Called by the task engine when a task is assigned at a location marker that
    maps to a registered SitePop site. Ensures the site is fully populated
    immediately, even if no player has physically entered the trigger radius yet.

    No-ops silently if the site is already active.

    Params:
        0: STRING — siteId (must exist in ARC_sitePopRegistry)

    Returns: BOOLEAN — true on success or already-active, false if site unknown.
*/

if (!isServer) exitWith {false};

params [["_siteId", "", [""]]];
if (_siteId isEqualTo "") exitWith {false};

private _hg    = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _active = missionNamespace getVariable ["ARC_sitePopActive", createHashMap];

// Guard: already active
private _record = [_active, _siteId, []] call _hg;
if ((count _record) > 0) exitWith
{
    diag_log format ["[ARC][SITEPOP][INFO] ARC_fnc_sitePopActivateSite: '%1' already active.", _siteId];
    true
};

// Verify the site is registered before attempting spawn
private _registry = missionNamespace getVariable ["ARC_sitePopRegistry", createHashMap];
private _tmpl     = [_registry, _siteId, []] call _hg;
if (!(_tmpl isEqualType []) || { (count _tmpl) < 7 }) exitWith
{
    diag_log format ["[ARC][SITEPOP][WARN] ARC_fnc_sitePopActivateSite: siteId '%1' not in registry — cannot activate.", _siteId];
    false
};

diag_log format ["[ARC][SITEPOP][INFO] ARC_fnc_sitePopActivateSite: task-triggered activation for site '%1'.", _siteId];

[_siteId] call ARC_fnc_sitePopSpawnSite

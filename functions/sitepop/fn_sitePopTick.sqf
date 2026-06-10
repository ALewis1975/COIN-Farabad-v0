/*
    ARC_fnc_sitePopTick

    Server-side proximity watcher loop for the SitePop subsystem.
    Spawned by ARC_fnc_sitePopInit; runs indefinitely at 30-second intervals.

    Each tick:
    - For each registered site that is NOT currently active and NOT in lockout:
        Check whether any player is within triggerRadiusM. If yes, call
        ARC_fnc_sitePopSpawnSite.
    - For each registered site that IS currently active:
        Check whether any player is within despawnRadiusM.
        If no player is within that radius, begin or advance the grace-period
        countdown. When the grace period expires, call ARC_fnc_sitePopDespawnSite.
        If a player returns before the grace period expires, reset the countdown.

    State written (via ARC_fnc_sitePopSpawnSite / ARC_fnc_sitePopDespawnSite):
        ARC_sitePopActive   — updated in-place (HashMap is by reference)
        ARC_sitePopLockout  — updated in-place

    No params. No meaningful return value (loop function).
*/

if (!isServer) exitWith {};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _tickS = missionNamespace getVariable ["ARC_sitePopTickIntervalSec", 30];
if (!(_tickS isEqualType 0)) then { _tickS = 30; };
_tickS = (_tickS max 10) min 120;

diag_log format ["[ARC][SITEPOP][INFO] ARC_fnc_sitePopTick: proximity tick loop started (tick=%1s).", _tickS];

while {true} do
{
    sleep _tickS;

    if (!isServer) exitWith {};

    // Idle gate: skip sitepop proximity/spawn work while no interfaced players
    // are connected (gate grace exceeds site despawn grace, so active sites
    // wind down before the pause engages).
    if ([] call ARC_fnc_idleGateActive) then { continue; };

    private _siteIds  = missionNamespace getVariable ["ARC_sitePopSiteIds",  []];
    private _registry = missionNamespace getVariable ["ARC_sitePopRegistry", createHashMap];
    private _active   = missionNamespace getVariable ["ARC_sitePopActive",   createHashMap];
    private _lockout  = missionNamespace getVariable ["ARC_sitePopLockout",  createHashMap];

    if (!(_siteIds isEqualType []) || { !(_registry isEqualType createHashMap) }) then { continue; };
    if ((count _siteIds) isEqualTo 0) then { continue; };

    private _alivePlayers = allPlayers select {
        alive _x && { !(_x isEqualTo objNull) }
    };

    {
        private _siteId = _x;

        private _tmpl = [_registry, _siteId, []] call _hg;
        if (!(_tmpl isEqualType []) || { (count _tmpl) < 7 }) then { continue; };

        // Extract only the fields needed by the tick loop.
        // Full template format: [siteId, marker, trigR, despawnR, graceS, groups, sitePos]
        private _trigR    = _tmpl select 2;
        private _despawnR = _tmpl select 3;
        private _graceS   = _tmpl select 4;
        private _sitePos  = _tmpl select 6;

        if (!(_sitePos isEqualType []) || { (count _sitePos) < 2 }) then { continue; };
        if (!(_trigR isEqualType 0))    then { _trigR    = 600; };
        if (!(_despawnR isEqualType 0)) then { _despawnR = 900; };
        if (!(_graceS isEqualType 0))   then { _graceS   = 120; };

        // Current state for this site
        private _record     = [_active, _siteId, []] call _hg;
        private _isActive   = ((count _record) > 0);

        private _lockExpiry = [_lockout, _siteId, -1] call _hg;
        private _inLockout  = (_lockExpiry > 0 && { _lockExpiry > time });

        // Player proximity check against despawnRadius (covers both spawn and despawn logic)
        private _nearCount = {
            (_x distance2D _sitePos) < _despawnR
        } count _alivePlayers;
        private _hasNearPlayers = (_nearCount > 0);

        if (_isActive) then
        {
            // -----------------------------------------------------------------
            // Active site: manage despawn grace period
            // -----------------------------------------------------------------
            if (!_hasNearPlayers) then
            {
                private _emptyAt = _record select 1;
                if (_emptyAt < 0) then
                {
                    // First tick with no players: start grace countdown
                    _active set [_siteId, [(_record select 0), time]];
                    diag_log format ["[ARC][SITEPOP][INFO] ARC_fnc_sitePopTick: '%1' grace period started (expires in %2 s).", _siteId, _graceS];
                }
                else
                {
                    if ((time - _emptyAt) >= _graceS) then
                    {
                        // Grace expired — despawn
                        [_siteId] call ARC_fnc_sitePopDespawnSite;
                    };
                };
            }
            else
            {
                // Players present: reset grace countdown if it was running
                private _emptyAt = _record select 1;
                if (_emptyAt >= 0) then
                {
                    _active set [_siteId, [(_record select 0), -1]];
                };
            };
        }
        else
        {
            // -----------------------------------------------------------------
            // Inactive site: check proximity trigger (skip if in lockout)
            // -----------------------------------------------------------------
            if (!_inLockout) then
            {
                private _trigCount = {
                    (_x distance2D _sitePos) < _trigR
                } count _alivePlayers;

                if (_trigCount > 0) then
                {
                    [_siteId] call ARC_fnc_sitePopSpawnSite;
                };
            };
        };

    } forEach _siteIds;

    private _nextTickS = missionNamespace getVariable ["ARC_sitePopTickIntervalSec", _tickS];
    if (!(_nextTickS isEqualType 0)) then { _nextTickS = _tickS; };
    _tickS = (_nextTickS max 10) min 120;
};

/*
    ARC_fnc_sitePopDespawnSite

    Server: delete all spawned groups/units for an active site and apply a
    60-second re-spawn lockout.

    Iterates the site's spawn record from ARC_sitePopActive, deletes each unit
    and group, then resets the active record to an empty sentinel and writes
    the lockout expiry to ARC_sitePopLockout.

    No-ops silently if the site is not currently recorded as active.

    Params:
        0: STRING — siteId

    Returns: BOOLEAN — true on success, false if site not found or not active.
*/

if (!isServer) exitWith {false};

params [["_siteId", "", [""]]];
if (_siteId isEqualTo "") exitWith {false};

private _hg     = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _active = missionNamespace getVariable ["ARC_sitePopActive", createHashMap];

private _record = [_active, _siteId, []] call _hg;
if (!(_record isEqualType []) || { (count _record) isEqualTo 0 }) exitWith
{
    diag_log format ["[ARC][SITEPOP][WARN] ARC_fnc_sitePopDespawnSite: '%1' not in active map — no-op.", _siteId];
    false
};

private _groups    = _record select 0;
private _unitCount = 0;

if (!(_groups isEqualType [])) then { _groups = []; };

// ---------------------------------------------------------------------------
// Capture site-state deltas BEFORE units are deleted.
// Counts killed units per role family and updates ARC_sitePopSiteStates.
// ---------------------------------------------------------------------------
if (!isNil { missionNamespace getVariable "ARC_sitePopSiteStates" }) then
{
    private _siteStates = missionNamespace getVariable ["ARC_sitePopSiteStates", createHashMap];
    if (_siteStates isEqualType createHashMap) then
    {
        private _siteState = [_siteStates, _siteId, createHashMap] call _hg;
        if (!(_siteState isEqualType createHashMap)) then { _siteState = createHashMap; };

        // Per-role kill tally
        private _roleStats  = [_siteState, "roleStats",       createHashMap] call _hg;
        if (!(_roleStats isEqualType createHashMap)) then { _roleStats = createHashMap; };
        private _guardCas   = [_siteState, "guardCasualties", 0] call _hg;
        if (!(_guardCas isEqualType 0)) then { _guardCas = 0; };

        {
            private _g = _x;
            if (!isNull _g) then
            {
                private _role     = _g getVariable ["ARC_sitePop_role", ""];
                private _gKilled  = { !(alive _x) } count (units _g);

                // Accumulate into role stats
                if (!(_role isEqualTo "") && { _gKilled > 0 }) then
                {
                    private _prevKills = [_roleStats, _role, 0] call _hg;
                    if (!(_prevKills isEqualType 0)) then { _prevKills = 0; };
                    _roleStats set [_role, _prevKills + _gKilled];
                };

                // Accumulate guard casualties from non-civilian groups
                if (!((side _g) isEqualTo civilian) && { _gKilled > 0 }) then
                {
                    _guardCas = _guardCas + _gKilled;
                };
            };
        } forEach _groups;

        _siteState set ["roleStats",       _roleStats];
        _siteState set ["guardCasualties", _guardCas];
        _siteState set ["lastDespawnAt",   serverTime];

        // Update adaptation level from cumulative guard casualties (never downgrade).
        // Thresholds:  >2 → level 1 (minor hardening)
        //              >5 → level 2 (elevated; also aligns with _disorderThreshold in fn_prisonEvalIncident)
        //             >10 → level 3 (maximum; triggers breakout-eligible state in fn_prisonEvalIncident)
        private _newAdapt = 0;
        if (_guardCas >  2) then { _newAdapt = 1; };
        if (_guardCas >  5) then { _newAdapt = 2; };
        if (_guardCas > 10) then { _newAdapt = 3; };
        private _currentAdapt = [_siteState, "adaptationLevel", 0] call _hg;
        if (!(_currentAdapt isEqualType 0)) then { _currentAdapt = 0; };
        if (_newAdapt > _currentAdapt) then
        {
            _siteState set ["adaptationLevel", _newAdapt];
        };

        _siteStates set [_siteId, _siteState];

        // Persist to durable ARC_state (survives server restart)
        ["sitepop_v1_site_states", _siteStates] call ARC_fnc_stateSet;

        diag_log format ["[ARC][SITEPOP][INFO] ARC_fnc_sitePopDespawnSite: '%1' state captured — guardCas=%2 adaptLevel=%3.",
            _siteId, _guardCas, ([_siteState, "adaptationLevel", 0] call _hg)];
    };
};

{
    private _g = _x;
    if (!isNull _g) then
    {
        // Delete any parked vehicles tracked on this group (vehicle-mode groups)
        private _gVehicles = _g getVariable ["ARC_sitePop_vehicles", []];
        { if (!isNull _x) then { deleteVehicle _x; }; } forEach _gVehicles;

        private _gUnits = units _g;
        _unitCount = _unitCount + (count _gUnits);
        { if (!isNull _x) then { deleteVehicle _x; }; } forEach _gUnits;
        deleteGroup _g;
    };
} forEach _groups;

// Reset active record to empty sentinel (marks site as inactive)
_active set [_siteId, []];

// Apply 60-second lockout before next proximity spawn is allowed
private _lockout = missionNamespace getVariable ["ARC_sitePopLockout", createHashMap];
private _lockoutS = 60;
_lockout set [_siteId, time + _lockoutS];

diag_log format ["[ARC][SITEPOP][INFO] ARC_fnc_sitePopDespawnSite: site '%1' despawned %2 unit(s); lockout for %3 s.", _siteId, _unitCount, _lockoutS];

true

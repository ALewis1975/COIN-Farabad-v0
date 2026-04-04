/*
    ARC_fnc_prisonEvalIncident

    Server: evaluate Karkanak Prison incident conditions and trigger event
    responses when thresholds are met. Called from ARC_fnc_prisonTick.

    Two independent event classes are evaluated per call:

    1. DISORDER — internal prison disturbance.
       Triggers when cumulative guardCasualties >= 5 OR riotCount >= 2.
       Effect: sets disorderActive = true (prisonTick transitions to INCIDENT_LOCKDOWN),
       increments riotCount in site state, raises adaptationLevel to at least 2.
       One-shot per session (does not re-trigger while disorderActive is true).

    2. INSURGENT-ASSISTED BREAKOUT — external breach event.
       Triggers when adaptationLevel >= 3 and there are no active breakout groups.
       Spawns a small tagged OPFOR group (2-4 units, east side) near the prison
       holding area. Group handles are stored in ARC_prisonState.activeBreakoutGroups.
       Previously spawned breakout groups whose units are all dead are pruned first.
       Suppression is resolved when all groups in activeBreakoutGroups have zero
       alive units (tracked against group handles, not side-wide population).

    Breakout actor tags (per unit):
        ARC_breakoutActor = true
        ARC_prisonSiteId  = "KarkanakPrison"

    Returns: Nothing
*/

if (!isServer) exitWith {};

private _hg     = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _siteId = "KarkanakPrison";

// ---------------------------------------------------------------------------
// Safety guards: require both state stores to be online
// ---------------------------------------------------------------------------
private _prisonState = missionNamespace getVariable ["ARC_prisonState", createHashMap];
if (!(_prisonState isEqualType createHashMap)) exitWith
{
    diag_log "[ARC][PRISON][WARN] ARC_fnc_prisonEvalIncident: ARC_prisonState not a HashMap — skipping.";
};

private _siteStates = missionNamespace getVariable ["ARC_sitePopSiteStates", createHashMap];
if (!(_siteStates isEqualType createHashMap)) exitWith {};

private _siteState = [_siteStates, _siteId, createHashMap] call _hg;
if (!(_siteState isEqualType createHashMap)) exitWith {};

// ---------------------------------------------------------------------------
// Read relevant counters
// ---------------------------------------------------------------------------
private _guardCas    = [_siteState, "guardCasualties",     0] call _hg;
private _riotCount   = [_siteState, "riotCount",           0] call _hg;
private _breachCount = [_siteState, "externalBreachCount", 0] call _hg;
private _adaptLevel  = [_siteState, "adaptationLevel",     0] call _hg;

if (!(_guardCas    isEqualType 0)) then { _guardCas    = 0; };
if (!(_riotCount   isEqualType 0)) then { _riotCount   = 0; };
if (!(_breachCount isEqualType 0)) then { _breachCount = 0; };
if (!(_adaptLevel  isEqualType 0)) then { _adaptLevel  = 0; };

// ---------------------------------------------------------------------------
// 1. Disorder evaluation
// ---------------------------------------------------------------------------
private _disorderThreshold = 5;
private _disorderActive    = [_prisonState, "disorderActive", false] call _hg;
if (!(_disorderActive isEqualType false)) then { _disorderActive = false; };

if (!_disorderActive && { (_guardCas >= _disorderThreshold || { _riotCount >= 2 }) }) then
{
    diag_log format ["[ARC][PRISON][INFO] ARC_fnc_prisonEvalIncident: DISORDER triggered — guardCas=%1 riotCount=%2.", _guardCas, _riotCount];

    _prisonState set ["disorderActive", true];

    // Increment riot counter and persist
    _siteState set ["riotCount", _riotCount + 1];

    // Raise adaptation level to at least 2 from a disorder event
    if (_adaptLevel < 2) then
    {
        _siteState set ["adaptationLevel", 2];
    };

    _siteStates set [_siteId, _siteState];
    ["sitepop_v1_site_states", _siteStates] call ARC_fnc_stateSet;
};

// ---------------------------------------------------------------------------
// 2. Insurgent-assisted breakout evaluation
// ---------------------------------------------------------------------------
private _breakoutGroups = [_prisonState, "activeBreakoutGroups", []] call _hg;
if (!(_breakoutGroups isEqualType [])) then { _breakoutGroups = []; };

// Prune dead breakout groups (all units eliminated)
private _liveBreakoutGroups = [];
{
    private _bg = _x;
    if (!isNull _bg) then
    {
        private _aliveCount = { alive _x } count (units _bg);
        if (_aliveCount > 0) then
        {
            _liveBreakoutGroups pushBack _bg;
        }
        else
        {
            diag_log format ["[ARC][PRISON][INFO] ARC_fnc_prisonEvalIncident: breakout group '%1' suppressed — all units eliminated.", groupId _bg];
        };
    };
} forEach _breakoutGroups;

_prisonState set ["activeBreakoutGroups", _liveBreakoutGroups];

// Trigger a new breakout only when:
//   - No active breakout groups currently spawned
//   - Prison has reached adaptationLevel 3 (severely stressed)
if ((count _liveBreakoutGroups) isEqualTo 0 && { _adaptLevel >= 3 }) then
{
    // Resolve spawn position within the prison holding area marker (or site centre fallback).
    // prison_holding_area is a RECTANGLE shape marker; getMarkerType returns "" for shape
    // markers, so we detect it by checking whether the marker position is non-zero instead.
    private _spawnPos = [];
    private _holdPos = getMarkerPos "prison_holding_area";
    if (!(_holdPos isEqualTo [0,0,0])) then
    {
        // Pick a random point inside the rectangle bounds using markerSize / markerDir.
        // markerSize returns [halfA, halfB] — half-extents along and across the marker direction.
        private _sz  = markerSize "prison_holding_area";
        private _dir = markerDir  "prison_holding_area";
        private _ha  = (_sz select 0) max 10; // half-extent along marker direction
        private _hb  = (_sz select 1) max 10; // half-extent perpendicular
        // Random offset in marker-local frame, then rotate to world frame.
        private _lx  = (_ha * 2 * (random 1)) - _ha;
        private _ly  = (_hb * 2 * (random 1)) - _hb;
        private _sinD = sin _dir;
        private _cosD = cos _dir;
        _spawnPos = [
            (_holdPos select 0) + (_lx * _cosD) - (_ly * _sinD),
            (_holdPos select 1) + (_lx * _sinD) + (_ly * _cosD),
            0
        ];
    }
    else
    {
        private _siteReg  = missionNamespace getVariable ["ARC_sitePopRegistry", createHashMap];
        private _siteTmpl = [_siteReg, _siteId, []] call _hg;
        if ((_siteTmpl isEqualType []) && { (count _siteTmpl) >= 7 }) then
        {
            private _siteCenter = _siteTmpl select 6;
            private _ang  = random 360;
            private _dist = 30 + random 40;
            _spawnPos = [(_siteCenter select 0) + (sin _ang) * _dist, (_siteCenter select 1) + (cos _ang) * _dist, 0];
        };
    };

    if ((count _spawnPos) >= 2) then
    {
        _spawnPos resize 3;

        // OPFOR class pool for breakout actors. Classes are filtered against CfgVehicles
        // at spawn time so absent mod classes are silently skipped.
        // If the mission's OPFOR faction changes (e.g., switching from UK3CB_TKA_O to a
        // different faction), update UK3CB_TKA_O_* entries here and in the relevant
        // farabad_site_templates.sqf pools to keep factions consistent.
        private _opforClasses = [
            "UK3CB_TKA_O_Soldier",
            "UK3CB_TKA_O_Soldier_L",
            "UK3CB_TKA_O_NCO",
            "O_Soldier_F",
            "O_Soldier_LAT_F"
        ];
        private _validClasses = _opforClasses select { isClass (configFile >> "CfgVehicles" >> _x) };

        if ((count _validClasses) > 0) then
        {
            private _breakoutCount = 2 + floor (random 3); // 2-4 units
            private _bg = createGroup [east, true];
            _bg allowFleeing 0;

            for "_i" from 1 to _breakoutCount do
            {
                private _ang  = random 360;
                private _off  = random 10;
                private _uPos = [(_spawnPos select 0) + (sin _ang) * _off, (_spawnPos select 1) + (cos _ang) * _off, 0];
                private _cls  = selectRandom _validClasses;
                private _u    = _bg createUnit [_cls, _uPos, [], 0, "NONE"];
                _u setPosATL _uPos;
                _u setVariable ["ARC_breakoutActor",  true,            false];
                _u setVariable ["ARC_prisonSiteId",   _siteId,         false];
                _u enableDynamicSimulation true;
            };

            _bg setGroupIdGlobal [format ["BREAKOUT %1 %2", _siteId, serverTime]];
            _bg setVariable ["ARC_sitePop_siteId", _siteId];
            _bg setVariable ["ARC_sitePop_role",   "breakout_actor"];

            _liveBreakoutGroups pushBack _bg;
            _prisonState set ["activeBreakoutGroups", _liveBreakoutGroups];

            // Increment breach counter in site state and persist
            _siteState set ["externalBreachCount", _breachCount + 1];
            _siteStates set [_siteId, _siteState];
            ["sitepop_v1_site_states", _siteStates] call ARC_fnc_stateSet;

            diag_log format ["[ARC][PRISON][INFO] ARC_fnc_prisonEvalIncident: BREAKOUT spawned %1 actor(s) at %2 (breachCount=%3).",
                _breakoutCount, _spawnPos, _breachCount + 1];
        }
        else
        {
            diag_log "[ARC][PRISON][WARN] ARC_fnc_prisonEvalIncident: no valid OPFOR classes for breakout spawn — skipping.";
        };
    }
    else
    {
        diag_log "[ARC][PRISON][WARN] ARC_fnc_prisonEvalIncident: could not resolve breakout spawn position — skipping.";
    };
};

// Write prison state back
missionNamespace setVariable ["ARC_prisonState", _prisonState];

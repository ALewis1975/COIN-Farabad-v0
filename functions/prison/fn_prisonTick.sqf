/*
    ARC_fnc_prisonTick

    Server: non-blocking Karkanak Prison overlay tick loop.
    Spawned by ARC_fnc_prisonInit. Runs every 30 seconds indefinitely.

    Behaviour:
    - Skips silently when KarkanakPrison is not currently active in ARC_sitePopActive.
    - Computes a base phase from game time (LOCKDOWN at night, DAY_OPERATIONS otherwise)
      and an INCIDENT_LOCKDOWN override when ARC_prisonState.disorderActive is true.
    - Detects prayer windows via ARC_worldTimeEvents (published by worldtime_events_server.sqf).
    - Applies phase and prayer overlays IDEMPOTENTLY — only acts on transitions to avoid
      redundant AI calls on every tick.
    - Prayer overlay: pauses wander AI (disableAI "PATH") for prisoner/escort groups;
      restores AI when the prayer window clears.
    - No inner wait loops; no spawning of prayer crowds; the loop body is synchronous.
    - Calls ARC_fnc_prisonEvalIncident at the end of each active tick.

    Returns: Nothing (loop function).
*/

if (!isServer) exitWith {};

private _tickS  = 30;
private _siteId = "KarkanakPrison";

// Role tags whose wander AI is paused during prayer windows.
// COUPLING: these must match the exact roleTag values in data/farabad_site_templates.sqf
// (KarkanakPrison block). Update here if template role names change.
private _wanderRoles = [
    "prisoner_dorm_01", "prisoner_dorm_02", "prisoner_dorm_03", "prisoner_dorm_04",
    "prisoner_holding", "prisoner", "escort"
];

diag_log "[ARC][PRISON][INFO] ARC_fnc_prisonTick: prison overlay tick loop started.";

while {true} do
{
    sleep _tickS;

    if (!isServer) exitWith {};

    // Re-declare _hg inside the loop body so sqflint resolves it from this scope.
    private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

    // ------------------------------------------------------------------
    // Skip if KarkanakPrison is not currently active
    // ------------------------------------------------------------------
    private _active       = missionNamespace getVariable ["ARC_sitePopActive", createHashMap];
    private _activeRecord = [_active, _siteId, []] call _hg;
    if ((count _activeRecord) isEqualTo 0) then { continue; };

    private _spawnedGroups = _activeRecord select 0;
    if (!(_spawnedGroups isEqualType [])) then { _spawnedGroups = []; };

    private _prisonState = missionNamespace getVariable ["ARC_prisonState", createHashMap];
    if (!(_prisonState isEqualType createHashMap)) then
    {
        _prisonState = createHashMap;
    };

    // ------------------------------------------------------------------
    // Compute base phase from game time
    // ------------------------------------------------------------------
    private _dt = daytime;
    private _basePhase = "DAY_OPERATIONS";
    if (_dt < 6 || { _dt >= 22 }) then { _basePhase = "LOCKDOWN"; };

    // Incident lockdown overrides all other phases
    private _disorderActive = [_prisonState, "disorderActive", false] call _hg;
    if (!(_disorderActive isEqualType false)) then { _disorderActive = false; };
    if (_disorderActive) then { _basePhase = "INCIDENT_LOCKDOWN"; };

    // ------------------------------------------------------------------
    // Compute prayer overlay from ARC_worldTimeEvents
    // ------------------------------------------------------------------
    private _wtEvents = missionNamespace getVariable ["ARC_worldTimeEvents", []];
    if (!(_wtEvents isEqualType [])) then { _wtEvents = []; };

    private _prayerActive = false;
    {
        private _evtLower = toLower _x;
        if ((_evtLower find "prayer") >= 0) exitWith { _prayerActive = true; };
    } forEach _wtEvents;

    // ------------------------------------------------------------------
    // Detect transitions (only act on change for efficiency)
    // ------------------------------------------------------------------
    private _currentPhase    = [_prisonState, "phase",        "DAY_OPERATIONS"] call _hg;
    private _wasPrayerActive = [_prisonState, "prayerActive", false]            call _hg;
    if (!(_wasPrayerActive isEqualType false)) then { _wasPrayerActive = false; };

    private _phaseChanged  = !(_basePhase isEqualTo _currentPhase);
    private _prayerChanged = !(_prayerActive isEqualTo _wasPrayerActive);

    // ------------------------------------------------------------------
    // Apply phase transition (idempotent — only on change)
    // ------------------------------------------------------------------
    if (_phaseChanged) then
    {
        diag_log format ["[ARC][PRISON][INFO] ARC_fnc_prisonTick: phase '%1' → '%2'.", _currentPhase, _basePhase];
        _prisonState set ["phase", _basePhase];

        {
            private _g = _x;
            if (isNull _g) then { continue; };

            switch (_basePhase) do
            {
                case "LOCKDOWN":
                {
                    _g setBehaviour "SAFE";
                    _g setCombatMode "WHITE";
                    { _x disableAI "PATH"; doStop _x; } forEach (units _g);
                };
                case "INCIDENT_LOCKDOWN":
                {
                    if (!((side _g) isEqualTo civilian)) then
                    {
                        _g setBehaviour "AWARE";
                        _g setCombatMode "YELLOW";
                    }
                    else
                    {
                        { _x disableAI "PATH"; doStop _x; } forEach (units _g);
                    };
                };
                default
                {
                    // DAY_OPERATIONS: restore normal SAFE behaviour.
                    _g setBehaviour "SAFE";
                    _g setCombatMode "WHITE";
                    { _x enableAI "PATH"; } forEach (units _g);
                };
            };
        } forEach _spawnedGroups;
    };

    // ------------------------------------------------------------------
    // Apply prayer overlay transition (idempotent — only on change)
    // ------------------------------------------------------------------
    if (_prayerChanged) then
    {
        if (_prayerActive) then
        {
            diag_log "[ARC][PRISON][INFO] ARC_fnc_prisonTick: prayer window started — pausing wander groups.";
            {
                private _g = _x;
                if (isNull _g) then { continue; };
                private _role = _g getVariable ["ARC_sitePop_role", ""];
                if (_role in _wanderRoles) then
                {
                    { _x disableAI "PATH"; doStop _x; } forEach (units _g);
                };
            } forEach _spawnedGroups;
        }
        else
        {
            diag_log "[ARC][PRISON][INFO] ARC_fnc_prisonTick: prayer window ended — resuming wander groups.";
            {
                private _g = _x;
                if (isNull _g) then { continue; };
                private _role = _g getVariable ["ARC_sitePop_role", ""];
                if (_role in _wanderRoles) then
                {
                    { _x enableAI "PATH"; } forEach (units _g);
                };
            } forEach _spawnedGroups;
        };
        _prisonState set ["prayerActive", _prayerActive];
    };

    // ------------------------------------------------------------------
    // Update tick timestamp and write state back
    // ------------------------------------------------------------------
    _prisonState set ["lastTickAt", serverTime];
    missionNamespace setVariable ["ARC_prisonState", _prisonState];

    // Evaluate incident conditions (disorder + breakout)
    [] call ARC_fnc_prisonEvalIncident;
};

/*
    Called periodically.

    Responsibilities:
    - Maintain/rehydrate the active incident task if needed.
    - Tick threads and prune expired leads.
    - Publish a public SITREP snapshot and persist state.

    Note:
    Incident creation is TOC-controlled. This tick never auto-creates new tasks.
*/

if (!isServer) exitWith {false};

// During an explicit ResetAll, avoid creating a new incident mid-reset.
if (missionNamespace getVariable ["ARC_resetInProgress", false]) exitWith {false};

private _activeTaskId = ["activeTaskId", ""] call ARC_fnc_stateGet;

if (_activeTaskId isEqualTo "") then
{
    // No active incident. TOC will generate the next when ready.
    ["INC", "TICK: No active incident at t=%1. Waiting for TOC generate request.", [serverTime], "DEBUG"] call ARC_fnc_log;
}
else
{
	// If a restart wiped the task framework, rehydrate.
	if (!([_activeTaskId] call BIS_fnc_taskExists)) then
    {
        private _ok = [] call ARC_fnc_taskRehydrateActive;
        if (!_ok) then
        {
            // Hard reset, so we don't deadlock the loop.
            ["activeTaskId", ""] call ARC_fnc_stateSet;
            ["activeIncidentType", ""] call ARC_fnc_stateSet;
            ["activeIncidentMarker", ""] call ARC_fnc_stateSet;
            ["activeIncidentDisplayName", ""] call ARC_fnc_stateSet;
            ["activeIncidentCreatedAt", -1] call ARC_fnc_stateSet;
        };
    };
};

// Maintain threads (confidence/heat decay) and prune expired leads.
[] call ARC_fnc_threadTickAll;
[] call ARC_fnc_leadPrune;
[] call ARC_fnc_companyCommandTick;
[] call ARC_fnc_companyCommandVirtualOpsTick;


// Sustainment drain
// Base stocks should naturally deplete over time as BLUFOR operates.
// This creates early mission pressure for logistics while still allowing
// convoy success/failure (handled in ARC_fnc_incidentClose) to swing readiness.
private _now = serverTime;
private _last = ["sustainLastAt", -1] call ARC_fnc_stateGet;

if (!(_last isEqualType 0) || { _last < 0 }) then
{
    ["sustainLastAt", _now] call ARC_fnc_stateSet;
}
else
{
    private _dt = (_now - _last) max 0;

    // Only apply when enough time has elapsed (incidentLoop ticks ~every 60s).
    if (_dt >= 30) then
    {
        private _hours = _dt / 3600;

        private _fuel = ["baseFuel", 0.38] call ARC_fnc_stateGet;
        private _ammo = ["baseAmmo", 0.32] call ARC_fnc_stateGet;
        private _med  = ["baseMed",  0.40] call ARC_fnc_stateGet;

        // Player-scaled drain (models higher ops tempo with larger elements).
        private _nBlu = count (allPlayers select { alive _x && { side group _x in [west, independent] } });
        if (_nBlu < 1) then { _nBlu = 1; };

        private _perPlayer = missionNamespace getVariable ["ARC_sustainPlayerScale", 0.06];
        if (!(_perPlayer isEqualType 0)) then { _perPlayer = 0.06; };
        _perPlayer = (_perPlayer max 0) min 0.25;

        private _scale = 1 + ((_nBlu - 1) * _perPlayer);
        _scale = (_scale max 1) min 3;

        // Active incident multiplier (operations consume more while a mission is in-flight).
        private _hasActive = !((["activeTaskId", ""] call ARC_fnc_stateGet) isEqualTo "");
        private _accepted = ["activeIncidentAccepted", false] call ARC_fnc_stateGet;
        if (_hasActive && { _accepted isEqualType true && { _accepted } }) then
        {
            private _m = missionNamespace getVariable ["ARC_sustainActiveIncidentMult", 1.35];
            if (!(_m isEqualType 0)) then { _m = 1.35; };
            _m = (_m max 1) min 3;
            _scale = _scale * _m;
        };

        // Rates are 0..1 stock per hour (tune via missionNamespace overrides).
        private _rFuel = missionNamespace getVariable ["ARC_sustainFuelPerHour", 0.07];
        private _rAmmo = missionNamespace getVariable ["ARC_sustainAmmoPerHour", 0.05];
        private _rMed  = missionNamespace getVariable ["ARC_sustainMedPerHour",  0.04];

        if (!(_rFuel isEqualType 0)) then { _rFuel = 0.07; };
        if (!(_rAmmo isEqualType 0)) then { _rAmmo = 0.05; };
        if (!(_rMed  isEqualType 0)) then { _rMed  = 0.04; };

        _rFuel = (_rFuel max 0) min 0.30;
        _rAmmo = (_rAmmo max 0) min 0.30;
        _rMed  = (_rMed  max 0) min 0.30;

        _fuel = (_fuel - (_rFuel * _hours * _scale)) max 0;
        _ammo = (_ammo - (_rAmmo * _hours * _scale)) max 0;
        _med  = (_med  - (_rMed  * _hours * _scale)) max 0;

        ["baseFuel", _fuel] call ARC_fnc_stateSet;
        ["baseAmmo", _ammo] call ARC_fnc_stateSet;
        ["baseMed",  _med] call ARC_fnc_stateSet;

        ["sustainLastAt", _now] call ARC_fnc_stateSet;
    };
};


// Intel layer periodic maintenance (metrics + order completion)
[] call ARC_fnc_intelMetricsTick;
[] call ARC_fnc_intelOrderTick;

// Publish a public snapshot for client briefing / SITREP
[] call ARC_fnc_publicBroadcastState;
// Persist on every tick (safe and simple). If this becomes chatty, we can throttle.
[] call ARC_fnc_stateSave;
true

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
// Reconcile the TOC backlog against the (now pruned) lead pool so stale
// "in the TOC Queue" indications are dropped when their lead ages out.
if (!isNil "ARC_fnc_tocBacklogPrune") then { [] call ARC_fnc_tocBacklogPrune; };
[] call ARC_fnc_companyCommandTick;
[] call ARC_fnc_companyCommandVirtualOpsTick;


// Sustainment drain
// Base stocks naturally deplete through SUPPLYLEDGER v1 so ambient drain is auditable.
[] call ARC_fnc_supplyApplyAmbientDrain;


// Intel layer periodic maintenance (metrics + order completion)
[] call ARC_fnc_intelMetricsTick;
[] call ARC_fnc_intelOrderTick;

// Medical subsystem recovery tick
if (missionNamespace getVariable ["ARC_medical_initialized", false]) then {
    [] call ARC_fnc_medicalTick;
};

// Publish a public snapshot for client briefing / SITREP
[] call ARC_fnc_publicBroadcastState;
// Persist on every tick (safe and simple). If this becomes chatty, we can throttle.
[] call ARC_fnc_stateSave;
true

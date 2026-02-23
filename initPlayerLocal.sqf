if (!hasInterface) exitWith {};

waitUntil { !isNull player };

// Avoid init races: wait for server bootstrap + state snapshots.
// In hosted MP / dev environments this can occasionally fail to publish; use a bounded timeout + adaptive fallback.
private _readyTimeoutSec = 35;
private _readyWaitStartedAt = diag_tickTime;
missionNamespace setVariable ["ARC_clientStateRefreshEnabled", false];

diag_log format [
    "[ARC][INFO] initPlayerLocal: waiting for ARC_serverReady (timeout=%1s).",
    _readyTimeoutSec
];

waitUntil {
    (missionNamespace getVariable ["ARC_serverReady", false]) || ((diag_tickTime - _readyWaitStartedAt) > _readyTimeoutSec)
};

private _serverReadyAtGate = missionNamespace getVariable ["ARC_serverReady", false];
if (_serverReadyAtGate) then
{
    missionNamespace setVariable ["ARC_clientStateRefreshEnabled", true];
    diag_log format [
        "[ARC][INFO] initPlayerLocal: ARC_serverReady observed after %1s; enabling client state refresh.",
        round (diag_tickTime - _readyWaitStartedAt)
    ];
}
else
{
    diag_log format [
        "[ARC][WARN] initPlayerLocal: ARC_serverReady timeout threshold reached (%1s); continuing with client init fallback and keeping state refresh gated.",
        _readyTimeoutSec
    ];

    [] spawn {
        private _fallbackWaitStart = diag_tickTime;
        waitUntil { missionNamespace getVariable ["ARC_serverReady", false] };

        missionNamespace setVariable ["ARC_clientStateRefreshEnabled", true];
        diag_log format [
            "[ARC][INFO] initPlayerLocal: ARC_serverReady observed after fallback (+%1s post-timeout); enabling delayed client refresh.",
            round (diag_tickTime - _fallbackWaitStart)
        ];

        if (!isNil { missionNamespace getVariable "ARC_pub_state" }) then
        {
            [] call ARC_fnc_briefingUpdateClient;
            if (!isNil "ARC_fnc_tocRefreshClient") then { [] call ARC_fnc_tocRefreshClient; };
        };
    };
};

// Build stamp breadcrumb (client)
[] spawn {
    uiSleep 2;
    diag_log format ["[ARC][BUILD][CLIENT] %1", missionNamespace getVariable ["ARC_buildStamp","UNKNOWN"]];
};

[] execVM "scripts\ARC_clearLightbarToastClient.sqf";

// ---------------------------------------------------------------------------
// Client init (keep this deterministic)
// ---------------------------------------------------------------------------
[] call ARC_fnc_intelInit;
[] call ARC_fnc_briefingInitClient;
[] call ARC_fnc_tocInitPlayer;

// Farabad Console (tablet UI) - keybind + client init
[] call ARC_fnc_uiConsoleInitClient;

// CIVSUB contact (ALiVE-style) - client init
[] call ARC_fnc_civsubContactInitClient;

// ---------------------------------------------------------------------------
// Console resilience: rebind/reinit a few times in case actions/keybinds get cleared
// by locality swaps, mods, or UI rebuilds.
// ---------------------------------------------------------------------------
if (!(missionNamespace getVariable ["ARC_consoleKeepaliveRunning", false])) then
{
    missionNamespace setVariable ["ARC_consoleKeepaliveRunning", true];
};

// ---------------------------------------------------------------------------
// JIP-safe snapshot watcher (NO PV EH / no local var pitfalls)
// - Waits for ARC_pub_state to exist
// - Refreshes briefing/TOC once on join
// - Refreshes again whenever ARC_pub_stateUpdatedAt changes
//   (serverTime token from server publish; watcher only does inequality checks).
// ---------------------------------------------------------------------------
if (!(missionNamespace getVariable ["ARC_clientSnapshotWatcherRunning", false])) then
{
    missionNamespace setVariable ["ARC_clientSnapshotWatcherRunning", true];

    [] spawn {
        // Single refresh contract: keep TOC + briefing parity when any client snapshot signal changes.
        private _refreshClientSnapshotView = {
            // Debounce: skip if a refresh already ran within the last second
            private _pendingAt = uiNamespace getVariable ["ARC_clientSnapshotRefreshPendingAt", -1];
            if (!(_pendingAt isEqualType 0)) then { _pendingAt = -1; };
            private _now = diag_tickTime;
            if ((_now - _pendingAt) < 1) exitWith {};
            uiNamespace setVariable ["ARC_clientSnapshotRefreshPendingAt", _now];

            [] call ARC_fnc_briefingUpdateClient;
            if (!isNil "ARC_fnc_tocRefreshClient") then { [] call ARC_fnc_tocRefreshClient; };
            uiNamespace setVariable ["ARC_console_dirty", true];
        };

        // Wait for server readiness gate + first snapshot
        waitUntil {
            (missionNamespace getVariable ["ARC_clientStateRefreshEnabled", false]) &&
            { !isNil { missionNamespace getVariable "ARC_pub_state" } }
        };

        // Initial refresh for JIP
        call _refreshClientSnapshotView;

        private _lastState = missionNamespace getVariable ["ARC_pub_stateUpdatedAt", -1];
        private _lastS1 = missionNamespace getVariable ["ARC_pub_s1_registryUpdatedAt", -1];
        private _lastCompany = missionNamespace getVariable ["ARC_pub_companyCommandUpdatedAt", -1];
        private _stateFallbackRefreshed = false;

        // Preferred path: react immediately to server snapshot publish events.
        private _existingStateEhId = missionNamespace getVariable ["ARC_clientSnapshotPvEhId", -1];
        if (_existingStateEhId < 0) then
        {
            missionNamespace setVariable ["ARC_clientSnapshotPvEhId", "ARC_pub_stateUpdatedAt" addPublicVariableEventHandler {
                private _refreshEnabled = missionNamespace getVariable ["ARC_clientStateRefreshEnabled", false];
                // Race-avoidance contract: PV event handlers must only run refresh after client readiness gate is lifted.
                if (_refreshEnabled) then { [] spawn _refreshClientSnapshotView; };
            }];
        };

        private _existingS1EhId = missionNamespace getVariable ["ARC_clientS1SnapshotPvEhId", -1];
        if (_existingS1EhId < 0) then
        {
            missionNamespace setVariable ["ARC_clientS1SnapshotPvEhId", "ARC_pub_s1_registryUpdatedAt" addPublicVariableEventHandler {
                private _refreshEnabled = missionNamespace getVariable ["ARC_clientStateRefreshEnabled", false];
                if (_refreshEnabled) then { [] spawn _refreshClientSnapshotView; };
            }];
        };

        private _existingCompanyEhId = missionNamespace getVariable ["ARC_clientCompanySnapshotPvEhId", -1];
        if (_existingCompanyEhId < 0) then
        {
            missionNamespace setVariable ["ARC_clientCompanySnapshotPvEhId", "ARC_pub_companyCommandUpdatedAt" addPublicVariableEventHandler {
                private _refreshEnabled = missionNamespace getVariable ["ARC_clientStateRefreshEnabled", false];
                if (_refreshEnabled) then { [] spawn _refreshClientSnapshotView; };
            }];
        };

        // Fallback resilience path: if PV events are missed in edge cases, poll less frequently.
        while {true} do
        {
            uiSleep 2;

            // Snapshot fallback belongs in polling (not PV EH gating): recover if state arrives before/update token propagation.
            if ((missionNamespace getVariable ["ARC_clientStateRefreshEnabled", false]) && { !isNil { missionNamespace getVariable "ARC_pub_state" } } && { _lastState < 0 } && { !_stateFallbackRefreshed }) then
            {
                _lastState = missionNamespace getVariable ["ARC_pub_stateUpdatedAt", _lastState];
                _stateFallbackRefreshed = true;
                call _refreshClientSnapshotView;
            };

            private _nowState = missionNamespace getVariable ["ARC_pub_stateUpdatedAt", _lastState];
            private _nowS1 = missionNamespace getVariable ["ARC_pub_s1_registryUpdatedAt", _lastS1];
            private _nowCompany = missionNamespace getVariable ["ARC_pub_companyCommandUpdatedAt", _lastCompany];

            private _changed = false;
            if (_nowState isEqualType 0 && { _nowState != _lastState }) then { _lastState = _nowState; _changed = true; };
            if (_nowS1 isEqualType 0 && { _nowS1 != _lastS1 }) then { _lastS1 = _nowS1; _changed = true; };
            if (_nowCompany isEqualType 0 && { _nowCompany != _lastCompany }) then { _lastCompany = _nowCompany; _changed = true; };

            if (_changed) then { call _refreshClientSnapshotView; };
        };
    };
};

// ---------------------------------------------------------------------------
// TOC addAction keepalive
//
// Ensures mobile TOC vehicles and late-spawned TOC stations always get menus,
// and recovers if another script clears actions.
// ---------------------------------------------------------------------------
if (!(missionNamespace getVariable ["ARC_tocKeepaliveRunning", false])) then
{
    missionNamespace setVariable ["ARC_tocKeepaliveRunning", true];
};

private _getInEhId = player getVariable ["ARC_tocGetInEhId", -1];
if (_getInEhId < 0) then
{
    _getInEhId = player addEventHandler ["GetInMan", { [] call ARC_fnc_tocInitPlayer; }];
    player setVariable ["ARC_tocGetInEhId", _getInEhId];
};

private _getOutEhId = player getVariable ["ARC_tocGetOutEhId", -1];
if (_getOutEhId < 0) then
{
    _getOutEhId = player addEventHandler ["GetOutMan", { [] call ARC_fnc_tocInitPlayer; }];
    player setVariable ["ARC_tocGetOutEhId", _getOutEhId];
};

// Consolidated scheduler loop for console + TOC safety keepalives.
if (
    (missionNamespace getVariable ["ARC_consoleKeepaliveRunning", false]) &&
    (missionNamespace getVariable ["ARC_tocKeepaliveRunning", false]) &&
    !(missionNamespace getVariable ["ARC_clientKeepaliveSchedulerRunning", false])
) then
{
    missionNamespace setVariable ["ARC_clientKeepaliveSchedulerRunning", true];

    [] spawn {
        private _nextConsoleAt = diag_tickTime + 5;
        private _nextTocAt = diag_tickTime + 5;
        private _consoleFastRetriesLeft = 12;
        private _tocFastRetriesLeft = 12;

        while {true} do
        {
            private _now = diag_tickTime;

            if (_now >= _nextConsoleAt) then
            {
                if (!isNil "ARC_fnc_uiConsoleInitClient") then { [] call ARC_fnc_uiConsoleInitClient; };

                if (_consoleFastRetriesLeft > 0) then
                {
                    _consoleFastRetriesLeft = _consoleFastRetriesLeft - 1;
                };

                if (_consoleFastRetriesLeft > 0) then
                {
                    _nextConsoleAt = _now + 5;
                }
                else
                {
                    _nextConsoleAt = _now + 30;
                };
            };

            if (_now >= _nextTocAt) then
            {
                if (!isNil "ARC_fnc_tocInitPlayer") then { [] call ARC_fnc_tocInitPlayer; };

                if (_tocFastRetriesLeft > 0) then
                {
                    _tocFastRetriesLeft = _tocFastRetriesLeft - 1;
                };

                if (_tocFastRetriesLeft > 0) then
                {
                    _nextTocAt = _now + 5;
                }
                else
                {
                    _nextTocAt = _now + 30;
                };
            };

            uiSleep 0.25;
        };
    };
};

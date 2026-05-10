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

// ACE Medical → TOC CASEVAC integration (Item 21)
// Registers the ace_unconscious CBA event handler on this client.
if (!isNil "ARC_fnc_medicalAceIncapHandler") then
{
    [] call ARC_fnc_medicalAceIncapHandler;
};

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
        private _snapshotPollS = missionNamespace getVariable ["ARC_clientSnapshotFallbackPollS", 3];
        if (!(_snapshotPollS isEqualType 0)) then { _snapshotPollS = 3; };
        _snapshotPollS = (_snapshotPollS max 1) min 10;

        private _snapshotDiagS = missionNamespace getVariable ["ARC_clientSnapshotDiagIntervalS", 120];
        if (!(_snapshotDiagS isEqualType 0)) then { _snapshotDiagS = 120; };
        _snapshotDiagS = (_snapshotDiagS max 30) min 600;
        private _lastSnapshotDiagAt = diag_tickTime;

        uiNamespace setVariable ["ARC_clientSnapshotRefreshCount", 0];

        // Wait for server readiness gate + first snapshot
        private _snapshotGateWarnIntervalSec = 45;
        private _snapshotGateWarnAt = diag_tickTime + _snapshotGateWarnIntervalSec;
        waitUntil {
            private _refreshEnabled = missionNamespace getVariable ["ARC_clientStateRefreshEnabled", false];
            private _hasState = !isNil { missionNamespace getVariable "ARC_pub_state" };
            private _ready = _refreshEnabled && { _hasState };
            if (!_ready && { diag_tickTime >= _snapshotGateWarnAt }) then
            {
                diag_log format [
                    "[ARC][WARN] initPlayerLocal snapshot watcher: waiting for initial state gate=%1 hasState=%2",
                    _refreshEnabled,
                    _hasState
                ];
                _snapshotGateWarnAt = diag_tickTime + _snapshotGateWarnIntervalSec;
            };
            _ready
        };

        // Initial refresh for JIP
        if (!isNil "ARC_fnc_clientSnapshotRefresh") then { [] call ARC_fnc_clientSnapshotRefresh; };

        private _lastState = missionNamespace getVariable ["ARC_pub_stateUpdatedAt", -1];
        private _lastS1 = missionNamespace getVariable ["ARC_pub_s1_registryUpdatedAt", -1];
        private _lastCompany = missionNamespace getVariable ["ARC_pub_companyCommandUpdatedAt", -1];
        private _lastIntel = missionNamespace getVariable ["ARC_pub_intelUpdatedAt", -1];
        private _lastQueue = missionNamespace getVariable ["ARC_pub_queueUpdatedAt", -1];
        private _lastOrders = missionNamespace getVariable ["ARC_pub_ordersUpdatedAt", -1];
        private _lastAirbase = missionNamespace getVariable ["ARC_pub_airbaseUiSnapshotUpdatedAt", -1];
        private _lastEodDispo = missionNamespace getVariable ["ARC_pub_eodDispoApprovalsUpdatedAt", -1];
        private _stateFallbackRefreshed = false;

        // Preferred path: react immediately to server snapshot publish events.
        private _snapshotSignalEhBindings = [
            ["ARC_pub_stateUpdatedAt", "ARC_clientSnapshotPvEhId"],
            ["ARC_pub_s1_registryUpdatedAt", "ARC_clientS1SnapshotPvEhId"],
            ["ARC_pub_companyCommandUpdatedAt", "ARC_clientCompanySnapshotPvEhId"],
            ["ARC_pub_intelUpdatedAt", "ARC_clientIntelSnapshotPvEhId"],
            ["ARC_pub_queueUpdatedAt", "ARC_clientQueueSnapshotPvEhId"],
            ["ARC_pub_ordersUpdatedAt", "ARC_clientOrdersSnapshotPvEhId"],
            ["ARC_pub_airbaseUiSnapshotUpdatedAt", "ARC_clientAirbaseSnapshotPvEhId"],
            ["ARC_pub_eodDispoApprovalsUpdatedAt", "ARC_clientEodDispoSnapshotPvEhId"]
        ];

        {
            _x params [
                ["_signalVarName", "", [""]],
                ["_ehIdVarName", "", [""]]
            ];

            private _existingEhId = missionNamespace getVariable [_ehIdVarName, -1];
            if (_existingEhId isEqualType 0 && { _existingEhId >= 0 }) then { continue; };

            private _newEhId = _signalVarName addPublicVariableEventHandler {
                if (
                    (missionNamespace getVariable ["ARC_clientStateRefreshEnabled", false]) &&
                    { !isNil "ARC_fnc_clientSnapshotRefresh" }
                ) then
                {
                    [] spawn ARC_fnc_clientSnapshotRefresh;
                };
            };
            missionNamespace setVariable [_ehIdVarName, _newEhId];
        } forEach _snapshotSignalEhBindings;

        diag_log format [
            "[ARC][INFO] initPlayerLocal snapshot watcher: registered PV handlers=%1",
            count _snapshotSignalEhBindings
        ];

        // Fallback resilience path: if PV events are missed in edge cases, poll less frequently.
        while {true} do
        {
            uiSleep _snapshotPollS;

            // Snapshot fallback belongs in polling (not PV EH gating): recover if state arrives before/update token propagation.
            if ((missionNamespace getVariable ["ARC_clientStateRefreshEnabled", false]) && { !isNil { missionNamespace getVariable "ARC_pub_state" } } && { _lastState < 0 } && { !_stateFallbackRefreshed }) then
            {
                _lastState = missionNamespace getVariable ["ARC_pub_stateUpdatedAt", _lastState];
                _stateFallbackRefreshed = true;
                if (!isNil "ARC_fnc_clientSnapshotRefresh") then { [] call ARC_fnc_clientSnapshotRefresh; };
            };

            private _nowState = missionNamespace getVariable ["ARC_pub_stateUpdatedAt", _lastState];
            private _nowS1 = missionNamespace getVariable ["ARC_pub_s1_registryUpdatedAt", _lastS1];
            private _nowCompany = missionNamespace getVariable ["ARC_pub_companyCommandUpdatedAt", _lastCompany];
            private _nowIntel = missionNamespace getVariable ["ARC_pub_intelUpdatedAt", _lastIntel];
            private _nowQueue = missionNamespace getVariable ["ARC_pub_queueUpdatedAt", _lastQueue];
            private _nowOrders = missionNamespace getVariable ["ARC_pub_ordersUpdatedAt", _lastOrders];
            private _nowAirbase = missionNamespace getVariable ["ARC_pub_airbaseUiSnapshotUpdatedAt", _lastAirbase];
            private _nowEodDispo = missionNamespace getVariable ["ARC_pub_eodDispoApprovalsUpdatedAt", _lastEodDispo];

            private _changed = false;
            if (_nowState isEqualType 0 && { _nowState != _lastState }) then { _lastState = _nowState; _changed = true; };
            if (_nowS1 isEqualType 0 && { _nowS1 != _lastS1 }) then { _lastS1 = _nowS1; _changed = true; };
            if (_nowCompany isEqualType 0 && { _nowCompany != _lastCompany }) then { _lastCompany = _nowCompany; _changed = true; };
            if (_nowIntel isEqualType 0 && { _nowIntel != _lastIntel }) then { _lastIntel = _nowIntel; _changed = true; };
            if (_nowQueue isEqualType 0 && { _nowQueue != _lastQueue }) then { _lastQueue = _nowQueue; _changed = true; };
            if (_nowOrders isEqualType 0 && { _nowOrders != _lastOrders }) then { _lastOrders = _nowOrders; _changed = true; };
            if (_nowAirbase isEqualType 0 && { _nowAirbase != _lastAirbase }) then { _lastAirbase = _nowAirbase; _changed = true; };
            if (_nowEodDispo isEqualType 0 && { _nowEodDispo != _lastEodDispo }) then { _lastEodDispo = _nowEodDispo; _changed = true; };

            if (_changed && { !isNil "ARC_fnc_clientSnapshotRefresh" }) then { [] call ARC_fnc_clientSnapshotRefresh; };

            if (missionNamespace getVariable ["ARC_debugLogEnabled", false]) then
            {
                if ((diag_tickTime - _lastSnapshotDiagAt) >= _snapshotDiagS) then
                {
                    private _refreshes = uiNamespace getVariable ["ARC_clientSnapshotRefreshCount", 0];
                    if (!(_refreshes isEqualType 0)) then { _refreshes = 0; };
                    diag_log format [
                        "[ARC][CLIENT][SCHED] initPlayerLocal snapshot watcher: poll=%1s refreshes=%2",
                        _snapshotPollS,
                        _refreshes
                    ];
                    _lastSnapshotDiagAt = diag_tickTime;
                };
            };
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
        private _retryFastS = missionNamespace getVariable ["ARC_clientKeepaliveFastRetryS", 5];
        if (!(_retryFastS isEqualType 0)) then { _retryFastS = 5; };
        _retryFastS = (_retryFastS max 2) min 15;

        private _steadyRetryS = missionNamespace getVariable ["ARC_clientKeepaliveSteadyRetryS", 45];
        if (!(_steadyRetryS isEqualType 0)) then { _steadyRetryS = 45; };
        _steadyRetryS = (_steadyRetryS max 15) min 180;

        private _loopSleepS = missionNamespace getVariable ["ARC_clientKeepaliveLoopSleepS", 1];
        if (!(_loopSleepS isEqualType 0)) then { _loopSleepS = 1; };
        _loopSleepS = (_loopSleepS max 0.25) min 5;

        if (missionNamespace getVariable ["ARC_debugLogEnabled", false]) then
        {
            diag_log format [
                "[ARC][CLIENT][SCHED] initPlayerLocal keepalive scheduler: fast=%1s steady=%2s loopSleep=%3s",
                _retryFastS,
                _steadyRetryS,
                _loopSleepS
            ];
        };

        private _nextConsoleAt = diag_tickTime + _retryFastS;
        private _nextTocAt = diag_tickTime + _retryFastS;
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
                    _nextConsoleAt = _now + _retryFastS;
                }
                else
                {
                    _nextConsoleAt = _now + _steadyRetryS;
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
                    _nextTocAt = _now + _retryFastS;
                }
                else
                {
                    _nextTocAt = _now + _steadyRetryS;
                };
            };

            uiSleep _loopSleepS;
        };
    };
};

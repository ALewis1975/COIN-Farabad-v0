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
        // Wait for server readiness gate + first snapshot
        waitUntil {
            (missionNamespace getVariable ["ARC_clientStateRefreshEnabled", false]) &&
            { !isNil { missionNamespace getVariable "ARC_pub_state" } }
        };

        private _refresh = {
            [] call ARC_fnc_briefingUpdateClient;
            if (!isNil "ARC_fnc_tocRefreshClient") then { [] call ARC_fnc_tocRefreshClient; };
        };

        // Initial refresh for JIP
        call _refresh;

        private _last = missionNamespace getVariable ["ARC_pub_stateUpdatedAt", -1];

        while {true} do
        {
            uiSleep 0.5;
            private _now = missionNamespace getVariable ["ARC_pub_stateUpdatedAt", _last];
            if (_now isEqualType 0 && { _now != _last }) then
            {
                _last = _now;
                call _refresh;
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

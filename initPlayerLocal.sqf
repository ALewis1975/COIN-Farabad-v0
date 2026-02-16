if (!hasInterface) exitWith {};

waitUntil { !isNull player };

// Avoid init races: wait for server bootstrap + state snapshots.
// In hosted MP / dev environments this can occasionally fail to publish; use a timeout fallback so UI doesn't deadlock.
private _t0 = diag_tickTime;
waitUntil {
    (missionNamespace getVariable ["ARC_serverReady", false]) || ((diag_tickTime - _t0) > 20)


// ---------------------------------------------------------------------------
// Police Extended: clear "Lightbar ON" toast on clients (startup)
// ---------------------------------------------------------------------------
[] execVM "ARC_clearLightbarToastClient.sqf";
};
if (!(missionNamespace getVariable ["ARC_serverReady", false])) then
{
    diag_log "[ARC][WARN] initPlayerLocal: ARC_serverReady timeout; continuing with client init (dev fallback).";
};

// Build stamp breadcrumb (client)
[] spawn {
    uiSleep 2;
    diag_log format ["[ARC][BUILD][CLIENT] %1", missionNamespace getVariable ["ARC_buildStamp","UNKNOWN"]];
};

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
if (isNil { missionNamespace getVariable "ARC_consoleKeepaliveRunning" }) then
{
    missionNamespace setVariable ["ARC_consoleKeepaliveRunning", true];

    [] spawn {
        // Retry window: first minute after join
        for "_i" from 0 to 11 do
        {
            uiSleep 5;

            if (!isNil "ARC_fnc_uiConsoleInitClient") then { [] call ARC_fnc_uiConsoleInitClient; };
            if (!isNil "ARC_fnc_tocInitPlayer") then { [] call ARC_fnc_tocInitPlayer; };
        };

        // Slow keepalive thereafter
        while {true} do
        {
            uiSleep 30;
            if (!isNil "ARC_fnc_uiConsoleInitClient") then { [] call ARC_fnc_uiConsoleInitClient; };
        };
    };
};

// ---------------------------------------------------------------------------
// JIP-safe snapshot watcher (NO PV EH / no local var pitfalls)
// - Waits for ARC_pub_state to exist
// - Refreshes briefing/TOC once on join
// - Refreshes again whenever ARC_pub_stateUpdatedAt changes
// ---------------------------------------------------------------------------
if (isNil { missionNamespace getVariable "ARC_clientSnapshotWatcherRunning" }) then
{
    missionNamespace setVariable ["ARC_clientSnapshotWatcherRunning", true];

    [] spawn {
        // Wait for first snapshot
        waitUntil { !isNil { missionNamespace getVariable "ARC_pub_state" } };

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
player addEventHandler ["GetInMan", { [] call ARC_fnc_tocInitPlayer; }];
player addEventHandler ["GetOutMan", { [] call ARC_fnc_tocInitPlayer; }];

[] spawn {
    uiSleep 5;

    // Fast retries during early init / JIP timing
    for "_i" from 0 to 11 do
    {
        [] call ARC_fnc_tocInitPlayer;
        uiSleep 5;
    };

    // Keepalive thereafter:
    while {true} do
    {
        [] call ARC_fnc_tocInitPlayer;
        uiSleep 30;
    };
};

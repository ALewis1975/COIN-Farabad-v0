/*
    COIN Farabad - initJIPcompatible.sqf

    Explicit JIP (Join-In-Progress) handler for late-joining players.

    Called from initPlayerLocal.sqf or via a mission event handler when a
    new player joins after the mission has already started.

    Authority: CLIENT-LOCAL only.
    Mirrors the JIP-fallback logic in initPlayerLocal.sqf but is isolated
    here so it can be called independently for late-join scenarios and
    tested without re-running the full client init path.

    The script intentionally duplicates no state — it relies on the same
    ARC_clientStateRefreshEnabled gate used by the snapshot watcher.
*/

if (!hasInterface) exitWith {};

waitUntil { !isNull player };

diag_log "[ARC][INFO] initJIPcompatible: starting JIP client init.";

// ---------------------------------------------------------------------------
// Gate: wait for ARC_serverReady (bounded — mirrors initPlayerLocal.sqf).
// ---------------------------------------------------------------------------
private _jipTimeoutSec     = 35;
private _jipWaitStartedAt  = diag_tickTime;

waitUntil {
    (missionNamespace getVariable ["ARC_serverReady", false]) ||
    ((diag_tickTime - _jipWaitStartedAt) > _jipTimeoutSec)
};

private _serverReadyAtJip = missionNamespace getVariable ["ARC_serverReady", false];

if (_serverReadyAtJip) then
{
    diag_log format [
        "[ARC][INFO] initJIPcompatible: ARC_serverReady observed after %1s.",
        round (diag_tickTime - _jipWaitStartedAt)
    ];
}
else
{
    diag_log format [
        "[ARC][WARN] initJIPcompatible: ARC_serverReady timeout (%1s); continuing with JIP fallback.",
        _jipTimeoutSec
    ];
};

// ---------------------------------------------------------------------------
// Enable client state refresh (idempotent — safe to call more than once).
// ---------------------------------------------------------------------------
missionNamespace setVariable ["ARC_clientStateRefreshEnabled", true];

// ---------------------------------------------------------------------------
// Wait for the first server state snapshot before refreshing client UI.
// ---------------------------------------------------------------------------
waitUntil { !isNil { missionNamespace getVariable "ARC_pub_state" } };

// Briefing + TOC snapshot refresh
if (!isNil "ARC_fnc_briefingUpdateClient") then { [] call ARC_fnc_briefingUpdateClient; };
if (!isNil "ARC_fnc_tocRefreshClient")     then { [] call ARC_fnc_tocRefreshClient; };

// Intel overlay
if (!isNil "ARC_fnc_intelInit") then { [] call ARC_fnc_intelInit; };

// Console (tablet UI)
if (!isNil "ARC_fnc_uiConsoleInitClient") then { [] call ARC_fnc_uiConsoleInitClient; };

// TOC actions (vehicle menus)
if (!isNil "ARC_fnc_tocInitPlayer") then { [] call ARC_fnc_tocInitPlayer; };

diag_log "[ARC][INFO] initJIPcompatible: JIP client init complete.";

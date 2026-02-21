/*
    COIN Farabad - initIntro.sqf

    Mission intro sequence for player immersion.

    Called on the LOCAL client immediately after the player slot is assigned.
    Displays an ARC mission briefing hint and optional flavor text. An intro
    camera can be enabled here when the terrain and scripted cameras are ready.

    Authority: CLIENT-LOCAL only.
    No state is written here — this is display-only.
*/

if (!hasInterface) exitWith {};

waitUntil { !isNull player };

diag_log "[ARC][INFO] initIntro: starting mission intro sequence.";

// ---------------------------------------------------------------------------
// Introductory hint overlay (non-blocking).
// ---------------------------------------------------------------------------
private _introMsg = "FARABAD COIN (2011) — Persistent, Dynamic COIN Sandbox\n\nWelcome to Farabad District, Afghanistan.\n\nYour mission is to support stability operations against insurgent networks.\n\nCheck the TASK LOG for current objectives and report to your element commander.";

// Use the ARC client hint helper when available; fall back to titleText.
if (!isNil "ARC_fnc_clientHint") then
{
    [_introMsg, "INFO"] call ARC_fnc_clientHint;
}
else
{
    titleText [_introMsg, "BLACK IN", 3];
};

// ---------------------------------------------------------------------------
// Build stamp breadcrumb visible in RPT for this client session.
// ---------------------------------------------------------------------------
[] spawn
{
    uiSleep 2;
    private _stamp = missionNamespace getVariable ["ARC_buildStamp", "UNKNOWN"];
    diag_log format ["[ARC][BUILD][INTRO] %1", _stamp];
};

diag_log "[ARC][INFO] initIntro: intro sequence dispatched.";

/*
    COIN Farabad - onPlayerKilled.sqf

    Executed on the local machine (client) when the local player is killed.

    Params (engine-supplied):
      _unit       : Object  – the killed player unit
      _killer     : Object  – the object that killed _unit (may be objNull)
      _instigator : Object  – the instigator of the kill (may be objNull)
      _useEffects : Boolean – whether visual/sound effects are used

    Authority: CLIENT-LOCAL only. Do NOT write to missionNamespace here.
    Server-side attribution is handled by ARC_fnc_civsubOnCivKilled and
    future ARC_fnc_playerKilled (server RPC).
*/

if (!hasInterface) exitWith {};

params [
    ["_unit",       objNull, [objNull]],
    ["_killer",     objNull, [objNull]],
    ["_instigator", objNull, [objNull]]
];

if (isNull _unit) exitWith {};

// ---------------------------------------------------------------------------
// Logging
// ---------------------------------------------------------------------------
private _killerName = if (isNull _killer) then { "UNKNOWN" } else { name _killer };
diag_log format [
    "[ARC][INFO] onPlayerKilled: unit=%1 killer=%2 instigator=%3",
    name _unit, _killerName, _instigator
];

// ---------------------------------------------------------------------------
// CIVSUB hook: notify server of player-killed event for attribution.
// Guard with !isNil to remain safe when ARC_fnc_playerKilled is not yet
// compiled (future feature hook).
// ---------------------------------------------------------------------------
if (!isNil "ARC_fnc_playerKilled") then
{
    [_unit, _killer, _instigator] remoteExec ["ARC_fnc_playerKilled", 2];
};

// ---------------------------------------------------------------------------
// UI cleanup: close any open ARC overlays on death to prevent stale dialogs.
// ---------------------------------------------------------------------------
if (!isNil "ARC_fnc_uiConsoleClose") then
{
    [] call ARC_fnc_uiConsoleClose;
};

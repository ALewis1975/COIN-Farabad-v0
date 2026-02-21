/*
    COIN Farabad - onPlayerRespawn.sqf

    Executed on the local machine (client) after the local player respawns.

    Params (engine-supplied):
      _unit   : Object – the new (respawned) player unit
      _corpse : Object – the old (killed) unit/corpse

    Authority: CLIENT-LOCAL only.
    Re-initializes client-side ARC systems so they bind correctly to the new
    unit reference after respawn.
*/

if (!hasInterface) exitWith {};

params [
    ["_unit",   objNull, [objNull]],
    ["_corpse", objNull, [objNull]]
];

if (isNull _unit) exitWith {};

diag_log format [
    "[ARC][INFO] onPlayerRespawn: new unit=%1 corpse=%2",
    name _unit, _corpse
];

// ---------------------------------------------------------------------------
// Re-initialize client subsystems after respawn.
// All guarded with !isNil so this file is safe even when subsystems are
// added or removed incrementally.
// ---------------------------------------------------------------------------

// Briefing + intel overlay
if (!isNil "ARC_fnc_briefingInitClient")   then { [] call ARC_fnc_briefingInitClient; };
if (!isNil "ARC_fnc_briefingUpdateClient") then { [] call ARC_fnc_briefingUpdateClient; };
if (!isNil "ARC_fnc_intelInit")            then { [] call ARC_fnc_intelInit; };

// Console (tablet UI) keybind + client init
if (!isNil "ARC_fnc_uiConsoleInitClient") then { [] call ARC_fnc_uiConsoleInitClient; };

// CIVSUB contact layer
if (!isNil "ARC_fnc_civsubContactInitClient") then { [] call ARC_fnc_civsubContactInitClient; };

// TOC menus (vehicle actions)
if (!isNil "ARC_fnc_tocInitPlayer") then { [] call ARC_fnc_tocInitPlayer; };

// TOC GetIn/GetOut event handlers — reattach to new unit after respawn.
private _getInEhId = _unit getVariable ["ARC_tocGetInEhId", -1];
if (_getInEhId < 0) then
{
    _getInEhId = _unit addEventHandler ["GetInMan", { [] call ARC_fnc_tocInitPlayer; }];
    _unit setVariable ["ARC_tocGetInEhId", _getInEhId];
};

private _getOutEhId = _unit getVariable ["ARC_tocGetOutEhId", -1];
if (_getOutEhId < 0) then
{
    _getOutEhId = _unit addEventHandler ["GetOutMan", { [] call ARC_fnc_tocInitPlayer; }];
    _unit setVariable ["ARC_tocGetOutEhId", _getOutEhId];
};

diag_log "[ARC][INFO] onPlayerRespawn: client re-init complete.";

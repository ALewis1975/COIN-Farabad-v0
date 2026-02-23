/*
  ARC_lightbarStartupServer.sqf
  Farabad COIN - Police Extended Lightbar Startup (server-side)

  Purpose:
    - Centralize Police Extended lightbar enabling at mission start
    - Replace per-object init code in mission.sqm
    - Provide deterministic logging and warnings when variable names are missing

  Locality:
    - Server only. Vehicles placed in the editor are local to server at start.

  Notes:
    - This replicates the prior init call: this execVM "\Expansion_Mod_Police\Vehicles\Scripts\Lightbar\CODE2_On.sqf";
    - For Patrol_08 we also replicate: this disableAI "LIGHTS";
*/

if (!isServer) exitWith {};

private _log = {
  params [
    ["_level", "INFO", [""]],
    ["_message", "", [""]],
    ["_meta", []]
  ];

  if (!isNil "ARC_fnc_farabadLog") then {
    ["POLICE", _level, _message, _meta] call ARC_fnc_farabadLog;
  } else {
    diag_log format ["[FARABAD][POLICE][%1] msg=%2 meta=%3", _level, _message, _meta];
  };
};

// Targets: read from missionNamespace override if set by initServer.sqf,
// otherwise fall back to the original hardcoded list.
// Each entry is [varName, disableAILights].
private _defaultTargets = [
  ["Patrol_01", false],
  ["Patrol_07", false],
  ["Patrol_08", true],
  ["Patrol_09", false]
];

private _targets = missionNamespace getVariable ["ARC_lightbarTargets", _defaultTargets];
if !(_targets isEqualType []) then { _targets = _defaultTargets; };

{
  _x params ["_varName", "_disableAILights"];

  private _veh = missionNamespace getVariable [_varName, objNull];
  if (isNull _veh) then {
    ["WARN", "LIGHTBAR vehicle variable not found.", [["vehicleVar", _varName], ["result", "objNull"]]] call _log;
  } else {
    _veh execVM "\Expansion_Mod_Police\Vehicles\Scripts\Lightbar\CODE2_On.sqf";

    if (_disableAILights) then {
      _veh disableAI "LIGHTS";
    };

    ["INFO", "LIGHTBAR enabled.", [["vehicleVar", _varName], ["type", typeOf _veh], ["disableAILights", _disableAILights]]] call _log;
  };
} forEach _targets;

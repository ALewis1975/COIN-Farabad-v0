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
  params [["_msg", "", [""]], ["_args", [], [[]]]];
  if (!isNil "ARC_fnc_log") then { ["POLICE", _msg, _args, "WARN"] call ARC_fnc_log; }
  else { diag_log (if ((count _args) > 0) then { format ([_msg] + _args) } else { _msg }); };
};

private _targets = [
  ["Patrol_01", false],
  ["Patrol_07", false],
  ["Patrol_08", true],
  ["Patrol_09", false]
];

{
  _x params ["_varName", "_disableAILights"];

  private _veh = missionNamespace getVariable [_varName, objNull];
  if (isNull _veh) then {
    ["[FARABAD][POLICE][LIGHTBAR][WARN] Vehicle var '%1' not found (objNull).", [_varName]] call _log;
  } else {
    _veh execVM "\Expansion_Mod_Police\Vehicles\Scripts\Lightbar\CODE2_On.sqf";

    if (_disableAILights) then {
      _veh disableAI "LIGHTS";
    };

    ["[FARABAD][POLICE][LIGHTBAR][OK] Enabled lightbar on '%1' (%2).", [_varName, typeOf _veh]] call _log;
  };
} forEach _targets;

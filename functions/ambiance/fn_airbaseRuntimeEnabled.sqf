/*
    AIRBASE runtime gate helper (server-authoritative).
    Returns true only when live AIRBASE runtime is explicitly enabled.

    Master gate variable:
      missionNamespace getVariable ["airbase_v1_runtime_enabled", false]
*/

params [["_entryPoint", "UNKNOWN", [""]]];

if (!isServer) exitWith {false};

private _enabled = missionNamespace getVariable ["airbase_v1_runtime_enabled", false];
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = false; };

if (!_enabled) then {
    diag_log format ["[ARC][AIRBASE][PLANNING] Runtime gate blocked entrypoint '%1' (airbase_v1_runtime_enabled=false).", _entryPoint];
};

_enabled

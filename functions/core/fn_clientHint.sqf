/*
    Client: display a hint message.

    Params:
      0: STRING - message
      1: STRING - optional dedupe key
      2: NUMBER - optional cooldown seconds for repeated identical hints

    This exists because some server configs/mods restrict remoteExec of commands.
    Remoting a function is often more reliable than remoting the 'hint' command directly.
*/

if (!hasInterface) exitWith {false};

params [
    ["_txt", ""],
    ["_gateKey", ""],
    ["_gateCooldown", 0]
];

if (!(_txt isEqualType "")) then { _txt = str _txt; };
if (!(_gateKey isEqualType "")) then { _gateKey = str _gateKey; };
_gateKey = trim _gateKey;
if (!(_gateCooldown isEqualType 0)) then { _gateCooldown = 0; };
_gateCooldown = _gateCooldown max 0;

if (_gateKey != "" && { !([_gateKey, _gateCooldown, _txt] call ARC_fnc_clientNotifyGate) }) exitWith {false};

hint _txt;
true;

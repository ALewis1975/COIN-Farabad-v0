/*
    Client: display a hint message.

    Params:
      0: STRING - message

    This exists because some server configs/mods restrict remoteExec of commands.
    Remoting a function is often more reliable than remoting the 'hint' command directly.
*/

if (!hasInterface) exitWith {false};

params [["_txt", ""]];

if (!(_txt isEqualType "")) then { _txt = str _txt; };

hint _txt;
true;

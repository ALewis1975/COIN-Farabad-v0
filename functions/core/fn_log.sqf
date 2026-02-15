/*
    ARC_fnc_log

    Lightweight structured logger.

    Usage:
      ["SYS", "message"] call ARC_fnc_log;
      ["INCIDENT", "spawned X at %1", [_pos]] call ARC_fnc_log;
      ["SYS", "bad input", [], "WARN"] call ARC_fnc_log;

    Params:
      0: STRING - channel (e.g. "SYS", "INC", "NET")
      1: STRING - message or format string
      2: ARRAY  - optional format args (default [])
      3: STRING - optional level: "INFO" | "WARN" | "ERROR" | "DEBUG" (default "INFO")

    Controls:
      missionNamespace getVariable ["ARC_debugLogEnabled", false]
      missionNamespace getVariable ["ARC_debugLogToChat", false]  (client only)
*/

params [
    ["_chan", "ARC", [""]],
    ["_msg", "", [""]],
    ["_args", [], [[]]],
    ["_lvl", "INFO", [""]]
];

private _enabled = missionNamespace getVariable ["ARC_debugLogEnabled", false];

// Always log WARN/ERROR, even if debug is off.
private _force = (_lvl in ["WARN","ERROR"]);

if !(_enabled or _force) exitWith { false };

private _stamp = diag_tickTime;
private _text = if !(_msg isEqualType "") then { str _msg } else {
    if ((count _args) > 0) then { format ([_msg] + _args) } else { _msg }
};

// If caller passed args but message isn't a format string, above can throw.
// Guard: fall back to concatenation.
if (isNil "_text") then { _text = str _msg + " " + str _args; };

private _line = format ["[ARC][%1][%2][%3] %4", _chan, _lvl, _stamp, _text];
diag_log _line;

if (hasInterface && { missionNamespace getVariable ["ARC_debugLogToChat", false] }) then
{
    systemChat _line;
};

true

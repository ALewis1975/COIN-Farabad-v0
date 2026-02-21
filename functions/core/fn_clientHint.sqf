/*
    Client: centralized client notification wrapper.

    Params:
      New API:
        0: STRING - message
        1: STRING - severity level (INFO | WARN | ERROR | ACTION_REQUIRED)
        2: STRING - channel policy (AUTO | HINT | TOAST | CHAT | BOTH | NONE)
        3: STRING - optional dedupe key
        4: NUMBER - optional cooldown seconds for repeated identical notifications

      Legacy API (supported for backward compatibility):
        0: STRING - message
        1: STRING - optional dedupe key
        2: NUMBER - optional cooldown seconds

    This exists because some server configs/mods restrict remoteExec of commands.
    Remoting a function is often more reliable than remoting the 'hint' command directly.
*/

if (!hasInterface) exitWith {false};

// sqflint-compat helpers
private _trimFn     = compile "params ['_s']; trim _s";

private _knownLevels = ["INFO", "WARN", "ERROR", "ACTION_REQUIRED"];
private _knownChannels = ["AUTO", "HINT", "TOAST", "CHAT", "BOTH", "NONE"];

private _txt = _this param [0, ""];
private _arg1 = _this param [1, ""];
private _arg2 = _this param [2, ""];
private _arg3 = _this param [3, ""];
private _arg4 = _this param [4, 0];

private _level = "INFO";
private _channel = "AUTO";
private _gateKey = "";
private _gateCooldown = 0;

private _arg1Upper = if (_arg1 isEqualType "") then { toUpper ([_arg1] call _trimFn) } else { "" };
private _arg2Upper = if (_arg2 isEqualType "") then { toUpper ([_arg2] call _trimFn) } else { "" };
private _isNewApi = (_arg1Upper in _knownLevels) || (_arg2Upper in _knownChannels);

if (_isNewApi) then
{
    _level = if (_arg1Upper in _knownLevels) then { _arg1Upper } else { "INFO" };
    _channel = if (_arg2Upper in _knownChannels) then { _arg2Upper } else { "AUTO" };
    _gateKey = _arg3;
    _gateCooldown = _arg4;
}
else
{
    _gateKey = _arg1;
    _gateCooldown = _arg2;
};

if (!(_txt isEqualType "")) then { _txt = str _txt; };
if (!(_gateKey isEqualType "")) then { _gateKey = str _gateKey; };
_gateKey = [_gateKey] call _trimFn;
if (!(_gateCooldown isEqualType 0)) then { _gateCooldown = 0; };
_gateCooldown = _gateCooldown max 0;

if (_gateKey != "" && { !([_gateKey, _gateCooldown, _txt] call ARC_fnc_clientNotifyGate) }) exitWith {false};

if (_channel isEqualTo "AUTO") then
{
    _channel = switch (_level) do
    {
        case "ACTION_REQUIRED": { "HINT" };
        case "ERROR": { "BOTH" };
        case "WARN": { "TOAST" };
        default { "TOAST" };
    };
};

if (_channel isEqualTo "NONE") exitWith {true};

private _title = switch (_level) do
{
    case "WARN": { "Warning" };
    case "ERROR": { "Error" };
    case "ACTION_REQUIRED": { "Action Required" };
    default { "ARC" };
};

switch (_channel) do
{
    case "HINT": { hint _txt; };
    case "TOAST": { [_title, _txt] call ARC_fnc_clientToast; };
    case "CHAT": { systemChat format ["[ARC][%1] %2", _level, _txt]; };
    case "BOTH":
    {
        hint _txt;
        systemChat format ["[ARC][%1] %2", _level, _txt];
    };
    default { hint _txt; };
};

true;

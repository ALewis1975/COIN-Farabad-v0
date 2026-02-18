/*
    Saves ARC_state from missionNamespace into missionProfileNamespace.
    Call this periodically and on key events.
*/

if (!isServer) exitWith {false};

private _state = missionNamespace getVariable ["ARC_state", []];
missionProfileNamespace setVariable ["ARC_state", _state];

private _op = "stateSave";
private _criticalKeys = ["ARC_state"];
private _timestamp = systemTimeUTC;
private _saveOk = false;
private _errorPayload = "";

try
{
    _saveOk = saveMissionProfileNamespace;
}
catch
{
    _saveOk = false;
    _errorPayload = _exception;
};

if (!_saveOk) exitWith {
    if (_errorPayload isEqualTo "") then {
        _errorPayload = "saveMissionProfileNamespace returned false";
    };

    private _logMsg = format [
        "operation=%1 timestamp=%2 keys=%3 error=%4",
        _op,
        _timestamp,
        _criticalKeys,
        _errorPayload
    ];

    if (!isNil "ARC_fnc_log") then {
        ["SYS", _logMsg, [], "ERROR"] call ARC_fnc_log;
    } else {
        diag_log format ["[ARC][SYS][ERROR] %1", _logMsg];
    };

    false
};

if (!isNil "ARC_fnc_log") then {
    ["SYS", format ["operation=%1 timestamp=%2 keys=%3 result=success", _op, _timestamp, _criticalKeys], [], "DEBUG"] call ARC_fnc_log;
};

true

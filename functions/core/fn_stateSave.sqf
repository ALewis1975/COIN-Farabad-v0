/*
    Saves ARC_state from missionNamespace into missionProfileNamespace.
    Call this periodically and on key events.
*/

if (!isServer) exitWith {false};

private _state = missionNamespace getVariable ["ARC_state", []];
private _stateCheck = [_state, "ARRAY_SHAPE", "ARC_state", [[], 0, -1, true]] call ARC_fnc_paramAssert;
private _stateOk = _stateCheck param [0, false];
_state = _stateCheck param [1, []];
if (!_stateOk) then {
    ["STATE", format ["stateSave guard: code=%1 msg=%2", _stateCheck param [2, "ARC_ASSERT_UNKNOWN"], _stateCheck param [3, "ARC_state invalid"]], ["code", _stateCheck param [2, "ARC_ASSERT_UNKNOWN"], "guard", "stateSave", "key", "ARC_state"]] call ARC_fnc_farabadWarn;
};
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

/*
    ARC_fnc_mapClick_arm

    Client utility: arms one-shot map click using code-block onMapSingleClick style.

    Params:
      0: HASHMAP context

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

if (!canSuspend) exitWith { _this spawn ARC_fnc_mapClick_arm; true };

params [["_ctx", createHashMap]];
if !(_ctx isEqualType createHashMap) then { _ctx = createHashMap; };

private _state = uiNamespace getVariable ["ARC_mapClick_state", "IDLE"];
if (_state in ["ARMED", "CAPTURED"]) then
{
    ["REARM"] call ARC_fnc_mapClick_disarm;
};

private _debug = uiNamespace getVariable ["ARC_mapClick_debug", false];
private _armedAt = diag_tickTime;
private _timeout = _ctx getOrDefault ["timeoutSec", 45];
_timeout = (_timeout max 30) min 60;
private _deadline = _armedAt + _timeout;
private _type = toUpper (_ctx getOrDefault ["type", ""]);

diag_log format ["[FARABAD][MAPCLICK][ARM] type=%1 timeoutSec=%2", _type, _timeout];

uiNamespace setVariable ["ARC_mapClick_state", "ARMED"];
uiNamespace setVariable ["ARC_mapClick_ctx", _ctx];
uiNamespace setVariable ["ARC_mapClick_armedAt", _armedAt];
uiNamespace setVariable ["ARC_mapClick_deadline", _deadline];
uiNamespace setVariable ["ARC_mapClick_lastPos", nil];
uiNamespace setVariable ["ARC_mapClick_lastErr", ""];
uiNamespace setVariable ["ARC_mapClick_cleanupDone", false];
uiNamespace setVariable ["ARC_mapClick_debug", _debug];

onMapSingleClick
{
    _this call ARC_fnc_mapClick_onClick;
};

openMap [true, false];
waitUntil { uiSleep 0.05; visibleMap };

[_armedAt, _deadline] spawn
{
    params ["_token", "_expireAt"];

    waitUntil
    {
        uiSleep 0.05;

        private _stateNow = uiNamespace getVariable ["ARC_mapClick_state", "IDLE"];
        private _armedAtNow = uiNamespace getVariable ["ARC_mapClick_armedAt", nil];
        private _cleanupDone = uiNamespace getVariable ["ARC_mapClick_cleanupDone", true];

        _cleanupDone
        || {!(_armedAtNow isEqualTo _token)}
        || {(_stateNow != "ARMED")}
        || {!visibleMap}
        || {diag_tickTime >= _expireAt}
    };

    private _stateNow = uiNamespace getVariable ["ARC_mapClick_state", "IDLE"];
    private _armedAtNow = uiNamespace getVariable ["ARC_mapClick_armedAt", nil];
    private _cleanupDone = uiNamespace getVariable ["ARC_mapClick_cleanupDone", true];
    if (_cleanupDone || {!(_armedAtNow isEqualTo _token)} || {!(_stateNow isEqualTo "ARMED")}) exitWith {};

    if (diag_tickTime >= _expireAt) exitWith
    {
        diag_log "[FARABAD][MAPCLICK][TIMEOUT]";
        ["TIMEOUT"] call ARC_fnc_mapClick_disarm;
    };

    if (!visibleMap) then
    {
        ["CANCELLED"] call ARC_fnc_mapClick_disarm;
    };
};

true

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

if ((uiNamespace getVariable ["ARC_mapClick_state", "IDLE"]) isEqualTo "ARMED") then
{
    ["rearm"] call ARC_fnc_mapClick_disarm;
};

private _debug = uiNamespace getVariable ["ARC_mapClick_debug", false];
private _armedAt = diag_tickTime;

uiNamespace setVariable ["ARC_mapClick_state", "ARMED"];
uiNamespace setVariable ["ARC_mapClick_ctx", _ctx];
uiNamespace setVariable ["ARC_mapClick_armedAt", _armedAt];
uiNamespace setVariable ["ARC_mapClick_lastPos", nil];
uiNamespace setVariable ["ARC_mapClick_lastErr", ""];
uiNamespace setVariable ["ARC_mapClick_debug", _debug];

onMapSingleClick
{
    _this call ARC_fnc_mapClick_onClick;
};

openMap [true, false];
waitUntil { uiSleep 0.05; visibleMap };

[_armedAt] spawn
{
    params ["_token"];

    waitUntil
    {
        uiSleep 0.05;

        private _state = uiNamespace getVariable ["ARC_mapClick_state", "IDLE"];
        (_state != "ARMED") || {!visibleMap}
    };

    private _stateNow = uiNamespace getVariable ["ARC_mapClick_state", "IDLE"];
    private _armedAtNow = uiNamespace getVariable ["ARC_mapClick_armedAt", nil];
    if ((_stateNow isEqualTo "ARMED") && {!visibleMap} && {_armedAtNow isEqualTo _token}) then
    {
        hint "Map click canceled.";
        ["map_closed"] call ARC_fnc_mapClick_disarm;
    };
};

true

/*
    ARC_fnc_uiConsoleActionAirPrimary

    AIR primary action:
      - Control roles: HOLD/RELEASE departures (toggle)
      - Read-only roles: refresh paint only
*/

if (!hasInterface) exitWith {false};

private _disp = findDisplay 78000;
if (isNull _disp) exitWith {false};

private _canAirControl = ["ARC_console_airCanControl", false] call ARC_fnc_uiNsGetBool;
if (!_canAirControl) exitWith
{
    [_disp, false] call ARC_fnc_uiConsoleAirPaint;
    ["AIR", "Read-only snapshot refreshed."] call ARC_fnc_clientToast;
    true
};

private _hold = ["ARC_console_airHoldDepartures", false] call ARC_fnc_uiNsGetBool;
if (_hold) then
{
    [] call ARC_fnc_airbaseClientRequestReleaseDepartures;
    ["AIR", "Release request sent to tower control."] call ARC_fnc_clientToast;
}
else
{
    [] call ARC_fnc_airbaseClientRequestHoldDepartures;
    ["AIR", "Hold request sent to tower control."] call ARC_fnc_clientToast;
};

[_disp] call ARC_fnc_uiConsoleRefresh;
true

/*
    ARC_fnc_uiConsoleActionAirPrimary

    AIR primary action:
      - Control roles: HOLD/RELEASE departures (toggle)
      - Read-only roles: refresh paint only
*/

if (!hasInterface) exitWith {false};

private _disp = findDisplay 78000;
if (isNull _disp) exitWith {false};

private _canAirHoldRelease = ["ARC_console_airCanHoldRelease", false] call ARC_fnc_uiNsGetBool;
if (!_canAirHoldRelease) exitWith
{
    [_disp, false] call ARC_fnc_uiConsoleAirPaint;
    ["AIR", "No HOLD/RELEASE permission."] call ARC_fnc_clientToast;
    true
};

private _hold = ["ARC_console_airHoldDepartures", false] call ARC_fnc_uiNsGetBool;
private _requestAction = if (_hold) then {"RELEASE"} else {"HOLD"};
private _permAction = switch (_requestAction) do
{
    case "HOLD": {"Hold"};
    case "RELEASE": {"Release"};
    default {""};
};
private _canRequestAction = [format ["ARC_console_airCan%1", _permAction], false] call ARC_fnc_uiNsGetBool;
if (!_canRequestAction) exitWith
{
    [_disp, false] call ARC_fnc_uiConsoleAirPaint;
    ["AIR", format ["No %1 permission.", _requestAction]] call ARC_fnc_clientToast;
    true
};

if (_requestAction isEqualTo "RELEASE") then
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

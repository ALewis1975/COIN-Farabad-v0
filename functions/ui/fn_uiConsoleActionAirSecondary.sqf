/*
    ARC_fnc_uiConsoleActionAirSecondary

    AIR secondary action:
      - Control roles: Expedite selected queued flight (non-first) or cancel first queued flight.
      - Read-only roles: refresh details.
*/

if (!hasInterface) exitWith {false};

private _disp = findDisplay 78000;
if (isNull _disp) exitWith {false};

private _canAirQueueManage = ["ARC_console_airCanQueueManage", false] call ARC_fnc_uiNsGetBool;
if (!_canAirQueueManage) exitWith
{
    [_disp, false] call ARC_fnc_uiConsoleAirPaint;
    ["AIR", "No EXPEDITE/CANCEL permission."] call ARC_fnc_clientToast;
    true
};

private _ctrlList = _disp displayCtrl 78011;
if (isNull _ctrlList) exitWith {false};

private _sel = lbCurSel _ctrlList;
if (_sel < 0) exitWith { ["AIR", "Select a queued flight first."] call ARC_fnc_clientToast; false };

private _data = _ctrlList lbData _sel;
if (!(_data isEqualType "") || { (_data find "AIR_FID|") != 0 }) exitWith
{
    ["AIR", "Select a queue row (not summary)."] call ARC_fnc_clientToast;
    false
};

private _parts = _data splitString "|";
if ((count _parts) < 2) exitWith { ["AIR", "Invalid queue selection."] call ARC_fnc_clientToast; false };

private _fid = _parts select 1;
if (_fid isEqualTo "") exitWith { ["AIR", "Invalid queue selection."] call ARC_fnc_clientToast; false };

private _requestAction = if (_sel == 1) then {"CANCEL"} else {"PRIORITIZE"};
private _canRequestAction = [format ["ARC_console_airCan%1", _requestAction], false] call ARC_fnc_uiNsGetBool;
if (!_canRequestAction) exitWith
{
    [_disp, false] call ARC_fnc_uiConsoleAirPaint;
    ["AIR", format ["No %1 permission for selected queue action.", _requestAction]] call ARC_fnc_clientToast;
    true
};

if (_requestAction isEqualTo "CANCEL") then
{
    [_fid] call ARC_fnc_airbaseClientRequestCancelQueuedFlight;
    ["AIR", format ["Cancel request sent: %1", _fid]] call ARC_fnc_clientToast;
}
else
{
    [_fid] call ARC_fnc_airbaseClientRequestPrioritizeFlight;
    ["AIR", format ["Expedite request sent: %1", _fid]] call ARC_fnc_clientToast;
};

[_disp] call ARC_fnc_uiConsoleRefresh;
true

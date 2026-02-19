/*
    ARC_fnc_uiConsoleActionAirPrimary

    AIR primary action (row-aware):
      - REQ row: APPROVE selected clearance request
      - FLT row: EXPEDITE selected queued flight
      - Other rows: global HOLD departures
*/

if (!hasInterface) exitWith {false};

private _disp = findDisplay 78000;
if (isNull _disp) exitWith {false};

private _ctrlList = _disp displayCtrl 78011;
if (isNull _ctrlList) exitWith {false};

private _sel = lbCurSel _ctrlList;
private _data = if (_sel >= 0) then { _ctrlList lbData _sel } else { "" };
if (!(_data isEqualType "")) then { _data = ""; };
private _parts = _data splitString "|";
private _rowType = if ((count _parts) > 0) then { _parts select 0 } else { "" };

switch (_rowType) do
{
    case "REQ":
    {
        private _rid = _parts param [1, ""];
        if (_rid isEqualTo "" || { _rid isEqualTo "NONE" }) exitWith {
            ["AIR", "Select a pending clearance request first."] call ARC_fnc_clientToast;
            false
        };

        private _canAirQueueManage = ["ARC_console_airCanQueueManage", false] call ARC_fnc_uiNsGetBool;
        if (!_canAirQueueManage) exitWith
        {
            [_disp, false] call ARC_fnc_uiConsoleAirPaint;
            ["AIR", "No queue authorization for clearance approvals."] call ARC_fnc_clientToast;
            true
        };

        [_rid, true, "UI_PRIMARY_APPROVE"] call ARC_fnc_airbaseClientRequestClearanceDecision;
        ["AIR", format ["Approve request sent: %1", _rid]] call ARC_fnc_clientToast;
    };

    case "LANE":
    {
        private _lane = _parts param [1, ""];
        if (_lane isEqualTo "") exitWith {
            ["AIR", "Select an ATC lane first."] call ARC_fnc_clientToast;
            false
        };

        private _canAirStaff = ["ARC_console_airCanStaff", false] call ARC_fnc_uiNsGetBool;
        if (!_canAirStaff) exitWith
        {
            [_disp, false] call ARC_fnc_uiConsoleAirPaint;
            ["AIR", "No permission to claim lane staffing."] call ARC_fnc_clientToast;
            true
        };

        [_lane, true] call ARC_fnc_airbaseClientRequestSetLaneStaffing;
        ["AIR", format ["Claim request sent for %1 lane.", toUpperANSI _lane]] call ARC_fnc_clientToast;
    };

    case "FLT":
    {
        private _fid = _parts param [1, ""];
        if (_fid isEqualTo "" || { _fid isEqualTo "NONE" }) exitWith {
            ["AIR", "Select a queued flight first."] call ARC_fnc_clientToast;
            false
        };

        private _canAirQueueManage = ["ARC_console_airCanQueueManage", false] call ARC_fnc_uiNsGetBool;
        private _canPrioritize = ["ARC_console_airCanPrioritize", false] call ARC_fnc_uiNsGetBool;
        if (!_canAirQueueManage || !_canPrioritize) exitWith
        {
            [_disp, false] call ARC_fnc_uiConsoleAirPaint;
            ["AIR", "No permission to expedite queued flights."] call ARC_fnc_clientToast;
            true
        };

        [_fid] call ARC_fnc_airbaseClientRequestPrioritizeFlight;
        ["AIR", format ["Expedite request sent: %1", _fid]] call ARC_fnc_clientToast;
    };

    default
    {
        private _canAirHoldRelease = ["ARC_console_airCanHoldRelease", false] call ARC_fnc_uiNsGetBool;
        if (!_canAirHoldRelease) exitWith
        {
            [_disp, false] call ARC_fnc_uiConsoleAirPaint;
            ["AIR", "No HOLD permission."] call ARC_fnc_clientToast;
            true
        };

        private _canHold = ["ARC_console_airCanHold", false] call ARC_fnc_uiNsGetBool;
        if (!_canHold) exitWith
        {
            [_disp, false] call ARC_fnc_uiConsoleAirPaint;
            ["AIR", "No HOLD permission."] call ARC_fnc_clientToast;
            true
        };

        [] call ARC_fnc_airbaseClientRequestHoldDepartures;
        ["AIR", "Hold request sent to tower control."] call ARC_fnc_clientToast;
    };
};

[_disp] call ARC_fnc_uiConsoleRefresh;
true

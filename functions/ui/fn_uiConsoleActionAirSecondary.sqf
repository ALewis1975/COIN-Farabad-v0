/*
    ARC_fnc_uiConsoleActionAirSecondary

    AIR secondary action.
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
private _rowType = toUpper (_parts param [0, ""]);

private _debugAir = missionNamespace getVariable ["ARC_debugInspectorEnabled", false];
if (!(_debugAir isEqualType true) && !(_debugAir isEqualType false)) then { _debugAir = false; };

private _cycleModes = {
    params ["_current", "_canControl", "_debugEnabled"];
    private _modes = ["AIRFIELD_OPS"];
    if (_canControl) then { _modes pushBack "CLEARANCES"; };
    if (_debugEnabled) then { _modes pushBack "DEBUG"; };
    private _idx = _modes find _current;
    if (_idx < 0) exitWith { _modes select 0 };
    _modes select ((_idx + 1) mod (count _modes))
};

private _airMode = ["ARC_console_airMode", "TOWER"] call ARC_fnc_uiNsGetString;
_airMode = toUpper _airMode;
_airMode = (_airMode splitString " ") joinString "";
if (_airMode isEqualTo "PILOT") exitWith {
    private _canAirControl = ["ARC_console_airCanControl", false] call ARC_fnc_uiNsGetBool;
    if (_canAirControl) then {
        uiNamespace setVariable ["ARC_console_airMode", "TOWER"];
        uiNamespace setVariable ["ARC_console_airSubmode", "AIRFIELD_OPS"];
        ["AIR", "Switched AIR mode to TOWER."] call ARC_fnc_clientToast;
    } else {
        ["AIR", "Pilot submode refreshed."] call ARC_fnc_clientToast;
    };
    [_disp] call ARC_fnc_uiConsoleRefresh;
    true
};

private _canAirControl = ["ARC_console_airCanControl", false] call ARC_fnc_uiNsGetBool;
private _airSubmode = ["ARC_console_airSubmode", "AIRFIELD_OPS"] call ARC_fnc_uiNsGetString;
_airSubmode = toUpper _airSubmode;
_airSubmode = (_airSubmode splitString " ") joinString "";
if !(_airSubmode in ["AIRFIELD_OPS", "CLEARANCES", "DEBUG"]) then { _airSubmode = "AIRFIELD_OPS"; };

switch (_airSubmode) do
{
    case "CLEARANCES":
    {
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
                    ["AIR", "READ-ONLY: no queue authorization for denials."] call ARC_fnc_clientToast;
                    true
                };

                [_rid, false, "UI_SECONDARY_DENY"] call ARC_fnc_airbaseClientRequestClearanceDecision;
                ["AIR", format ["Deny request sent: %1", _rid]] call ARC_fnc_clientToast;
            };

            case "FLT":
            {
                private _fid = _parts param [1, ""];
                if (_fid isEqualTo "" || { _fid isEqualTo "NONE" }) exitWith {
                    ["AIR", "Select a queued flight first."] call ARC_fnc_clientToast;
                    false
                };

                private _canAirQueueManage = ["ARC_console_airCanQueueManage", false] call ARC_fnc_uiNsGetBool;
                private _canCancel = ["ARC_console_airCanCancel", false] call ARC_fnc_uiNsGetBool;
                if (!_canAirQueueManage || !_canCancel) exitWith
                {
                    ["AIR", "READ-ONLY: no permission to cancel queued flights."] call ARC_fnc_clientToast;
                    true
                };

                [_fid] call ARC_fnc_airbaseClientRequestCancelQueuedFlight;
                ["AIR", format ["Cancel request sent: %1", _fid]] call ARC_fnc_clientToast;
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
                    ["AIR", "READ-ONLY: no permission to release lane staffing."] call ARC_fnc_clientToast;
                    true
                };

                [_lane, false] call ARC_fnc_airbaseClientRequestSetLaneStaffing;
                ["AIR", format ["Release request sent for %1 lane.", toUpper _lane]] call ARC_fnc_clientToast;
            };

            default
            {
                // Phase 3 safety: non-action rows cycle submode (no queue/airfield action).
                private _nextMode = [_airSubmode, _canAirControl, _debugAir] call _cycleModes;
                uiNamespace setVariable ["ARC_console_airSubmode", _nextMode];
                ["AIR", format ["Switched AIR view to %1.", _nextMode]] call ARC_fnc_clientToast;
            };
        };
    };

    case "DEBUG":
    {
        private _nextMode = [_airSubmode, _canAirControl, _debugAir] call _cycleModes;
        uiNamespace setVariable ["ARC_console_airSubmode", _nextMode];
        ["AIR", format ["Switched AIR view to %1.", _nextMode]] call ARC_fnc_clientToast;
    };

    default
    {
        private _nextMode = [_airSubmode, _canAirControl, _debugAir] call _cycleModes;
        if (_nextMode isEqualTo _airSubmode) then {
            ["AIR", "AIRFIELD OPS refreshed."] call ARC_fnc_clientToast;
        } else {
            uiNamespace setVariable ["ARC_console_airSubmode", _nextMode];
            ["AIR", format ["Switched AIR view to %1.", _nextMode]] call ARC_fnc_clientToast;
        };
    };
};

[_disp] call ARC_fnc_uiConsoleRefresh;
true

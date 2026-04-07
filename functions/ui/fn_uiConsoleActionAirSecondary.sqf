/*
    ARC_fnc_uiConsoleActionAirSecondary

    AIR secondary action.
    Phase 4: destructive actions (DENY, CANCEL flight) require double-press confirmation.
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

                // Phase 4: confirm destructive DENY action
                private _pending = uiNamespace getVariable ["ARC_console_airConfirmPending", ""];
                if (!(_pending isEqualType "")) then { _pending = ""; };
                private _pendingRid = uiNamespace getVariable ["ARC_console_airConfirmRid", ""];
                if (!(_pendingRid isEqualType "")) then { _pendingRid = ""; };
                if (_pending isEqualTo "DENY" && { _pendingRid isEqualTo _rid }) then {
                    uiNamespace setVariable ["ARC_console_airConfirmPending", ""];
                    uiNamespace setVariable ["ARC_console_airConfirmRid", ""];
                    uiNamespace setVariable ["ARC_console_airConfirmLabel", ""];
                    [_rid, false, "UI_SECONDARY_DENY"] call ARC_fnc_airbaseClientRequestClearanceDecision;
                    ["AIR", format ["DENY confirmed: %1", _rid]] call ARC_fnc_clientToast;
                } else {
                    uiNamespace setVariable ["ARC_console_airConfirmPending", "DENY"];
                    uiNamespace setVariable ["ARC_console_airConfirmRid", _rid];
                    uiNamespace setVariable ["ARC_console_airConfirmLabel", format ["Press again or ENTER to DENY %1.", _rid]];
                    ["AIR", format ["Press again or ENTER to DENY %1.", _rid]] call ARC_fnc_clientToast;
                };
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

                // Phase 4: confirm destructive CANCEL FLIGHT action
                private _pending = uiNamespace getVariable ["ARC_console_airConfirmPending", ""];
                if (!(_pending isEqualType "")) then { _pending = ""; };
                private _pendingFid = uiNamespace getVariable ["ARC_console_airConfirmFid", ""];
                if (!(_pendingFid isEqualType "")) then { _pendingFid = ""; };
                if (_pending isEqualTo "CANCEL_FLIGHT" && { _pendingFid isEqualTo _fid }) then {
                    uiNamespace setVariable ["ARC_console_airConfirmPending", ""];
                    uiNamespace setVariable ["ARC_console_airConfirmFid", ""];
                    uiNamespace setVariable ["ARC_console_airConfirmLabel", ""];
                    [_fid] call ARC_fnc_airbaseClientRequestCancelQueuedFlight;
                    ["AIR", format ["CANCEL confirmed: %1", _fid]] call ARC_fnc_clientToast;
                } else {
                    uiNamespace setVariable ["ARC_console_airConfirmPending", "CANCEL_FLIGHT"];
                    uiNamespace setVariable ["ARC_console_airConfirmFid", _fid];
                    uiNamespace setVariable ["ARC_console_airConfirmLabel", format ["Press again or ENTER to CANCEL %1.", _fid]];
                    ["AIR", format ["Press again or ENTER to CANCEL flight %1.", _fid]] call ARC_fnc_clientToast;
                };
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

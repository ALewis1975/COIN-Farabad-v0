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

private _casreqSnapshot = uiNamespace getVariable ["ARC_console_casreqSnapshot", []];
if !(_casreqSnapshot isEqualType []) then { _casreqSnapshot = []; };
private _casreqId = uiNamespace getVariable ["ARC_console_casreqId", ""];
if !(_casreqId isEqualType "") then { _casreqId = ""; };
// AIR actions consume only server-published CASREQ snapshot contract.

private _airMode = ["ARC_console_airMode", "TOWER"] call ARC_fnc_uiNsGetString;
_airMode = toUpper _airMode;
_airMode = (_airMode splitString " ") joinString "";

if (_airMode isEqualTo "PILOT") exitWith {
    private _canAirPilot = ["ARC_console_airCanPilot", false] call ARC_fnc_uiNsGetBool;
    if (!_canAirPilot) then {
        ["AIR", "Pilot submode is not authorized for your callsign."] call ARC_fnc_clientToast;
        [_disp] call ARC_fnc_uiConsoleRefresh;
        false
    } else {
        private _requestType = switch (_rowType) do {
            case "PACT": { _parts param [1, ""] };
            default { "" };
        };

        if (_requestType isEqualTo "") then {
            ["AIR", "Select a pilot action first."] call ARC_fnc_clientToast;
        } else {
            if (_requestType isEqualTo "CANCEL") then {
                private _pub = missionNamespace getVariable ["ARC_pub_state", []];
                private _air = [_pub, "airbase", []] call {
                    params ["_pairs", "_k", "_def"]; private _v=_def; { if (_x isEqualType [] && {(count _x)>=2} && {(_x#0) isEqualTo _k}) exitWith {_v=_x#1}; } forEach _pairs; _v
                };
                private _pending = [_air, "clearancePending", []] call {
                    params ["_pairs", "_k", "_def"]; private _v=_def; { if (_x isEqualType [] && {(count _x)>=2} && {(_x#0) isEqualTo _k}) exitWith {_v=_x#1}; } forEach _pairs; _v
                };
                private _uid = getPlayerUID player;
                private _rid = "";
                {
                    if (!(_x isEqualType [])) then { continue; };
                    private _meta = _x param [9, []];
                    private _pilotUid = "";
                    { if (_x isEqualType [] && {(count _x)>=2} && {(_x#0) isEqualTo "pilotUid"}) exitWith { _pilotUid = _x#1; }; } forEach _meta;
                    if (_pilotUid isEqualTo _uid) exitWith { _rid = _x param [0, ""]; };
                } forEach _pending;

                if (_rid isEqualTo "") then {
                    ["AIR", "No pending pilot request to cancel."] call ARC_fnc_clientToast;
                } else {
                    [_rid] call ARC_fnc_airbaseClientCancelClearanceRequest;
                    ["AIR", format ["Cancel request sent: %1", _rid]] call ARC_fnc_clientToast;
                };
            } else {
                private _veh = vehicle player;
                if (isNull _veh || {_veh isEqualTo player}) then {
                    ["AIR", "Pilot actions require being in an aircraft."] call ARC_fnc_clientToast;
                } else {
                    [_requestType, _veh, if (_requestType isEqualTo "REQ_EMERGENCY") then {100} else {20}, "PLAYER", "", "", ""] call ARC_fnc_airbaseClientSubmitClearanceRequest;
                    ["AIR", format ["Request queued: %1", _requestType]] call ARC_fnc_clientToast;
                };
            };
        };

        [_disp] call ARC_fnc_uiConsoleRefresh;
        true
    };
};

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
        ["AIR", format ["Claim request sent for %1 lane.", toUpper _lane]] call ARC_fnc_clientToast;
    };

    case "FLT":
    {
        private _fid = _parts param [1, ""];
        if (_fid isEqualTo "" || { _fid isEqualTo "NONE" }) exitWith {
            ["AIR", "Select a queued flight first."] call ARC_fnc_clientToast;
            false
        };

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
        ["AIR", format ["Hold request sent to tower control. CASREQ=%1", if (_casreqId isEqualTo "") then {"-"} else {_casreqId}]] call ARC_fnc_clientToast;
    };
};

[_disp] call ARC_fnc_uiConsoleRefresh;
true

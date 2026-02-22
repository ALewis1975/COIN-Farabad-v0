/*
    File: functions/ambiance/fn_airbaseRunwayLockReserve.sqf
    Author: ARC / Ambient Airbase Subsystem
    Description:
      Attempts to reserve the runway for a specific flight/request.
*/

if (!isServer) exitWith { false };

params [
    ["_fid", ""],
    ["_kind", ""],
    ["_detail", ""],
    ["_reserveS", 120],
    ["_reason", "APPROVAL"]
];

if (_fid isEqualTo "") exitWith { false };
if (!(_reserveS isEqualType 0) || { _reserveS < 1 }) then { _reserveS = 120; };

["reserve", false] call ARC_fnc_airbaseRunwayLockSweep;

private _state = missionNamespace getVariable ["airbase_v1_runwayState", "OPEN"];
if (!(_state isEqualType "") || !(_state in ["OPEN", "RESERVED", "OCCUPIED"])) then { _state = "OPEN"; };
private _owner = missionNamespace getVariable ["airbase_v1_runwayOwner", ""];
if (!(_owner isEqualType "")) then { _owner = ""; };

if (!((_state isEqualTo "OPEN") || { (_state isEqualTo "RESERVED") && { _owner isEqualTo _fid } })) exitWith {
    private _opsDeny = missionNamespace getVariable ["airbase_v1_opsLogEnabled", true];
    if (!(_opsDeny isEqualType true) && !(_opsDeny isEqualType false)) then { _opsDeny = true; };
    private _dbgOpsDeny = missionNamespace getVariable ["airbase_v1_debugOpsLog", false];
    if (_opsDeny || _dbgOpsDeny) then {
        private _rtDeny = missionNamespace getVariable ["airbase_v1_rt", createHashMap];
        private _centerDeny = _rtDeny get "bubbleCenter";
        if (isNil "_centerDeny") then { _centerDeny = getMarkerPos "mkr_airbaseCenter"; };

        ["OPS", format ["AIRBASE RUNWAY: reserve denied for %1 (%2 %3)", _fid, _kind, _detail], _centerDeny, 0, [
            ["reason", "LOCKED"],
            ["state", _state],
            ["owner", _owner]
        ]] call ARC_fnc_intelLog;
    };
    false
};

private _prevState = _state;
private _until = serverTime + _reserveS;
missionNamespace setVariable ["airbase_v1_runwayState", "RESERVED", true];
missionNamespace setVariable ["airbase_v1_runwayOwner", _fid, true];
missionNamespace setVariable ["airbase_v1_runwayUntil", _until, true];

private _ops = missionNamespace getVariable ["airbase_v1_opsLogEnabled", true];
if (!(_ops isEqualType true) && !(_ops isEqualType false)) then { _ops = true; };
private _dbgOps = missionNamespace getVariable ["airbase_v1_debugOpsLog", false];
if (_ops || _dbgOps) then {
    private _rt = missionNamespace getVariable ["airbase_v1_rt", createHashMap];
    private _center = _rt get "bubbleCenter";
    if (isNil "_center") then { _center = getMarkerPos "mkr_airbaseCenter"; };

    ["OPS", format ["AIRBASE RUNWAY: %1 -> RESERVED (%2 %3 %4)", _prevState, _fid, _kind, _detail], _center, 0, [
        ["flightId", _fid],
        ["kind", _kind],
        ["detail", _detail],
        ["owner", _fid],
        ["until", _until],
        ["reason", _reason]
    ]] call ARC_fnc_intelLog;
};

true

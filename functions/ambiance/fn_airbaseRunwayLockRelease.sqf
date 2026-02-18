/*
    File: functions/ambiance/fn_airbaseRunwayLockRelease.sqf
    Author: ARC / Ambient Airbase Subsystem
    Description:
      Releases runway lock ownership to OPEN state.
*/

if (!isServer) exitWith { false };

params [
    ["_fid", ""],
    ["_kind", ""],
    ["_detail", ""],
    ["_result", ""],
    ["_force", false],
    ["_reason", "COMPLETE"]
];

["release", false] call ARC_fnc_airbaseRunwayLockSweep;

private _state = missionNamespace getVariable ["airbase_v1_runwayState", "OPEN"];
if (!(_state isEqualType "") || !(_state in ["OPEN", "RESERVED", "OCCUPIED"])) then { _state = "OPEN"; };
private _owner = missionNamespace getVariable ["airbase_v1_runwayOwner", ""];
if (!(_owner isEqualType "")) then { _owner = ""; };
private _until = missionNamespace getVariable ["airbase_v1_runwayUntil", -1];
if (!(_until isEqualType 0)) then { _until = -1; };

if (!(_force || (_owner isEqualTo _fid) || (_owner isEqualTo ""))) exitWith {
    private _opsDeny = missionNamespace getVariable ["airbase_v1_opsLogEnabled", true];
    if (!(_opsDeny isEqualType true) && !(_opsDeny isEqualType false)) then { _opsDeny = true; };
    private _dbgOpsDeny = missionNamespace getVariable ["airbase_v1_debugOpsLog", false];
    if (_opsDeny || _dbgOpsDeny) then {
        private _rtDeny = missionNamespace getVariable ["airbase_v1_rt", createHashMap];
        private _centerDeny = _rtDeny get "bubbleCenter";
        if (isNil "_centerDeny") then { _centerDeny = getMarkerPos "mkr_airbaseCenter"; };

        ["OPS", format ["AIRBASE RUNWAY: release denied for %1 (owner=%2)", _fid, _owner], _centerDeny, 0, [
            ["kind", _kind],
            ["detail", _detail],
            ["result", _result],
            ["reason", "OWNER_MISMATCH"]
        ]] call ARC_fnc_intelLog;
    };
    false
};

missionNamespace setVariable ["airbase_v1_runwayState", "OPEN", true];
missionNamespace setVariable ["airbase_v1_runwayOwner", "", true];
missionNamespace setVariable ["airbase_v1_runwayUntil", -1, true];

private _ops = missionNamespace getVariable ["airbase_v1_opsLogEnabled", true];
if (!(_ops isEqualType true) && !(_ops isEqualType false)) then { _ops = true; };
private _dbgOps = missionNamespace getVariable ["airbase_v1_debugOpsLog", false];
if (_ops || _dbgOps) then {
    private _rt = missionNamespace getVariable ["airbase_v1_rt", createHashMap];
    private _center = _rt get "bubbleCenter";
    if (isNil "_center") then { _center = getMarkerPos "mkr_airbaseCenter"; };

    ["OPS", format ["AIRBASE RUNWAY: %1 -> OPEN (%2 result=%3)", _state, _fid, _result], _center, 0, [
        ["flightId", _fid],
        ["kind", _kind],
        ["detail", _detail],
        ["result", _result],
        ["reason", _reason],
        ["previousOwner", _owner],
        ["previousUntil", _until]
    ]] call ARC_fnc_intelLog;
};

true

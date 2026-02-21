/*
    File: functions/ambiance/fn_airbaseRunwayLockSweep.sqf
    Author: ARC / Ambient Airbase Subsystem
    Description:
      Fail-safe runway lock cleanup. Clears stale/invalid lock states so the runway cannot remain stuck.
*/

if (!isServer) exitWith { false };

params [
    ["_ctx", "tick"],
    ["_force", false]
];

// sqflint-compat helpers
private _mapGet   = compile "params ['_h','_k']; _h get _k";

private _state = missionNamespace getVariable ["airbase_v1_runwayState", "OPEN"];
if (!(_state isEqualType "") || !(_state in ["OPEN", "RESERVED", "OCCUPIED"])) then {
    _state = "OPEN";
};

private _owner = missionNamespace getVariable ["airbase_v1_runwayOwner", ""];
if (!(_owner isEqualType "")) then { _owner = ""; };

private _until = missionNamespace getVariable ["airbase_v1_runwayUntil", -1];
if (!(_until isEqualType 0)) then { _until = -1; };

private _nowTs = serverTime;
private _changed = false;
private _why = "";

private _timedOut = (_until >= 0) && { _nowTs >= _until };
private _missingOwner = (_state in ["RESERVED", "OCCUPIED"]) && { _owner isEqualTo "" };
private _orphanedExec = (_state isEqualTo "OCCUPIED") && { !(missionNamespace getVariable ["airbase_v1_execActive", false]) };

if (_force || _timedOut || _missingOwner || _orphanedExec) then {
    _changed = true;

    if (_force) then {
        _why = "FORCED";
    } else {
        if (_timedOut) then {
            _why = "TIMEOUT";
        } else {
            if (_missingOwner) then {
                _why = "MISSING_OWNER";
            } else {
                if (_orphanedExec) then {
                    _why = "ORPHANED_EXEC";
                };
            };
        };
    };

    missionNamespace setVariable ["airbase_v1_runwayState", "OPEN", true];
    missionNamespace setVariable ["airbase_v1_runwayOwner", "", true];
    missionNamespace setVariable ["airbase_v1_runwayUntil", -1, true];

    private _ops = missionNamespace getVariable ["airbase_v1_opsLogEnabled", true];
    if (!(_ops isEqualType true) && !(_ops isEqualType false)) then { _ops = true; };
    private _dbgOps = missionNamespace getVariable ["airbase_v1_debugOpsLog", false];
    if (_ops || _dbgOps) then {
        private _rt = missionNamespace getVariable ["airbase_v1_rt", createHashMap];
        private _center = [_rt, "bubbleCenter"] call _mapGet;
        if (isNil "_center") then { _center = getMarkerPos "mkr_airbaseCenter"; };

        ["OPS", format ["AIRBASE RUNWAY: %1 -> OPEN (cleanup %2)", _state, _why], _center, 0, [
            ["context", _ctx],
            ["reason", _why],
            ["previousOwner", _owner],
            ["previousUntil", _until],
            ["now", _nowTs]
        ]] call ARC_fnc_intelLog;
    };
};

_changed

/*
    dev\ARC_selfTest.sqf  (solo-friendly integration checks)

    Run from debug console:
      [] execVM "dev\ARC_selfTest.sqf";                 // quick checks only
      [true] execVM "dev\ARC_selfTest.sqf";             // includes a create->close incident cycle (if safe)

    This script ALWAYS writes to RPT via diag_log with prefix [ARC][DEV],
    regardless of ARC_debugLogEnabled.
*/

params [["_fullCycle", false, [false]]];

private _log = {
    params [["_chan","DEV"], ["_msg",""], ["_args",[]], ["_lvl","INFO"]];
    private _text = _msg;
    if (_args isEqualType [] && {count _args > 0}) then { _text = format ([_msg] + _args); };
    diag_log format ["[ARC][DEV][%1][%2] %3", _chan, _lvl, _text];
};

["SYS","SELFTEST start (full=%1)",[_fullCycle],"INFO"] call _log;
["SYS","Context: isServer=%1 hasInterface=%2 isMultiplayer=%3", [isServer, hasInterface, isMultiplayer], "INFO"] call _log;

// Wait for readiness if present (avoid racing snapshots)
private _t0 = diag_tickTime;
private _hasReady = !isNil { missionNamespace getVariable "ARC_serverReady" };
if (_hasReady) then
{
    waitUntil { missionNamespace getVariable ["ARC_serverReady", false] };
    ["SYS","ARC_serverReady after %1s", [diag_tickTime - _t0], "INFO"] call _log;
}
else
{
    ["SYS","ARC_serverReady var not present; continuing.",[], "WARN"] call _log;
};

// Check state container
private _state = missionNamespace getVariable ["ARC_state", []];
if !(_state isEqualType []) then
{
    ["SYS","FAIL: ARC_state wrong type: %1", [typeName _state], "ERROR"] call _log;
}
else
{
    ["SYS","ARC_state entries=%1", [count _state], "INFO"] call _log;
};

// Check critical functions exist
private _needFns = [
    "ARC_fnc_stateGet",
    "ARC_fnc_stateSet",
    "ARC_fnc_publicBroadcastState",
    "ARC_fnc_incidentCreate",
    "ARC_fnc_incidentClose",
    "ARC_fnc_briefingUpdateClient"
];
{
    if (isNil _x) then
    {
        ["SYS","FAIL: missing function %1",[_x],"ERROR"] call _log;
    };
} forEach _needFns;

// Snapshot publish test (server-side)
if (isServer) then
{
    [] call ARC_fnc_publicBroadcastState;
    private _upd = missionNamespace getVariable ["ARC_pub_stateUpdatedAt", -1];
    private _pub = missionNamespace getVariable ["ARC_pub_state", []];

    if !(_upd isEqualType 0) then
    {
        ["SYS","FAIL: ARC_pub_stateUpdatedAt missing/wrong type (%1)", [typeName _upd], "ERROR"] call _log;
    }
    else
    {
        ["SYS","Snapshot publish OK (updatedAt=%1, pubPairs=%2)", [_upd, count _pub], "INFO"] call _log;
    };
}
else
{
    ["SYS","Not server: skipping snapshot publish test (run from host/SP).",[], "WARN"] call _log;
};

// Client refresh test (safe)
if (hasInterface) then
{
    [] call ARC_fnc_briefingUpdateClient;
    ["UI","Called ARC_fnc_briefingUpdateClient (no error)", [], "INFO"] call _log;
};

sleep 0.25;

// Optional incident create->close cycle (server-only)
if (_fullCycle) then
{
    if (!isServer) then
    {
        ["INC","Full cycle requested but not server. Run in SP/hosted.",[], "WARN"] call _log;
    }
    else
    {
        private _active = ["activeTaskId",""] call ARC_fnc_stateGet;
        if (_active isNotEqualTo "") then
        {
            ["INC","SKIP: active incident exists (%1). Not clobbering.",[_active],"WARN"] call _log;
        }
        else
        {
            private _okCreate = [] call ARC_fnc_incidentCreate;
            if (!_okCreate) then
            {
                ["INC","FAIL: ARC_fnc_incidentCreate returned false",[], "ERROR"] call _log;
            }
            else
            {
                private _tid = ["activeTaskId",""] call ARC_fnc_stateGet;
                ["INC","Created incident ok (id=%1)",[_tid],"INFO"] call _log;

                sleep 1;

                private _okClose = ["SUCCEEDED"] call ARC_fnc_incidentClose;
                if (!_okClose) then
                {
                    ["INC","FAIL: ARC_fnc_incidentClose returned false",[], "ERROR"] call _log;
                }
                else
                {
                    sleep 0.5;
                    private _after = ["activeTaskId",""] call ARC_fnc_stateGet;
                    if (_after isNotEqualTo "") then
                    {
                        ["INC","FAIL: activeTaskId still set after close (%1)",[_after],"ERROR"] call _log;
                    }
                    else
                    {
                        ["INC","Close ok; activeTaskId cleared",[], "INFO"] call _log;
                    };
                };
            };
        };
    };
};

["SYS","SELFTEST end",[], "INFO"] call _log;

if (hasInterface) then
{
    hintSilent "ARC self-test completed. Check RPT for [ARC][DEV] lines.";
};

true

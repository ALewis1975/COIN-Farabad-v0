/*
    ARC_fnc_uiConsoleTestRunServer

    Server-side ARC test-suite runner for the Farabad Console.
    execVMs tests\run_all.sqf on the server, waits for completion, and routes
    a PASS/FAIL summary back to the requesting client for display in the
    Headquarters tab (mirrors ARC_fnc_uiConsoleQAAuditServer's RPC pattern).

    Called from client via HQ tab -> Execute (ADMIN_RUN_TESTS).

    Params:
      0: requester (OBJECT) - used to route the report back to the correct client
*/

if (!isServer) exitWith { false };

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\core\fn_rpcValidateSender.sqf"; };

params [
    ["_requester", objNull, [objNull]]
];

private _owner = 0;
if (!isNull _requester) then { _owner = owner _requester; };
if (_owner <= 0 && { !isNil "remoteExecutedOwner" }) then { _owner = remoteExecutedOwner; };

// S1 + S3: sender validation and HQ role gate (test runner is approver-only).
if (!isNil "remoteExecutedOwner" && { _owner > 0 }) then
{
    private _requestor = _requester;
    if (isNull _requestor) then
    {
        { if (owner _x == _owner) exitWith { _requestor = _x; }; } forEach allPlayers;
    };
    private _reoOwner = if (!isNil "remoteExecutedOwner") then { remoteExecutedOwner } else { -1 };
    if (!([_requestor, "ARC_fnc_uiConsoleTestRunServer", "Test run denied: sender verification failed.", "TEST_RUN_SECURITY_DENIED", true, _reoOwner] call ARC_fnc_rpcValidateSender)) exitWith {false};
    private _isOmni = [_requestor, "OMNI"] call ARC_fnc_rolesHasGroupIdToken;
    private _can = _isOmni || { [_requestor] call ARC_fnc_rolesCanApproveQueue };
    if (!_can) exitWith {
        diag_log format ["[ARC][SEC] ARC_fnc_uiConsoleTestRunServer: unauthorized caller owner=%1", _owner];
        if (_owner > 0) then {
            ["<t size='1.05' font='PuristaMedium'>ARC Test Suite</t><br/><br/><t color='#F87171'>Denied: approver/OMNI only.</t>"] remoteExec ["ARC_fnc_uiConsoleTestRunClientReceive", _owner];
        };
        false
    };
};

private _runInProgress = missionNamespace getVariable ["ARC_testRun_inProgress", false];
if (!(_runInProgress isEqualType true)) then { _runInProgress = false; };
if (_runInProgress) exitWith {
    diag_log "[ARC][TEST] Run rejected (in progress).";
    if (_owner > 0) then
    {
        ["<t size='1.05' font='PuristaMedium'>ARC Test Suite</t><br/><br/><t color='#F87171'>Run rejected: another test run is already in progress.</t>"]
            remoteExec ["ARC_fnc_uiConsoleTestRunClientReceive", _owner];
    };
    false
};

// Debounce: the test suite is heavy and mutates/restores state — reject
// re-invocations within 60 seconds of the last run start.
private _lastRun = missionNamespace getVariable ["ARC_testRun_lastStartTime", -999];
if (serverTime - _lastRun < 60) exitWith {
    diag_log format ["[ARC][TEST] Run rejected (debounce). lastStart=%1 now=%2", _lastRun, serverTime];
    if (_owner > 0) then
    {
        ["<t size='1.05' font='PuristaMedium'>ARC Test Suite</t><br/><br/><t color='#F87171'>Run rejected: another run started less than 60s ago.</t>"]
            remoteExec ["ARC_fnc_uiConsoleTestRunClientReceive", _owner];
    };
    false
};
missionNamespace setVariable ["ARC_testRun_lastStartTime", serverTime, false];
missionNamespace setVariable ["ARC_testRun_inProgress", true, false];

diag_log format ["[ARC][TEST] ARC_fnc_uiConsoleTestRunServer: run requested by owner=%1", _owner];

// execVM is fine from an unscheduled remoteExec frame, but waiting on
// completion needs a scheduled environment — spawn the wait/report stage.
[_owner] spawn {
    params ["_owner"];

    private _t0 = diag_tickTime;
    private _handle = [] execVM "tests\run_all.sqf";

    // run_all.sqf resets ARC_TEST_pass / ARC_TEST_fail itself at startup and
    // logs per-test results to the server RPT with [ARC][TEST] prefixes.
    private _timeoutAt = diag_tickTime + 600;
    waitUntil { sleep 0.5; (scriptDone _handle) || { diag_tickTime > _timeoutAt } };

    private _timedOut = !(scriptDone _handle);
    if (_timedOut) then { terminate _handle; };
    private _elapsed = diag_tickTime - _t0;
    private _fail = missionNamespace getVariable ["ARC_TEST_fail", 0];
    if (!(_pass isEqualType 0)) then { _pass = 0; };
    if (!(_fail isEqualType 0)) then { _fail = 0; };

    diag_log format ["[ARC][TEST] ARC_fnc_uiConsoleTestRunServer: done pass=%1 fail=%2 elapsed=%3s timedOut=%4", _pass, _fail, _elapsed toFixed 1, _timedOut];

    private _nl = "<br/>";
    private _lines = [];
    _lines pushBack "<t size='1.2' font='PuristaMedium'>ARC Test Suite (tests\run_all.sqf)</t>";
    _lines pushBack format ["<t size='0.9' color='#BDBDBD'>Server time:</t> <t size='0.9'>%1</t>", serverTime];
    _lines pushBack "";

    if (_timedOut) then
    {
        _lines pushBack "<t color='#F87171' font='PuristaMedium'>TIMED OUT</t> <t>Runner did not finish within 600s — check server RPT.</t>";
        _lines pushBack "";
    };

    private _okAll = (!_timedOut) && { _fail == 0 };
    private _statusColor = if (_okAll) then { "#6EE7B7" } else { "#FF6B6B" };
    private _statusLabel = if (_okAll) then { "PASS" } else { "FAIL" };
    _lines pushBack format ["<t color='%1' size='1.1' font='PuristaMedium'>%2</t>", _statusColor, _statusLabel];
    _lines pushBack format ["<t color='#6EE7B7'>Passed:</t> <t>%1</t>", _pass];
    _lines pushBack format ["<t color='#FF6B6B'>Failed:</t> <t>%1</t>", _fail];
    _lines pushBack format ["<t color='#BDBDBD'>Elapsed:</t> <t>%1s</t>", _elapsed toFixed 1];
    _lines pushBack "";
    _lines pushBack "<t size='0.95' color='#BDBDBD'>Per-test detail is in the server RPT ([ARC][TEST] lines). On FAIL, grab the RPT and the mission build stamp and report it.</t>";

    private _report = _lines joinString _nl;

    if (_owner > 0) then
    {
        [_report] remoteExec ["ARC_fnc_uiConsoleTestRunClientReceive", _owner];
    };

    missionNamespace setVariable ["ARC_testRun_inProgress", false, false];
};

true

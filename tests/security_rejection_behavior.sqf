/*
    Run locally on a DISPOSABLE dedicated server with a connected player:
      [allPlayers select 0] execVM "tests\security_rejection_behavior.sqf";
    Never remoteExec this harness. Uses real production sender validation and
    the existing local-only dry-run seams; never assigns engine identifiers.
    Real remote/spoofed/hosted/JIP cases remain the manual acceptance matrix.
*/
if (!isServer || {isRemoteExecuted}) exitWith {false};
params [["_unit", objNull, [objNull]]];
if (isNull _unit || {!isPlayer _unit} || {!(_unit in allPlayers)}) exitWith
{
    diag_log "[ARC][SECURITY_TEST] BLOCKED: a connected player is required";
    false
};
private _keys = ["ARC_TEST_mode", "ARC_TEST_tocDryRun", "ARC_TEST_tocCanApproveQueueOverride", "ARC_TEST_tocResetCalls", "ARC_TEST_tocSaveCalls", "ARC_TEST_tocRebuildCalls"];
private _saved = _keys apply { [_x, !(isNil {missionNamespace getVariable _x}), missionNamespace getVariable [_x, false]] };
private _failed = 0;
private _assert = {
    params ["_condition", "_label"];
    if (!_condition) then {_failed = _failed + 1;};
    diag_log format ["[ARC][SECURITY_TEST] %1 %2", if (_condition) then {"PASS"} else {"FAIL"}, _label];
};
missionNamespace setVariable ["ARC_TEST_mode", true];
missionNamespace setVariable ["ARC_TEST_tocDryRun", true];
{
    _x params ["_fn", "_counter", "_label"];
    missionNamespace setVariable [_counter, 0];
    missionNamespace setVariable ["ARC_TEST_tocCanApproveQueueOverride", false];
    private _result = [_unit, owner _unit] call _fn;
    [(_result isEqualTo false) && {(missionNamespace getVariable [_counter,-1]) == 0}, _label + " role denial leaves counter unchanged"] call _assert;
    missionNamespace setVariable ["ARC_TEST_tocCanApproveQueueOverride", true];
    _result = [_unit, (owner _unit) + 10000] call _fn;
    [(_result isEqualTo false) && {(missionNamespace getVariable [_counter,-1]) == 0}, _label + " owner mismatch leaves counter unchanged"] call _assert;
    _result = [_unit, owner _unit] call _fn;
    [(_result isEqualTo true) && {(missionNamespace getVariable [_counter,-1]) == 1}, _label + " authorized dry-run increments once"] call _assert;
} forEach [
    [ARC_fnc_tocRequestResetAll,"ARC_TEST_tocResetCalls","reset"],
    [ARC_fnc_tocRequestSave,"ARC_TEST_tocSaveCalls","save"],
    [ARC_fnc_tocRequestRebuildActive,"ARC_TEST_tocRebuildCalls","rebuild"]
];
{
    _x params ["_key", "_existed", "_value"];
    if (_existed) then {missionNamespace setVariable [_key,_value];}
    else {missionNamespace setVariable [_key,nil];};
} forEach _saved;
diag_log format ["[ARC][SECURITY_TEST] SUMMARY failures=%1; remote/hosted/JIP acceptance still required",_failed];
_failed == 0

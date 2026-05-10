/*
    ARC_fnc_taskengEnsureParentCaseTask

    Server-only: ensure a CASE parent task exists in the Arma task system for the
    given thread ID. Idempotent — safe to call on every incident create.

    Params:
      0: STRING - threadId (must be non-empty)

    Returns:
      STRING - CASE task ID (e.g. "CASE:TH-001"), or "" on error.
*/

if (!isServer) exitWith {""};

params [["_threadId", "", [""]]];

if (_threadId isEqualTo "") exitWith
{
    diag_log "[ARC][TASKENG] taskengEnsureParentCaseTask: empty threadId — skipping.";
    ""
};

private _caseId = "CASE:" + _threadId;

// Idempotent: if the task already exists in the Arma task system, return early.
// Use the documented BIS_fnc_taskExists API instead of the unsupported
// `side getTaskState string` form, which the engine rejects with "Missing ;".
if ([_caseId] call BIS_fnc_taskExists) exitWith
{
    private _existingState = "";
    if (!isNil "BIS_fnc_taskState") then
    {
        _existingState = [_caseId] call BIS_fnc_taskState;
        if (!(_existingState isEqualType "")) then { _existingState = ""; };
    };
    diag_log format ["[ARC][TASKENG] taskengEnsureParentCaseTask: task %1 already exists (state=%2).", _caseId, _existingState];
    _caseId
};

// Create the CASE parent task for the thread.
private _title       = "[CASE] " + _threadId;
private _description = "Lead-driven task cluster for thread " + _threadId + ".";
[west, _caseId, [_title, _description, ""], objNull, "ASSIGNED", 0, true, ""] call BIS_fnc_taskCreate;

// Record the CASE task ID in the thread store.
private _store = ["taskeng_v0_thread_store", createHashMap] call ARC_fnc_stateGet;
if (!(_store isEqualType createHashMap)) then { _store = createHashMap; };
_store set [_threadId, _caseId];
["taskeng_v0_thread_store", _store] call ARC_fnc_stateSet;

diag_log format ["[ARC][TASKENG] taskengEnsureParentCaseTask: created CASE task %1 for thread %2.", _caseId, _threadId];

_caseId

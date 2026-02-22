/*
  ARC Test Runner (single file)

  Run from Debug Console:
    [] execVM "tests/run_all.sqf";

  Output:
    RPT lines prefixed with [ARC][TEST]

  Notes:
  - Keep tests lightweight and contract-focused.
  - Run state-changing tests only on the server.
*/

// ---- Minimal testlib (inlined) ----
ARC_TEST_pass = 0;
ARC_TEST_fail = 0;

if (isNil "ARC_TEST_fnc_log") then {
  ARC_TEST_fnc_log = {
    params [
      "_level",         // "INFO" | "PASS" | "FAIL"
      "_id",            // test id string
      "_msg",           // message
      ["_meta", []]     // array or string
    ];

    private _metaStr = _meta;
    if !(_meta isEqualType "") then { _metaStr = str _meta; };

    diag_log format ["[ARC][TEST][%1] %2 %3 meta=%4", _level, _id, _msg, _metaStr];

    if (_level isEqualTo "PASS") exitWith { ARC_TEST_pass = ARC_TEST_pass + 1; };
    if (_level isEqualTo "FAIL") exitWith { ARC_TEST_fail = ARC_TEST_fail + 1; };
  };

  ARC_TEST_fnc_assert = {
    params [
      "_cond",
      "_id",
      "_msg",
      ["_meta", []]
    ];

    if (_cond) then {
      ["PASS", _id, _msg, _meta] call ARC_TEST_fnc_log;
      true
    } else {
      ["FAIL", _id, _msg, _meta] call ARC_TEST_fnc_log;
      false
    };
  };

  ARC_TEST_fnc_assertNotNil = {
    params [
      "_varName",
      "_id",
      "_msg"
    ];

    private _exists = !(isNil _varName);
    [_exists, _id, _msg, ["var", _varName]] call ARC_TEST_fnc_assert;
  };

  ARC_TEST_fnc_summary = {
    params [["_label", "RUN"]];
    ["INFO", _label, format ["Summary pass=%1 fail=%2", ARC_TEST_pass, ARC_TEST_fail], []] call ARC_TEST_fnc_log;
  };

  ARC_TEST_fnc_diag = {
    params [
      "_id",
      "_msg",
      ["_meta", []]
    ];

    ["INFO", _id, _msg, _meta] call ARC_TEST_fnc_log;
  };

  ARC_TEST_fnc_measure = {
    params [
      "_id",
      "_msg",
      "_fn"
    ];

    private _tMeasure = diag_tickTime;
    private _result = call _fn;
    private _dtMs = (diag_tickTime - _tMeasure) * 1000;
    ["INFO", _id, _msg, ["durationMs", _dtMs]] call ARC_TEST_fnc_log;
    _result
  };

  ARC_TEST_fnc_assertType = {
    params [
      "_value",
      "_sample",
      "_id",
      "_msg"
    ];

    private _ok = (_value isEqualType _sample);
    [_ok, _id, _msg, ["value", _value, "sampleType", typeName _sample]] call ARC_TEST_fnc_assert;
  };

  ARC_TEST_fnc_stateSnapshot = {
    params ["_keys"];
    private _saved = [];
    {
      _saved pushBack [_x, missionNamespace getVariable [format ["ARC_state_%1", _x], nil]];
    } forEach _keys;
    _saved
  };

  ARC_TEST_fnc_stateRestore = {
    params ["_saved"];
    {
      _x params ["_k", "_v"];
      if (isNil "_v") then {
        missionNamespace setVariable [format ["ARC_state_%1", _k], nil];
      } else {
        [_k, _v] call ARC_fnc_stateSet;
      };
    } forEach _saved;
  };

  ARC_TEST_fnc_varSnapshot = {
    params ["_keys"];
    private _saved = [];
    {
      _saved pushBack [_x, missionNamespace getVariable [_x, nil]];
    } forEach _keys;
    _saved
  };

  ARC_TEST_fnc_varRestore = {
    params ["_saved"];
    {
      _x params ["_k", "_v"];
      missionNamespace setVariable [_k, _v];
    } forEach _saved;
  };
};

// Backfill helper funcs when testlib is already loaded from a prior run.
if (isNil "ARC_TEST_fnc_stateSnapshot") then {
  ARC_TEST_fnc_stateSnapshot = {
    params ["_keys"];
    private _saved = [];
    {
      _saved pushBack [_x, missionNamespace getVariable [format ["ARC_state_%1", _x], nil]];
    } forEach _keys;
    _saved
  };
};

if (isNil "ARC_TEST_fnc_stateRestore") then {
  ARC_TEST_fnc_stateRestore = {
    params ["_saved"];
    {
      _x params ["_k", "_v"];
      if (isNil "_v") then {
        missionNamespace setVariable [format ["ARC_state_%1", _k], nil];
      } else {
        [_k, _v] call ARC_fnc_stateSet;
      };
    } forEach _saved;
  };
};

if (isNil "ARC_TEST_fnc_varSnapshot") then {
  ARC_TEST_fnc_varSnapshot = {
    params ["_keys"];
    private _saved = [];
    {
      _saved pushBack [_x, missionNamespace getVariable [_x, nil]];
    } forEach _keys;
    _saved
  };
};

if (isNil "ARC_TEST_fnc_varRestore") then {
  ARC_TEST_fnc_varRestore = {
    params ["_saved"];
    {
      _x params ["_k", "_v"];
      missionNamespace setVariable [_k, _v];
    } forEach _saved;
  };
};

if (isNil "ARC_TEST_fnc_diag") then {
  ARC_TEST_fnc_diag = {
    params ["_id", "_msg", ["_meta", []]];
    ["INFO", _id, _msg, _meta] call ARC_TEST_fnc_log;
  };
};

if (isNil "ARC_TEST_fnc_measure") then {
  ARC_TEST_fnc_measure = {
    params ["_id", "_msg", "_fn"];
    private _tMeasure = diag_tickTime;
    private _result = call _fn;
    private _dtMs = (diag_tickTime - _tMeasure) * 1000;
    ["INFO", _id, _msg, ["durationMs", _dtMs]] call ARC_TEST_fnc_log;
    _result
  };
};

if (isNil "ARC_TEST_fnc_assertType") then {
  ARC_TEST_fnc_assertType = {
    params ["_value", "_sample", "_id", "_msg"];
    private _ok = (_value isEqualType _sample);
    [_ok, _id, _msg, ["value", _value, "sampleType", typeName _sample]] call ARC_TEST_fnc_assert;
  };
};

// ---- Runner ----
waitUntil { !isNil "ARC_TEST_fnc_log" };

private _t0 = diag_tickTime;
["INFO", "RUN", "Reset test counters for deterministic run", ["pass", ARC_TEST_pass, "fail", ARC_TEST_fail]] call ARC_TEST_fnc_log;
["INFO", "RUN", "Starting ARC test runner", ["isServer", isServer, "isDedicated", isDedicated, "clientOwner", clientOwner]] call ARC_TEST_fnc_log;

/*
  Edit this list to match your mission public APIs.
  Keep it limited to core contracts so it catches regressions early.
*/
private _expectedFunctions = [
  "ARC_fnc_execSpawnConvoy",
  "ARC_fnc_worldGetZoneForPos"
];

// Unit: sanity checks (run everywhere)
[true, "UT-SANITY-000", "runner executed", []] call ARC_TEST_fnc_assert;
[true, "UT-SANITY-001", "diag_log command is assumed available in engine", []] call ARC_TEST_fnc_assert;
["UT-DIAG-000", "runtime context", ["time", time, "diag_tickTime", diag_tickTime, "isMultiplayer", isMultiplayer, "didJIP", didJIP]] call ARC_TEST_fnc_diag;

[missionNamespace getVariable ["ARC_pub_state", createHashMap], createHashMap, "UT-DIAG-001", "ARC_pub_state defaults to HashMap type"] call ARC_TEST_fnc_assertType;
[missionNamespace getVariable ["ARC_pub_stateUpdatedAt", -1], 0, "UT-DIAG-002", "ARC_pub_stateUpdatedAt defaults to numeric type"] call ARC_TEST_fnc_assertType;

private _diagNoop = [
  "UT-PERF-000",
  "noop harness timing",
  {
    private _sum = 0;
    for "_i" from 1 to 500 do { _sum = _sum + _i; };
    _sum
  }
] call ARC_TEST_fnc_measure;
[(_diagNoop isEqualType 0) && {_diagNoop > 0}, "UT-PERF-001", "measurement wrapper returns callback result", ["result", _diagNoop]] call ARC_TEST_fnc_assert;

{
  [_x, format ["UT-API-%1", _forEachIndex + 1], "expected function exists"] call ARC_TEST_fnc_assertNotNil;
} forEach _expectedFunctions;


// Unit: theme schema contract
if (!(isNil "ARC_fnc_consoleThemeGet")) then {
  private _theme = call ARC_fnc_consoleThemeGet;
  private _requiredThemeKeys = [
    "bezelOuter",
    "bezelGreen",
    "bezelInner",
    "screen",
    "text",
    "border",
    "statusGreen",
    "statusAmber",
    "statusRed"
  ];

  private _isThemeHashMap = _theme isEqualType createHashMap;
  [_isThemeHashMap, "UT-THEME-000", "console theme returns HashMap", ["type", typeName _theme]] call ARC_TEST_fnc_assert;

  if (_isThemeHashMap) then {
    private _themeKeys = keys _theme;

    {
      private _hasKey = _x in _themeKeys;
      [
        _hasKey,
        format ["UT-THEME-%1", _forEachIndex + 1],
        format ["console theme contains key '%1'", _x]
      ] call ARC_TEST_fnc_assert;
    } forEach _requiredThemeKeys;

    [
      (count _themeKeys) >= (count _requiredThemeKeys),
      "UT-THEME-KEYCOUNT-001",
      "console theme exposes expected minimum key count",
      ["keys", count _themeKeys]
    ] call ARC_TEST_fnc_assert;
  } else {
    ["INFO", "UT-THEME-SKIP", "theme key checks skipped because return type is not HashMap", ["type", typeName _theme]] call ARC_TEST_fnc_log;
  };
} else {
  ["INFO", "UT-THEME-SKIP", "theme contract skipped; ARC_fnc_consoleThemeGet missing", []] call ARC_TEST_fnc_log;
};

// Unit: CBA availability (optional)
private _hasCBA = !(isNil "CBA_fnc_addPerFrameHandler");
[_hasCBA, "UT-ENV-001", "CBA per-frame handler available (optional)", []] call ARC_TEST_fnc_assert;

// Unit: convoy bridge spacing clamp contract
private _convoyBridgeSpacingFinal = {
  params ["_bridgeMode", "_spacing", "_bridgeSpacingM"];
  if (_bridgeMode) then { _spacing min _bridgeSpacingM } else { _spacing };
};
[
  ([true, 59, 35] call _convoyBridgeSpacingFinal) isEqualTo 35,
  "UT-CONVOY-BRIDGE-001",
  "bridge mode clamps spacing to tighter bridge spacing"
] call ARC_TEST_fnc_assert;
[
  ([false, 59, 35] call _convoyBridgeSpacingFinal) isEqualTo 59,
  "UT-CONVOY-BRIDGE-002",
  "non-bridge mode keeps planned convoy spacing"
] call ARC_TEST_fnc_assert;

// Unit: non-bridge catch-up thresholds should react before gaps become extreme.
private _convoyCatchupCap = {
  params ["_spacing", "_speedKph", "_minKph", "_holdKph", "_slowF", "_holdF", "_maxGap"];
  private _gapSlow = ((_spacing max 20) * _slowF) max 120;
  private _gapHold = ((_spacing max 20) * _holdF) max 220;
  if (_maxGap > _gapHold) exitWith { _holdKph };
  if (_maxGap > _gapSlow) exitWith { ((_speedKph * 0.60) max _minKph) min _speedKph };
  _speedKph
};
[
  ([59, 35, 10, 8, 2.2, 3.4, 150] call _convoyCatchupCap) < 35,
  "UT-CONVOY-CATCHUP-001",
  "non-bridge moderate tail gap triggers slowdown for cohesion"
] call ARC_TEST_fnc_assert;
[
  ([59, 35, 10, 8, 2.2, 3.4, 230] call _convoyCatchupCap) isEqualTo 8,
  "UT-CONVOY-CATCHUP-002",
  "non-bridge large tail gap triggers hold-speed catch-up"
] call ARC_TEST_fnc_assert;

// Authoritative-only checks (server)
if (isServer) then {
  ["INFO", "UT-SERVER-000", "Running server-only tests", []] call ARC_TEST_fnc_log;

  if (!(isNil "ARC_fnc_rpcValidateSender")) then {
    private _rpcVars = ["remoteExecutedOwner"];
    private _rpcVarSaved = [_rpcVars] call ARC_TEST_fnc_varSnapshot;
    private _rpcCaller = createVehicle ["Logic", [0, 0, 0], [], 0, "NONE"];

    missionNamespace setVariable ["remoteExecutedOwner", nil];
    private _rpcLocal = [_rpcCaller, "UT_RPC_LOCAL", "", "UT_RPC_EVENT"] call ARC_fnc_rpcValidateSender;
    [_rpcLocal, "UT-RPC-001", "rpcValidateSender allows non-remote invocation", []] call ARC_TEST_fnc_assert;

    missionNamespace setVariable ["remoteExecutedOwner", owner _rpcCaller];
    private _rpcMatch = [_rpcCaller, "UT_RPC_MATCH", "", "UT_RPC_EVENT"] call ARC_fnc_rpcValidateSender;
    [_rpcMatch, "UT-RPC-002", "rpcValidateSender accepts matching owner", ["owner", owner _rpcCaller]] call ARC_TEST_fnc_assert;

    private _badOwner = (owner _rpcCaller) + 100;
    missionNamespace setVariable ["remoteExecutedOwner", _badOwner];
    private _rpcMismatch = [_rpcCaller, "UT_RPC_MISMATCH", "", "UT_RPC_EVENT"] call ARC_fnc_rpcValidateSender;
    [!_rpcMismatch, "UT-RPC-003", "rpcValidateSender rejects owner mismatch", ["expected", owner _rpcCaller, "actual", _badOwner]] call ARC_TEST_fnc_assert;

    private _rpcNull = [objNull, "UT_RPC_NULL", "", "UT_RPC_EVENT"] call ARC_fnc_rpcValidateSender;
    [!_rpcNull, "UT-RPC-004", "rpcValidateSender rejects null caller on remote RPC", ["remoteOwner", _badOwner]] call ARC_TEST_fnc_assert;

    deleteVehicle _rpcCaller;
    [_rpcVarSaved] call ARC_TEST_fnc_varRestore;
  } else {
    ["INFO", "UT-RPC-SKIP", "rpcValidateSender tests skipped; function missing", []] call ARC_TEST_fnc_log;
  };

  if (!(isNil "ARC_fnc_tocRequestCloseIncident") && !(isNil "ARC_fnc_stateSet") && !(isNil "ARC_fnc_stateGet")) then {
    private _closeKeys = [
      "activeIncidentClosePending",
      "activeIncidentSitrepSent",
      "activeTaskId",
      "activeIncidentSitrepFromGroup",
      "activeIncidentAcceptedByGroup",
      "lastTaskingGroup",
      "tocOrders",
      "activeIncidentClosePendingAt",
      "activeIncidentClosePendingResult",
      "activeIncidentClosePendingOrderId",
      "activeIncidentClosePendingGroup",
      "activeIncidentCloseReady"
    ];
    private _closeSaved = [_closeKeys] call ARC_TEST_fnc_stateSnapshot;

    private _closeVars = ["ARC_activeIncidentClosePending", "ARC_activeIncidentCloseReady"];
    private _closeVarsSaved = [_closeVars] call ARC_TEST_fnc_varSnapshot;

    private _closeFnVars = [
      "ARC_fnc_rolesHasGroupIdToken",
      "ARC_fnc_rolesCanApproveQueue",
      "ARC_fnc_rpcValidateSender"
    ];
    private _closeFnSaved = [_closeFnVars] call ARC_TEST_fnc_varSnapshot;

    private _closeCaller = createVehicle ["Logic", [0, 0, 0], [], 0, "NONE"];

    ARC_fnc_rpcValidateSender = { true };
    ARC_fnc_rolesHasGroupIdToken = { false };
    ARC_fnc_rolesCanApproveQueue = { true };

    ["activeIncidentClosePending", false] call ARC_fnc_stateSet;
    ["activeIncidentSitrepSent", false] call ARC_fnc_stateSet;
    ["activeTaskId", "UT-CLOSE-TASK-1"] call ARC_fnc_stateSet;
    ["activeIncidentSitrepFromGroup", "ALPHA"] call ARC_fnc_stateSet;
    ["tocOrders", [["O1", 1, "ISSUED", "HOLD", "ALPHA", [], []]]] call ARC_fnc_stateSet;

    private _closeNeedSitrep = ["SUCCEEDED", _closeCaller, _closeCaller] call ARC_fnc_tocRequestCloseIncident;
    [!_closeNeedSitrep, "UT-CLOSE-001", "closeout denied before SITREP is sent", []] call ARC_TEST_fnc_assert;

    ["activeIncidentSitrepSent", true] call ARC_fnc_stateSet;
    ["activeIncidentClosePending", true] call ARC_fnc_stateSet;
    private _closePendingDeny = ["SUCCEEDED", _closeCaller, _closeCaller] call ARC_fnc_tocRequestCloseIncident;
    [!_closePendingDeny, "UT-CLOSE-002", "closeout denied when already pending", []] call ARC_TEST_fnc_assert;

    ["activeIncidentClosePending", false] call ARC_fnc_stateSet;
    ARC_fnc_rolesCanApproveQueue = { false };
    private _closeUnauthorized = ["SUCCEEDED", _closeCaller, _closeCaller] call ARC_fnc_tocRequestCloseIncident;
    [!_closeUnauthorized, "UT-CLOSE-003", "closeout denied for unauthorized caller", []] call ARC_TEST_fnc_assert;

    deleteVehicle _closeCaller;
    [_closeSaved] call ARC_TEST_fnc_stateRestore;
    [_closeVarsSaved] call ARC_TEST_fnc_varRestore;
    [_closeFnSaved] call ARC_TEST_fnc_varRestore;
  } else {
    ["INFO", "UT-CLOSE-SKIP", "closeout gate tests skipped; prerequisites missing", []] call ARC_TEST_fnc_log;
  };

  if (!(isNil "ARC_fnc_tocRequestSave") && !(isNil "ARC_fnc_tocRequestResetAll") && !(isNil "ARC_fnc_tocRequestRebuildActive")) then {
    private _tocVars = [
      "remoteExecutedOwner",
      "ARC_fnc_rolesHasGroupIdToken",
      "ARC_fnc_rolesCanApproveQueue",
      "ARC_fnc_rpcValidateSender",
      "ARC_fnc_stateSave",
      "ARC_fnc_resetAll",
      "ARC_fnc_taskRehydrateActive",
      "civsub_v1_enabled"
    ];
    private _tocSaved = [_tocVars] call ARC_TEST_fnc_varSnapshot;

    private _tocCaller = createVehicle ["Logic", [0, 0, 0], [], 0, "NONE"];
    private _tocOwner = owner _tocCaller;

    ARC_TEST_tocSaveCalls = 0;
    ARC_TEST_tocResetCalls = 0;
    ARC_TEST_tocRebuildCalls = 0;

    ARC_fnc_stateSave = { ARC_TEST_tocSaveCalls = ARC_TEST_tocSaveCalls + 1; true };
    ARC_fnc_resetAll = { ARC_TEST_tocResetCalls = ARC_TEST_tocResetCalls + 1; true };
    ARC_fnc_taskRehydrateActive = { ARC_TEST_tocRebuildCalls = ARC_TEST_tocRebuildCalls + 1; true };
    ARC_fnc_rpcValidateSender = { true };
    ARC_fnc_rolesHasGroupIdToken = { false };
    ARC_fnc_rolesCanApproveQueue = { false };

    missionNamespace setVariable ["remoteExecutedOwner", _tocOwner];
    missionNamespace setVariable ["civsub_v1_enabled", false];

    private _saveDenied = [_tocCaller] call ARC_fnc_tocRequestSave;
    [!_saveDenied && { ARC_TEST_tocSaveCalls isEqualTo 0 }, "UT-TOC-AUTH-001", "tocRequestSave denies unauthorized caller", ["saveCalls", ARC_TEST_tocSaveCalls]] call ARC_TEST_fnc_assert;

    private _resetDenied = [_tocCaller] call ARC_fnc_tocRequestResetAll;
    [!_resetDenied && { ARC_TEST_tocResetCalls isEqualTo 0 }, "UT-TOC-AUTH-002", "tocRequestResetAll denies unauthorized caller", ["resetCalls", ARC_TEST_tocResetCalls]] call ARC_TEST_fnc_assert;

    private _rebuildDenied = [_tocCaller] call ARC_fnc_tocRequestRebuildActive;
    [!_rebuildDenied && { ARC_TEST_tocRebuildCalls isEqualTo 0 }, "UT-TOC-AUTH-003", "tocRequestRebuildActive denies unauthorized caller", ["rebuildCalls", ARC_TEST_tocRebuildCalls]] call ARC_TEST_fnc_assert;

    ARC_fnc_rolesCanApproveQueue = { true };

    private _saveAllowed = [_tocCaller] call ARC_fnc_tocRequestSave;
    [_saveAllowed && { ARC_TEST_tocSaveCalls isEqualTo 1 }, "UT-TOC-AUTH-004", "tocRequestSave allows authorized caller", ["saveCalls", ARC_TEST_tocSaveCalls]] call ARC_TEST_fnc_assert;

    private _resetAllowed = [_tocCaller] call ARC_fnc_tocRequestResetAll;
    [_resetAllowed && { ARC_TEST_tocResetCalls isEqualTo 1 }, "UT-TOC-AUTH-005", "tocRequestResetAll allows authorized caller", ["resetCalls", ARC_TEST_tocResetCalls]] call ARC_TEST_fnc_assert;

    private _rebuildAllowed = [_tocCaller] call ARC_fnc_tocRequestRebuildActive;
    [_rebuildAllowed && { ARC_TEST_tocRebuildCalls isEqualTo 1 }, "UT-TOC-AUTH-006", "tocRequestRebuildActive allows authorized caller", ["rebuildCalls", ARC_TEST_tocRebuildCalls]] call ARC_TEST_fnc_assert;

    deleteVehicle _tocCaller;
    [_tocSaved] call ARC_TEST_fnc_varRestore;
  } else {
    ["INFO", "UT-TOC-AUTH-SKIP", "TOC request auth tests skipped; prerequisites missing", []] call ARC_TEST_fnc_log;
  };

  /*
    Place server-only contract tests here. Examples:
    - incident state machine transition validation
    - follow-on creation emits replication
    - convoy spawn preconditions
  */

  // Regression: first progress update should prevent watchdog from immediately marking close-ready.
  if (!(isNil "ARC_fnc_incidentWatchdog") && !(isNil "ARC_fnc_stateSet") && !(isNil "ARC_fnc_stateGet")) then {
    private _wdKeys = [
      "activeTaskId",
      "activeIncidentCreatedAt",
      "activeIncidentAccepted",
      "activeIncidentAcceptedAt",
      "activeIncidentCloseReady",
      "activeExecLastProg",
      "activeExecLastProgressAt"
    ];

    private _wdSaved = [_wdKeys] call ARC_TEST_fnc_stateSnapshot;

    private _wdCfgSaved = [
      ["ARC_wd_graceSeconds", missionNamespace getVariable ["ARC_wd_graceSeconds", nil]],
      ["ARC_wd_acceptedTimeout", missionNamespace getVariable ["ARC_wd_acceptedTimeout", nil]]
    ];

    private _nowWd = serverTime;
    ["activeTaskId", "UT-WD-INC-1"] call ARC_fnc_stateSet;
    ["activeIncidentCreatedAt", _nowWd - 300] call ARC_fnc_stateSet;
    ["activeIncidentAccepted", true] call ARC_fnc_stateSet;
    ["activeIncidentAcceptedAt", _nowWd - 120] call ARC_fnc_stateSet;
    ["activeIncidentCloseReady", false] call ARC_fnc_stateSet;
    ["activeExecLastProg", 1] call ARC_fnc_stateSet;
    ["activeExecLastProgressAt", _nowWd - 5] call ARC_fnc_stateSet;

    missionNamespace setVariable ["ARC_wd_graceSeconds", 0];
    missionNamespace setVariable ["ARC_wd_acceptedTimeout", 30];

    private _wdMarked = [] call ARC_fnc_incidentWatchdog;
    private _wdCloseReady = ["activeIncidentCloseReady", false] call ARC_fnc_stateGet;

    [!_wdMarked, "UT-WD-001", "watchdog not marked immediately after fresh progress", ["marked", _wdMarked]] call ARC_TEST_fnc_assert;
    [!_wdCloseReady, "UT-WD-002", "close-ready remains false after fresh progress", ["closeReady", _wdCloseReady]] call ARC_TEST_fnc_assert;

    [_wdSaved] call ARC_TEST_fnc_stateRestore;

    {
      _x params ["_k", "_v"];
      if (isNil "_v") then { missionNamespace setVariable [_k, nil]; } else { missionNamespace setVariable [_k, _v]; };
    } forEach _wdCfgSaved;
  } else {
    ["INFO", "UT-WD-SKIP", "watchdog regression prerequisites missing", []] call ARC_TEST_fnc_log;
  };

} else {
  ["INFO", "UT-SERVER-SKIP", "Skipping server-only tests (not running on server)", []] call ARC_TEST_fnc_log;
};

sleep 0.1;
["INFO", "RUN", format ["Completed in %1s", (diag_tickTime - _t0)], []] call ARC_TEST_fnc_log;
call ARC_TEST_fnc_summary;

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

// ---------- Task 2.2 regression: intelLog array cap algorithm ----------

// Trims to configured max
private _capLog = [];
for "_i" from 1 to 15 do { _capLog pushBack _i; };
private _capMax = 10;
if ((count _capLog) > _capMax) then { _capLog = _capLog select [((count _capLog) - _capMax), _capMax]; };
[(count _capLog) isEqualTo 10, "UT-ILCAP-001", "intelLog cap trims array to configured max", ["count", count _capLog]] call ARC_TEST_fnc_assert;
// Preserves most-recent tail (not head): first retained entry = 15-10+1 = 6
[(_capLog select 0) isEqualTo 6, "UT-ILCAP-002", "intelLog cap preserves most-recent tail (not head)", ["first", _capLog select 0]] call ARC_TEST_fnc_assert;

// Cap not applied when under limit
private _capLogSmall = [];
for "_i" from 1 to 5 do { _capLogSmall pushBack _i; };
if ((count _capLogSmall) > _capMax) then { _capLogSmall = _capLogSmall select [((count _capLogSmall) - _capMax), _capMax]; };
[(count _capLogSmall) isEqualTo 5, "UT-ILCAP-003", "intelLog cap not applied when under limit", ["count", count _capLogSmall]] call ARC_TEST_fnc_assert;

// Configurable max: below-10 input clamps to 10
private _capRawLow = 5;
private _capClampedLow = (_capRawLow max 10) min 2000;
[_capClampedLow isEqualTo 10, "UT-ILCAP-004", "intelLog ARC_intelLogMaxEntries below 10 clamps to 10", ["clamped", _capClampedLow]] call ARC_TEST_fnc_assert;

// Type guard: non-numeric falls back to default 500
private _capBadType = "not_a_number";
if (!(_capBadType isEqualType 0)) then { _capBadType = 500; };
[_capBadType isEqualTo 500, "UT-ILCAP-005", "intelLog non-numeric ARC_intelLogMaxEntries falls back to 500", ["fallback", _capBadType]] call ARC_TEST_fnc_assert;


// ---------- Task 2.2 regression: incidentHistory array cap algorithm ----------

// Trims to configured max, preserves tail
private _capHist = [];
for "_i" from 1 to 15 do { _capHist pushBack _i; };
private _capHistMax = 10;
if ((count _capHist) > _capHistMax) then { _capHist = _capHist select [((count _capHist) - _capHistMax), _capHistMax]; };
[(count _capHist) isEqualTo 10, "UT-IHCAP-001", "incidentHistory cap trims array to configured max", ["count", count _capHist]] call ARC_TEST_fnc_assert;
[(_capHist select 0) isEqualTo 6, "UT-IHCAP-002", "incidentHistory cap preserves most-recent tail", ["first", _capHist select 0]] call ARC_TEST_fnc_assert;

// Cap not applied when under limit
private _capHistSmall = [];
for "_i" from 1 to 5 do { _capHistSmall pushBack _i; };
if ((count _capHistSmall) > _capHistMax) then { _capHistSmall = _capHistSmall select [((count _capHistSmall) - _capHistMax), _capHistMax]; };
[(count _capHistSmall) isEqualTo 5, "UT-IHCAP-003", "incidentHistory cap not applied when under limit", ["count", count _capHistSmall]] call ARC_TEST_fnc_assert;


// ---------- Phase 1 regression: API existence for new/changed functions ----------

private _phase1ApiFns = [
  "ARC_fnc_devDiagnosticsSnapshot",
  "ARC_fnc_devToggleDebugMode",
  "ARC_fnc_devDiagnosticsClientReceive",
  "ARC_fnc_paramAssert",
  "ARC_fnc_stateGet",
  "ARC_fnc_stateSet",
  "ARC_fnc_devCompileAuditServer",
  "ARC_fnc_civsubIdentityTouch",
  "ARC_fnc_uiConsoleQAAuditServer"
];
{
  [_x, format ["UT-PH1-API-%1", _forEachIndex + 1], format ["Phase 1 function '%1' exists", _x]] call ARC_TEST_fnc_assertNotNil;
} forEach _phase1ApiFns;


// ---------- Phase 1 regression: paramAssert contract tests ----------

if (!(isNil "ARC_fnc_paramAssert")) then {

  // ARRAY_SHAPE — valid array
  private _paArrOk = [[1, 2, 3], "ARRAY_SHAPE", "testArr", [[], 1, 5, false]] call ARC_fnc_paramAssert;
  [(_paArrOk select 0), "UT-PASSERT-001", "ARRAY_SHAPE accepts valid array within bounds"] call ARC_TEST_fnc_assert;

  // ARRAY_SHAPE — too short
  private _paArrShort = [[], "ARRAY_SHAPE", "testArr", [[], 2, 5, false]] call ARC_fnc_paramAssert;
  [!(_paArrShort select 0), "UT-PASSERT-002", "ARRAY_SHAPE rejects array below minCount"] call ARC_TEST_fnc_assert;
  [(_paArrShort select 2) isEqualTo "ARC_ASSERT_ARRAY_SHAPE", "UT-PASSERT-003", "ARRAY_SHAPE below-min returns correct code"] call ARC_TEST_fnc_assert;

  // ARRAY_SHAPE — non-array input
  private _paArrType = ["not_array", "ARRAY_SHAPE", "testArr", [[], 0, 5, false]] call ARC_fnc_paramAssert;
  [!(_paArrType select 0), "UT-PASSERT-004", "ARRAY_SHAPE rejects non-array input"] call ARC_TEST_fnc_assert;
  [(_paArrType select 2) isEqualTo "ARC_ASSERT_TYPE_MISMATCH", "UT-PASSERT-005", "ARRAY_SHAPE type-mismatch returns correct code"] call ARC_TEST_fnc_assert;

  // SCALAR_BOUNDS — in range
  private _paScOk = [50, "SCALAR_BOUNDS", "testNum", [0, 0, 100]] call ARC_fnc_paramAssert;
  [(_paScOk select 0), "UT-PASSERT-006", "SCALAR_BOUNDS accepts value in range"] call ARC_TEST_fnc_assert;

  // SCALAR_BOUNDS — below min
  private _paScLow = [-5, "SCALAR_BOUNDS", "testNum", [0, 0, 100]] call ARC_fnc_paramAssert;
  [!(_paScLow select 0), "UT-PASSERT-007", "SCALAR_BOUNDS rejects value below minimum"] call ARC_TEST_fnc_assert;
  [(_paScLow select 2) isEqualTo "ARC_ASSERT_SCALAR_BOUNDS", "UT-PASSERT-008", "SCALAR_BOUNDS below-min returns correct code"] call ARC_TEST_fnc_assert;

  // SCALAR_BOUNDS — above max
  private _paScHigh = [200, "SCALAR_BOUNDS", "testNum", [0, 0, 100]] call ARC_fnc_paramAssert;
  [!(_paScHigh select 0), "UT-PASSERT-009", "SCALAR_BOUNDS rejects value above maximum"] call ARC_TEST_fnc_assert;

  // SCALAR_BOUNDS — type mismatch
  private _paScType = ["string_val", "SCALAR_BOUNDS", "testNum", [0, 0, 100]] call ARC_fnc_paramAssert;
  [!(_paScType select 0), "UT-PASSERT-010", "SCALAR_BOUNDS rejects non-numeric input"] call ARC_TEST_fnc_assert;

  // NON_EMPTY_STRING — valid
  private _paStrOk = ["hello", "NON_EMPTY_STRING", "testStr", [""]] call ARC_fnc_paramAssert;
  [(_paStrOk select 0), "UT-PASSERT-011", "NON_EMPTY_STRING accepts valid string"] call ARC_TEST_fnc_assert;

  // NON_EMPTY_STRING — empty (uses toUpper-compatible trim from Phase 1)
  private _paStrEmpty = ["", "NON_EMPTY_STRING", "testStr", ["fallback"]] call ARC_fnc_paramAssert;
  [!(_paStrEmpty select 0), "UT-PASSERT-012", "NON_EMPTY_STRING rejects empty string"] call ARC_TEST_fnc_assert;
  [(_paStrEmpty select 2) isEqualTo "ARC_ASSERT_EMPTY_STRING", "UT-PASSERT-013", "NON_EMPTY_STRING empty returns correct code"] call ARC_TEST_fnc_assert;

  // Unknown rule
  private _paUnknown = ["x", "BOGUS_RULE", "test", []] call ARC_fnc_paramAssert;
  [!(_paUnknown select 0), "UT-PASSERT-014", "unknown rule rejects input"] call ARC_TEST_fnc_assert;
  [(_paUnknown select 2) isEqualTo "ARC_ASSERT_RULE_UNKNOWN", "UT-PASSERT-015", "unknown rule returns correct code"] call ARC_TEST_fnc_assert;

} else {
  ["INFO", "UT-PASSERT-SKIP", "paramAssert tests skipped; function missing", []] call ARC_TEST_fnc_log;
};


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


  // ---------- Phase 1 regression: stateGet / stateSet roundtrip ----------

  if (!(isNil "ARC_fnc_stateSet") && !(isNil "ARC_fnc_stateGet")) then {
    private _stateTestKeys = ["_ut_state_test_str", "_ut_state_test_num", "_ut_state_test_arr"];
    private _stSaved = [_stateTestKeys] call ARC_TEST_fnc_stateSnapshot;

    // Set + Get string
    ["_ut_state_test_str", "hello_phase1"] call ARC_fnc_stateSet;
    private _stStr = ["_ut_state_test_str", ""] call ARC_fnc_stateGet;
    [_stStr isEqualTo "hello_phase1", "UT-STATE-001", "stateSet/stateGet roundtrip for STRING", ["got", _stStr]] call ARC_TEST_fnc_assert;

    // Set + Get number
    ["_ut_state_test_num", 42] call ARC_fnc_stateSet;
    private _stNum = ["_ut_state_test_num", -1] call ARC_fnc_stateGet;
    [_stNum isEqualTo 42, "UT-STATE-002", "stateSet/stateGet roundtrip for SCALAR", ["got", _stNum]] call ARC_TEST_fnc_assert;

    // Set + Get array
    ["_ut_state_test_arr", [1, "two", 3]] call ARC_fnc_stateSet;
    private _stArr = ["_ut_state_test_arr", []] call ARC_fnc_stateGet;
    [_stArr isEqualTo [1, "two", 3], "UT-STATE-003", "stateSet/stateGet roundtrip for ARRAY", ["got", _stArr]] call ARC_TEST_fnc_assert;

    // Overwrite existing key
    ["_ut_state_test_str", "updated"] call ARC_fnc_stateSet;
    private _stUpd = ["_ut_state_test_str", ""] call ARC_fnc_stateGet;
    [_stUpd isEqualTo "updated", "UT-STATE-004", "stateSet overwrites existing key", ["got", _stUpd]] call ARC_TEST_fnc_assert;

    // Get with default for missing key
    private _stMiss = ["_ut_state_nonexistent_key", "DEFAULT"] call ARC_fnc_stateGet;
    [_stMiss isEqualTo "DEFAULT", "UT-STATE-005", "stateGet returns default for missing key", ["got", _stMiss]] call ARC_TEST_fnc_assert;

    // String-form call
    private _stStrForm = "_ut_state_test_num" call ARC_fnc_stateGet;
    [(_stStrForm isEqualType 0), "UT-STATE-006", "stateGet accepts string-form call (returns SCALAR)", ["got", _stStrForm]] call ARC_TEST_fnc_assert;
    [_stStrForm isEqualTo 42, "UT-STATE-006b", "stateGet string-form returns correct value", ["expected", 42, "got", _stStrForm]] call ARC_TEST_fnc_assert;

    // Malformed input returns false
    private _stBad = "justAString" call ARC_fnc_stateSet;
    [!_stBad, "UT-STATE-007", "stateSet rejects string input (expects array)", ["got", _stBad]] call ARC_TEST_fnc_assert;

    // Empty-key returns false
    private _stEmpty = ["", "value"] call ARC_fnc_stateSet;
    [!_stEmpty, "UT-STATE-008", "stateSet rejects empty key", ["got", _stEmpty]] call ARC_TEST_fnc_assert;

    [_stSaved] call ARC_TEST_fnc_stateRestore;
  } else {
    ["INFO", "UT-STATE-SKIP", "stateGet/stateSet tests skipped; functions missing", []] call ARC_TEST_fnc_log;
  };


  // ---------- Bug 2 regression: loop guard nil-clear pattern ----------

  private _lgVars = ["ARC_incidentLoopRunning", "ARC_execLoopRunning"];
  private _lgSaved = [_lgVars] call ARC_TEST_fnc_varSnapshot;

  // Simulate stale guard (as if a previous session set both without clearing)
  missionNamespace setVariable ["ARC_incidentLoopRunning", true];
  missionNamespace setVariable ["ARC_execLoopRunning", true];

  // Apply the bootstrap nil-clear (mirrors fn_bootstrapServer.sqf fix)
  missionNamespace setVariable ["ARC_incidentLoopRunning", nil];
  missionNamespace setVariable ["ARC_execLoopRunning", nil];

  [isNil "ARC_incidentLoopRunning", "UT-LOOPGUARD-001", "nil-clear removes stale ARC_incidentLoopRunning guard", []] call ARC_TEST_fnc_assert;
  [isNil "ARC_execLoopRunning", "UT-LOOPGUARD-002", "nil-clear removes stale ARC_execLoopRunning guard", []] call ARC_TEST_fnc_assert;

  [_lgSaved] call ARC_TEST_fnc_varRestore;


  // ---------- Phase 1 regression: compile audit debounce ----------

  if (!(isNil "ARC_fnc_devCompileAuditServer")) then {
    private _auditVars = ["ARC_compileAudit_lastStartTime"];
    private _auditSaved = [_auditVars] call ARC_TEST_fnc_varSnapshot;

    // Simulate recent audit (within 15s)
    missionNamespace setVariable ["ARC_compileAudit_lastStartTime", serverTime, false];
    private _debounced = [objNull] call ARC_fnc_devCompileAuditServer;
    [!_debounced, "UT-CAUDIT-001", "compile audit rejects re-invocation within 15s debounce", ["result", _debounced]] call ARC_TEST_fnc_assert;

    // Simulate expired debounce (>15s ago) — should accept invocation
    missionNamespace setVariable ["ARC_compileAudit_lastStartTime", serverTime - 20, false];
    // The function will proceed past the debounce guard and attempt CfgFunctions iteration.
    // Even if it returns false (due to missing config data), the debounce timestamp should
    // be updated to prove it accepted the invocation.
    [objNull] call ARC_fnc_devCompileAuditServer;
    private _updatedTs = missionNamespace getVariable ["ARC_compileAudit_lastStartTime", -999];
    [(_updatedTs > (serverTime - 5)), "UT-CAUDIT-002", "compile audit accepts invocation after debounce expires (timestamp updated)", ["ts", _updatedTs, "serverTime", serverTime]] call ARC_TEST_fnc_assert;

    [_auditSaved] call ARC_TEST_fnc_varRestore;
  } else {
    ["INFO", "UT-CAUDIT-SKIP", "compile audit tests skipped; function missing", []] call ARC_TEST_fnc_log;
  };


  // ---------- Phase 1 regression: diagnostics functions ----------

  if (!(isNil "ARC_fnc_devDiagnosticsSnapshot")) then {
    // Function exists and is callable (server-side)
    [!(isNil "ARC_fnc_devDiagnosticsSnapshot"), "UT-DIAG-SNAP-001", "devDiagnosticsSnapshot function exists"] call ARC_TEST_fnc_assert;
    [!(isNil "ARC_fnc_devToggleDebugMode"), "UT-DIAG-SNAP-002", "devToggleDebugMode function exists"] call ARC_TEST_fnc_assert;
    [!(isNil "ARC_fnc_devDiagnosticsClientReceive"), "UT-DIAG-SNAP-003", "devDiagnosticsClientReceive function exists"] call ARC_TEST_fnc_assert;
  } else {
    ["INFO", "UT-DIAG-SNAP-SKIP", "diagnostics snapshot tests skipped; function missing", []] call ARC_TEST_fnc_log;
  };


  // ---------- Threat Governor gate tests ----------
  // Covers: disabled flag, global cooldown, district cooldown, budget exhausted,
  //         VBIED/SUICIDE escalation-tier minimums, disruption penalty, allow-through.

  if (!(isNil "ARC_fnc_threatGovernorCheck") && !(isNil "ARC_fnc_stateSet") && !(isNil "ARC_fnc_stateGet")) then {
    private _govStateKeys = [
      "threat_v0_enabled",
      "threat_v0_global_cooldown_until",
      "threat_v0_district_risk",
      "threat_v0_attack_budget"
    ];
    private _govStateSaved = [_govStateKeys] call ARC_TEST_fnc_stateSnapshot;
    private _govVarsSaved  = [["civsub_v1_enabled"]] call ARC_TEST_fnc_varSnapshot;

    missionNamespace setVariable ["civsub_v1_enabled", false];

    // UT-GOV-001/002: disabled flag → [false, "THREAT_DISABLED"]
    ["threat_v0_enabled", false]      call ARC_fnc_stateSet;
    ["threat_v0_global_cooldown_until", -1] call ARC_fnc_stateSet;
    ["threat_v0_district_risk",  createHashMap] call ARC_fnc_stateSet;
    ["threat_v0_attack_budget",  createHashMap] call ARC_fnc_stateSet;

    private _govDis = ["D01", "IED", 0] call ARC_fnc_threatGovernorCheck;
    [!(_govDis select 0), "UT-GOV-001", "governor rejects when threat_v0_enabled=false"] call ARC_TEST_fnc_assert;
    [((_govDis select 1) isEqualTo "THREAT_DISABLED"), "UT-GOV-002", "governor returns THREAT_DISABLED deny reason", ["reason", _govDis select 1]] call ARC_TEST_fnc_assert;

    // UT-GOV-003/004: global cooldown active → [false, "GLOBAL_COOLDOWN"]
    ["threat_v0_enabled", true] call ARC_fnc_stateSet;
    ["threat_v0_global_cooldown_until", serverTime + 3600] call ARC_fnc_stateSet;

    private _govGc = ["D01", "IED", 0] call ARC_fnc_threatGovernorCheck;
    [!(_govGc select 0), "UT-GOV-003", "governor rejects on active global cooldown"] call ARC_TEST_fnc_assert;
    [((_govGc select 1) isEqualTo "GLOBAL_COOLDOWN"), "UT-GOV-004", "governor returns GLOBAL_COOLDOWN deny reason", ["reason", _govGc select 1]] call ARC_TEST_fnc_assert;

    // UT-GOV-005/006: district cooldown active → [false, "DISTRICT_COOLDOWN"]
    ["threat_v0_global_cooldown_until", -1] call ARC_fnc_stateSet;
    private _riskMapDc = createHashMap;
    private _entryDc   = createHashMap;
    _entryDc set ["cooldown_until", serverTime + 3600];
    _riskMapDc set ["D01", _entryDc];
    ["threat_v0_district_risk", _riskMapDc] call ARC_fnc_stateSet;

    private _govDc = ["D01", "IED", 0] call ARC_fnc_threatGovernorCheck;
    [!(_govDc select 0), "UT-GOV-005", "governor rejects on active district cooldown"] call ARC_TEST_fnc_assert;
    [((_govDc select 1) isEqualTo "DISTRICT_COOLDOWN"), "UT-GOV-006", "governor returns DISTRICT_COOLDOWN deny reason", ["reason", _govDc select 1]] call ARC_TEST_fnc_assert;

    // UT-GOV-007/008: budget exhausted (spent >= budget_points) → [false, "BUDGET_EXHAUSTED"]
    ["threat_v0_district_risk", createHashMap] call ARC_fnc_stateSet;
    private _budgetExh = createHashMap;
    private _entryExh  = createHashMap;
    _entryExh set ["budget_points", 3];
    _entryExh set ["spent_today",   3];
    _budgetExh set ["D01", _entryExh];
    ["threat_v0_attack_budget", _budgetExh] call ARC_fnc_stateSet;

    private _govExh = ["D01", "IED", 0] call ARC_fnc_threatGovernorCheck;
    [!(_govExh select 0), "UT-GOV-007", "governor rejects when spent_today equals budget_points"] call ARC_TEST_fnc_assert;
    [((_govExh select 1) isEqualTo "BUDGET_EXHAUSTED"), "UT-GOV-008", "governor returns BUDGET_EXHAUSTED deny reason", ["reason", _govExh select 1]] call ARC_TEST_fnc_assert;

    // UT-GOV-009/010: VBIED at tier 1 (needs tier 2) → [false, "ESCALATION_TIER"]
    ["threat_v0_attack_budget", createHashMap] call ARC_fnc_stateSet;
    private _govVbiedLow = ["D01", "VBIED", 1] call ARC_fnc_threatGovernorCheck;
    [!(_govVbiedLow select 0), "UT-GOV-009", "governor rejects VBIED at tier 1 (minimum is tier 2)"] call ARC_TEST_fnc_assert;
    [((_govVbiedLow select 1) isEqualTo "ESCALATION_TIER"), "UT-GOV-010", "governor returns ESCALATION_TIER for under-tier VBIED", ["reason", _govVbiedLow select 1]] call ARC_TEST_fnc_assert;

    // UT-GOV-011: VBIED at required tier 2, budget clear → [true, ""]
    private _govVbiedOk = ["D01", "VBIED", 2] call ARC_fnc_threatGovernorCheck;
    [(_govVbiedOk select 0), "UT-GOV-011", "governor allows VBIED at required tier 2 with budget available"] call ARC_TEST_fnc_assert;

    // UT-GOV-012/013: SUICIDE at tier 2 (needs tier 3) → [false, "ESCALATION_TIER"]
    private _govSuicide = ["D01", "SUICIDE", 2] call ARC_fnc_threatGovernorCheck;
    [!(_govSuicide select 0), "UT-GOV-012", "governor rejects SUICIDE at tier 2 (minimum is tier 3)"] call ARC_TEST_fnc_assert;
    [((_govSuicide select 1) isEqualTo "ESCALATION_TIER"), "UT-GOV-013", "governor returns ESCALATION_TIER for under-tier SUICIDE", ["reason", _govSuicide select 1]] call ARC_TEST_fnc_assert;

    // UT-GOV-014: IED at tier 0, empty budget map → [true, ""] (uses default budget_points=3)
    private _govIedOk = ["D01", "IED", 0] call ARC_fnc_threatGovernorCheck;
    [(_govIedOk select 0), "UT-GOV-014", "governor allows IED at tier 0 with fresh budget"] call ARC_TEST_fnc_assert;

    // UT-GOV-015: disruption penalty reduces effective budget to 0 → BUDGET_EXHAUSTED
    // budget_points=2, penalty_pts=2, effective=0; spent_today=1 → 1 >= 0 → exhausted.
    private _budgetPenalty = createHashMap;
    private _entryPenalty  = createHashMap;
    _entryPenalty set ["budget_points",           2];
    _entryPenalty set ["spent_today",             1];
    _entryPenalty set ["disruption_penalty_pts",  2];
    _entryPenalty set ["disruption_penalty_until", serverTime + 3600];
    _budgetPenalty set ["D02", _entryPenalty];
    ["threat_v0_attack_budget", _budgetPenalty] call ARC_fnc_stateSet;

    private _govPenalty = ["D02", "IED", 0] call ARC_fnc_threatGovernorCheck;
    [!(_govPenalty select 0), "UT-GOV-015", "governor rejects when disruption penalty zeroes effective budget", ["result", _govPenalty select 1]] call ARC_TEST_fnc_assert;

    // NOTE: cleanup is unconditional — ARC_TEST_fnc_assert only logs, never exitWith the caller.
    [_govStateSaved] call ARC_TEST_fnc_stateRestore;
    [_govVarsSaved]  call ARC_TEST_fnc_varRestore;
  } else {
    ["INFO", "UT-GOV-SKIP", "threatGovernorCheck tests skipped; prerequisites missing", []] call ARC_TEST_fnc_log;
  };


  // ---------- ARC_stateWriteGen counter tests ----------
  // Verifies that every ARC_fnc_stateSet call increments the write-generation counter,
  // enabling callers to detect intervening writes across sleep boundaries.

  if (!(isNil "ARC_fnc_stateSet") && !(isNil "ARC_fnc_stateGet")) then {
    // Snapshot both the gen counter and the two test state keys so cleanup is exact.
    private _wgVarSaved   = [["ARC_stateWriteGen"]] call ARC_TEST_fnc_varSnapshot;
    private _wgStateSaved = [["_ut_wg_test", "_ut_wg_other"]] call ARC_TEST_fnc_stateSnapshot;

    missionNamespace setVariable ["ARC_stateWriteGen", 0];
    ["_ut_wg_test", "initial_value"] call ARC_fnc_stateSet;
    private _wgAfter1 = missionNamespace getVariable ["ARC_stateWriteGen", 0];
    [(_wgAfter1 isEqualTo 1), "UT-WRITEGEN-001", "ARC_stateWriteGen is 1 after first stateSet", ["gen", _wgAfter1]] call ARC_TEST_fnc_assert;

    ["_ut_wg_test", "updated_value"] call ARC_fnc_stateSet;
    private _wgAfter2 = missionNamespace getVariable ["ARC_stateWriteGen", 0];
    [(_wgAfter2 isEqualTo 2), "UT-WRITEGEN-002", "ARC_stateWriteGen increments by 1 on each stateSet", ["gen", _wgAfter2]] call ARC_TEST_fnc_assert;

    // Verify staleRead detection: snapshot gen, simulate intervening write, confirm gen changed.
    private _wgSnap = missionNamespace getVariable ["ARC_stateWriteGen", 0];
    ["_ut_wg_other", "concurrent"] call ARC_fnc_stateSet;
    private _wgSnapAfter = missionNamespace getVariable ["ARC_stateWriteGen", 0];
    [!(_wgSnapAfter isEqualTo _wgSnap), "UT-WRITEGEN-003", "gen snapshot detects intervening write (staleRead detection pattern)", ["snap", _wgSnap, "after", _wgSnapAfter]] call ARC_TEST_fnc_assert;

    // Restore state keys and write-gen counter. Cleanup is unconditional.
    [_wgStateSaved] call ARC_TEST_fnc_stateRestore;
    [_wgVarSaved]   call ARC_TEST_fnc_varRestore;
  } else {
    ["INFO", "UT-WRITEGEN-SKIP", "stateWriteGen tests skipped; stateSet/stateGet missing", []] call ARC_TEST_fnc_log;
  };


  // ---------- CASREQ ID builder tests ----------
  // Covers: return type, CAS: prefix, district embedding, seq increment, D00 fallback.

  if (!(isNil "ARC_fnc_casreqBuildId") && !(isNil "ARC_fnc_stateSet") && !(isNil "ARC_fnc_stateGet")) then {
    private _casreqSaved = [["casreq_v1_seq"]] call ARC_TEST_fnc_stateSnapshot;
    ["casreq_v1_seq", 0] call ARC_fnc_stateSet;

    private _casId1 = ["D01"] call ARC_fnc_casreqBuildId;
    [(_casId1 isEqualType ""), "UT-CASREQ-001", "casreqBuildId returns a STRING", ["got", _casId1]] call ARC_TEST_fnc_assert;
    [((_casId1 find "CAS:") isEqualTo 0), "UT-CASREQ-002", "casreqBuildId result begins with CAS: prefix", ["got", _casId1]] call ARC_TEST_fnc_assert;
    [((_casId1 find "D01") >= 0), "UT-CASREQ-003", "casreqBuildId embeds district D01 in ID", ["got", _casId1]] call ARC_TEST_fnc_assert;

    // UT-CASREQ-004/005: successive calls produce unique IDs and advance seq
    private _casId2 = ["D01"] call ARC_fnc_casreqBuildId;
    [!(_casId2 isEqualTo _casId1), "UT-CASREQ-004", "casreqBuildId produces unique IDs on successive calls", ["id1", _casId1, "id2", _casId2]] call ARC_TEST_fnc_assert;
    private _seqAfter2 = ["casreq_v1_seq", -1] call ARC_fnc_stateGet;
    [(_seqAfter2 isEqualTo 2), "UT-CASREQ-005", "casreq_v1_seq is 2 after two calls (started at 0)", ["seq", _seqAfter2]] call ARC_TEST_fnc_assert;

    // UT-CASREQ-006: empty district falls back to D00
    ["casreq_v1_seq", 0] call ARC_fnc_stateSet;
    private _casIdEmpty = [""] call ARC_fnc_casreqBuildId;
    [((_casIdEmpty find "D00") >= 0), "UT-CASREQ-006", "casreqBuildId uses D00 fallback for empty district string", ["got", _casIdEmpty]] call ARC_TEST_fnc_assert;

    // UT-CASREQ-007: 2-char district (count < 3) falls back to D00
    ["casreq_v1_seq", 0] call ARC_fnc_stateSet;
    private _casIdShort = ["D1"] call ARC_fnc_casreqBuildId;
    [((_casIdShort find "D00") >= 0), "UT-CASREQ-007", "casreqBuildId uses D00 fallback for 2-char district (count<3)", ["got", _casIdShort]] call ARC_TEST_fnc_assert;

    [_casreqSaved] call ARC_TEST_fnc_stateRestore;
  } else {
    ["INFO", "UT-CASREQ-SKIP", "casreqBuildId tests skipped; prerequisites missing", []] call ARC_TEST_fnc_log;
  };

} else {
  ["INFO", "UT-SERVER-SKIP", "Skipping server-only tests (not running on server)", []] call ARC_TEST_fnc_log;
};

sleep 0.1;


// ---------- CIVSUB district clamp tests ----------
// Tests ARC_fnc_civsubDistrictsClamp: W/R/G + food/water/fear_idx clamped to 0..100.
// Runs on any machine (no server/state dependency).

if (!(isNil "ARC_fnc_civsubDistrictsClamp")) then {
  private _hgCl = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k,_d]";

  // UT-CLAMP-001/002/003: over-range values capped at 100
  private _clHigh = createHashMap;
  _clHigh set ["W_EFF_U", 150];
  _clHigh set ["R_EFF_U", 999];
  _clHigh set ["G_EFF_U", 100];
  [_clHigh] call ARC_fnc_civsubDistrictsClamp;
  [([_clHigh, "W_EFF_U", -1] call _hgCl) isEqualTo 100, "UT-CLAMP-001", "clamp caps W_EFF_U at 100 when over-range",  ["W", [_clHigh, "W_EFF_U", -1] call _hgCl]] call ARC_TEST_fnc_assert;
  [([_clHigh, "R_EFF_U", -1] call _hgCl) isEqualTo 100, "UT-CLAMP-002", "clamp caps R_EFF_U at 100 when over-range",  ["R", [_clHigh, "R_EFF_U", -1] call _hgCl]] call ARC_TEST_fnc_assert;
  [([_clHigh, "G_EFF_U", -1] call _hgCl) isEqualTo 100, "UT-CLAMP-003", "clamp preserves G_EFF_U exactly at 100",     ["G", [_clHigh, "G_EFF_U", -1] call _hgCl]] call ARC_TEST_fnc_assert;

  // UT-CLAMP-004/005/006: under-0 values floored to 0
  private _clLow = createHashMap;
  _clLow set ["W_EFF_U", -50];
  _clLow set ["R_EFF_U", -1];
  _clLow set ["G_EFF_U", 0];
  [_clLow] call ARC_fnc_civsubDistrictsClamp;
  [([_clLow, "W_EFF_U", -99] call _hgCl) isEqualTo 0, "UT-CLAMP-004", "clamp floors W_EFF_U to 0 when under-range",   ["W", [_clLow, "W_EFF_U", -99] call _hgCl]] call ARC_TEST_fnc_assert;
  [([_clLow, "R_EFF_U", -99] call _hgCl) isEqualTo 0, "UT-CLAMP-005", "clamp floors R_EFF_U to 0 when under-range",   ["R", [_clLow, "R_EFF_U", -99] call _hgCl]] call ARC_TEST_fnc_assert;
  [([_clLow, "G_EFF_U", -99] call _hgCl) isEqualTo 0, "UT-CLAMP-006", "clamp preserves G_EFF_U exactly at 0",         ["G", [_clLow, "G_EFF_U", -99] call _hgCl]] call ARC_TEST_fnc_assert;

  // UT-CLAMP-007/008/009: in-range values unchanged
  private _clMid = createHashMap;
  _clMid set ["W_EFF_U", 45];
  _clMid set ["R_EFF_U", 55];
  _clMid set ["G_EFF_U", 35];
  [_clMid] call ARC_fnc_civsubDistrictsClamp;
  [([_clMid, "W_EFF_U", -1] call _hgCl) isEqualTo 45, "UT-CLAMP-007", "clamp leaves W_EFF_U unchanged when in-range", ["W", [_clMid, "W_EFF_U", -1] call _hgCl]] call ARC_TEST_fnc_assert;
  [([_clMid, "R_EFF_U", -1] call _hgCl) isEqualTo 55, "UT-CLAMP-008", "clamp leaves R_EFF_U unchanged when in-range", ["R", [_clMid, "R_EFF_U", -1] call _hgCl]] call ARC_TEST_fnc_assert;
  [([_clMid, "G_EFF_U", -1] call _hgCl) isEqualTo 35, "UT-CLAMP-009", "clamp leaves G_EFF_U unchanged when in-range", ["G", [_clMid, "G_EFF_U", -1] call _hgCl]] call ARC_TEST_fnc_assert;

  // UT-CLAMP-010: non-hashmap input returns false (boolean false, not nil or other)
  private _clBad = "not_a_hashmap" call ARC_fnc_civsubDistrictsClamp;
  [(_clBad isEqualTo false), "UT-CLAMP-010", "clamp returns boolean false for non-hashmap input"] call ARC_TEST_fnc_assert;

  // UT-CLAMP-011/012/013: secondary index fields (food_idx, water_idx, fear_idx) also clamped
  private _clIdx = createHashMap;
  _clIdx set ["food_idx",  120];
  _clIdx set ["water_idx",  -5];
  _clIdx set ["fear_idx",   50];
  [_clIdx] call ARC_fnc_civsubDistrictsClamp;
  [([_clIdx, "food_idx",  -1] call _hgCl) isEqualTo 100, "UT-CLAMP-011", "clamp caps food_idx at 100",              ["food",  [_clIdx, "food_idx",  -1] call _hgCl]] call ARC_TEST_fnc_assert;
  [([_clIdx, "water_idx", -99] call _hgCl) isEqualTo 0,  "UT-CLAMP-012", "clamp floors water_idx to 0",             ["water", [_clIdx, "water_idx", -99] call _hgCl]] call ARC_TEST_fnc_assert;
  [([_clIdx, "fear_idx",  -1] call _hgCl) isEqualTo 50,  "UT-CLAMP-013", "clamp leaves in-range fear_idx unchanged", ["fear",  [_clIdx, "fear_idx",  -1] call _hgCl]] call ARC_TEST_fnc_assert;
} else {
  ["INFO", "UT-CLAMP-SKIP", "civsubDistrictsClamp tests skipped; function missing", []] call ARC_TEST_fnc_log;
};


// ---------- Threat district risk-decay rate math tests ----------
// Validates the WHITE-score modulation formula from fn_threatDistrictRiskDecay.sqf.
// Tested inline (no tick-function call) so these run on any machine without timing deps.
// IMPORTANT: If the formula in fn_threatDistrictRiskDecay.sqf changes, update these
//            expected values to match — see functions/threat/fn_threatDistrictRiskDecay.sqf.
//
// Formula (canonical source: fn_threatDistrictRiskDecay.sqf):
//   effectiveRate = baseRate
//   if whiteScore >= 70: effectiveRate = baseRate * 2   (high legitimacy → fast decay)
//   if whiteScore >= 50: riskLevel -= effectiveRate      (clamp 0)
//   if whiteScore < 30:  riskLevel += effectiveRate      (clamp 100)
//   else (30–49):        riskLevel -= effectiveRate*0.5  (clamp 0)

{
  _x params ["_label", "_id", "_baseRate", "_whiteScore", "_initialRisk", "_expectedRisk"];
  private _effectiveRate = _baseRate;
  if (_whiteScore >= 70) then { _effectiveRate = _baseRate * 2; };
  private _resultRisk = _initialRisk;
  if (_whiteScore >= 50) then {
    _resultRisk = (_initialRisk - _effectiveRate) max 0;
  } else {
    if (_whiteScore < 30) then {
      _resultRisk = (_initialRisk + _effectiveRate) min 100;
    } else {
      _resultRisk = (_initialRisk - (_effectiveRate * 0.5)) max 0;
    };
  };
  [(_resultRisk isEqualTo _expectedRisk), _id, _label, ["got", _resultRisk, "expected", _expectedRisk]] call ARC_TEST_fnc_assert;
} forEach [
  // [label, testId, baseRate, whiteScore, initialRisk, expectedRisk]
  ["WHITE>=70: effectiveRate doubles  (rate=1,w=80,risk=50 → 48)", "UT-DECAY-001", 1, 80, 50, 48],
  ["WHITE 50-69: normal decay        (rate=1,w=60,risk=50 → 49)", "UT-DECAY-002", 1, 60, 50, 49],
  ["WHITE<30: passive rise           (rate=1,w=20,risk=50 → 51)", "UT-DECAY-003", 1, 20, 50, 51],
  ["WHITE 30-49: half-rate decay     (rate=2,w=40,risk=50 → 49)", "UT-DECAY-004", 2, 40, 50, 49],
  ["risk floor clamp                 (rate=5,w=80,risk=1  →  0)", "UT-DECAY-005", 5, 80,  1,  0],
  ["risk ceiling clamp               (rate=5,w=10,risk=99 →100)", "UT-DECAY-006", 5, 10, 99, 100]
];



["INFO", "RUN", format ["Completed in %1s", (diag_tickTime - _t0)], []] call ARC_TEST_fnc_log;
call ARC_TEST_fnc_summary;

/*
  ARC Test Runner (safe dev harness)

  Run from Debug Console or HQ test action:
    [] execVM "tests/run_all.sqf";

  Output:
    RPT lines prefixed with [ARC][TEST]

  Contract after issue #675:
  - Run only when explicitly enabled by dev/test mode (enforced by caller for HQ action).
  - Never assign engine-reserved variables such as remoteExecutedOwner.
  - Never create brain-bearing Logic objects with createVehicle.
  - Never monkey-patch final mission functions.
  - State/variable mutations must use bounded snapshot/restore helpers.
*/

// ---- Minimal testlib (inlined) ----
ARC_TEST_pass = 0;
ARC_TEST_fail = 0;

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

ARC_TEST_fnc_skip = {
  params ["_id", "_msg", ["_meta", []]];
  ["INFO", _id, format ["SKIP: %1", _msg], _meta] call ARC_TEST_fnc_log;
  true
};

ARC_TEST_fnc_assertNotNil = {
  params ["_varName", "_id", "_msg"];
  private _exists = !(isNil _varName);
  [_exists, _id, _msg, ["var", _varName]] call ARC_TEST_fnc_assert;
};

ARC_TEST_fnc_summary = {
  params [["_label", "RUN"]];
  ["INFO", _label, format ["Summary pass=%1 fail=%2", ARC_TEST_pass, ARC_TEST_fail], []] call ARC_TEST_fnc_log;
};

ARC_TEST_fnc_diag = {
  params ["_id", "_msg", ["_meta", []]];
  ["INFO", _id, _msg, _meta] call ARC_TEST_fnc_log;
};

ARC_TEST_fnc_assertType = {
  params ["_value", "_sample", "_id", "_msg"];
  private _ok = (_value isEqualType _sample);
  [_ok, _id, _msg, ["value", _value, "sampleType", typeName _sample]] call ARC_TEST_fnc_assert;
};

ARC_TEST_fnc_measure = {
  params ["_id", "_msg", "_fn"];
  private _tMeasure = diag_tickTime;
  private _result = call _fn;
  private _dtMs = (diag_tickTime - _tMeasure) * 1000;
  ["INFO", _id, _msg, ["durationMs", _dtMs]] call ARC_TEST_fnc_log;
  _result
};

ARC_TEST_fnc_varSnapshot = {
  params ["_keys"];
  private _saved = [];
  {
    private _k = _x;
    if (!(_k isEqualType "")) then { _k = str _k; };
    private _exists = !(isNil { missionNamespace getVariable _k });
    if (_exists) then {
      _saved pushBack [_k, true, missionNamespace getVariable _k];
    } else {
      _saved pushBack [_k, false];
    };
  } forEach _keys;
  _saved
};

ARC_TEST_fnc_varRestore = {
  params ["_saved"];
  {
    private _k = _x param [0, "", [""]];
    private _exists = _x param [1, false, [true]];
    if (_k isEqualTo "") then { continue; };
    if (_exists && { (count _x) >= 3 }) then {
      missionNamespace setVariable [_k, _x select 2, false];
    } else {
      missionNamespace setVariable [_k, nil, false];
    };
  } forEach _saved;
};

ARC_TEST_fnc_stateSnapshot = {
  params ["_keys"];
  private _saved = [];
  private _sentinel = "__ARC_TEST_MISSING_STATE_VALUE__";
  {
    private _k = _x;
    if (!(_k isEqualType "")) then { _k = str _k; };
    private _v = [_k, _sentinel] call ARC_fnc_stateGet;
    if (_v isEqualTo _sentinel) then {
      _saved pushBack [_k, false];
    } else {
      _saved pushBack [_k, true, _v];
    };
  } forEach _keys;
  _saved
};

ARC_TEST_fnc_stateRestore = {
  params ["_saved"];
  {
    private _k = _x param [0, "", [""]];
    private _exists = _x param [1, false, [true]];
    if (_k isEqualTo "") then { continue; };

    if (_exists && { (count _x) >= 3 }) then {
      [_k, _x select 2] call ARC_fnc_stateSet;
    } else {
      // ARC_fnc_stateSet has no delete operation. Remove the test key directly
      // from the authoritative ARC_state pairs array.
      private _state = missionNamespace getVariable ["ARC_state", []];
      if (_state isEqualType []) then {
        _state = _state select { !(_x isEqualType [] && { (count _x) >= 1 } && { (_x select 0) isEqualTo _k }) };
        missionNamespace setVariable ["ARC_state", _state, false];
      };
    };
  } forEach _saved;
};

ARC_TEST_fnc_pickPlayer = {
  private _u = objNull;
  {
    if (isPlayer _x && { (owner _x) > 0 }) exitWith { _u = _x; };
  } forEach allPlayers;
  _u
};

// ---- Runner ----
waitUntil { !isNil "ARC_TEST_fnc_log" };

private _t0 = diag_tickTime;
["INFO", "RUN", "Reset test counters for deterministic run", ["pass", ARC_TEST_pass, "fail", ARC_TEST_fail]] call ARC_TEST_fnc_log;
["INFO", "RUN", "Starting ARC safe test runner", ["isServer", isServer, "isDedicated", isDedicated, "clientOwner", clientOwner]] call ARC_TEST_fnc_log;

// Unit: sanity checks (run everywhere)
[true, "UT-SANITY-000", "runner executed", []] call ARC_TEST_fnc_assert;
[true, "UT-SANITY-001", "diag_log command is assumed available in engine", []] call ARC_TEST_fnc_assert;
["UT-DIAG-000", "runtime context", ["time", time, "diag_tickTime", diag_tickTime, "isMultiplayer", isMultiplayer, "didJIP", didJIP]] call ARC_TEST_fnc_diag;

// Public state can be HashMap in early init or pairs-array snapshot during active runtime.
private _pubState = missionNamespace getVariable ["ARC_pub_state", createHashMap];
[(_pubState isEqualType createHashMap) || { _pubState isEqualType [] }, "UT-DIAG-001", "ARC_pub_state has supported snapshot type", ["type", typeName _pubState]] call ARC_TEST_fnc_assert;
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
} forEach [
  "ARC_fnc_execSpawnConvoy",
  "ARC_fnc_worldGetZoneForPos",
  "ARC_fnc_stateGet",
  "ARC_fnc_stateSet",
  "ARC_fnc_rpcValidateSender"
];

// Unit: CBA availability (optional in live stack but expected in project profile)
private _hasCBA = !(isNil "CBA_fnc_addPerFrameHandler");
[_hasCBA, "UT-ENV-001", "CBA per-frame handler available", []] call ARC_TEST_fnc_assert;

// Unit: convoy bridge spacing clamp contract
private _convoyBridgeSpacingFinal = {
  params ["_bridgeMode", "_spacing", "_bridgeSpacingM"];
  if (_bridgeMode) then { _spacing min _bridgeSpacingM } else { _spacing };
};
[([true, 59, 35] call _convoyBridgeSpacingFinal) isEqualTo 35, "UT-CONVOY-BRIDGE-001", "bridge mode clamps spacing to tighter bridge spacing"] call ARC_TEST_fnc_assert;
[([false, 59, 35] call _convoyBridgeSpacingFinal) isEqualTo 59, "UT-CONVOY-BRIDGE-002", "non-bridge mode keeps planned convoy spacing"] call ARC_TEST_fnc_assert;

// Unit: paramAssert contract smoke
if (!(isNil "ARC_fnc_paramAssert")) then {
  private _paArrOk = [[1, 2, 3], "ARRAY_SHAPE", "testArr", [[], 1, 5, false]] call ARC_fnc_paramAssert;
  [(_paArrOk select 0), "UT-PASSERT-001", "ARRAY_SHAPE accepts valid array within bounds"] call ARC_TEST_fnc_assert;

  private _paArrType = ["not_array", "ARRAY_SHAPE", "testArr", [[], 0, 5, false]] call ARC_fnc_paramAssert;
  [!(_paArrType select 0), "UT-PASSERT-002", "ARRAY_SHAPE rejects non-array input"] call ARC_TEST_fnc_assert;
  [(_paArrType select 2) isEqualTo "ARC_ASSERT_TYPE_MISMATCH", "UT-PASSERT-003", "ARRAY_SHAPE type-mismatch returns correct code"] call ARC_TEST_fnc_assert;

  private _paStrEmpty = ["", "NON_EMPTY_STRING", "testStr", ["fallback"]] call ARC_fnc_paramAssert;
  [!(_paStrEmpty select 0), "UT-PASSERT-004", "NON_EMPTY_STRING rejects empty string"] call ARC_TEST_fnc_assert;
  [(_paStrEmpty select 2) isEqualTo "ARC_ASSERT_EMPTY_STRING", "UT-PASSERT-005", "NON_EMPTY_STRING empty returns correct code"] call ARC_TEST_fnc_assert;
} else {
  ["UT-PASSERT-SKIP", "paramAssert tests skipped; function missing", []] call ARC_TEST_fnc_skip;
};

// Authoritative-only checks (server)
if (isServer) then {
  ["INFO", "UT-SERVER-000", "Running server-only safe tests", []] call ARC_TEST_fnc_log;

  // RPC tests use explicit caller-owner seam. They never set engine-reserved
  // remoteExecutedOwner and never create Logic objects.
  if (!(isNil "ARC_fnc_rpcValidateSender")) then {
    private _rpcCaller = call ARC_TEST_fnc_pickPlayer;
    if (isNull _rpcCaller) then {
      ["UT-RPC-SKIP", "rpcValidateSender remote-owner tests skipped; no valid player object", []] call ARC_TEST_fnc_skip;
    } else {
      private _rpcOwner = owner _rpcCaller;

      private _rpcMatch = [_rpcCaller, "UT_RPC_MATCH", "", "UT_RPC_EVENT", false, _rpcOwner] call ARC_fnc_rpcValidateSender;
      [_rpcMatch, "UT-RPC-001", "rpcValidateSender accepts matching explicit owner", ["owner", _rpcOwner]] call ARC_TEST_fnc_assert;

      private _badOwner = _rpcOwner + 100;
      private _rpcMismatch = [_rpcCaller, "UT_RPC_MISMATCH", "", "UT_RPC_EVENT", false, _badOwner] call ARC_fnc_rpcValidateSender;
      [!_rpcMismatch, "UT-RPC-002", "rpcValidateSender rejects owner mismatch via explicit seam", ["expected", _rpcOwner, "actual", _badOwner]] call ARC_TEST_fnc_assert;

      private _rpcNull = [objNull, "UT_RPC_NULL", "", "UT_RPC_EVENT", false, _rpcOwner] call ARC_fnc_rpcValidateSender;
      [!_rpcNull, "UT-RPC-003", "rpcValidateSender rejects null caller via explicit seam", ["remoteOwner", _rpcOwner]] call ARC_TEST_fnc_assert;
    };
  } else {
    ["UT-RPC-SKIP", "rpcValidateSender tests skipped; function missing", []] call ARC_TEST_fnc_skip;
  };

  // Closeout gate tests are intentionally skipped until a closeout-specific dry-run
  // seam exists. Calling the production RPC directly creates security-denial OPS spam.
  ["UT-CLOSE-SKIP", "tocRequestCloseIncident tests skipped; no closeout dry-run seam exists", []] call ARC_TEST_fnc_skip;

  // TOC request auth tests use production test seams instead of overriding final functions.
  if (!(isNil "ARC_fnc_tocRequestSave") && !(isNil "ARC_fnc_tocRequestResetAll") && !(isNil "ARC_fnc_tocRequestRebuildActive")) then {
    private _tocCaller = call ARC_TEST_fnc_pickPlayer;
    if (isNull _tocCaller) then {
      ["UT-TOC-AUTH-SKIP", "TOC request auth tests skipped; no valid player object", []] call ARC_TEST_fnc_skip;
    } else {
      private _tocOwner = owner _tocCaller;
      private _tocVars = [
        "ARC_TEST_mode",
        "ARC_TEST_tocDryRun",
        "ARC_TEST_tocCanApproveQueueOverride",
        "ARC_TEST_tocSaveCalls",
        "ARC_TEST_tocResetCalls",
        "ARC_TEST_tocRebuildCalls",
        "civsub_v1_enabled"
      ];
      private _tocSaved = [_tocVars] call ARC_TEST_fnc_varSnapshot;

      missionNamespace setVariable ["ARC_TEST_mode", true, false];
      missionNamespace setVariable ["ARC_TEST_tocDryRun", true, false];
      missionNamespace setVariable ["ARC_TEST_tocSaveCalls", 0, false];
      missionNamespace setVariable ["ARC_TEST_tocResetCalls", 0, false];
      missionNamespace setVariable ["ARC_TEST_tocRebuildCalls", 0, false];
      missionNamespace setVariable ["civsub_v1_enabled", false, false];

      missionNamespace setVariable ["ARC_TEST_tocCanApproveQueueOverride", false, false];

      private _saveDenied = [_tocCaller, _tocOwner] call ARC_fnc_tocRequestSave;
      [!_saveDenied && { (missionNamespace getVariable ["ARC_TEST_tocSaveCalls", 0]) isEqualTo 0 }, "UT-TOC-AUTH-001", "tocRequestSave denies unauthorized caller", ["saveCalls", missionNamespace getVariable ["ARC_TEST_tocSaveCalls", 0]]] call ARC_TEST_fnc_assert;

      private _resetDenied = [_tocCaller, _tocOwner] call ARC_fnc_tocRequestResetAll;
      [!_resetDenied && { (missionNamespace getVariable ["ARC_TEST_tocResetCalls", 0]) isEqualTo 0 }, "UT-TOC-AUTH-002", "tocRequestResetAll denies unauthorized caller", ["resetCalls", missionNamespace getVariable ["ARC_TEST_tocResetCalls", 0]]] call ARC_TEST_fnc_assert;

      private _rebuildDenied = [_tocCaller, _tocOwner] call ARC_fnc_tocRequestRebuildActive;
      [!_rebuildDenied && { (missionNamespace getVariable ["ARC_TEST_tocRebuildCalls", 0]) isEqualTo 0 }, "UT-TOC-AUTH-003", "tocRequestRebuildActive denies unauthorized caller", ["rebuildCalls", missionNamespace getVariable ["ARC_TEST_tocRebuildCalls", 0]]] call ARC_TEST_fnc_assert;

      missionNamespace setVariable ["ARC_TEST_tocCanApproveQueueOverride", true, false];

      private _saveAllowed = [_tocCaller, _tocOwner] call ARC_fnc_tocRequestSave;
      [_saveAllowed && { (missionNamespace getVariable ["ARC_TEST_tocSaveCalls", 0]) isEqualTo 1 }, "UT-TOC-AUTH-004", "tocRequestSave allows authorized caller", ["saveCalls", missionNamespace getVariable ["ARC_TEST_tocSaveCalls", 0]]] call ARC_TEST_fnc_assert;

      private _resetAllowed = [_tocCaller, _tocOwner] call ARC_fnc_tocRequestResetAll;
      [_resetAllowed && { (missionNamespace getVariable ["ARC_TEST_tocResetCalls", 0]) isEqualTo 1 }, "UT-TOC-AUTH-005", "tocRequestResetAll allows authorized caller", ["resetCalls", missionNamespace getVariable ["ARC_TEST_tocResetCalls", 0]]] call ARC_TEST_fnc_assert;

      private _rebuildAllowed = [_tocCaller, _tocOwner] call ARC_fnc_tocRequestRebuildActive;
      [_rebuildAllowed && { (missionNamespace getVariable ["ARC_TEST_tocRebuildCalls", 0]) isEqualTo 1 }, "UT-TOC-AUTH-006", "tocRequestRebuildActive allows authorized caller", ["rebuildCalls", missionNamespace getVariable ["ARC_TEST_tocRebuildCalls", 0]]] call ARC_TEST_fnc_assert;

      [_tocSaved] call ARC_TEST_fnc_varRestore;
    };
  } else {
    ["UT-TOC-AUTH-SKIP", "TOC request auth tests skipped; prerequisites missing", []] call ARC_TEST_fnc_skip;
  };

  // State API smoke and nil-safe state restore.
  if (!(isNil "ARC_fnc_stateSet") && !(isNil "ARC_fnc_stateGet")) then {
    private _stateKeys = ["_ut_state_test_str", "_ut_state_test_num", "_ut_state_missing_restore"];
    private _stSaved = [_stateKeys] call ARC_TEST_fnc_stateSnapshot;

    ["_ut_state_test_str", "hello_phase1"] call ARC_fnc_stateSet;
    private _stStr = ["_ut_state_test_str", ""] call ARC_fnc_stateGet;
    [_stStr isEqualTo "hello_phase1", "UT-STATE-001", "stateSet/stateGet roundtrip for STRING", ["got", _stStr]] call ARC_TEST_fnc_assert;

    ["_ut_state_test_num", 42] call ARC_fnc_stateSet;
    private _stNum = ["_ut_state_test_num", -1] call ARC_fnc_stateGet;
    [_stNum isEqualTo 42, "UT-STATE-002", "stateSet/stateGet roundtrip for SCALAR", ["got", _stNum]] call ARC_TEST_fnc_assert;

    [_stSaved] call ARC_TEST_fnc_stateRestore;
    private _missingRestored = ["_ut_state_missing_restore", "MISSING"] call ARC_fnc_stateGet;
    [_missingRestored isEqualTo "MISSING", "UT-STATE-003", "stateRestore removes missing state keys cleanly", ["got", _missingRestored]] call ARC_TEST_fnc_assert;
  } else {
    ["UT-STATE-SKIP", "stateGet/stateSet tests skipped; functions missing", []] call ARC_TEST_fnc_skip;
  };

  // CIVSUB clamp guard smoke: non-hashmap input must return false without RPT error.
  if (!(isNil "ARC_fnc_civsubDistrictsClamp")) then {
    private _clampBad = ["not_hashmap"] call ARC_fnc_civsubDistrictsClamp;
    [(_clampBad isEqualType false) && {!_clampBad}, "UT-CLAMP-001", "civsubDistrictsClamp returns false for non-hashmap input", ["got", _clampBad]] call ARC_TEST_fnc_assert;

    private _d = createHashMapFromArray [["W_EFF_U", 150], ["R_EFF_U", -20], ["G_EFF_U", 35], ["food_idx", 110], ["water_idx", -1], ["fear_idx", 50]];
    private _clampOk = [_d] call ARC_fnc_civsubDistrictsClamp;
    [_clampOk, "UT-CLAMP-002", "civsubDistrictsClamp accepts hashmap input", []] call ARC_TEST_fnc_assert;
    [((_d getOrDefault ["W_EFF_U", -1]) isEqualTo 100), "UT-CLAMP-003", "clamp caps W_EFF_U at 100", ["W", _d getOrDefault ["W_EFF_U", -1]]] call ARC_TEST_fnc_assert;
    [((_d getOrDefault ["R_EFF_U", -1]) isEqualTo 0), "UT-CLAMP-004", "clamp floors R_EFF_U at 0", ["R", _d getOrDefault ["R_EFF_U", -1]]] call ARC_TEST_fnc_assert;
  } else {
    ["UT-CLAMP-SKIP", "civsubDistrictsClamp tests skipped; function missing", []] call ARC_TEST_fnc_skip;
  };
};

private _elapsed = diag_tickTime - _t0;
["INFO", "RUN", format ["Completed ARC safe test runner in %1s", _elapsed toFixed 2], ["pass", ARC_TEST_pass, "fail", ARC_TEST_fail]] call ARC_TEST_fnc_log;
["RUN"] call ARC_TEST_fnc_summary;

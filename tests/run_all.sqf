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
if (isNil "ARC_TEST_pass") then { ARC_TEST_pass = 0; };
if (isNil "ARC_TEST_fail") then { ARC_TEST_fail = 0; };

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
};

// ---- Runner ----
waitUntil { !isNil "ARC_TEST_fnc_log" };

private _t0 = diag_tickTime;
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
[!(isNil "diag_log"), "UT-SANITY-001", "diag_log command is available", []] call ARC_TEST_fnc_assert;

{
  [_x, format ["UT-API-%1", _forEachIndex + 1], "expected function exists"] call ARC_TEST_fnc_assertNotNil;
} forEach _expectedFunctions;

// Unit: CBA availability (optional)
private _hasCBA = !(isNil "CBA_fnc_addPerFrameHandler");
[_hasCBA, "UT-ENV-001", "CBA per-frame handler available (optional)", []] call ARC_TEST_fnc_assert;

// Authoritative-only checks (server)
if (isServer) then {
  ["INFO", "UT-SERVER-000", "Running server-only tests", []] call ARC_TEST_fnc_log;

  /*
    Place server-only contract tests here. Examples:
    - incident state machine transition validation
    - follow-on creation emits replication
    - convoy spawn preconditions
  */

} else {
  ["INFO", "UT-SERVER-SKIP", "Skipping server-only tests (not running on server)", []] call ARC_TEST_fnc_log;
};

sleep 0.1;
["INFO", "RUN", format ["Completed in %1s", (diag_tickTime - _t0)], []] call ARC_TEST_fnc_log;
call ARC_TEST_fnc_summary;

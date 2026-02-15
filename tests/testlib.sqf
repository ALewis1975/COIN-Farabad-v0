/*
  ARC Test Library (drop-in)
  - Minimal assertion + logging helpers for Farabad COIN

  Usage:
    [] execVM "tests\\run_all.sqf";

  Output:
    RPT lines prefixed with [ARC][TEST]
*/

if (isNil "ARC_TEST_pass") then { ARC_TEST_pass = 0; };
if (isNil "ARC_TEST_fail") then { ARC_TEST_fail = 0; };

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

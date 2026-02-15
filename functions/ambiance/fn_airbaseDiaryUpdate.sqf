/*
    File: functions/ambiance/fn_airbaseDiaryUpdate.sqf
    Author: ARC / Ambient Airbase Subsystem

    Description:
      Client-side helper to create an "Airbase" diary subject and append queue snapshots.

    Params:
      0: STRING - record title
      1: STRING - record text (structured text / HTML)

    Notes:
      - Diary records cannot be edited in-place; we append new records when the queue changes.
*/

if (!hasInterface) exitWith {};
if (isNull player) exitWith {};

params ["_title", "_text"];
if (!(_title isEqualType "") || {!(_text isEqualType "")}) exitWith {};

private _subjId = "ARC_AIRBASE";

// Create subject once per client
if (isNil { missionNamespace getVariable "airbase_v1_diary_subject_created" }) then {
    player createDiarySubject [_subjId, "Airbase"];
    missionNamespace setVariable ["airbase_v1_diary_subject_created", true];
};

// De-dupe identical consecutive updates (helps when multiple ticks fire quickly)
private _last = missionNamespace getVariable ["airbase_v1_diary_lastText", ""];
if (_text isEqualTo _last) exitWith {};
missionNamespace setVariable ["airbase_v1_diary_lastText", _text];

// Append record
player createDiaryRecord [_subjId, [_title, _text]];

/*
    File: functions/ambiance/fn_airbaseDiaryUpdate.sqf
    Author: ARC / Ambient Airbase Subsystem

    Description:
      Client-side helper to create/update one rolling "Airbase" diary status record.

    Params:
      0: STRING - record title
      1: STRING - record text (structured text / HTML)

    Notes:
      - Uses setDiaryRecordText through a compiled helper for sqflint compatibility.
*/

if (!hasInterface) exitWith {};
if (isNull player) exitWith {};

params ["_title", "_text"];
if (!(_title isEqualType "") || {!(_text isEqualType "")}) exitWith {};

private _subjId = "ARC_AIRBASE";
private _recVar = "airbase_v1_diary_status_record";
private _setDiaryRecordTextCompat = compileFinal "
    params ['_unit', '_recordRef', '_recordText'];
    _unit setDiaryRecordText [_recordRef, _recordText];
";

// Create subject once per client; recreate if another briefing script resets diary subjects.
if ((isNil { missionNamespace getVariable "airbase_v1_diary_subject_created" }) || { !(player diarySubjectExists _subjId) }) then {
    player createDiarySubject [_subjId, "Airbase"];
    missionNamespace setVariable ["airbase_v1_diary_subject_created", true];
    player setVariable [_recVar, diaryRecordNull];
};

private _rec = player getVariable [_recVar, diaryRecordNull];
if (_rec isEqualTo diaryRecordNull) then {
    _rec = player createDiaryRecord [_subjId, [_title, _text]];
    player setVariable [_recVar, _rec];
};

// If we still don't have a valid record handle (subject not visible yet, briefing
// mid-rebuild, etc.), clear the dedupe cache so the next tick retries record creation
// instead of short-circuiting on a stale "lastText" match.
if (_rec isEqualTo diaryRecordNull) exitWith {
    missionNamespace setVariable ["airbase_v1_diary_lastText", ""];
};

// De-dupe identical consecutive updates (helps when multiple ticks fire quickly)
private _last = missionNamespace getVariable ["airbase_v1_diary_lastText", ""];
if (_text isEqualTo _last) exitWith {};
missionNamespace setVariable ["airbase_v1_diary_lastText", _text];

if (!(_rec isEqualTo diaryRecordNull)) then {
    [player, [_subjId, _rec], [_title, _text, ""]] call _setDiaryRecordTextCompat;
};

/*
    Client-side: create (or re-create) custom diary subjects + records, and keep them updated.

    Subjects:
      - ARC_OPS    : tasking + active incident dashboard
      - ARC_INTEL  : intel feed (player + virtual)
      - ARC_SITREP : high-level situation summary

    Notes:
      - Diary commands are local, so this runs on each client.
      - Some modsets/scripts rebuild briefing/diary subjects after init.
        This function is idempotent and will recreate missing subjects/records
        without duplicating the update loop.

    See:
      - createDiarySubject
      - createDiaryRecord
      - setDiaryRecordText
*/

if (!hasInterface) exitWith {false};

// Ensure subjects exist (IDs remain stable; titles are what players see).
private _ensureSubject = {
    params ["_id", "_title"];
    if !(player diarySubjectExists _id) then
    {
        player createDiarySubject [_id, _title, ""];
    };
};

["ARC_OPS", "OPS"] call _ensureSubject;
["ARC_INTEL", "INTEL"] call _ensureSubject;
["ARC_SITREP", "SITREP"] call _ensureSubject;

// Ensure records exist (store handles so update can set text).
private _ensureRecord = {
    params ["_varName", "_subject", "_title", "_initText"];

    private _rec = player getVariable [_varName, diaryRecordNull];
    if (_rec isEqualTo diaryRecordNull) then
    {
        _rec = player createDiaryRecord [_subject, [_title, _initText]];
        player setVariable [_varName, _rec];
    };

    _rec
};

["ARC_diary_rec_ops", "ARC_OPS", "OPS Dashboard", "Initializing..."] call _ensureRecord;
["ARC_diary_rec_intel", "ARC_INTEL", "Intel Feed", "Initializing..."] call _ensureRecord;
["ARC_diary_rec_sitrep", "ARC_SITREP", "SITREP", "Initializing..."] call _ensureRecord;
["ARC_diary_rec_opord", "Diary", "OPORD", "Initializing..."] call _ensureRecord;
["ARC_diary_rec_orbat", "Diary", "ORBAT", "Initializing..."] call _ensureRecord;
// SOI (Signal Operating Instructions) integrated into the same Diary schema as OPORD/ORBAT.
["ARC_diary_rec_soi", "Diary", "SOI", "Initializing..."] call _ensureRecord;

// Compatibility flag (older code used this gate). Keep, but do not rely on it.
player setVariable ["ARC_briefingInit_done", true];

// Start a single update loop per client.
if !(player getVariable ["ARC_briefingUpdateLoop_started", false]) then
{
    player setVariable ["ARC_briefingUpdateLoop_started", true];

    [] spawn
    {
        while {hasInterface} do
        {
            [] call ARC_fnc_briefingUpdateClient;
            uiSleep 10;
        };
    };
};

[] call ARC_fnc_briefingUpdateClient;

// Lightweight task timers HUD (does not overwrite hints)
[] call ARC_fnc_uiTaskTimersInitClient;
true

/*
    Client-side: hard reset the ARC diary records.

    Why:
    - Server-side persistence/task resets can leave clients with stale diary text.
    - Some modsets/scripts rebuild diary UI elements during init/JIP.

    What this does:
    - Removes the current ARC record handles (if present)
    - Forces ARC_fnc_briefingInitClient / ARC_fnc_briefingUpdateClient to recreate them

    Records covered:
      - ARC_OPS    : OPS Dashboard
      - ARC_INTEL  : Intel Feed
      - ARC_SITREP : SITREP
      - Diary      : OPORD / ORBAT / SOI
*/

if (!hasInterface) exitWith {false};

// Cancel any pending map-click intel logging
missionNamespace setVariable ["ARC_pendingIntelCategory", nil];
missionNamespace setVariable ["ARC_pendingIntelSummary", nil];
missionNamespace setVariable ["ARC_pendingIntelDetails", nil];

private _eh = missionNamespace getVariable ["ARC_pendingIntelMapEH", -1];
if (_eh isEqualType 0 && { _eh >= 0 }) then
{
    removeMissionEventHandler ["MapSingleClick", _eh];
};
missionNamespace setVariable ["ARC_pendingIntelMapEH", -1];

// Cancel any pending map-click lead request placement
private _leh = missionNamespace getVariable ["ARC_pendingLeadReqMapEH", -1];
if (_leh isEqualType 0 && { _leh >= 0 }) then
{
    removeMissionEventHandler ["MapSingleClick", _leh];
};
missionNamespace setVariable ["ARC_pendingLeadReqMapEH", -1];

missionNamespace setVariable ["ARC_lastLeadReqType", nil];
missionNamespace setVariable ["ARC_lastLeadReqSummary", nil];
missionNamespace setVariable ["ARC_lastLeadReqDetails", nil];
missionNamespace setVariable ["ARC_lastLeadReqConfidence", nil];
missionNamespace setVariable ["ARC_lastLeadReqStrength", nil];
missionNamespace setVariable ["ARC_lastLeadReqTTL", nil];

// Legacy cleanup (older builds used onMapSingleClick)
onMapSingleClick "";

private _removeRecord = {
    params ["_subject", "_varName"];

    private _old = player getVariable [_varName, diaryRecordNull];
    if !(_old isEqualTo diaryRecordNull) then
    {
        player removeDiaryRecord [_subject, _old];
    };

    player setVariable [_varName, diaryRecordNull];
};

["ARC_OPS",   "ARC_diary_rec_ops"] call _removeRecord;
["ARC_INTEL", "ARC_diary_rec_intel"] call _removeRecord;
["ARC_SITREP","ARC_diary_rec_sitrep"] call _removeRecord;

["Diary", "ARC_diary_rec_opord"] call _removeRecord;
["Diary", "ARC_diary_rec_orbat"] call _removeRecord;
["Diary", "ARC_diary_rec_soi"] call _removeRecord;

// Recreate + refresh immediately
[] call ARC_fnc_briefingInitClient;
[] call ARC_fnc_briefingUpdateClient;

// Follow-up refreshes to smooth over network/JIP ordering edge cases
[] spawn { uiSleep 0.5; [] call ARC_fnc_briefingUpdateClient; };
[] spawn { uiSleep 2;   [] call ARC_fnc_briefingUpdateClient; };

true

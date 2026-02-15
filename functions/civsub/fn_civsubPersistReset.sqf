/*
    ARC_fnc_civsubPersistReset

    Phase 6: Reset CIVSUB persistence + (if enabled) rebuild fresh in-memory state.

    Intended for controlled testing and schema/district-table changes.
    It resets CIVSUB profileNamespace keys even if CIVSUB is currently disabled.

    Params: none

    Returns: BOOL
*/

if (!isServer) exitWith {false};

private _enabled = missionNamespace getVariable ["civsub_v1_enabled", false];
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = false; };

// Clear persisted blob
profileNamespace setVariable ["FARABAD_CIVSUB_V1_STATE", ""];

// New campaign id
private _cid = [] call ARC_fnc_civsubUuid;
profileNamespace setVariable ["FARABAD_CIVSUB_V1_CAMPAIGN_ID", _cid];

saveProfileNamespace;

if (!_enabled) exitWith
{
    diag_log format ["[CIVSUB][PERSIST] Reset persisted blob only (CIVSUB disabled). campaign_id=%1", _cid];
    true
};

// Fresh in-memory state
private _districts = [] call ARC_fnc_civsubDistrictsCreateDefaults;
missionNamespace setVariable ["civsub_v1_districts", _districts, true];
missionNamespace setVariable ["civsub_v1_identities", createHashMap, true];
missionNamespace setVariable ["civsub_v1_crimedb", createHashMap, true];
missionNamespace setVariable ["civsub_v1_identity_seq", 0, true];

// Re-init dependent subsystems
[] call ARC_fnc_civsubIdentityInit;
[] call ARC_fnc_civsubCrimeDbInit;

// Save immediately so reset survives a restart
[] call ARC_fnc_civsubPersistSave;

diag_log format ["[CIVSUB][PERSIST] Reset complete. campaign_id=%1 districts=%2", _cid, count (keys _districts)];

true

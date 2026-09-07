/*
    ARC_fnc_stateLoad

    Loads persisted ARC_state from missionProfileNamespace and merges onto defaults.

    Defensive/sanitizing loader:
      - Accepts only entries shaped like ["key", value]
      - Discards invalid entries silently
      - Drops nil-valued entries (nil is unsupported for persisted state)
      - Never indexes into unknown types

    Nil policy:
      - `nil` is never persisted. Use empty substitutes instead (`false`, "", [], 0,
        createHashMap, etc.) when a key should remain defined.

    Storage key: missionProfileNamespace getVariable ["ARC_state", ...]

    Debug:
      missionNamespace setVariable ["ARC_debugState", true];
*/

if (!isServer) exitWith { false };

private _defaults = [] call ARC_fnc_stateInit;
if !(_defaults isEqualType []) then { _defaults = []; };

private _raw = missionProfileNamespace getVariable ["ARC_state", []];
private _rawCheck = [_raw, "ARRAY_SHAPE", "ARC_state(profile)", [[], 0, -1, true]] call ARC_fnc_paramAssert;
private _rawOk = _rawCheck param [0, false];
_raw = _rawCheck param [1, []];
if (!_rawOk) then {
    ["STATE", format ["stateLoad guard: code=%1 msg=%2", _rawCheck param [2, "ARC_ASSERT_UNKNOWN"], _rawCheck param [3, "ARC_state(profile) invalid"]], ["code", _rawCheck param [2, "ARC_ASSERT_UNKNOWN"], "guard", "stateLoad", "key", "ARC_state"]] call ARC_fnc_farabadWarn;
};

// Sanitize raw persisted entries
	private _clean = [];
	private _droppedNil = false;
	{
	    if !(_x isEqualType []) then { continue; };

	    private _entryCount = count _x;
	    if (_entryCount < 2) then { continue; };

	    private _k = _x param [0, "", [""]];
	    if (_k isEqualTo "") then { continue; };

	    // NOTE: A stored value can be `nil` (e.g., due to earlier script errors or
	    // legacy code using nil as a "clear" signal). Assigning nil to a variable
	    // *undefines* it in SQF, which can cascade into "Undefined variable" errors.
	    // We treat nil as "drop this entry" during load.
	    if (isNil { _x select 1 }) then
	    {
	        _droppedNil = true;
	        [
	            "STATE",
	            format ["stateLoad dropped nil persisted value for key '%1'", _k],
	            ["key", _k]
	        ] call ARC_fnc_farabadWarn;
	    }
	    else
	    {
	        private _v = _x select 1;
	        _clean pushBack [_k, _v];
	    };
	} forEach _raw;

// Clock v1: freeze offline progression and translate into this process clock.
// The current legacy saver stamps s1RegistryUpdatedAt on every write, so it is
// an exact legacy anchor, not an inferred activity timestamp.
private _clockIndex = -1;
{ if ((_x select 0) isEqualTo "persistenceClock") exitWith { _clockIndex = _forEachIndex; }; } forEach _clean;
private _clock = if (_clockIndex < 0) then {[]} else {(_clean select _clockIndex) select 1};
private _hasClock = !(_clock isEqualTo []);
private _clockOk = !_hasClock || {
    _clock isEqualType [] && {count _clock >= 4} && {(_clock select 0) isEqualTo 1} &&
    {(_clock select 1) isEqualType 0} && {(_clock select 1) >= 0} &&
    {(_clock select 3) isEqualTo "FREEZE_OFFLINE"}
};
if (!_clockOk) exitWith {
    missionNamespace setVariable ["ARC_persistenceClockBlocked", true];
    diag_log "[ARC][PERSIST][ERROR] Unsupported clock schema; campaign load/save blocked; profile preserved.";
    false
};
private _now = serverTime;
private _savedAt = if (_hasClock) then {_clock select 1} else {-1};
if (_savedAt < 0) then {
    private _legacyIndex = -1;
    { if ((_x select 0) isEqualTo "s1RegistryUpdatedAt") exitWith { _legacyIndex = _forEachIndex; }; } forEach _clean;
    if (_legacyIndex >= 0) then {
        private _candidate = (_clean select _legacyIndex) select 1;
        if (_candidate isEqualType 0 && {_candidate >= 0}) then {_savedAt = _candidate};
    };
};
// Older-than-current saves without any anchor cannot be translated honestly.
// Preserve their data for an explicit operator migration instead of inventing time.
if (_savedAt < 0 && {count _clean > 0}) exitWith {
    missionNamespace setVariable ["ARC_persistenceClockBlocked", true];
    diag_log "[ARC][PERSIST][ERROR] Legacy ARC_state lacks a save-clock anchor; profile preserved; supply a verified persistenceClock before loading.";
    false
};
if (_savedAt < 0) then {_savedAt = _now};
if (!_hasClock && {count _clean > 0} && {isNil {missionProfileNamespace getVariable "ARC_state_preClockV1"}}) then {
    missionProfileNamespace setVariable ["ARC_state_preClockV1", _raw];
};
_clean = [_clean, _savedAt, _now] call ARC_fnc_stateRebaseClock;
missionNamespace setVariable ["ARC_persistenceClockBlocked", false];
// Runtime workers never survive a restore; new work must reserve current IDs.
{
    private _worker = missionNamespace getVariable [_x, scriptNull];
    if (_worker isEqualType scriptNull && {!scriptDone _worker}) then {terminate _worker};
    missionNamespace setVariable [_x, scriptNull];
} forEach ["threat_v0_drivenWorker", "threat_v0_suicideWorker"];
missionNamespace setVariable ["threat_v0_drivenPending", []];
missionNamespace setVariable ["ARC_persistenceClockSnapshot", [1, _savedAt, _now, "FREEZE_OFFLINE", !_hasClock]];
diag_log format ["[ARC][PERSIST] ts=%1 actor=SERVER id=ARC_state grid=N/A clock=1 savedAt=%2 policy=FREEZE_OFFLINE legacy=%3", _now, _savedAt, !_hasClock];

// Merge: start with defaults, then apply overrides from _clean
private _merged = +_defaults;
	{
	    // Safe extraction (never assign nil into a variable)
	    private _k = _x select 0;
	    private _v = _x select 1;
    private _idx = -1;
    for "_i" from 0 to ((count _merged) - 1) do
    {
        private _e = _merged select _i;
        if (_e isEqualType [] && { (count _e) >= 2 } && { (_e select 0) isEqualTo _k }) exitWith
        {
            _idx = _i;
        };
    };

	    if (_idx < 0) then
	    {
	        _merged pushBack [_k, _v];
	    }
	    else
	    {
	        (_merged select _idx) set [1, _v];
	    };
} forEach _clean;

missionNamespace setVariable ["ARC_state", _merged];

	// If we dropped nil entries, rewrite the profile state once to prevent the same
	// load-time errors from recurring across restarts.
	if (_droppedNil) then
	{
	    [
	        "STATE",
	        "stateLoad detected nil persisted values; rewriting sanitized ARC_state profile payload",
	        ["storageKey", "ARC_state"]
	    ] call ARC_fnc_farabadWarn;

	    [] call ARC_fnc_stateSave;
	};

if (missionNamespace getVariable ["ARC_debugState", false]) then
{
    diag_log format ["[ARC][STATE] stateLoad raw=%1 clean=%2 defaults=%3 merged=%4", count _raw, count _clean, count _defaults, count _merged];
};

true

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

	    missionProfileNamespace setVariable ["ARC_state", _merged];
	    saveMissionProfileNamespace;
	};

if (missionNamespace getVariable ["ARC_debugState", false]) then
{
    diag_log format ["[ARC][STATE] stateLoad raw=%1 clean=%2 defaults=%3 merged=%4", count _raw, count _clean, count _defaults, count _merged];
};

true

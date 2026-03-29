/*
    ARC_fnc_consoleVmAdapterV1

    Client-side: reads the published Console VM v1 envelope from missionNamespace
    and provides safe accessors for UI paint functions.

    This is the Phase A "observe" adapter. It reads the server-published VM payload
    but still allows legacy fallback to direct ARC_pub_* reads when the VM is not
    available or stale.

    Reference: docs/architecture/Console_VM_v1.md

    Params:
        0: STRING - section name (e.g. "incident", "ops", "stateSummary", "followOn",
                    "access", "civsub")
        1: STRING - key within section (optional; if empty, returns entire section)
        2: ANY    - default value if key not found

    Returns:
        ANY - value from VM section, or _default if unavailable
*/

params [
    ["_section", "", [""]],
    ["_key", "", [""]],
    ["_default", nil]
];

// sqflint-compatible helpers
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _trimFn = compile "params ['_s']; trim _s";

if (_section isEqualTo "") exitWith { _default };

// Read the published VM envelope from missionNamespace
private _vm = missionNamespace getVariable ["ARC_consoleVM_payload", []];

// Validate envelope shape
if (!(_vm isEqualType [])) exitWith {
    _default
};

// Find sections entry
private _sections = nil;
{
    if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "sections" }) exitWith {
        _sections = _x select 1;
    };
} forEach _vm;

if (isNil "_sections") exitWith { _default };
if (!(_sections isEqualType createHashMap)) exitWith { _default };

// Get requested section
private _sec = [_sections, _section, []] call _hg;

// If no specific key requested, return entire section
if (_key isEqualTo "") exitWith { _sec };

// Find key within section (pairs array format)
if (_sec isEqualType []) then {
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith {
            _default = _x select 1;
        };
    } forEach _sec;
};

_default

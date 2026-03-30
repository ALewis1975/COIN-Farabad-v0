/*
    ARC_fnc_consoleVmAdapterV1

    Client-side adapter for the ARC_ConsoleVM_v1 payload.

    Reads a named key from a named section of ARC_consoleVM_payload with a
    safe default fallback (nil / type mismatch → default).

    Params:
      0: STRING - section name ("incident"|"followOn"|"ops"|"stateSummary"|"access"|"civsub")
      1: STRING - key name within section data
      2: ANY    - default value returned when key is absent or type mismatches

    Returns:
      ANY — value for the key, or the default

    Usage example:
      private _taskId = ["incident", "task_id", ""] call ARC_fnc_consoleVmAdapterV1;
      private _fuel   = ["stateSummary", "base_fuel", 0.68] call ARC_fnc_consoleVmAdapterV1;

    Note: this adapter is available for future tab migrations. Existing tab paint
    functions still read ARC_pub_* directly and are not yet using this adapter.
*/

if (!hasInterface) exitWith { (_this select 2) };

params [
    ["_sectionName", "", [""]],
    ["_key",         "", [""]],
    ["_default",     nil]
];

if (_sectionName isEqualTo "" || { _key isEqualTo "" }) exitWith { _default };

private _payload = missionNamespace getVariable ["ARC_consoleVM_payload", []];
if (!(_payload isEqualType [])) exitWith { _default };
if (_payload isEqualTo []) exitWith { _default };

// Find "sections" key in payload
private _sections = [];
{
    if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "sections" }) exitWith {
        _sections = _x select 1;
    };
} forEach _payload;

if (!(_sections isEqualType []) || { _sections isEqualTo [] }) exitWith { _default };

// Find the named section
private _sectionData = [];
{
    if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _sectionName }) exitWith {
        private _sec = _x select 1;
        if (_sec isEqualType []) then
        {
            {
                if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo "data" }) exitWith {
                    _sectionData = _x select 1;
                };
            } forEach _sec;
        };
    };
} forEach _sections;

if (!(_sectionData isEqualType []) || { _sectionData isEqualTo [] }) exitWith { _default };

// Find the key within section data
private _value = _default;
{
    if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith {
        _value = _x select 1;
    };
} forEach _sectionData;

_value

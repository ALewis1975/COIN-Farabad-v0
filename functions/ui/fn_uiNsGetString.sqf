/*
    ARC_fnc_uiNsGetString

    Reads a uiNamespace string with type validation and self-healing.
*/

params [
    ["_key", "", [""]],
    ["_default", "", [""]],
    ["_normalize", true, [true]]
];


// sqflint-compatible helpers
private _trimFn  = compile "params ['_s']; trim _s";
private _value = uiNamespace getVariable [_key, _default];

if !(_value isEqualType "") then
{
    [_key, "STRING", typeName _value] call ARC_fnc_uiNsWarnTypeMismatchOnce;
    _value = _default;
    uiNamespace setVariable [_key, _value];
};

if (_normalize) then
{
    _value = [_value] call _trimFn;
};

_value

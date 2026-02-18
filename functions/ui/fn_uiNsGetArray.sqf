/*
    ARC_fnc_uiNsGetArray

    Reads a uiNamespace array with type validation and self-healing.
*/

params [
    ["_key", "", [""]],
    ["_default", [], [[]]]
];

private _value = uiNamespace getVariable [_key, _default];

if !(_value isEqualType []) then
{
    [_key, "ARRAY", typeName _value] call ARC_fnc_uiNsWarnTypeMismatchOnce;
    _value = +_default;
    uiNamespace setVariable [_key, _value];
};

_value

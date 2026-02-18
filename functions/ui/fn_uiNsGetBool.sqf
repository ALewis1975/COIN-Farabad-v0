/*
    ARC_fnc_uiNsGetBool

    Reads a uiNamespace bool with type validation and self-healing.
*/

params [
    ["_key", "", [""]],
    ["_default", false, [true]]
];

private _value = uiNamespace getVariable [_key, _default];

if (!(_value isEqualType true) && !(_value isEqualType false)) then
{
    [_key, "BOOL", typeName _value] call ARC_fnc_uiNsWarnTypeMismatchOnce;
    _value = _default;
    uiNamespace setVariable [_key, _value];
};

_value

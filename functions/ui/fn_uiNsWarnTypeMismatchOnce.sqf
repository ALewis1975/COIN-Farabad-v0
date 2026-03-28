/*
    ARC_fnc_uiNsWarnTypeMismatchOnce

    Emits a type-mismatch warning at most once per client session for a given
    uiNamespace key and expected type label.
*/

params [
    ["_key", "", [""]],
    ["_expected", "", [""]],
    ["_actual", "", [""]]
];

if (_key isEqualTo "" || { _expected isEqualTo "" }) exitWith {false};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _warned = uiNamespace getVariable ["ARC_uiNs_typeWarned", createHashMap];
if !(_warned isEqualType createHashMap) then
{
    _warned = createHashMap;
    uiNamespace setVariable ["ARC_uiNs_typeWarned", _warned];
};

private _token = format ["%1|%2", _key, _expected];
if ([_warned, _token, false] call _hg) exitWith {false};

_warned set [_token, true];
uiNamespace setVariable ["ARC_uiNs_typeWarned", _warned];

diag_log format [
    "[ARC][WARN] uiNamespace key '%1' had invalid type (%2), expected %3; reset to default.",
    _key,
    _actual,
    _expected
];

true

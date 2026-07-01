/*
    ARC_fnc_stateGet

    Safe get from mission state.

    Usage:
      ["key", _default] call ARC_fnc_stateGet;
      "key" call ARC_fnc_stateGet;   // default nil
*/

private _key = "";
private _hasDefault = false;
private _default = objNull;

// Normalize input
switch (true) do
{
    case (_this isEqualType []):
    {
        _key = _this param [0, "", [""]];
        if ((count _this) > 1 && { !(isNil { _this select 1 }) }) then
        {
            _default = _this select 1;
            _hasDefault = true;
        };
    };
    case (_this isEqualType ""):
    {
        _key = _this;
    };
    default
    {
        _key = "";
    };
};

private _returnDefault = {
    if (_hasDefault) exitWith { _default };
    nil
};

if (_key isEqualTo "") exitWith { call _returnDefault };

private _state = missionNamespace getVariable ["ARC_state", []];
if !(_state isEqualType []) exitWith { call _returnDefault };

private _val = call _returnDefault;
{
    if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith
    {
        _val = _x select 1;
    };
} forEach _state;

_val
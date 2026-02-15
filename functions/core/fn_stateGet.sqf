/*
    ARC_fnc_stateGet

    Safe get from mission state.

    Usage:
      ["key", _default] call ARC_fnc_stateGet;
      "key" call ARC_fnc_stateGet;   // default nil
*/

private _key = "";
private _default = nil;

// Normalize input
switch (true) do
{
    case (_this isEqualType []):
    {
        _key = _this param [0, "", [""]];
        _default = _this param [1, nil];
    };
    case (_this isEqualType ""):
    {
        _key = _this;
        _default = nil;
    };
    default
    {
        _key = "";
        _default = nil;
    };
};

if (_key isEqualTo "") exitWith { _default };

private _state = missionNamespace getVariable ["ARC_state", []];
if !(_state isEqualType []) exitWith { _default };

private _val = _default;
{
    if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith
    {
        _val = _x select 1;
    };
} forEach _state;

_val

/*
    ARC_fnc_stateSetGet

    Compatibility wrapper for older iterations that referenced ARC_fnc_stateSetGet.

    This file exists to prevent mission-load errors and is intentionally defensive.

    GET:
      ["key", _default] call ARC_fnc_stateSetGet;
      "key" call ARC_fnc_stateSetGet;

    SET (explicit):
      ["key", _value, true] call ARC_fnc_stateSetGet; // third arg true => SET

    Returns:
      - GET: stored value or default
      - SET: true on success, false otherwise
*/

private _args = _this;
if !(_args isEqualType []) then { _args = [_args]; };

private _key = _args param [0, "", [""]];
if (_key isEqualTo "") exitWith { nil };

private _doSet = false;
if ((count _args) >= 3) then
{
    _doSet = _args param [2, false, [false]];
};

if (_doSet) then
{
    private _value = _args param [1, nil];

    if !(isNil "ARC_fnc_stateSet") exitWith
    {
        [_key, _value] call ARC_fnc_stateSet
    };

    // Fallback if stateSet is not registered
    private _state = missionNamespace getVariable ["ARC_state", []];
    if !(_state isEqualType []) then { _state = []; };

    private _idx = -1;
    for "_i" from 0 to ((count _state) - 1) do
    {
        private _e = _state select _i;
        if (_e isEqualType [] && { (count _e) >= 2 } && { (_e select 0) isEqualTo _key }) exitWith
        {
            _idx = _i;
        };
    };

    if (_idx < 0) then
    {
        _state pushBack [_key, _value];
    }
    else
    {
        (_state select _idx) set [1, _value];
    };

    missionNamespace setVariable ["ARC_state", _state];
    true
}
else
{
    private _default = _args param [1, nil];

    if !(isNil "ARC_fnc_stateGet") exitWith
    {
        [_key, _default] call ARC_fnc_stateGet
    };

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
};

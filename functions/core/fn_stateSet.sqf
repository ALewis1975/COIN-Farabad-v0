/*
    ARC_fnc_stateSet

    Safe set into mission state.

    Usage:
      ["key", value] call ARC_fnc_stateSet;

    This function is defensive and will not throw on malformed inputs.

    Persisted-value policy:
      - `nil` is unsupported as a stored state value. Passing nil clears/removes the key.
      - Use explicit empty substitutes when a key should stay defined (`false`, "", [], 0,
        createHashMap, etc.).
*/

if !(_this isEqualType []) exitWith { false };
if ((count _this) < 2) exitWith { false };

	private _key = _this param [0, "", [""]];

if (_key isEqualTo "") exitWith { false };

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

	// NOTE: Assigning `nil` to a variable *undefines* it in SQF. We treat nil as a
	// "clear key" request rather than persisting nil into state.
	if (isNil { _this select 1 }) then
	{
	    // Clear/remove the key if it exists.
	    if (_idx >= 0) then { _state deleteAt _idx; };
	}
	else
	{
	    private _value = _this select 1;
	    if (_idx < 0) then
	    {
	        _state pushBack [_key, _value];
	    }
	    else
	    {
	        (_state select _idx) set [1, _value];
	    };
	};

missionNamespace setVariable ["ARC_state", _state];
true

/*
    Pure CIVSUB persistence envelope clock v1 migration.
    Keeps every district/identity/crime tuple and the v1 domain schema intact.
    [] means unsupported/malformed clock; callers must preserve the profile.
*/
params [["_state", [], [[]]], ["_now", 0, [0]]];
// CIVSUB's existing serialized representation contains only simple arrays.
private _clone = {
    params ["_value"];
    if (_value isEqualType []) exitWith {_value apply {[_x] call _clone}};
    _value
};
private _out = [_state] call _clone;
private _ci = -1;
{ if (_x isEqualType [] && {count _x >= 2} && {(_x select 0) isEqualTo "persistenceClock"}) exitWith { _ci = _forEachIndex; }; } forEach _out;
private _clock = if (_ci < 0) then {[]} else {(_out select _ci) select 1};
private _legacy = _clock isEqualTo [];
private _valid = _legacy || {
    _clock isEqualType [] && {count _clock >= 4} && {(_clock select 0) isEqualTo 1} &&
    {(_clock select 1) isEqualType 0} && {(_clock select 1) >= 0} &&
    {(_clock select 3) isEqualTo "FREEZE_OFFLINE"}
};
if (!_valid) exitWith {[]};
private _savedAt = if (_legacy) then {_now} else {_clock select 1};
private _delta = _now - _savedAt;
private _stamp = {
    params ["_v"];
    if !(_v isEqualType 0) exitWith {_v};
    if (_legacy) exitWith {0};
    _v + _delta
};
private _deadline = {
    params ["_v", "_legacyMax"];
    if !(_v isEqualType 0) exitWith {0};
    if (_v <= 0) exitWith {_v};
    if (_legacy) exitWith {_now + (_v min _legacyMax)};
    (_now + ((_v - _savedAt) max 0)) max 0.001
};
{
    _x params ["_key", "_rows"];
    switch (_key) do {
        case "districts": {
            {
                if (_x isEqualType [] && {count _x >= 16}) then {
                    _x set [13, [_x select 13, 3600] call _deadline];
                    _x set [14, [_x select 14, 1800] call _deadline];
                    _x set [15, [_x select 15] call _stamp];
                };
            } forEach _rows;
        };
        case "identities": {
            {
                private _row = _x;
                if (_row isEqualType [] && {count _row >= 17}) then {
                    {if (count _row > _x) then {_row set [_x, [_row select _x] call _stamp]}} forEach [16,18,21,23];
                    private _seen = _row select 15;
                    if (_seen isEqualType []) then {
                        {
                            if (_x isEqualType [] && {count _x >= 4}) then {
                                _x set [1, [_x select 1] call _stamp];
                                _x set [2, [_x select 2] call _stamp];
                            };
                        } forEach _seen;
                    };
                };
            } forEach _rows;
        };
        case "crimedb": {
            {
                if (_x isEqualType [] && {count _x >= 8}) then {
                    _x set [6, [_x select 6] call _stamp];
                    private _history = _x select 7;
                    if (_history isEqualType []) then {
                        {if (_x isEqualType [] && {count _x >= 2}) then {_x set [1, [_x select 1] call _stamp]}} forEach _history;
                    };
                };
            } forEach _rows;
        };
    };
} forEach (_out select {_x isEqualType [] && {count _x >= 2} && {(_x select 1) isEqualType []}});
private _newClock = ["persistenceClock", [1, _now, _clock param [2, []], "FREEZE_OFFLINE"]];
if (_ci < 0) then {_out pushBack _newClock} else {_out set [_ci, _newClock]};
_out

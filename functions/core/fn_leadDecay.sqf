/* Pure confidence evaluation. Preserve the 12-field lead tuple and metadata. */
params [["_entry", [], [[]]], ["_now", 0, [0]], ["_rate", 0.6, [0]], ["_floor", 0.05, [0]]];
if (count _entry < 7) exitWith {_entry};
private _strength = _entry select 4;
private _expires = _entry select 6;
if !(_strength isEqualType 0 && {_expires isEqualType 0} && {_expires > 0}) exitWith {_entry};
private _out = +_entry;
// Pre-metadata legacy tuples are padded only to the existing current 12 fields.
while {count _out < 11} do {_out pushBack ""};
if (count _out < 12) then {_out pushBack []};
private _meta = _out select 11;
if !(_meta isEqualType []) then {_meta = []} else {_meta = +_meta};
private _get = {
    params ["_key", "_default"];
    private _i = -1;
    { if (_x isEqualType [] && {count _x >= 2} && {(_x select 0) isEqualTo _key}) exitWith { _i = _forEachIndex; }; } forEach _meta;
    if (_i < 0) exitWith {_default};
    (_meta select _i) select 1
};
private _version = ["leadDecayV", 0] call _get;
private _original = ["leadDecayStrength", _strength] call _get;
private _startedAt = ["leadDecayStartedAt", _now] call _get;
private _ttl = ["leadDecayTtl", (_expires - _now) max 0] call _get;
private _valid = _version isEqualTo 1 && {_original isEqualType 0} && {_startedAt isEqualType 0} && {_ttl isEqualType 0};
if (!_valid) then {
    // A legacy lead may already be decayed. Adopt today's strength instead of
    // reapplying total-age decay or inventing the original confidence.
    _original = _strength;
    _startedAt = _now;
    _ttl = (_expires - _now) max 0;
    _meta = _meta select {!(_x isEqualType [] && {count _x >= 1} && {(_x select 0) in ["leadDecayV","leadDecayStrength","leadDecayStartedAt","leadDecayTtl"]})};
    _meta append [["leadDecayV",1],["leadDecayStrength",_original],["leadDecayStartedAt",_startedAt],["leadDecayTtl",_ttl]];
};
_out set [11, _meta];
if (_ttl <= 0) exitWith {_out};
private _ageFraction = (((_now - _startedAt) max 0) / _ttl) min 1;
_rate = (_rate max 0) min 1;
_floor = (_floor max 0) min 0.5;
private _minimum = (_original * (1 - _rate)) max _floor;
private _value = (_original - ((_original - _minimum) * _ageFraction)) max _floor;
_out set [4, _value min _original];
_out

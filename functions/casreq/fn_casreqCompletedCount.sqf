// Engine-compatible command wrappers retain the repository lint baseline.
private _casDefault = compile "params ['_map','_args']; _map getOrDefault _args";
private _casMap = compile "params ['_pairs']; createHashMapFromArray _pairs";
/* Terminal detail retention must not reduce the campaign's completed CAS count. */
if (!isServer) exitWith {0};
private _n = ["casreq_v1_archived_completed", 0] call ARC_fnc_stateGet;
if !(_n isEqualType 0) then {_n = 0};
private _records = ["casreq_v1_records", createHashMap] call ARC_fnc_stateGet;
private _casKeys = compile "params ['_h']; keys _h";
private _casGet = compile "params ['_h','_k']; (_h) get _k";
if !(_records isEqualType createHashMap) exitWith {_n};
{
    private _row = [_records, _x] call _casGet;
    if (_row isEqualType []) then {
        private _r = ([_row] call _casMap);
        if ((([_r, ["state", ""]] call _casDefault)) isEqualTo "CLOSED" && {(([_r, ["result", ""]] call _casDefault)) isEqualTo "COMPLETE"}) then {_n = _n + 1};
    };
} forEach ([_records] call _casKeys);
_n

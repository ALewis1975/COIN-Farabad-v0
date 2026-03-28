/*
    ARC_fnc_civsubIdentityEvictIfNeeded

    Enforces the hard cap on persisted/touched identities.

    Params:
      0: cap (int) default 500

    Eviction rule (baseline): oldest-by-lastSeen.
    Phase 3 uses last_interaction_ts as the eviction clock.

    Returns: int (number evicted)
*/

if (!isServer) exitWith {0};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {0};

params [["_cap", 500, [0]]];
if (_cap < 1) exitWith {0};

private _ids = missionNamespace getVariable ["civsub_v1_identities", createHashMap];
if !(_ids isEqualType createHashMap) exitWith {0};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _keys = keys _ids;
private _cnt = count _keys;
if (_cnt <= _cap) exitWith {0};

private _rows = [];
{
    private _rec = _ids get _x;
    if !(_rec isEqualType createHashMap) then { continue; };
    private _ts = [_rec, "last_interaction_ts", 0] call _hg;
    _rows pushBack [_x, _ts];
} forEach _keys;

_rows sort true; // ascending by timestamp

private _need = (count _rows) - _cap;
private _evicted = 0;
for "_i" from 0 to (_need - 1) do {
    private _id = (_rows select _i) select 0;
    _ids deleteAt _id;
    _evicted = _evicted + 1;
};

missionNamespace setVariable ["civsub_v1_identities", _ids, true];
missionNamespace setVariable ["civsub_v1_identity_evictions", (missionNamespace getVariable ["civsub_v1_identity_evictions", 0]) + _evicted, true];

_evicted

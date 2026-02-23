/*
    ARC_fnc_civsubIdentityTouch

    Marks a civilian identity as "touched" and ensures it exists in persistence.

    Params:
      0: districtId (string) e.g. "D01"
      1: actorUid (string) e.g. getPlayerUID player (optional)
      2: civ_uid (string, optional; if empty, generated)
      3: homePos ([x,y,z], optional)

    Returns: HashMap identity record (created or updated)
*/

if (!isServer) exitWith {createHashMap};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {createHashMap};

params [
    ["_districtId", "", [""]],
    ["_actorUid", "", [""]],
    ["_civUid", "", [""]],
    ["_homePos", [0,0,0], [[]]]
];

// sqflint-compatible helper: getOrDefault is not recognised by sqflint 0.3.x static analyser.
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k,_d]";

if (_districtId isEqualTo "") exitWith {createHashMap};
if (_civUid isEqualTo "") exitWith {createHashMap};

private _ids = missionNamespace getVariable ["civsub_v1_identities", createHashMap];
// tolerate legacy array-of-pairs store
if (_ids isEqualType []) then { _ids = createHashMapFromArray _ids; };
if !(_ids isEqualType createHashMap) then { _ids = createHashMap; };

if (_civUid isEqualTo "") then {
    private _tmpUid = "";
    private _nilUid = isNil { _tmpUid = [_districtId] call ARC_fnc_civsubIdentityGenerateUid; };
    if (_nilUid || {_tmpUid isEqualTo ""}) exitWith { createHashMap };
    _civUid = _tmpUid;
};

private _rec = [_ids, _civUid, createHashMap] call _hg;
if !(_rec isEqualType createHashMap) then { _rec = createHashMap; };

if ((count (keys _rec)) == 0) then {
    private _tmpRec = createHashMap;
    private _nilRec = isNil { _tmpRec = [_civUid, _districtId, _homePos] call ARC_fnc_civsubIdentityGenerateProfile; };
    if (_nilRec || {!(_tmpRec isEqualType createHashMap)} || {(count _tmpRec) == 0}) exitWith { createHashMap };
    _rec = _tmpRec;
};

// Update seen_by ledger
if !(_actorUid isEqualTo "") then {
    private _seen = [_rec, "seen_by", createHashMap] call _hg;
    if !(_seen isEqualType createHashMap) then { _seen = createHashMap; };

    private _row = [_seen, _actorUid, [serverTime, serverTime, 0]] call _hg; // [first, last, count]
    if !(_row isEqualType []) then { _row = [serverTime, serverTime, 0]; };

    _row set [1, serverTime];
    _row set [2, (_row select 2) + 1];
    _seen set [_actorUid, _row];
    _rec set ["seen_by", _seen];
};

_rec set ["last_interaction_ts", serverTime];
_ids set [_civUid, _rec];
missionNamespace setVariable ["civsub_v1_identities", _ids, true];

// Enforce cap (best-effort)
isNil { [500] call ARC_fnc_civsubIdentityEvictIfNeeded; };

_rec

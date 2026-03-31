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

// sqflint-compatible helpers: operators not recognised by sqflint 0.3.x static analyser.
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k,_d]";
private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";
private _keysFn = compile "params ['_m']; keys _m";

if (_districtId isEqualTo "") exitWith {createHashMap};
if (_civUid isEqualTo "") exitWith {createHashMap};

private _ids = missionNamespace getVariable ["civsub_v1_identities", createHashMap];
// tolerate legacy array-of-pairs store
if (_ids isEqualType []) then { _ids = [_ids] call _hmCreate; };
if !(_ids isEqualType createHashMap) then { _ids = createHashMap; };

// Guard: generate UID if not supplied. Use a flag so the early-exit fires at
// function scope, not only inside the then-block (exitWith exits its enclosing
// block, which would be the then-clause, not this function).
private _civUidOk = true;
if (_civUid isEqualTo "") then {
    private _tmpUid = "";
    private _nilUid = isNil { _tmpUid = [_districtId] call ARC_fnc_civsubIdentityGenerateUid; _tmpUid };
    if (_nilUid || {_tmpUid isEqualTo ""}) then {
        _civUidOk = false;
    } else {
        _civUid = _tmpUid;
    };
};
if (!_civUidOk) exitWith {
    diag_log format ["[CIVSUB][WARN] fn_civsubIdentityTouch: UID generation failed did=%1", _districtId];
    createHashMap
};

private _rec = [_ids, _civUid, createHashMap] call _hg;
if !(_rec isEqualType createHashMap) then { _rec = createHashMap; };

// Guard: generate profile for new civilian. Same flag pattern — exitWith inside
// then-block would only exit that block, not the function.
private _profOk = true;
if ((count ([_rec] call _keysFn)) == 0) then {
    private _tmpRec = createHashMap;
    private _nilRec = isNil { _tmpRec = [_civUid, _districtId, _homePos] call ARC_fnc_civsubIdentityGenerateProfile; _tmpRec };
    if (_nilRec || {!(_tmpRec isEqualType createHashMap)} || {(count _tmpRec) == 0}) then {
        _profOk = false;
    } else {
        _rec = _tmpRec;
    };
};
if (!_profOk) exitWith {
    diag_log format ["[CIVSUB][WARN] fn_civsubIdentityTouch: profile generation failed civUid=%1 did=%2", _civUid, _districtId];
    createHashMap
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

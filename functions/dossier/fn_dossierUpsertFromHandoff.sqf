/*
    ARC_fnc_dossierUpsertFromHandoff

    Unified SHERIFF/SSE dossier: on detainee handoff at SHERIFF_HOLDING, build (or
    merge) one auditable record that joins CIVSUB identity (name/charges/wanted) with
    SSE/IED evidence captured for the active incident, then emits a confidence-weighted
    lead and publishes the dossier read model for field/TOC consoles + SITREP annex.

    Server-only. Persistence-safe: records are stored as array-of-pairs under the
    versioned state key dossier_v0_records (reset via ARC_fnc_resetAll).

    Params:
      0: OBJECT  _civ      detainee unit
      1: STRING  _civUid   detainee civ_uid
      2: STRING  _did      district id
      3: STRING  _actorUid handing-off player UID
      4: NUMBER  _wl       wanted level (fallback if record missing)
      5: HASHMAP _rec      identity record (may be empty)

    Returns:
      STRING dossierId ("" on failure / disabled)
*/

if (!isServer) exitWith {""};

params [
    ["_civ", objNull, [objNull]],
    ["_civUid", "", [""]],
    ["_did", "", [""]],
    ["_actorUid", "UNKNOWN", [""]],
    ["_wl", 0, [0]],
    ["_rec", createHashMap, [createHashMap]]
];

if (!(["dossier_v0_enabled", true] call ARC_fnc_stateGet)) exitWith {""};
if (_civUid isEqualTo "") exitWith {""};

private _hg     = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _keysFn = compile "params ['_h']; keys _h";

if !(_rec isEqualType createHashMap) then { _rec = createHashMap; };

// ---- Identity sub-record ------------------------------------------------
private _first = [_rec, "first_name", ""] call _hg;
private _last  = [_rec, "last_name", ""] call _hg;
private _nameParts = [];
if (!(_first isEqualTo "")) then { _nameParts pushBack _first; };
if (!(_last isEqualTo "")) then { _nameParts pushBack _last; };
private _name = _nameParts joinString " ";
if (_name isEqualTo "") then { _name = "UNKNOWN"; };

private _nat        = [_rec, "nationality", ""] call _hg;
private _wlRec      = [_rec, "wanted_level", _wl] call _hg;
if !(_wlRec isEqualType 0) then { _wlRec = _wl; };
private _charges    = [_rec, "charges", []] call _hg;
if !(_charges isEqualType []) then { _charges = []; };
private _reasonTxt  = [_rec, "wanted_reason_text", ""] call _hg;
private _wConf      = [_rec, "wanted_confidence", 0] call _hg;
if !(_wConf isEqualType 0) then { _wConf = 0; };

// Identity confidence component (0..1): prefer explicit wanted_confidence, else map wanted_level.
private _idConf = _wConf;
if (_idConf <= 0) then { _idConf = ((_wlRec / 3) max 0) min 1; };

private _identity = [
    ["civ_uid",      _civUid],
    ["name",         _name],
    ["nationality",  _nat],
    ["wanted_level", _wlRec],
    ["charges",      _charges],
    ["reason",       _reasonTxt]
];

// ---- Evidence capture: case files linked to the active incident/task ----
private _taskId  = ["activeTaskId", ""] call ARC_fnc_stateGet;
private _incType = ["activeIncidentType", ""] call ARC_fnc_stateGet;

private _caseFiles = ["ied_v0_case_files", createHashMap] call ARC_fnc_stateGet;
if !(_caseFiles isEqualType createHashMap) then { _caseFiles = createHashMap; };

private _evidence = [];
private _evConf = 0;
{
    private _cf = [_caseFiles, _x, createHashMap] call _hg;
    if (_cf isEqualType createHashMap) then {
        private _cfTask = [_cf, "taskId", ""] call _hg;
        if (!(_taskId isEqualTo "") && {_cfTask isEqualTo _taskId}) then {
            private _items = [_cf, "evidence_items", []] call _hg;
            if !(_items isEqualType []) then { _items = []; };
            private _cfConf = [_cf, "confidence", 0] call _hg;
            if !(_cfConf isEqualType 0) then { _cfConf = 0; };
            if (_cfConf > _evConf) then { _evConf = _cfConf; };
            _evidence pushBack [
                ["case_file_id", _x],
                ["item_count",   count _items],
                ["confidence",   _cfConf],
                ["lead_id",      [_cf, "leadId", ""] call _hg]
            ];
        };
    };
} forEach ([_caseFiles] call _keysFn);

// ---- Combined confidence weighting --------------------------------------
private _conf = _idConf;
if ((count _evidence) > 0) then {
    _conf = (0.6 * _idConf) + (0.4 * _evConf);
};
_conf = (_conf max 0) min 1;

// ---- Position / grid ----------------------------------------------------
private _pos = [0,0,0];
if (!isNull _civ) then { _pos = getPosATL _civ; };
if (!(_pos isEqualType []) || {(count _pos) < 2}) then { _pos = [0,0,0]; };
private _z = 0;
if ((count _pos) >= 3 && { (_pos select 2) isEqualType 0 }) then { _z = _pos select 2; };
_pos = [_pos select 0, _pos select 1, _z];
private _grid = mapGridPosition _pos;

// ---- Confidence-weighted lead -------------------------------------------
private _leadStrength = _conf max 0.1;
private _leadId = [
    "RECON",
    format ["Dossier: %1 follow-up (SSE)", _name],
    _pos,
    _leadStrength,
    5400,
    _taskId,
    _incType,
    "",
    "sheriff_sse_dossier"
] call ARC_fnc_leadCreate;
if (isNil "_leadId" || {!(_leadId isEqualType "")}) then { _leadId = ""; };

// ---- Build / append record (array-of-pairs, serialization-safe) ---------
private _records = ["dossier_v0_records", []] call ARC_fnc_stateGet;
if !(_records isEqualType []) then { _records = []; };

// Upsert by detainee civ_uid: merge an existing open record rather than duplicate.
private _pget = compile "params ['_arr','_key','_def']; if (!(_arr isEqualType [])) exitWith { _def }; private _r = _def; { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _r = _x select 1 }; } forEach _arr; _r";
private _idx = -1;
{
    private _exIdentity = [_x, "identity", []] call _pget;
    if !(_exIdentity isEqualType []) then { _exIdentity = []; };
    private _exUid = [_exIdentity, "civ_uid", ""] call _pget;
    if (_exUid isEqualTo _civUid) exitWith { _idx = _forEachIndex; };
} forEach _records;

private _now = serverTime;

// Identity continuity: preserve dossier_id + created_ts when merging an existing record,
// only consuming a new sequence id (and timestamp) for a genuinely new dossier.
private _dossierId = "";
private _createdTs = _now;
private _seq = ["dossier_v0_seq", 0] call ARC_fnc_stateGet;
if !(_seq isEqualType 0) then { _seq = 0; };

if (_idx >= 0) then {
    private _prev = _records select _idx;
    private _prevId = [_prev, "dossier_id", ""] call _pget;
    if ((_prevId isEqualType "") && {!(_prevId isEqualTo "")}) then { _dossierId = _prevId; };
    private _prevCreated = [_prev, "created_ts", _now] call _pget;
    if (_prevCreated isEqualType 0) then { _createdTs = _prevCreated; };
};

if (_dossierId isEqualTo "") then {
    // New dossier: allocate the next sequence id.
    _seq = _seq + 1;
    private _seqStr = str _seq;
    while {(count _seqStr) < 6} do { _seqStr = "0" + _seqStr; };
    _dossierId = format ["DOS:%1", _seqStr];
    ["dossier_v0_seq", _seq] call ARC_fnc_stateSet;
};

private _record = [
    ["dossier_id",  _dossierId],
    ["v",           0],
    ["created_ts",  _createdTs],
    ["updated_ts",  _now],
    ["task_id",     _taskId],
    ["incident_type", _incType],
    ["district_id", _did],
    ["pos",         _pos],
    ["grid",        _grid],
    ["identity",    _identity],
    ["evidence",    _evidence],
    ["handoff",     [
        ["stage",     "SHERIFF_HOLDING"],
        ["to",        "SHERIFF"],
        ["actor_uid", _actorUid],
        ["ts",        _now]
    ]],
    ["confidence",  _conf],
    ["lead_id",     _leadId]
];

if (_idx >= 0) then {
    _records set [_idx, _record];
} else {
    _records pushBack _record;
};

// Bound the store (drop oldest).
private _maxRec = ["dossier_v0_max", 100] call ARC_fnc_stateGet;
if !(_maxRec isEqualType 0) then { _maxRec = 100; };
if (_maxRec < 1) then { _maxRec = 1; };
while {(count _records) > _maxRec} do { _records deleteAt 0; };

["dossier_v0_records", _records] call ARC_fnc_stateSet;

// Bind the stable dossier id to the detainee so delayed EPW transfer / MP locality
// changes can still prove which handoff created the persisted dossier.
if (!isNull _civ) then {
    _civ setVariable ["ARC_dossier_id", _dossierId, true];
    _civ setVariable ["ARC_dossier_handoff_task_id", _taskId, true];
};

// ---- OPS lifecycle log + read-model publish -----------------------------
if (!isNil "ARC_fnc_intelLog") then {
    [
        "OPS",
        format ["Dossier %1 opened — %2 (conf %3)", _dossierId, _name, (round (_conf * 100))],
        _pos,
        [
            ["event", "DOSSIER_OPENED"],
            ["id", _dossierId],
            ["civ_uid", _civUid],
            ["lead_id", _leadId],
            ["actor", _actorUid]
        ]
    ] call ARC_fnc_intelLog;
};

[] call ARC_fnc_dossierBroadcast;

diag_log format ["[ARC][INFO] ARC_fnc_dossierUpsertFromHandoff: dossier=%1 civ=%2 conf=%3 evidence=%4 lead=%5", _dossierId, _civUid, _conf, count _evidence, _leadId];

_dossierId

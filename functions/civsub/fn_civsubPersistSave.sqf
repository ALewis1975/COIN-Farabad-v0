/*
    ARC_fnc_civsubPersistSave

    Writes CIVSUB v1 state to profileNamespace.

    Baseline calls for a JSON blob. For compatibility and regression resistance,
    v1 stores a parseSimpleArray-friendly serialized array in FARABAD_CIVSUB_V1_STATE.

    Phase 3 expands saved content to include:
      - districts
      - crime DB (30 POIs + status)
      - touched identities (capped at 500)
      - identity sequence counter
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_persist", true]) exitWith {true};

if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if !(_districts isEqualType createHashMap) exitWith {false};

// Enforce identity cap before save
[500] call ARC_fnc_civsubIdentityEvictIfNeeded;

private _ids = missionNamespace getVariable ["civsub_v1_identities", createHashMap];
if !(_ids isEqualType createHashMap) then { _ids = createHashMap; };

private _db = missionNamespace getVariable ["civsub_v1_crimedb", createHashMap];
if !(_db isEqualType createHashMap) then { _db = createHashMap; };

// Serialize districts as fixed-order arrays for persistence stability.
private _districtArr = [];
{
    private _d = _districts get _x;
    if !(_d isEqualType createHashMap) then { continue; };

    private _centroid = [_d, "centroid", [0,0] call _hg];
    private _row = [
        [_d, "id", _x] call _hg,
        _centroid,
        [_d, "radius_m", 0] call _hg,
        [_d, "pop_total", 0] call _hg,

        [_d, "W_EFF_U", 0] call _hg,
        [_d, "R_EFF_U", 0] call _hg,
        [_d, "G_EFF_U", 0] call _hg,

        [_d, "W_BASE_U", 45] call _hg,
        [_d, "R_BASE_U", 55] call _hg,
        [_d, "G_BASE_U", 35] call _hg,

        [_d, "food_idx", 50] call _hg,
        [_d, "water_idx", 50] call _hg,
        [_d, "fear_idx", 50] call _hg,

        [_d, "cooldown_nextLead_ts", 0] call _hg,
        [_d, "cooldown_nextAttack_ts", 0] call _hg,
        [_d, "last_player_touch_ts", 0] call _hg
        ,[_d, "civ_cas_kia", 0] call _hg
        ,[_d, "civ_cas_wia", 0] call _hg
        ,[_d, "crime_db_hits", 0] call _hg
        ,[_d, "detentions_initiated", 0] call _hg
        ,[_d, "detentions_handed_off", 0] call _hg
        ,[_d, "aid_events", 0] call _hg
    ];

    _districtArr pushBack _row;
} forEach (keys _districts);

// Serialize identities (touched-only) as fixed-order arrays.
private _idArr = [];
{
    private _rec = _ids get _x;
    if !(_rec isEqualType createHashMap) then { continue; };

    private _flags = [_rec, "flags", [] call _hg];
    if !(_flags isEqualType []) then { _flags = []; };

    private _seen = [_rec, "seen_by", createHashMap] call _hg;
    private _seenRows = [];
    if (_seen isEqualType createHashMap) then {
        {
            private _row = _seen get _x;
            if (_row isEqualType [] && {count _row >= 3}) then {
                _seenRows pushBack [_x, _row select 0, _row select 1, _row select 2];
            };
        } forEach (keys _seen);
    };

    _idArr pushBack [
        [_rec, "civ_uid", _x] call _hg,
        [_rec, "first_name", ""] call _hg,
        [_rec, "last_name", ""] call _hg,
        [_rec, "sex", ""] call _hg,
        [_rec, "dob_iso", ""] call _hg,
        [_rec, "nationality", ""] call _hg,
        [_rec, "home_district_id", ""] call _hg,
        [_rec, "home_pos", [0,0,0] call _hg],
        [_rec, "occupation", ""] call _hg,
        [_rec, "background", ""] call _hg,
        [_rec, "passport_serial", ""] call _hg,
        [_rec, "passport_expires_iso", ""] call _hg,
        [_rec, "passport_isPassport", true] call _hg,
        _flags,
        [_rec, "wanted_level", 0] call _hg,
        _seenRows,
        [_rec, "last_interaction_ts", 0] call _hg,
        // Phase 7: detention status (optional; backward compatible)
        [_rec, "status_detained", false] call _hg,
        [_rec, "status_detainedAt", 0] call _hg,
        [_rec, "status_detainedDistrictId", ""] call _hg,
        [_rec, "status_handedOff", false] call _hg,
        [_rec, "status_handedOffAt", 0] call _hg,
        [_rec, "status_handedOffTo", ""] call _hg,
        [_rec, "status_releasedAt", 0] call _hg,
        [_rec, "poi_id", ""] call _hg,
        [_rec, "charges", [] call _hg]
    ];
} forEach (keys _ids);

// Serialize crime DB records
private _crimeArr = [];
{
    private _rec = _db get _x;
    if !(_rec isEqualType createHashMap) then { continue; };

    private _hist = [_rec, "status_history", [] call _hg];
    if !(_hist isEqualType []) then { _hist = []; };

    _crimeArr pushBack [
        [_rec, "poi_id", _x] call _hg,
        [_rec, "category", ""] call _hg,
        [_rec, "homeDistrictId", ""] call _hg,
        [_rec, "passport_serial", ""] call _hg,
        [_rec, "is_hvt", false] call _hg,
        [_rec, "status", ""] call _hg,
        [_rec, "status_ts", 0] call _hg,
        _hist
    ];
} forEach (keys _db);

private _state = [
    ["version", missionNamespace getVariable ["civsub_v1_version", 1]],
    ["campaign_id", profileNamespace getVariable ["FARABAD_CIVSUB_V1_CAMPAIGN_ID", ""]],
    ["seed", missionNamespace getVariable ["civsub_v1_seed", 1337]],
    ["identity_seq", missionNamespace getVariable ["civsub_v1_identity_seq", 0]],
    ["districts", _districtArr],
    ["identities", _idArr],
    ["crimedb", _crimeArr]
];

profileNamespace setVariable ["FARABAD_CIVSUB_V1_STATE", str _state];
saveProfileNamespace;

missionNamespace setVariable ["civsub_v1_lastSave_ts", serverTime, true];
true

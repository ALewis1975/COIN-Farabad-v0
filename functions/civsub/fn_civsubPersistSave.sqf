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

    private _centroid = _d getOrDefault ["centroid", [0,0]];
    private _row = [
        _d getOrDefault ["id", _x],
        _centroid,
        _d getOrDefault ["radius_m", 0],
        _d getOrDefault ["pop_total", 0],

        _d getOrDefault ["W_EFF_U", 0],
        _d getOrDefault ["R_EFF_U", 0],
        _d getOrDefault ["G_EFF_U", 0],

        _d getOrDefault ["W_BASE_U", 45],
        _d getOrDefault ["R_BASE_U", 55],
        _d getOrDefault ["G_BASE_U", 35],

        _d getOrDefault ["food_idx", 50],
        _d getOrDefault ["water_idx", 50],
        _d getOrDefault ["fear_idx", 50],

        _d getOrDefault ["cooldown_nextLead_ts", 0],
        _d getOrDefault ["cooldown_nextAttack_ts", 0],
        _d getOrDefault ["last_player_touch_ts", 0]
        ,_d getOrDefault ["civ_cas_kia", 0]
        ,_d getOrDefault ["civ_cas_wia", 0]
        ,_d getOrDefault ["crime_db_hits", 0]
        ,_d getOrDefault ["detentions_initiated", 0]
        ,_d getOrDefault ["detentions_handed_off", 0]
        ,_d getOrDefault ["aid_events", 0]
    ];

    _districtArr pushBack _row;
} forEach (keys _districts);

// Serialize identities (touched-only) as fixed-order arrays.
private _idArr = [];
{
    private _rec = _ids get _x;
    if !(_rec isEqualType createHashMap) then { continue; };

    private _flags = _rec getOrDefault ["flags", []];
    if !(_flags isEqualType []) then { _flags = []; };

    private _seen = _rec getOrDefault ["seen_by", createHashMap];
    private _seenRows = [];
    if (_seen isEqualType createHashMap) then {
        {
            private _row = _seen get _x;
            if (_row isEqualType [] && {count _row >= 3}) then {
                _seenRows pushBack [_x, _row # 0, _row # 1, _row # 2];
            };
        } forEach (keys _seen);
    };

    _idArr pushBack [
        _rec getOrDefault ["civ_uid", _x],
        _rec getOrDefault ["first_name", ""],
        _rec getOrDefault ["last_name", ""],
        _rec getOrDefault ["sex", ""],
        _rec getOrDefault ["dob_iso", ""],
        _rec getOrDefault ["nationality", ""],
        _rec getOrDefault ["home_district_id", ""],
        _rec getOrDefault ["home_pos", [0,0,0]],
        _rec getOrDefault ["occupation", ""],
        _rec getOrDefault ["background", ""],
        _rec getOrDefault ["passport_serial", ""],
        _rec getOrDefault ["passport_expires_iso", ""],
        _rec getOrDefault ["passport_isPassport", true],
        _flags,
        _rec getOrDefault ["wanted_level", 0],
        _seenRows,
        _rec getOrDefault ["last_interaction_ts", 0],
        // Phase 7: detention status (optional; backward compatible)
        _rec getOrDefault ["status_detained", false],
        _rec getOrDefault ["status_detainedAt", 0],
        _rec getOrDefault ["status_detainedDistrictId", ""],
        _rec getOrDefault ["status_handedOff", false],
        _rec getOrDefault ["status_handedOffAt", 0],
        _rec getOrDefault ["status_handedOffTo", ""],
        _rec getOrDefault ["status_releasedAt", 0],
        _rec getOrDefault ["poi_id", ""],
        _rec getOrDefault ["charges", []]
    ];
} forEach (keys _ids);

// Serialize crime DB records
private _crimeArr = [];
{
    private _rec = _db get _x;
    if !(_rec isEqualType createHashMap) then { continue; };

    private _hist = _rec getOrDefault ["status_history", []];
    if !(_hist isEqualType []) then { _hist = []; };

    _crimeArr pushBack [
        _rec getOrDefault ["poi_id", _x],
        _rec getOrDefault ["category", ""],
        _rec getOrDefault ["homeDistrictId", ""],
        _rec getOrDefault ["passport_serial", ""],
        _rec getOrDefault ["is_hvt", false],
        _rec getOrDefault ["status", ""],
        _rec getOrDefault ["status_ts", 0],
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

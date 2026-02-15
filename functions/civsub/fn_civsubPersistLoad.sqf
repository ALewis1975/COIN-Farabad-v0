/*
    ARC_fnc_civsubPersistLoad

    Loads CIVSUB v1 state from profileNamespace.

    Returns: bool (true if loaded)
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_persist", true]) exitWith {false};

if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

private _blob = profileNamespace getVariable ["FARABAD_CIVSUB_V1_STATE", ""];
if (_blob isEqualTo "") exitWith {false};

private _parsed = parseSimpleArray _blob;
if !(_parsed isEqualType []) exitWith {false};

// _parsed is an array of [key,value] pairs
private _hm = createHashMapFromArray _parsed;

// --- Districts ---
private _districtRows = _hm getOrDefault ["districts", []];
if !(_districtRows isEqualType []) exitWith {false};

private _districts = createHashMap;
{
    if !(_x isEqualType []) then { continue; };
    if ((count _x) < 16) then { continue; };

    private _id = _x # 0;
    private _centroid = _x # 1;
    private _radius = _x # 2;
    private _pop = _x # 3;

    private _w = _x # 4;
    private _r = _x # 5;
    private _g = _x # 6;

    private _wb = _x # 7;
    private _rb = _x # 8;
    private _gb = _x # 9;

    private _food = _x # 10;
    private _water = _x # 11;
    private _fear = _x # 12;

    private _cdLead = _x # 13;
    private _cdAtk = _x # 14;
    private _lastTouch = _x # 15;

    // Phase 6 counters (baseline A.6). Backward compatible with older saves (no counters).
    private _kia = if ((count _x) > 16) then { _x # 16 } else { 0 };
    private _wia = if ((count _x) > 17) then { _x # 17 } else { 0 };
    private _crimeHits = if ((count _x) > 18) then { _x # 18 } else { 0 };
    private _detInit = if ((count _x) > 19) then { _x # 19 } else { 0 };
    private _detHand = if ((count _x) > 20) then { _x # 20 } else { 0 };
    private _aid = if ((count _x) > 21) then { _x # 21 } else { 0 };

    private _d = createHashMapFromArray [
        ["id", _id],
        ["centroid", _centroid],
        ["radius_m", _radius],
        ["pop_total", _pop],

        ["W_EFF_U", _w],
        ["R_EFF_U", _r],
        ["G_EFF_U", _g],

        ["W_BASE_U", _wb],
        ["R_BASE_U", _rb],
        ["G_BASE_U", _gb],

        ["food_idx", _food],
        ["water_idx", _water],
        ["fear_idx", _fear],

        ["cooldown_nextLead_ts", _cdLead],
        ["cooldown_nextAttack_ts", _cdAtk],
        ["last_player_touch_ts", _lastTouch],

        // Phase 6 counters (baseline A.6)
        ["civ_cas_kia", _kia],
        ["civ_cas_wia", _wia],
        ["crime_db_hits", _crimeHits],
        ["detentions_initiated", _detInit],
        ["detentions_handed_off", _detHand],
        ["aid_events", _aid]
    ];

    [_d] call ARC_fnc_civsubDistrictsClamp;
    _districts set [_id, _d];
} forEach _districtRows;

// --- Identities ---
private _ids = createHashMap;
private _idRows = _hm getOrDefault ["identities", []];
if (_idRows isEqualType []) then {
    {
        if !(_x isEqualType []) then { continue; };
        if ((count _x) < 17) then { continue; };

        private _civUid = _x # 0;
        private _first = _x # 1;
        private _last = _x # 2;
        private _sex = _x # 3;
        private _dob = _x # 4;
        private _nat = _x # 5;
        private _homeDid = _x # 6;
        private _homePos = _x # 7;
        private _occ = _x # 8;
        private _bg = _x # 9;
        private _ps = _x # 10;
        private _pe = _x # 11;
        private _isP = _x # 12;
        private _flags = _x # 13;
        private _wanted = _x # 14;
        private _seenRows = _x # 15;
        private _lastTs = _x # 16;

        // Phase 7 optional fields (backward compatible)
        private _detained = if ((count _x) > 17) then { _x # 17 } else { false };
        private _detainedAt = if ((count _x) > 18) then { _x # 18 } else { 0 };
        private _detainedDid = if ((count _x) > 19) then { _x # 19 } else { "" };
        private _handedOff = if ((count _x) > 20) then { _x # 20 } else { false };
        private _handedOffAt = if ((count _x) > 21) then { _x # 21 } else { 0 };
        private _handedOffTo = if ((count _x) > 22) then { _x # 22 } else { "" };
        private _releasedAt = if ((count _x) > 23) then { _x # 23 } else { 0 };
        private _poiId = if ((count _x) > 24) then { _x # 24 } else { "" };
        private _charges = if ((count _x) > 25) then { _x # 25 } else { [] };

        private _seen = createHashMap;
        if (_seenRows isEqualType []) then {
            {
                if (_x isEqualType [] && {count _x >= 4}) then {
                    _seen set [_x # 0, [_x # 1, _x # 2, _x # 3]];
                };
            } forEach _seenRows;
        };

        private _rec = createHashMapFromArray [
            ["civ_uid", _civUid],
            ["first_name", _first],
            ["last_name", _last],
            ["sex", _sex],
            ["dob_iso", _dob],
            ["nationality", _nat],
            ["home_district_id", _homeDid],
            ["home_pos", _homePos],
            ["occupation", _occ],
            ["background", _bg],
            ["passport_serial", _ps],
            ["passport_expires_iso", _pe],
            ["passport_isPassport", _isP],
            ["flags", _flags],
            ["wanted_level", _wanted],
            ["status_detained", _detained],
            ["status_detainedAt", _detainedAt],
            ["status_detainedDistrictId", _detainedDid],
            ["status_handedOff", _handedOff],
            ["status_handedOffAt", _handedOffAt],
            ["status_handedOffTo", _handedOffTo],
            ["status_releasedAt", _releasedAt],
            ["poi_id", _poiId],
            ["charges", _charges],
            ["seen_by", _seen],
            ["last_interaction_ts", _lastTs]
        ];

        _ids set [_civUid, _rec];
    } forEach _idRows;
};

// --- Crime DB ---
private _db = createHashMap;
private _crimeRows = _hm getOrDefault ["crimedb", []];
if (_crimeRows isEqualType []) then {
    {
        if !(_x isEqualType []) then { continue; };
        if ((count _x) < 8) then { continue; };

        private _poiId = _x # 0;
        private _cat = _x # 1;
        private _did = _x # 2;
        private _ps = _x # 3;
        private _isHvt = _x # 4;
        private _st = _x # 5;
        private _ts = _x # 6;
        private _hist = _x # 7;

        private _rec = createHashMapFromArray [
            ["poi_id", _poiId],
            ["category", _cat],
            ["homeDistrictId", _did],
            ["passport_serial", _ps],
            ["is_hvt", _isHvt],
            ["status", _st],
            ["status_ts", _ts],
            ["status_history", _hist]
        ];

        _db set [_poiId, _rec];
    } forEach _crimeRows;
};

missionNamespace setVariable ["civsub_v1_districts", _districts, true];
missionNamespace setVariable ["civsub_v1_identities", _ids, true];
missionNamespace setVariable ["civsub_v1_crimedb", _db, true];

private _ver = _hm getOrDefault ["version", missionNamespace getVariable ["civsub_v1_version", 1]];
missionNamespace setVariable ["civsub_v1_version", _ver, true];

missionNamespace setVariable ["civsub_v1_seed", _hm getOrDefault ["seed", missionNamespace getVariable ["civsub_v1_seed", 1337]], true];
missionNamespace setVariable ["civsub_v1_identity_seq", _hm getOrDefault ["identity_seq", missionNamespace getVariable ["civsub_v1_identity_seq", 0]], true];

// Enforce identity cap after load
[500] call ARC_fnc_civsubIdentityEvictIfNeeded;

true

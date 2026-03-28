/*
    ARC_fnc_civsubDistrictsCreateDefaults

    Creates locked v1 district records (D01..D20) using centroid/radius/pop planning table.
    Returns: hashmap districtId -> districtState(hashmap)
*/

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _districts = createHashMap;

private _seed = missionNamespace getVariable ["civsub_v1_seed", 1337];
if !(_seed isEqualType 0) then { _seed = 1337; };

// [id, planPop_5800, centroidX, centroidY, radius_m]
private _rows = [
    ["D01", 2089, 4580.8, 5317.7, 995],
    ["D02", 1601, 8407.3, 2825.1, 1862],
    ["D03", 286, 8703.0, 7263.9, 734],
    ["D04", 248, 4615.2, 9257.5, 1744],
    ["D05", 236, 9572.8, 9134.3, 430],
    ["D06", 224, 304.3, 5417.5, 1395],
    ["D07", 200, 1968.4, 4898.6, 495],
    ["D08", 159, 2351.0, 829.4, 1673],
    ["D09", 157, 150.7, 7700.9, 491],
    ["D10", 128, 8856.0, 5986.2, 198],
    ["D11", 121, 9080.9, 10455.1, 145],
    ["D12", 115, 4014.9, 3673.6, 576],
    ["D13", 49, 7516.3, 8643.4, 37],
    ["D14", 38, 7187.4, 2621.0, 2298],
    ["D15", 34, 9726.7, 3953.8, 47],
    ["D16", 28, 10114.0, 9383.7, 41],
    ["D17", 27, 255.4, 6349.4, 266],
    ["D18", 25, 451.3, 8677.6, 256],
    ["D19", 21, 8106.0, 6840.3, 10],
    ["D20", 14, 4251.9, 2959.6, 83]
];

{
    private _id = _x select 0;
    private _pop = _x select 1;
    private _cx = _x select 2;
    private _cy = _x select 3;
    private _rad = _x select 4;

    private _profile = [_id, _pop, [_cx, _cy], _seed] call ARC_fnc_civsubDistrictSeedProfile;

    private _wBase = [_profile, "W_BASE_U", 45] call _hg;
    private _rBase = [_profile, "R_BASE_U", 55] call _hg;
    private _gBase = [_profile, "G_BASE_U", 35] call _hg;

    private _wEff = [_profile, "W_EFF_U", _wBase] call _hg;
    private _rEff = [_profile, "R_EFF_U", _rBase] call _hg;
    private _gEff = [_profile, "G_EFF_U", _gBase] call _hg;

    private _d = [[
        ["id", _id],
        ["centroid", [_cx, _cy]],
        ["radius_m", _rad],
        ["pop_total", _pop],

        ["W_BASE_U", _wBase],
        ["R_BASE_U", _rBase],
        ["G_BASE_U", _gBase],

        ["W_EFF_U", _wEff],
        ["R_EFF_U", _rEff],
        ["G_EFF_U", _gEff],

        // Abstract indices (v1)
        ["food_idx", 50],
        ["water_idx", 50],
        ["fear_idx", 50],

        // Phase 6 counters (baseline A.6)
        ["civ_cas_kia", 0],
        ["civ_cas_wia", 0],
        ["crime_db_hits", 0],
        ["detentions_initiated", 0],
        ["detentions_handed_off", 0],
        ["aid_events", 0],


        // Cooldowns and touches
        ["cooldown_nextLead_ts", 0],
        ["cooldown_nextAttack_ts", 0],
        ["last_player_touch_ts", 0]
    ]] call _hmCreate;

    _districts set [_id, _d];
} forEach _rows;

_districts

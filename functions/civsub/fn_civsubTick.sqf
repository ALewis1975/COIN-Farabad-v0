/*
    ARC_fnc_civsubTick

    Phase 0-2:
      - Apply influence decay toward baseline (locked constants)
      - Maintain last tick timestamp
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _keysFn   = compile "params ['_m']; keys _m";
private _hmFrom   = compile "params ['_pairs']; private _r = createHashMap; { _r set [_x select 0, _x select 1]; } forEach _pairs; _r";

private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if (!(_districts isEqualType createHashMap)) exitWith {false};

[_districts] call ARC_fnc_civsubDistrictsApplyDecay;
missionNamespace setVariable ["civsub_v1_lastTick_ts", serverTime, true];

// Publish per-district public snapshots once per tick so clients can see updated district state.
// This avoids relying on replication of nested HashMap mutations.
{
    private _did = _x;
    private _d = [_districts, _did, createHashMap] call _hg;
    if (_d isEqualType []) then { _d = [_d] call _hmFrom; };
    if !(_d isEqualType createHashMap) then { continue; };

    private _pub = [
        ["G", [_d, "G_EFF_U", 35] call _hg],
        ["crime_db_hits", [_d, "crime_db_hits", 0] call _hg],
        ["detentions_initiated", [_d, "detentions_initiated", 0] call _hg],
        ["civ_cas_kia", [_d, "civ_cas_kia", 0] call _hg],
        ["districtId", _did],
        ["detentions_handed_off", [_d, "detentions_handed_off", 0] call _hg],
        ["R", [_d, "R_EFF_U", 55] call _hg],
        ["civ_cas_wia", [_d, "civ_cas_wia", 0] call _hg],
        ["ts", serverTime],
        ["aid_events", [_d, "aid_events", 0] call _hg],
        ["W", [_d, "W_EFF_U", 45] call _hg]
    ];

    missionNamespace setVariable [format ["civsub_v1_district_pub_%1", _did], _pub, true];
} forEach ([_districts] call _keysFn);

true

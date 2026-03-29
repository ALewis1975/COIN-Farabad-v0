/*
    ARC_fnc_civsubTick

    Phase 0-2:
      - Apply influence decay toward baseline (locked constants)
      - Maintain last tick timestamp
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";

private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if (!(_districts isEqualType createHashMap)) exitWith {false};

[_districts] call ARC_fnc_civsubDistrictsApplyDecay;
missionNamespace setVariable ["civsub_v1_lastTick_ts", serverTime, true];

// Publish per-district public snapshots once per tick so clients can see updated district state.
// This avoids relying on replication of nested HashMap mutations.
{
    private _did = _x;
    private _d = _districts getOrDefault [_did, createHashMap];
    if (_d isEqualType []) then { _d = [_d] call _hmCreate; };
    if !(_d isEqualType createHashMap) then { continue; };

    private _pub = [
        ["G", _d getOrDefault ["G_EFF_U", 35]],
        ["crime_db_hits", _d getOrDefault ["crime_db_hits", 0]],
        ["detentions_initiated", _d getOrDefault ["detentions_initiated", 0]],
        ["civ_cas_kia", _d getOrDefault ["civ_cas_kia", 0]],
        ["districtId", _did],
        ["detentions_handed_off", _d getOrDefault ["detentions_handed_off", 0]],
        ["R", _d getOrDefault ["R_EFF_U", 55]],
        ["civ_cas_wia", _d getOrDefault ["civ_cas_wia", 0]],
        ["ts", serverTime],
        ["aid_events", _d getOrDefault ["aid_events", 0]],
        ["W", _d getOrDefault ["W_EFF_U", 45]]
    ];

    missionNamespace setVariable [format ["civsub_v1_district_pub_%1", _did], _pub, true];
} forEach (keys _districts);

true

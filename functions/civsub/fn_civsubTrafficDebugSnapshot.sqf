/*
    ARC_fnc_civsubTrafficDebugSnapshot

    Server-only snapshot of CIVTRAF state for debugging/UI integration later.

    Returns HashMap with:
      - enabled, counts, perDistrictCounts
*/

if (!isServer) exitWith {createHashMap};

private _out = createHashMap;

_out set ["enabled", missionNamespace getVariable ["civsub_v1_traffic_enabled", false]];
_out set ["allow_moving", missionNamespace getVariable ["civsub_v1_traffic_allow_moving", false]];
_out set ["cap_global", missionNamespace getVariable ["civsub_v1_traffic_cap_global", -1]];
_out set ["cap_perDistrict", missionNamespace getVariable ["civsub_v1_traffic_cap_perDistrict", -1]];
_out set ["cap_moving_global", missionNamespace getVariable ["civsub_v1_traffic_cap_moving_global", -1]];
_out set ["prob_moving", missionNamespace getVariable ["civsub_v1_traffic_prob_moving", -1]];
_out set ["tick_i", missionNamespace getVariable ["civsub_v1_traffic_tick_i", -1]];
_out set ["spawn_radius_m", missionNamespace getVariable ["civsub_v1_traffic_spawnRadius_m", -1]];
_out set ["activity_phase", missionNamespace getVariable ["civsub_v1_activity_phase", "DAY"]];
_out set ["activity_tod", missionNamespace getVariable ["civsub_v1_activity_tod", -1]];
_out set ["activity_mul_traffic", missionNamespace getVariable ["civsub_v1_activity_mul_traffic_active", 1]];
_out set ["activity_mul_moving", missionNamespace getVariable ["civsub_v1_activity_mul_moving_active", 1]];
_out set ["activity_prob_moving_effective", missionNamespace getVariable ["civsub_v1_activity_prob_moving_effective", -1]];
_out set ["activity_mul_civ", missionNamespace getVariable ["civsub_v1_activity_mul_civ_active", 1]];
_out set ["activity_mul_sched_lead", missionNamespace getVariable ["civsub_v1_activity_mul_sched_lead_active", 1]];
_out set ["activity_mul_sched_attack", missionNamespace getVariable ["civsub_v1_activity_mul_sched_attack_active", 1]];

private _parked = missionNamespace getVariable ["civsub_v1_traffic_list_parked", []];
private _moving = missionNamespace getVariable ["civsub_v1_traffic_list_moving", []];

if !(_parked isEqualType []) then { _parked = []; };
if !(_moving isEqualType []) then { _moving = []; };

_out set ["count_parked", count (_parked select { !isNull _x })];
_out set ["count_moving", count (_moving select { !isNull _x })];

private _per = createHashMap;

{
    if (isNull _x) then { continue; };
    private _d = _x getVariable ["ARC_civtraf_districtId", "D00"];
    _per set [_d, 1 + ([_per, _d, 0] call getOrDefault)];
} forEach _parked;

{
    if (isNull _x) then { continue; };
    private _d = _x getVariable ["ARC_civtraf_districtId", "D00"];
    _per set [_d, 1 + ([_per, _d, 0] call getOrDefault)];
} forEach _moving;

_out set ["perDistrict", _per];

// Operating centers computed each tick (districtId -> [x,y,z])
private _ops = missionNamespace getVariable ["civsub_v1_traffic_opCenters", createHashMap];
if !(_ops isEqualType createHashMap) then { _ops = createHashMap; };
_out set ["opCenters", _ops];

_out

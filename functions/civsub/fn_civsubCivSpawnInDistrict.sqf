/*
    ARC_fnc_civsubCivSpawnInDistrict

    Spawns one civilian in the specified district, assigns an identity, and registers.

    Params:
      0: districtId (string)

    Returns: unit object or objNull

    Hotfix03:
      - Records explicit failure reasons/stages for ALL early exits
      - Increments spawn_fail_count on any failure path
      - Publishes lastSpawnStage for fast probing without relying on RPT
*/

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";

private _dbg = missionNamespace getVariable ["civsub_v1_debug", false];

// Phase 2 helpers (defined in civsubInitServer)
private _posIsRoadish = missionNamespace getVariable ["ARC_civsub_fnc_posIsRoadish", { params ["_p"]; isOnRoad _p }];
private _findOffRoad = missionNamespace getVariable ["ARC_civsub_fnc_findPosOffRoad", { params ["_p","_min","_max","_t"]; _p }];

private _fail = {
    params [
        ["_reason","",[""]],
        ["_stage","",[""]]
    ];

    missionNamespace setVariable ["civsub_v1_civ_lastSpawnFail", _reason, true];
    missionNamespace setVariable ["civsub_v1_civ_lastSpawnStage", _stage, true];
    missionNamespace setVariable ["civsub_v1_civ_spawn_fail_count", (missionNamespace getVariable ["civsub_v1_civ_spawn_fail_count", 0]) + 1, true];

    if (_dbg) then {
        diag_log format ["[CIVSUB][CIVS][SPAWN] FAIL stage=%1 reason=%2", _stage, _reason];
    };

    objNull
};

// Guard rails
if (!isServer) exitWith { ["not_server","guard"] call _fail };
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith { ["civsub_disabled","guard"] call _fail };
if !(missionNamespace getVariable ["civsub_v1_civs_enabled", false]) exitWith { ["civs_disabled","guard"] call _fail };

params [
    ["_districtId", "", [""]]
];
if (_districtId isEqualTo "") exitWith { ["districtId_empty","params"] call _fail };

// ── Ambient density modulation (Item 17): RED-heavy districts suppress civilian presence ──
// In high-RED districts the population avoids the streets (threat-driven modulation).
// Probability gate: HIGH_RED → 30 % spawn chance; NORMAL → 100 %.
// Configurable: civsub_v1_densityModEnabled (bool), civsub_v1_densityModRedThreshold (number, default 65).
private _densityModEnabled = missionNamespace getVariable ["civsub_v1_densityModEnabled", true];
if (!(_densityModEnabled isEqualType true) && !(_densityModEnabled isEqualType false)) then { _densityModEnabled = true; };

if (_densityModEnabled) then
{
    private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
    if (_districts isEqualType createHashMap) then
    {
        private _dMap = _districts getOrDefault [_districtId, createHashMap];
        if (_dMap isEqualType createHashMap) then
        {
            private _scoreR = _dMap getOrDefault ["R", 35];
            if (!(_scoreR isEqualType 0)) then { _scoreR = 35; };
            _scoreR = (_scoreR max 0) min 100;

            private _redThreshold = missionNamespace getVariable ["civsub_v1_densityModRedThreshold", 65];
            if (!(_redThreshold isEqualType 0)) then { _redThreshold = 65; };
            _redThreshold = (_redThreshold max 20) min 90;

            if (_scoreR >= _redThreshold) then
            {
                // High-RED: suppress spawns probabilistically
                private _spawnChance = 1 - ((_scoreR - _redThreshold) / (100 - _redThreshold)) * 0.70;
                _spawnChance = (_spawnChance max 0.10) min 1;

                if ((random 1) > _spawnChance) exitWith
                {
                    if (_dbg) then
                    {
                        diag_log format ["[CIVSUB][CIVS][DENSITY] district=%1 RED=%2 chance=%3 — spawn suppressed.", _districtId, _scoreR, round (_spawnChance * 100)];
                    };
                    ["density_suppressed_red", "density_mod"] call _fail
                };
            };
        };
    };
};

missionNamespace setVariable ["civsub_v1_civ_lastSpawnStage", "district_lookup", true];

private _district = [_districtId] call ARC_fnc_civsubDistrictsGetById;
// DistrictsGetById may return either a HashMap (preferred) or an Array-of-Pairs (legacy/debug form).
private _d = createHashMap;
if (_district isEqualType createHashMap) then {
    _d = _district;
} else {
    if (_district isEqualType []) then {
        if ((count _district) == 0) exitWith { ["district_empty","district_lookup"] call _fail };
        _d = [_district] call _hmCreate;
    } else {
        if (true) exitWith { [format ["district_bad_type_%1", typeName _district],"district_lookup"] call _fail };
    };
};

private _center = _d getOrDefault ["centroid", [0,0]];
private _radius = _d getOrDefault ["radius_m", 500];

if !(_center isEqualType []) exitWith { ["center_not_array","district_data"] call _fail };
if ((count _center) < 2) exitWith { ["center_bad","district_data"] call _fail };

private _spawnR = 200;
if (_radius < 250) then { _spawnR = _radius * 0.5; };
if (_spawnR < 50) then { _spawnR = 50; };

missionNamespace setVariable ["civsub_v1_civ_lastSpawnStage", "find_spawn_pos", true];

private _pos = [_districtId] call ARC_fnc_civsubCivPickSpawnPos;
if !(_pos isEqualType [] && {(count _pos) >= 2} && {!(_pos isEqualTo [0,0,0])}) then {
    _pos = [_center, _spawnR, _districtId] call ARC_fnc_civsubCivFindSpawnPos;
};
if !(_pos isEqualType [] && {(count _pos) >= 2}) then { _pos = _center; };
if ((count _pos) == 2) then { _pos = [_pos#0, _pos#1, 0]; };

// Phase 2: never spawn a civilian in the road.
if ([_pos] call _posIsRoadish) then
{
    private _fixed = [_pos, 2, 22, 14] call _findOffRoad;
    if !(_fixed isEqualTo [0,0,0]) then { _pos = _fixed; } else { ["pos_roadish","find_spawn_pos"] call _fail };
};

// De-cluster: try to keep some spacing between sampled civilians.
private _minSep = missionNamespace getVariable ["civsub_v1_civ_minSeparation_m", 20];
if (_minSep isEqualType 0 && {_minSep > 0}) then {
    private _reg = missionNamespace getVariable ["civsub_v1_civ_registry", createHashMap];
    if (_reg isEqualType createHashMap && {(count (keys _reg)) > 0}) then {
        private _tries = 0;
        private _ok = false;
        while {!_ok && {_tries < 10}} do {
            _tries = _tries + 1;
            _ok = true;
            {
                private _row = _reg get _x;
                if (_row isEqualType createHashMap) then {
                    private _u2 = _row getOrDefault ["unit", objNull];
                    if (!isNull _u2 && {(_pos distance2D (getPosATL _u2)) < _minSep}) exitWith {
                        _ok = false;
                    };
                };
            } forEach (keys _reg);
            if (!_ok) then {
                private _p2 = [_districtId] call ARC_fnc_civsubCivPickSpawnPos;
                if !(_p2 isEqualType [] && {(count _p2) >= 2} && {!(_p2 isEqualTo [0,0,0])}) then {
                    _p2 = [_center, _spawnR, _districtId] call ARC_fnc_civsubCivFindSpawnPos;
                };
                if (_p2 isEqualType [] && {(count _p2) >= 2}) then {
                    _pos = if ((count _p2) == 2) then { [_p2#0,_p2#1,0] } else { _p2 };
                };
            };
        };
    };
};

// Phase 2 final guard (post de-cluster)
if ([_pos] call _posIsRoadish) then
{
    private _fixed = [_pos, 2, 22, 14] call _findOffRoad;
    if !(_fixed isEqualTo [0,0,0]) then { _pos = _fixed; } else { ["pos_roadish","post_declust"] call _fail };
};

private _pool = [] call ARC_fnc_civsubCivBuildClassPool;
if !(_pool isEqualType [] && {count _pool > 0}) then { _pool = ["C_Man_casual_2_F","C_man_1"]; };
private _cls = selectRandom _pool;

if (_dbg) then {
    diag_log format ["[CIVSUB][CIVS][SPAWN] stage=begin did=%1 cls=%2 center=%3 r=%4 pos=%5", _districtId, _cls, _center, _spawnR, _pos];
};

missionNamespace setVariable ["civsub_v1_civ_lastSpawnStage", "create_group", true];

// Prefer createUnit in a civilian group (waypoints), but fall back to createAgent if createUnit fails.
private _grp = createGroup [civilian, true];
if (isNull _grp) exitWith { ["createGroup_null","create_group"] call _fail };

missionNamespace setVariable ["civsub_v1_civ_lastSpawnStage", "create_unit", true];

private _u = _grp createUnit [_cls, _pos, [], 0, "NONE"];
if (isNull _u) then
{
    // Fallback path: use createAgent (some environments silently fail createUnit)
    if (_dbg) then { diag_log "[CIVSUB][CIVS][SPAWN] createUnit returned null; attempting createAgent fallback"; };

    deleteGroup _grp;

    missionNamespace setVariable ["civsub_v1_civ_lastSpawnStage", "create_agent", true];

    _u = createAgent [_cls, _pos, [], 0, "NONE"];
    if (isNull _u) exitWith { ["createAgent_null","create_agent"] call _fail };

    _grp = group _u;
};

if (isNull _u) exitWith { ["unit_null_after_create","post_create"] call _fail };

missionNamespace setVariable ["civsub_v1_civ_lastSpawnStage", "post_create", true];

// Phase 7.3: harm attribution is handled by a single server-side EntityKilled mission EH (see fn_civsubInitServer).


// Keep them low-threat and not combatant
_u setBehaviour "SAFE";
_u setSpeedMode "LIMITED";
_u setCombatMode "BLUE";
_u allowFleeing 0.2;
_u disableAI "AUTOCOMBAT";
_u disableAI "SUPPRESSION";

// Give them a small wander loop (only if we have a valid group)
if !(isNull _grp) then {
    private _wp = _grp addWaypoint [[(_pos#0)+random 60 - 30, (_pos#1)+random 60 - 30, 0], 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "LIMITED";
    _wp setWaypointBehaviour "SAFE";
    _wp setWaypointCompletionRadius 5;
};

missionNamespace setVariable ["civsub_v1_civ_lastSpawnStage", "identity", true];

[_u, _districtId] call ARC_fnc_civsubCivAssignIdentity;
[_u, _districtId] call ARC_fnc_civsubCivRegisterSpawn;

missionNamespace setVariable ["civsub_v1_civ_lastSpawnFail", "", true];
missionNamespace setVariable ["civsub_v1_civ_lastSpawnStage", "ok", true];
missionNamespace setVariable ["civsub_v1_civ_lastSpawn_ts", serverTime, true];
missionNamespace setVariable ["civsub_v1_civ_spawn_ok_count", (missionNamespace getVariable ["civsub_v1_civ_spawn_ok_count", 0]) + 1, true];

_u

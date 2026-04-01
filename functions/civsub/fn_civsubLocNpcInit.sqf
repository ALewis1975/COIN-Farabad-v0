/*
    ARC_fnc_civsubLocNpcInit

    Initialises the Location-NPC layer (CIVLOC).

    Reads ARC_worldTerrainSites and ARC_worldNamedLocations (set by fn_worldInit), clusters
    nearby positions into discrete site centroids, assigns a NPC profile to each site and
    stores the resulting site registry.  Then starts the CIVLOC tick thread.

    NPC profiles define how many (and which type of) civilians should be present at a site
    for each time-of-day phase (NIGHT / DAY / PEAK).

    Profile entry format per phase:
      [phaseName, minCount, maxCount, [npcClasses]]

    Enable via:
      civsub_v1_locnpc_enabled = true
*/

if (!isServer) exitWith { false };
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith { false };
if !(missionNamespace getVariable ["civsub_v1_locnpc_enabled", false]) exitWith { false };
if (missionNamespace getVariable ["civsub_v1_locnpc_threadRunning", false]) exitWith { true };

missionNamespace setVariable ["civsub_v1_locnpc_threadRunning", true, true];

// ── NPC class pools ──────────────────────────────────────────────────────────
private _clsWorker = missionNamespace getVariable ["civsub_v1_locnpc_classPool_worker", ["UK3CB_TKC_C_WORKER", "C_man_1"]];
private _clsCiv    = missionNamespace getVariable ["civsub_v1_locnpc_classPool_civ",    ["UK3CB_TKC_C_CIV",    "C_man_polo_1_F"]];
if (!(_clsWorker isEqualType [])) then { _clsWorker = ["UK3CB_TKC_C_WORKER", "C_man_1"]; };
if (!(_clsCiv    isEqualType [])) then { _clsCiv    = ["UK3CB_TKC_C_CIV",    "C_man_polo_1_F"]; };

private _clsMixed = _clsWorker + _clsCiv;

// ── Profile definitions ──────────────────────────────────────────────────────
//  Each profile: array of [phaseName, minCount, maxCount, [classes]]
private _profFuelStation = [
    ["NIGHT", 0, 1, _clsWorker],
    ["DAY",   1, 2, _clsMixed],
    ["PEAK",  2, 3, _clsMixed]
];
private _profHospital = [
    ["NIGHT", 1, 2, _clsMixed],
    ["DAY",   2, 4, _clsMixed],
    ["PEAK",  3, 5, _clsMixed]
];
private _profWorksite = [
    ["NIGHT", 0, 1, _clsWorker],
    ["DAY",   2, 3, _clsWorker],
    ["PEAK",  3, 4, _clsWorker]
];
private _profSolar = [
    ["NIGHT", 0, 0, _clsWorker],
    ["DAY",   0, 1, _clsWorker],
    ["PEAK",  0, 1, _clsWorker]
];
private _profTransmitter = [
    ["NIGHT", 0, 0, _clsWorker],
    ["DAY",   0, 1, _clsWorker],
    ["PEAK",  0, 1, _clsWorker]
];

// ── Cluster helper (greedy; groups positions within _clusterR of first unassigned) ───
private _clusterR = missionNamespace getVariable ["civsub_v1_locnpc_cluster_m", 80];
if (!(_clusterR isEqualType 0)) then { _clusterR = 80; };

// Returns array of centroids given flat position list
private _fnCluster = {
    params [["_positions", [], [[]]], ["_r", 80, [0]]];
    private _remaining = +_positions;
    private _centroids = [];
    while { (count _remaining) > 0 } do {
        private _seed = _remaining select 0;
        private _group = [];
        private _next  = [];
        {
            private _p = _x;
            if ((count _p) < 2) then { continue; };
            if (([_seed select 0, _seed select 1, 0] distance2D [_p select 0, _p select 1, 0]) <= _r) then {
                _group pushBack _p;
            } else {
                _next pushBack _p;
            };
        } forEach _remaining;
        _remaining = _next;

        // compute mean centroid
        private _cx = 0; private _cy = 0; private _cz = 0;
        {
            _cx = _cx + (_x select 0);
            _cy = _cy + (_x select 1);
            _cz = _cz + (if ((count _x) > 2) then { _x select 2 } else { 0 });
        } forEach _group;
        private _n = count _group;
        _centroids pushBack [_cx / _n, _cy / _n, _cz / _n];
    };
    _centroids
};

// ── Build site registry ──────────────────────────────────────────────────────
//  Registry: array of [siteKey, siteType, centroidPos, profile]
private _sites = [];

// Terrain sites
private _terrainSites = missionNamespace getVariable ["ARC_worldTerrainSites", []];
if (!(_terrainSites isEqualType [])) then { _terrainSites = []; };

{
    _x params [["_type", "", [""]], ["_positions", [], [[]]]];
    if ((count _positions) == 0) then { continue; };

    private _profile = [];
    switch (_type) do {
        case "FUELSTATION":  { _profile = _profFuelStation; };
        case "HOSPITAL":     { _profile = _profHospital; };
        case "POWERSOLAR":   { _profile = _profSolar; };
        case "TRANSMITTER":  { _profile = _profTransmitter; };
        default              { _profile = []; };
    };
    if ((count _profile) == 0) then { continue; };

    private _centroids = [_positions, _clusterR] call _fnCluster;
    {
        private _centroid = _x;
        private _key = format ["TERRAIN:%1:%2:%3", _type, round (_centroid select 0), round (_centroid select 1)];
        _sites pushBack [_key, _type, _centroid, _profile];
    } forEach _centroids;
} forEach _terrainSites;

// Named locations with explicit worksite/hospital profiles
private _namedLocations = missionNamespace getVariable ["ARC_worldNamedLocations", []];
if (!(_namedLocations isEqualType [])) then { _namedLocations = []; };

{
    _x params [["_id", "", [""]], ["_displayName", "", [""]], ["_pos", [0,0,0], [[]]]];
    if (_id isEqualTo "") then { continue; };
    if ((count _pos) < 2) then { continue; };

    private _idLower = toLower _id;
    private _profile = [];
    if ((_idLower find "hospital") >= 0) then { _profile = _profHospital; };
    if ((_idLower find "industrial") >= 0) then { _profile = _profWorksite; };
    if ((_idLower find "refinery") >= 0 || { (_idLower find "oilfield") >= 0 } || { (_idLower find "oilrefinery") >= 0 }) then { _profile = _profWorksite; };
    if ((_idLower find "port") >= 0) then { _profile = _profWorksite; };
    if ((count _profile) == 0) then { continue; };

    private _key = format ["NAMED:%1", _id];
    // Avoid duplicate if a terrain site centroid is already within 120m
    private _dup = false;
    {
        private _row = _x;
        if ((count _row) < 3) then { continue; };
        private _existPos = _row select 2;
        if ((count _existPos) < 2) then { continue; };
        if (([_pos select 0, _pos select 1, 0] distance2D [_existPos select 0, _existPos select 1, 0]) < 120) exitWith { _dup = true; };
    } forEach _sites;
    if (_dup) then { continue; };

    _sites pushBack [_key, "NAMED", _pos, _profile];
} forEach _namedLocations;

missionNamespace setVariable ["civsub_v1_locnpc_sites", _sites, false];
missionNamespace setVariable ["civsub_v1_locnpc_registry", createHashMap, true];

private _tickS = missionNamespace getVariable ["civsub_v1_locnpc_tick_s", 10];
if (!(_tickS isEqualType 0)) then { _tickS = 10; };
if (_tickS < 5) then { _tickS = 5; };
missionNamespace setVariable ["civsub_v1_locnpc_tick_s", _tickS, true];

diag_log format ["[CIVLOC][INIT] enabled=YES sites=%1 tickS=%2", count _sites, _tickS];

[] spawn
{
    while { isServer && { missionNamespace getVariable ["civsub_v1_enabled", false] } && { missionNamespace getVariable ["civsub_v1_locnpc_enabled", false] } } do
    {
        [] call ARC_fnc_civsubLocNpcTick;

        private _s = missionNamespace getVariable ["civsub_v1_locnpc_tick_s", 10];
        if !(_s isEqualType 0) then { _s = 10; };
        if (_s < 5) then { _s = 5; };
        uiSleep _s;
    };

    missionNamespace setVariable ["civsub_v1_locnpc_threadRunning", false, true];
};

true

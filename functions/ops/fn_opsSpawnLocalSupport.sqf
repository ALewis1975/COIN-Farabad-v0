/*
    ARC_fnc_opsSpawnLocalSupport

    Server: Spawn host-nation / local friendly forces already on scene at an objective.

    Intended for tasks involving civilian infrastructure controlled by friendly/local forces.
    Spawns a small garrison element (in nearby buildings) and a small patrol element.

    Params:
        0: STRING - taskId
        1: STRING - incidentType (e.g. "CIVIL")
        2: STRING - incidentMarker (Eden marker id, if available)
        3: STRING - incidentDisplayName
        4: ARRAY  - center pos ATL [x,y,z]
        5: NUMBER - suggested radius (meters) (default 120)

    Returns:
        ARRAY - netId strings for spawned units
*/

if (!isServer) exitWith {[]};

params [
    ["_taskId", "", [""]],
    ["_typeU", "", [""]],
    ["_marker", "", [""]],
    ["_disp", "", [""]],
    ["_posATL", [], [[]]],
    ["_radius", 120, [0]]
];

if (_taskId isEqualTo "") exitWith {[]};
if (!(_posATL isEqualType []) || { (count _posATL) < 2 }) exitWith {[]};

private _todPolicy = [] call ARC_fnc_dynamicTodGetPolicy;
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _canSpawnOps = [_todPolicy, "canSpawnOps", true] call _hg;
if (!(_canSpawnOps isEqualType true) && !(_canSpawnOps isEqualType false)) then { _canSpawnOps = true; };
if (!_canSpawnOps) exitWith {[]};
private _todPhase = [_todPolicy, "phase", "DAY"] call _hg;
if (!(_todPhase isEqualType "")) then { _todPhase = "DAY"; };

private _enabled = missionNamespace getVariable ["ARC_localSupportEnabled", true];
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {[]};

private _persistInAO = missionNamespace getVariable ["ARC_localSupportPersistInAO", false];
if (!(_persistInAO isEqualType true) && !(_persistInAO isEqualType false)) then { _persistInAO = false; };

private _dynSim = missionNamespace getVariable ["ARC_localSupportDynamicSimEnabled", true];
if (!(_dynSim isEqualType true) && !(_dynSim isEqualType false)) then { _dynSim = true; };

// Optional LAMBS behaviors for friendly support units.
// Safe to run without the mod; we guard isNil before spawning tasks.
private _useLambs = missionNamespace getVariable ["ARC_supportUseLAMBS", true];
if (!(_useLambs isEqualType true) && !(_useLambs isEqualType false)) then { _useLambs = true; };

private _type = toUpper _typeU;
private _pos = +_posATL; _pos resize 3;

private _eligible = missionNamespace getVariable ["ARC_localSupportEligibleTypes", ["CIVIL","CHECKPOINT","DEFEND"]];
if (!(_eligible isEqualType [])) then { _eligible = ["CIVIL","CHECKPOINT","DEFEND"]; };
_eligible = _eligible apply { toUpper _x };
// IED cordons are authoritative for Farabad COIN. Even if a mission overrides the allow-list,
// IED must remain eligible.
if !((_type in _eligible) || { _type isEqualTo "IED" }) exitWith {[]};

// Keep the Airbase/JBF clean by default.
private _zone = [_pos] call ARC_fnc_worldGetZoneForPos;
if ((toUpper _zone) isEqualTo "AIRBASE") exitWith {[]};

private _excludeMarkers = missionNamespace getVariable ["ARC_localSupportExcludeMarkers", ["mkr_airbaseCenter","ARC_m_base_toc","ARC_convoy_start"]];
if (!(_excludeMarkers isEqualType [])) then { _excludeMarkers = ["mkr_airbaseCenter","ARC_m_base_toc","ARC_convoy_start"]; };
if (_marker in _excludeMarkers) exitWith {[]};

// Spawn rules:
//   - CIVIL / CHECKPOINT tasks: assume local forces already on scene.
//   - DEFEND tasks: spawn locals only on known infrastructure markers (avoid military compounds).
private _allow = false;

if (_type in ["CIVIL", "CHECKPOINT"]) then
{
    _allow = true;
}
else
{
    private _allowMarkers = missionNamespace getVariable ["ARC_localSupportMarkers", []];
    if (!(_allowMarkers isEqualType []) || { (count _allowMarkers) isEqualTo 0 }) then
    {
        // Default allow-list (civilian/industrial infrastructure under local control)
        _allowMarkers = [
            "ARC_loc_GreenZone",
            "ARC_loc_GrandMosque",
            "ARC_loc_BelleFoilleHotel",
            "ARC_loc_hospital",
            "ARC_loc_industrial022",
            "ARC_loc_KarkanakPrison",
            "ARC_loc_SolarFarm",
            "ARC_loc_PortFarabad",
            "ARC_loc_PresidentialPalace",
            "ARC_loc_EmbassyCompound",
            "ARC_loc_AwenaResevoir",
            "ARC_loc_JaziraOilRefinery",
            "marker_14",
            "ARC_loc_JaziraOilField"
        ];
    };

    _allow = (_marker in _allowMarkers);

    // Fallback: if the marker isn't in the allow-list, allow if the display name strongly implies
    // local-controlled infrastructure.
    if (!_allow) then
    {
        private _dn = toLower _disp;
        _allow =
            (_dn find "hospital") >= 0
            || (_dn find "mosque") >= 0
            || (_dn find "hotel") >= 0
            || (_dn find "palace") >= 0
            || (_dn find "embassy") >= 0
            || (_dn find "port") >= 0
            || (_dn find "prison") >= 0
            || (_dn find "reservoir") >= 0
            || (_dn find "refinery") >= 0
            || (_dn find "oil") >= 0
            || (_dn find "solar") >= 0
            || (_dn find "infrastructure") >= 0;
    };
};

if (!_allow) exitWith {[]};

// Presence radius (spawning + reuse)
private _presenceR = missionNamespace getVariable [format ["ARC_localSupportRadiusM_%1", _type], (_radius max 80) min 250];
if (!(_presenceR isEqualType 0)) then { _presenceR = (_radius max 80) min 250; };
_presenceR = (_presenceR max 50) min 500;

// Reuse existing local-support units near this AO (prevents stacking if tasks repeat at same site)
private _reuseExisting = missionNamespace getVariable ["ARC_localSupportReuseExisting", true];
if (!(_reuseExisting isEqualType true) && !(_reuseExisting isEqualType false)) then { _reuseExisting = true; };

if (_reuseExisting) then
{
    private _existing = allUnits select {
        alive _x
        && { !isPlayer _x }
        && { (_x getVariable ["ARC_isLocalSupport", false]) }
        && { (_x distance2D _pos) <= _presenceR }
    };

    if ((count _existing) >= 3) exitWith
    {
        private _nids = _existing apply { netId _x };

        // Associate them with the current task and pull them out of deferred cleanup queue (if queued).
        { _x setVariable ["ARC_localSupportTaskId", _taskId, true]; } forEach _existing;

        private _q = ["cleanupQueue", []] call ARC_fnc_stateGet;
        if (_q isEqualType []) then
        {
            _q = _q select { !((_x isEqualType []) && { (count _x) >= 1 } && { (_x select 0) in _nids }) };
            ["cleanupQueue", _q] call ARC_fnc_stateSet;
        };

        _nids
    };
};


// Side for locals: force BLUFOR (west). 3CB provides Takistan BLUFOR units, so we do not use Independent here.
private _side = missionNamespace getVariable ["ARC_localSupportSide", west];
if (!(_side isEqualTo west)) then { _side = west; };

// Map side -> config side number (CfgVehicles >> side)
private _fn_sideNum = {
    params ["_s"];
    if (_s isEqualTo east) exitWith { 0 };
    if (_s isEqualTo west) exitWith { 1 };
    if (_s isEqualTo independent) exitWith { 2 };
    if (_s isEqualTo civilian) exitWith { 3 };
    1
};

private _sideNum = [_side] call _fn_sideNum;

// Decide whether to use Police (TNP) or Army (TNA) for this site.
private _key = toLower (format ["%1 %2", _marker, _disp]);
private _useArmy = false;
if (_type isEqualTo "DEFEND") then { _useArmy = true; };

if ((_key find "oil") >= 0 || { (_key find "refinery") >= 0 } || { (_key find "solar") >= 0 } || { (_key find "prison") >= 0 } || { (_key find "palace") >= 0 } || { (_key find "embassy") >= 0 } || { (_key find "military") >= 0 }) then
{
    _useArmy = true;
};

private _factionId = if (_useArmy) then
{
    missionNamespace getVariable ["ARC_localSupportFaction_TNA", "UK3CB_TKA_B"]
}
else
{
    missionNamespace getVariable ["ARC_localSupportFaction_TNP", "UK3CB_TKP_B"]
};
if (!(_factionId isEqualType "")) then { _factionId = if (_useArmy) then { "UK3CB_TKA_B" } else { "UK3CB_TKP_B" }; };

private _userKey   = if (_useArmy) then { "ARC_localTnaUnitClasses" } else { "ARC_localTnpUnitClasses" };
private _cacheBase = if (_useArmy) then { "ARC_localTnaUnitClasses_cached" } else { "ARC_localTnpUnitClasses_cached" };
private _cacheKey  = format ["%1_%2", _cacheBase, _factionId];

private _classes = missionNamespace getVariable [_userKey, []];
if (!(_classes isEqualType [])) then { _classes = []; };

if ((count _classes) isEqualTo 0) then
{
    private _cached = missionNamespace getVariable [_cacheKey, []];
    if (_cached isEqualType [] && { (count _cached) > 0 }) then
    {
        _classes = +_cached;
    }
    else
    {
        private _found = [];
        private _cfg = configFile >> "CfgVehicles";
        private _sideNum = [_side] call _fn_sideNum;
        {
            if (getNumber (_x >> "scope") != 2) then { continue; };
            if ((getText (_x >> "faction")) != _factionId) then { continue; };
            if (getNumber (_x >> "side") != _sideNum) then { continue; };

            private _cn = configName _x;
            if (_cn isKindOf "Man") then
            {
                _found pushBack _cn;
            };
        } forEach ("true" configClasses _cfg);

        missionNamespace setVariable [_cacheKey, _found];
        _classes = _found;
    };
};

_classes = _classes select { isClass (configFile >> "CfgVehicles" >> _x) };
if ((count _classes) isEqualTo 0) then
{
    // BLUFOR fallback (keeps "friendly only" constraint even if 3CB BLUFOR factions are missing).
    _classes = [
        "B_GEN_Soldier_F",
        "B_GEN_Commander_F",
        "B_Soldier_F",
        "B_Soldier_AR_F",
        "B_Soldier_LAT_F"
    ];
    _classes = _classes select { isClass (configFile >> "CfgVehicles" >> _x) };
    if ((count _classes) isEqualTo 0) then { _classes = ["B_Soldier_F"]; };
};

// Counts (tunable per type)
private _garrisonN = missionNamespace getVariable [format ["ARC_localSupportGarrisonCount_%1", _type], -1];
if (!(_garrisonN isEqualType 0) || { _garrisonN < 0 }) then
{
    _garrisonN = switch (_type) do
    {
        case "CHECKPOINT": { 6 };
        case "CIVIL":      { 6 };
        case "IED":        { 6 };
        case "DEFEND":     { 8 };
        case "QRF":        { 8 };
        default             { 6 };
    };
};

private _patrolN = missionNamespace getVariable [format ["ARC_localSupportPatrolCount_%1", _type], -1];
if (!(_patrolN isEqualType 0) || { _patrolN < 0 }) then
{
    _patrolN = switch (_type) do
    {
        case "CHECKPOINT": { 4 };
        case "CIVIL":      { 4 };
        case "IED":        { 4 };
        case "DEFEND":     { 6 };
        case "QRF":        { 6 };
        default             { 4 };
    };
};

_garrisonN = (_garrisonN max 0) min 18;
_patrolN   = (_patrolN max 0) min 18;
private _garrisonR = missionNamespace getVariable ["ARC_localSupportGarrisonRadiusM", (_presenceR min 160)];
if (!(_garrisonR isEqualType 0)) then { _garrisonR = (_presenceR min 160); };
_garrisonR = (_garrisonR max 40) min 260;

// Patrol closer to the objective by default.
private _patrolR = missionNamespace getVariable ["ARC_localSupportPatrolRadiusM", (_presenceR min 160)];
if (!(_patrolR isEqualType 0)) then { _patrolR = (_presenceR min 160); };
_patrolR = (_patrolR max 50) min 450;

private _out = [];

// Helper: pick a class
private _fn_pickClass = {
    params ["_pool"];
    if (!(_pool isEqualType []) || { (count _pool) isEqualTo 0 }) exitWith { "B_Soldier_F" };
    selectRandom _pool
};

// Helper: building positions
private _fn_buildingPositions = {
    params ["_b"];
    private _arr = [];
    if (isNull _b) exitWith { _arr };

    if (!isNil "BIS_fnc_buildingPositions") then
    {
        _arr = [_b] call BIS_fnc_buildingPositions;
    }
    else
    {
        for "_i" from 0 to 40 do
        {
            private _p = _b buildingPos _i;
            if (!(_p isEqualType []) || { (count _p) < 2 }) exitWith {};
            if ((_p select 0) == 0 && { (_p select 1) == 0 }) exitWith {};
            _arr pushBack _p;
        };
    };

    {
        if (_x isEqualType [] && { (count _x) >= 2 }) then
        {
            private _p = +_x; _p resize 3;
            _arr set [_forEachIndex, _p];
        };
    } forEach _arr;

    _arr
};

// Helper: tag unit
private _fn_tagUnit = {
    params ["_u"];
    if (isNull _u) exitWith {};
    _u setVariable ["ARC_isLocalSupport", true, true];
    _u setVariable ["ARC_localSupportTaskId", _taskId, true];
    _u setVariable ["ARC_localSupportMarker", _marker, true];
    _u setVariable ["ARC_localSupportType", _type, true];
    _u setVariable ["ARC_dynamic_tod_phase_spawn", _todPhase, true];
    _u setVariable ["ARC_dynamic_tod_profile_spawn", [_todPolicy, "profile", "STANDARD"] call _hg, true];

    // Persist in AO like static checkpoint compositions (optional).
    if (_persistInAO) then
    {
        _u setVariable ["ARC_persistInAO", true, true];
    };

    // Dynamic simulation keeps persistent locals cheap when players are not nearby.
    if (_dynSim) then
    {
        _u enableDynamicSimulation true;
    };
};



// Helper: group name counter (server-side)
private _fn_nextGroupIdx = {
    private _i = missionNamespace getVariable ["ARC_localSupportGroupCounter", 0];
    if (!(_i isEqualType 0)) then { _i = 0; };
    _i = _i + 1;
    missionNamespace setVariable ["ARC_localSupportGroupCounter", _i];
    _i
};

// Helper: init group
private _fn_initGroup = {
    params ["_sideIn", ["_role", "SUPPORT", [""]]];

    private _g = createGroup [_sideIn, true];
    _g setVariable ["ARC_isLocalSupport", true, true];
    _g setVariable ["ARC_localSupportTaskId", _taskId, true];
    _g setVariable ["ARC_localSupportMarker", _marker, true];
    _g setVariable ["ARC_localSupportType", _type, true];
    _g setVariable ["ARC_localSupportRole", _role, true];
    _g setVariable ["ARC_dynamic_tod_phase_spawn", _todPhase, true];
    _g setVariable ["ARC_dynamic_tod_profile_spawn", [_todPolicy, "profile", "STANDARD"] call _hg, true];
    _g allowFleeing 0;

    // Start friendly locals calm unless threatened.
    _g setBehaviour "SAFE";
    _g setCombatMode "WHITE";

    // Human-readable group naming for command/Zeus/debug.
    private _idx = call _fn_nextGroupIdx;
    private _fTag = if (_useArmy) then { "TNA" } else { "TNP" };
    _g setGroupIdGlobal [format ["LS %1 %2 %3-%4", _fTag, _role, _type, _idx]];

    _g
};

// -----------------------------------------------------------------------------
// Garrison group
// -----------------------------------------------------------------------------
if (_garrisonN > 0) then
{
    private _grpG = [_side, "GARRISON"] call _fn_initGroup;

    private _buildings = nearestObjects [_pos, ["House","Building"], _garrisonR];
    private _bPos = [];

    {
        private _bp = [_x] call _fn_buildingPositions;
        if ((count _bp) > 0) then { _bPos append _bp; };
    } forEach _buildings;

    if (!isNil "BIS_fnc_arrayShuffle") then
    {
        _bPos = _bPos call BIS_fnc_arrayShuffle;
    }
    else
    {
        _bPos = _bPos apply { [random 1, _x] };
        _bPos sort true;
        _bPos = _bPos apply { (_x select 1) };
    };

    for "_i" from 1 to _garrisonN do
    {
        private _spawnP = if ((count _bPos) > 0) then { _bPos deleteAt 0 } else { _pos getPos [10 + random 25, random 360] };
        // Defensive: ensure we always pass a real position [x,y,z] into createUnit
        if (!(_spawnP isEqualType []) || { (count _spawnP) < 2 } || { (count _spawnP) > 3 }) then
        {
            _spawnP = _pos getPos [10 + random 25, random 360];
        };
        _spawnP resize 3;


        private _cls = [_classes] call _fn_pickClass;
        private _u = _grpG createUnit [_cls, _spawnP, [], 0, "NONE"];
        _u setPosATL _spawnP;

        [_u] call _fn_tagUnit;

        _u disableAI "PATH";
        _u setBehaviour "SAFE";
        _u setCombatMode "WHITE";
        _u setUnitPos "MIDDLE";
        doStop _u;

        _out pushBack (netId _u);
    };
};

// -----------------------------------------------------------------------------
// Patrol group
// -----------------------------------------------------------------------------
if (_patrolN > 0) then
{
    private _grpP = [_side, "PATROL"] call _fn_initGroup;

    for "_i" from 1 to _patrolN do
    {
        private _spawnP = _pos getPos [10 + random 35, random 360];
        _spawnP resize 3;
        private _cls = [_classes] call _fn_pickClass;

        private _u = _grpP createUnit [_cls, _spawnP, [], 0, "NONE"];
        _u setPosATL _spawnP;

        [_u] call _fn_tagUnit;

        _u setBehaviour "SAFE";
        _u setCombatMode "WHITE";

        _out pushBack (netId _u);
    };

    // Prefer LAMBS patrol if available, otherwise fall back to CBA patrol, then vanilla waypoints.
    // NOTE: SQF does not support "else if" without wrapping the nested if in an else code block.
    if (_useLambs && { !isNil "lambs_wp_fnc_taskPatrol" }) then
    {
        [_grpP, _pos, _patrolR] spawn lambs_wp_fnc_taskPatrol;
    }
    else
    {
        if (!isNil "CBA_fnc_taskPatrol") then
        {
            [_grpP, _pos, _patrolR, 5, "MOVE", "SAFE", "WHITE", "LIMITED", "STAG COLUMN"] call CBA_fnc_taskPatrol;
        }
        else
        {
            for "_w" from 1 to 4 do
            {
                private _wpPos = _pos getPos [_patrolR * (0.4 + random 0.6), random 360];
                private _wp = _grpP addWaypoint [_wpPos, 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointSpeed "LIMITED";
                _wp setWaypointBehaviour "SAFE";
                _wp setWaypointCombatMode "WHITE";
            };

            private _cycle = _grpP addWaypoint [_pos, 0];
            _cycle setWaypointType "CYCLE";
        };
    };
};

_out

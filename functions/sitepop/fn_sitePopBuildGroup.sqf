/*
    ARC_fnc_sitePopBuildGroup

    Server: spawn a single population group for a site.

    Steps:
    1. Parse group definition (roleTag, side, class pool, count range, behavior, radius).
    2. Filter class pool against CfgVehicles (handles absent mods gracefully).
    3. Draw unit count from [min, max] range.
    4. Obtain building slots from ARC_worldBuildingSlots cache; shuffle for variety.
    5. Create group and units; place each unit in a building slot (or random offset
       if slots exhausted).
    6. Strip weapons from civilian-side and prisoner units.
    7. Enable dynamic simulation per unit (cost reduction).
    8. Tag each unit and the group for cleanup.
    9. Call ARC_fnc_sitePopApplyAmbiance.

    Params:
        0: STRING — siteId
        1: ARRAY  — site world position [x, y, z] (ATL)
        2: ARRAY  — population group definition
                    [roleTag, sideStr, unitClassPool, countRange, behavior, spawnRadiusM]

    Returns: GROUP — the spawned group, or grpNull on failure.
*/

if (!isServer) exitWith {grpNull};

params [
    ["_siteId",   "", [""]],
    ["_sitePos",  [], [[]]],
    ["_groupDef", [], [[]]]
];

if (_siteId isEqualTo "") exitWith {grpNull};
if (!(_sitePos isEqualType []) || { (count _sitePos) < 2 }) exitWith {grpNull};
if (!(_groupDef isEqualType []) || { (count _groupDef) < 6 }) exitWith {grpNull};

_groupDef params [
    ["_roleTag",     "unit",   [""]],
    ["_sideStr",     "west",   [""]],
    ["_classPool",   [],       [[]]],
    ["_countRange",  [2, 4],   [[]]],
    ["_behavior",    "wander", [""]],
    ["_spawnRadiusM", 80,      [0]]
];

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

// ---------------------------------------------------------------------------
// Resolve side
// ---------------------------------------------------------------------------
private _side = switch (toLower _sideStr) do
{
    case "west":  { west };
    case "east":  { east };
    case "indep": { independent };
    case "civ":   { civilian };
    default       { west };
};

// ---------------------------------------------------------------------------
// Draw unit count
// ---------------------------------------------------------------------------
private _minCount = 1;
private _maxCount = 4;
if (_countRange isEqualType [] && { (count _countRange) >= 2 }) then
{
    _minCount = ((_countRange select 0) max 1);
    _maxCount = ((_countRange select 1) max _minCount);
};
private _count = _minCount + floor (random ((_maxCount - _minCount + 1)));
_count = _count min _maxCount;

// ---------------------------------------------------------------------------
// Filter class pool
// ---------------------------------------------------------------------------
private _validClasses = _classPool select { isClass (configFile >> "CfgVehicles" >> _x) };
if ((count _validClasses) isEqualTo 0) exitWith
{
    diag_log format ["[ARC][SITEPOP][WARN] ARC_fnc_sitePopBuildGroup: site '%1' role '%2' — no valid classes in pool; group skipped.", _siteId, _roleTag];
    grpNull
};

// ---------------------------------------------------------------------------
// Building slots from pre-scanned cache
// ---------------------------------------------------------------------------
private _slotsMap  = missionNamespace getVariable ["ARC_worldBuildingSlots", createHashMap];
private _slotsData = [_slotsMap, _siteId, [[], []]] call _hg;
private _bldSlots  = [];
if (_slotsData isEqualType [] && { (count _slotsData) >= 1 } && { (_slotsData select 0) isEqualType [] }) then
{
    _bldSlots = +(_slotsData select 0);
};

// Shuffle slots so different roles don't always cluster in the same buildings
if ((count _bldSlots) > 1 && { !isNil "BIS_fnc_arrayShuffle" }) then
{
    _bldSlots = _bldSlots call BIS_fnc_arrayShuffle;
};

// ---------------------------------------------------------------------------
// Effective spawn radius (non-zero guard)
// ---------------------------------------------------------------------------
private _spawnR = if (_spawnRadiusM > 0) then { _spawnRadiusM } else { 80 };

private _p3 = +_sitePos;
if ((count _p3) < 3) then { _p3 pushBack 0; };

// ---------------------------------------------------------------------------
// Parked-vehicle path (behavior = "parked")
// Creates vehicles from roadside positions in the building-index cache; returns
// a persistent group (auto-delete disabled) that carries an ARC_sitePop_vehicles
// variable for cleanup by ARC_fnc_sitePopDespawnSite.
// ---------------------------------------------------------------------------
if (_behavior isEqualTo "parked") exitWith
{
    private _roadsideSlots = [];
    if (_slotsData isEqualType [] && { (count _slotsData) >= 2 } && { (_slotsData select 1) isEqualType [] }) then
    {
        _roadsideSlots = +(_slotsData select 1);
    };
    if ((count _roadsideSlots) > 1 && { !isNil "BIS_fnc_arrayShuffle" }) then
    {
        _roadsideSlots = _roadsideSlots call BIS_fnc_arrayShuffle;
    };

    // false = do not auto-delete when empty; vehicles are tracked via variable
    private _grp = createGroup [_side, false];
    _grp setVariable ["ARC_sitePop_siteId", _siteId];
    _grp setVariable ["ARC_sitePop_role",   _roleTag];

    private _vehicles = [];
    for "_i" from 1 to _count do
    {
        private _spawnPos = [];
        if ((count _roadsideSlots) > 0) then
        {
            _spawnPos = _roadsideSlots deleteAt 0;
        }
        else
        {
            private _ang  = random 360;
            private _dist = 5 + random _spawnR;
            _spawnPos = [(_p3 select 0) + (sin _ang) * _dist, (_p3 select 1) + (cos _ang) * _dist, 0];
        };

        if (!(_spawnPos isEqualType []) || { (count _spawnPos) < 2 }) then
        {
            private _ang  = random 360;
            private _dist = 5 + random _spawnR;
            _spawnPos = [(_p3 select 0) + (sin _ang) * _dist, (_p3 select 1) + (cos _ang) * _dist, 0];
        };

        _spawnPos resize 3;

        private _cls = selectRandom _validClasses;
        private _veh = createVehicle [_cls, _spawnPos, [], 0, "NONE"];
        _veh setPosATL _spawnPos;
        _veh lock true;
        _veh enableDynamicSimulation true;
        _veh setVariable ["ARC_sitePop_siteId", _siteId];
        _veh setVariable ["ARC_sitePop_role",   _roleTag];
        _vehicles pushBack _veh;
    };

    _grp setVariable ["ARC_sitePop_vehicles", _vehicles];

    diag_log format ["[ARC][SITEPOP][INFO] ARC_fnc_sitePopBuildGroup: site '%1' role '%2' — %3 vehicle(s) spawned (parked).", _siteId, _roleTag, count _vehicles];

    _grp
};

// ---------------------------------------------------------------------------
// Create group
// ---------------------------------------------------------------------------
private _grp = createGroup [_side, true]; // true = delete group when empty

_grp setVariable ["ARC_sitePop_siteId", _siteId];
_grp setVariable ["ARC_sitePop_role",   _roleTag];

if (!(_side isEqualTo civilian)) then
{
    _grp allowFleeing 0;
};

_grp setBehaviour "SAFE";
_grp setCombatMode "WHITE";

private _grpIdx = missionNamespace getVariable ["ARC_sitePopGroupCounter", 0];
if (!(_grpIdx isEqualType 0)) then { _grpIdx = 0; };
_grpIdx = _grpIdx + 1;
missionNamespace setVariable ["ARC_sitePopGroupCounter", _grpIdx];
_grp setGroupIdGlobal [format ["SP %1 %2-%3", _siteId, _roleTag, _grpIdx]];

// ---------------------------------------------------------------------------
// Spawn units
// ---------------------------------------------------------------------------
for "_i" from 1 to _count do
{
    private _spawnPos = [];
    if ((count _bldSlots) > 0) then
    {
        _spawnPos = _bldSlots deleteAt 0;
    }
    else
    {
        private _ang  = random 360;
        private _dist = 5 + random _spawnR;
        _spawnPos = [(_p3 select 0) + (sin _ang) * _dist, (_p3 select 1) + (cos _ang) * _dist, 0];
    };

    if (!(_spawnPos isEqualType []) || { (count _spawnPos) < 2 }) then
    {
        private _ang  = random 360;
        private _dist = 5 + random _spawnR;
        _spawnPos = [(_p3 select 0) + (sin _ang) * _dist, (_p3 select 1) + (cos _ang) * _dist, 0];
    };

    _spawnPos resize 3;

    private _cls = selectRandom _validClasses;
    private _u   = _grp createUnit [_cls, _spawnPos, [], 0, "NONE"];
    _u setPosATL _spawnPos;

    // Tag unit for cleanup
    _u setVariable ["ARC_sitePop_siteId", _siteId];
    _u setVariable ["ARC_sitePop_role",   _roleTag];

    // Strip weapons: civilians and prisoners are always unarmed
    private _stripWeapons = ((_sideStr isEqualTo "civ") || { _roleTag isEqualTo "prisoner" });
    if (_stripWeapons) then
    {
        removeAllWeapons _u;
        removeAllItems _u;
    };

    // Reduce simulation cost when players are absent
    _u enableDynamicSimulation true;
};

// ---------------------------------------------------------------------------
// Apply LAMBS or vanilla ambiance behavior
// ---------------------------------------------------------------------------
[_grp, _behavior, _p3, _spawnR] call ARC_fnc_sitePopApplyAmbiance;

diag_log format ["[ARC][SITEPOP][INFO] ARC_fnc_sitePopBuildGroup: site '%1' role '%2' — %3 unit(s) spawned.", _siteId, _roleTag, count (units _grp)];

_grp

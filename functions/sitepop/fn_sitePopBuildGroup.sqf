/*
    ARC_fnc_sitePopBuildGroup

    Server: spawn a single population group for a site.

    Steps:
    1. Parse group definition (roleTag, side, class pool, count range, behavior, radius,
       optional spawnAnchor marker).
    2. Resolve effective spawn position: if spawnAnchor is a valid Eden marker, use its
       world position; otherwise fall back to the site centre.
    3. Filter class pool against CfgVehicles (handles absent mods gracefully).
    4. Draw unit count from [min, max] range; apply optional spawnCtx count delta.
    5. Obtain building slots from ARC_worldBuildingSlots cache; filter to anchor radius
       when an anchor is active; shuffle for variety.
    6. Create group and units; place each unit in a filtered slot (or random offset
       within anchor radius if slots exhausted).
    7. Strip weapons from civilian-side and prisoner units; strip vest/backpack and
       apply persistent tags for prisoner roles.
    8. Enable dynamic simulation per unit (cost reduction).
    9. Tag each unit and the group for cleanup.
   10. Call ARC_fnc_sitePopApplyAmbiance with anchor-aware position and marker name.

    Params:
        0: STRING — siteId
        1: ARRAY  — site world position [x, y, z] (ATL)
        2: ARRAY  — population group definition
                    [roleTag, sideStr, unitClassPool, countRange, behavior, spawnRadiusM]
                    Optional 7th element: spawnAnchor (STRING — Eden marker name for
                    zone-local slot filtering and wander; "" = site-wide, no anchor)
        3: ANY    — (optional) spawnCtx HashMap from ARC_fnc_sitePopGetSpawnModifiers.
                    Supported keys:
                      "roleDelta" → HashMap of roleTag → INTEGER count delta.

    Returns: GROUP — the spawned group, or grpNull on failure.
*/

if (!isServer) exitWith {grpNull};

params [
    ["_siteId",   "", [""]],
    ["_sitePos",  [], [[]]],
    ["_groupDef", [], [[]]],
    ["_spawnCtx", []]
];

if (_siteId isEqualTo "") exitWith {grpNull};
if (!(_sitePos isEqualType []) || { (count _sitePos) < 2 }) exitWith {grpNull};
if (!(_groupDef isEqualType []) || { (count _groupDef) < 6 }) exitWith {grpNull};

_groupDef params [
    ["_roleTag",      "unit",   [""]],
    ["_sideStr",      "west",   [""]],
    ["_classPool",    [],       [[]]],
    ["_countRange",   [2, 4],   [[]]],
    ["_behavior",     "wander", [""]],
    ["_spawnRadiusM", 80,       [0]],
    ["_spawnAnchor",  "",       [""]]
];

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

// ---------------------------------------------------------------------------
// Resolve effective spawn position from optional anchor marker
// ---------------------------------------------------------------------------
private _hasAnchor        = false;
private _effectiveSitePos = _sitePos;

if (!(_spawnAnchor isEqualTo "")) then
{
    if (!((getMarkerType _spawnAnchor) isEqualTo "")) then
    {
        private _anchorPos = getMarkerPos _spawnAnchor;
        private _anchorP3  = +_anchorPos;
        if ((count _anchorP3) < 3) then { _anchorP3 pushBack 0; };
        _effectiveSitePos = _anchorP3;
        _hasAnchor = true;
    }
    else
    {
        diag_log format ["[ARC][SITEPOP][WARN] ARC_fnc_sitePopBuildGroup: site '%1' role '%2' — anchor marker '%3' not found in mission; using site centre.", _siteId, _roleTag, _spawnAnchor];
    };
};

// ---------------------------------------------------------------------------
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

// Apply spawnCtx count delta (per-role modifier from fn_sitePopGetSpawnModifiers)
if (_spawnCtx isEqualType createHashMap) then
{
    private _roleDelta = [_spawnCtx, "roleDelta", createHashMap] call _hg;
    if (_roleDelta isEqualType createHashMap) then
    {
        private _delta = [_roleDelta, _roleTag, 0] call _hg;
        if (_delta isEqualType 0 && { !(_delta isEqualTo 0) }) then
        {
            _count = (_count + _delta) max 1;
        };
    };
};

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

// Filter building slots to anchor-local radius when an anchor is active.
// Removes slots outside spawnRadiusM of the anchor marker so units only
// occupy buildings within their designated subzone.
if (_hasAnchor) then
{
    private _anchorR2 = _spawnRadiusM * _spawnRadiusM;
    private _anchorX  = _effectiveSitePos select 0;
    private _anchorY  = _effectiveSitePos select 1;
    private _filtered = [];
    {
        if (!(_x isEqualType []) || { (count _x) < 2 }) then { continue; };
        private _dx = (_x select 0) - _anchorX;
        private _dy = (_x select 1) - _anchorY;
        if ((_dx * _dx + _dy * _dy) <= _anchorR2) then
        {
            _filtered pushBack _x;
        };
    } forEach _bldSlots;
    _bldSlots = _filtered;
};

// ---------------------------------------------------------------------------
// Effective spawn radius (non-zero guard)
// ---------------------------------------------------------------------------
private _spawnR = if (_spawnRadiusM > 0) then { _spawnRadiusM } else { 80 };

private _p3 = +_effectiveSitePos;
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

    // Filter roadside slots to anchor-local radius when an anchor is active.
    if (_hasAnchor) then
    {
        private _anchorR2 = _spawnRadiusM * _spawnRadiusM;
        private _anchorX  = _effectiveSitePos select 0;
        private _anchorY  = _effectiveSitePos select 1;
        private _filteredR = [];
        {
            if (!(_x isEqualType []) || { (count _x) < 2 }) then { continue; };
            private _dx = (_x select 0) - _anchorX;
            private _dy = (_x select 1) - _anchorY;
            if ((_dx * _dx + _dy * _dy) <= _anchorR2) then
            {
                _filteredR pushBack _x;
            };
        } forEach _roadsideSlots;
        _roadsideSlots = _filteredR;
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

        // Collision avoidance: skip positions already occupied by another vehicle.
        if ((count (nearestObjects [_spawnPos, ["LandVehicle"], 6])) > 0) then { continue; };

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

    // Strip weapons: civilians and prisoners are always unarmed.
    // Prisoner detection: any roleTag containing the substring "prisoner" qualifies
    // (covers prisoner_dorm_01..04, prisoner_holding, prisoner).
    // NOTE: no other role in farabad_site_templates.sqf contains this substring;
    // verify before adding roles with "prisoner" in the name for non-prisoner purposes.
    private _isPrisoner    = ((_roleTag find "prisoner") >= 0);
    private _stripWeapons  = ((_sideStr isEqualTo "civ") || { _isPrisoner });
    if (_stripWeapons) then
    {
        removeAllWeapons _u;
        removeAllItems _u;
    };

    // Prisoner-specific: strip vest/backpack and apply persistent identity tags.
    if (_isPrisoner) then
    {
        removeVest _u;
        removeBackpack _u;
        _u setVariable ["ARC_prisoner",      true,         false];
        _u setVariable ["ARC_prisonHomeZone", _spawnAnchor, false];
        _u setVariable ["ARC_prisonRiskTier", "low",        false];
    };

    // Reduce simulation cost when players are absent
    _u enableDynamicSimulation true;
};

// ---------------------------------------------------------------------------
// Deferred re-strip for prisoner units.
// The UK3CB Factions mod registers a unit_loadout event handler that re-applies
// the class loadout (including backpack) in the simulation frame after createUnit.
// Scheduling a second strip after one frame ensures UK3CB's EH runs first.
// ---------------------------------------------------------------------------
private _isPrisonerRole = ((_roleTag find "prisoner") >= 0);
if (_isPrisonerRole) then
{
    private _prisonerUnits = units _grp select { _x getVariable ["ARC_prisoner", false] };
    if ((count _prisonerUnits) > 0) then
    {
        _prisonerUnits spawn
        {
            sleep 0.1;
            {
                removeAllWeapons _x;
                removeAllItems _x;
                removeVest _x;
                removeBackpack _x;
            } forEach _this;
        };
    };
};

// ---------------------------------------------------------------------------
// CIVSUB identity and interaction registration for prisoner units.
// Assigns a CIVSUB uid and queues ACE/addAction interactions on clients so
// players can question and interact with prisoners via the contact dialog.
// Guarded: only runs when CIVSUB is enabled and functions are compiled.
// ---------------------------------------------------------------------------
if (_isPrisonerRole && { missionNamespace getVariable ["civsub_v1_enabled", false] } && { !isNil "ARC_fnc_civsubCivAssignIdentity" } && { !isNil "ARC_fnc_civsubDistrictsFindByPos" }) then
{
    private _prisonDistrictId = [_effectiveSitePos] call ARC_fnc_civsubDistrictsFindByPos;
    if (!(_prisonDistrictId isEqualTo "")) then
    {
        {
            if (!isNull _x && { _x getVariable ["ARC_prisoner", false] }) then
            {
                [_x, _prisonDistrictId] call ARC_fnc_civsubCivAssignIdentity;
            };
        } forEach (units _grp);
        diag_log format ["[ARC][SITEPOP][INFO] ARC_fnc_sitePopBuildGroup: site '%1' role '%2' — CIVSUB identities assigned (district=%3).", _siteId, _roleTag, _prisonDistrictId];
    } else {
        diag_log format ["[ARC][SITEPOP][WARN] ARC_fnc_sitePopBuildGroup: site '%1' role '%2' — prisoner CIVSUB skipped (no district resolved for pos %3).", _siteId, _roleTag, _effectiveSitePos];
    };
};

// ---------------------------------------------------------------------------
// Apply LAMBS or vanilla ambiance behavior
// ---------------------------------------------------------------------------
[_grp, _behavior, _p3, _spawnR, _spawnAnchor] call ARC_fnc_sitePopApplyAmbiance;

diag_log format ["[ARC][SITEPOP][INFO] ARC_fnc_sitePopBuildGroup: site '%1' role '%2' — %3 unit(s) spawned.", _siteId, _roleTag, count (units _grp)];

_grp

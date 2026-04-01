/*
    ARC_fnc_civsubLocNpcTick

    One CIVLOC tick:
      1. Prune null/dead units from the site registry.
      2. Determine which sites are inside any active player bubble.
      3. For each active site, compute desired NPC count for the current
         time-of-day phase and spawn/cull to match.
      4. Enforce global cap.
*/

if (!isServer) exitWith { false };
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith { false };
if !(missionNamespace getVariable ["civsub_v1_locnpc_enabled", false]) exitWith { false };

private _debug = missionNamespace getVariable ["civsub_v1_locnpc_debug", false];
if (!(_debug isEqualType true)) then { _debug = false; };

private _sites    = missionNamespace getVariable ["civsub_v1_locnpc_sites",    []];
private _registry = missionNamespace getVariable ["civsub_v1_locnpc_registry", createHashMap];
if (!(_sites    isEqualType []))          then { _sites    = []; };
if (!(_registry isEqualType createHashMap)) then { _registry = createHashMap; };

// ── 1. Prune dead/null from registry ────────────────────────────────────────
{
    private _key   = _x;
    private _units = _registry get _key;
    if (!(_units isEqualType [])) then { _registry set [_key, []]; continue; };
    private _live = [];
    {
        if (!isNull _x && { alive _x }) then { _live pushBack _x; };
    } forEach _units;
    _registry set [_key, _live];
} forEach (keys _registry);

// ── 2. Players + bubble radius ───────────────────────────────────────────────
private _players  = [] call ARC_fnc_civsubBubbleGetPlayers;
if ((count _players) == 0) exitWith { false };

private _bubbleR = missionNamespace getVariable ["civsub_v1_locnpc_bubbleRadius_m", 500];
if (!(_bubbleR isEqualType 0)) then { _bubbleR = 500; };
_bubbleR = (_bubbleR max 200) min 1000;

// ── 3. Time-of-day phase (reuse civsub_v1_activity_phase set by TrafficTick) ─
private _phase = missionNamespace getVariable ["civsub_v1_activity_phase", "DAY"];
if (!(_phase isEqualType "")) then { _phase = "DAY"; };

// ── 4. Global cap ────────────────────────────────────────────────────────────
private _capG = missionNamespace getVariable ["civsub_v1_locnpc_cap_global", 32];
if (!(_capG isEqualType 0)) then { _capG = 32; };

// Count all currently live loc-NPC units across all sites
private _totalLive = 0;
{
    private _units = _registry get _x;
    if (_units isEqualType []) then { _totalLive = _totalLive + (count _units); };
} forEach (keys _registry);

// ── 5. Process each site ─────────────────────────────────────────────────────
{
    private _row = _x;
    if ((count _row) < 4) then { continue; };
    private _siteKey  = _row select 0;
    private _siteType = _row select 1;
    private _sitePos  = _row select 2;
    private _profile  = _row select 3;

    if (!(_siteKey  isEqualType "")) then { continue; };
    if (!(_sitePos  isEqualType [])) then { continue; };
    if (!(_profile  isEqualType [])) then { continue; };
    if ((count _sitePos) < 2)      then { continue; };
    if ((count _profile) == 0)     then { continue; };

    // Inside any player bubble?
    private _inBubble = false;
    {
        if (!isNull _x && { (getPosATL _x) distance2D [_sitePos select 0, _sitePos select 1, 0] <= _bubbleR }) exitWith { _inBubble = true; };
    } forEach _players;
    if (!_inBubble) then { continue; };

    // Find the profile entry matching current phase (DAY as fallback)
    private _phaseRow = [];
    {
        if ((_x select 0) isEqualTo _phase) exitWith { _phaseRow = _x; };
    } forEach _profile;
    if ((count _phaseRow) == 0) then {
        {
            if ((_x select 0) isEqualTo "DAY") exitWith { _phaseRow = _x; };
        } forEach _profile;
    };
    if ((count _phaseRow) < 3) then { continue; };

    private _minC = _phaseRow select 1;
    private _maxC = _phaseRow select 2;
    private _clss = if ((count _phaseRow) > 3) then { _phaseRow select 3 } else { ["C_man_1"] };
    if (!(_minC isEqualType 0)) then { _minC = 0; };
    if (!(_maxC isEqualType 0)) then { _maxC = 0; };
    if (!(_clss isEqualType [])) then { _clss = ["C_man_1"]; };

    private _desired = _minC + floor (random ((_maxC - _minC + 1) max 1));
    _desired = _desired min _maxC;

    // Current live count for this site
    private _siteUnits = [];
    if (_siteKey in _registry) then { _siteUnits = _registry get _siteKey; };
    if (!(_siteUnits isEqualType [])) then { _siteUnits = []; };
    private _cur = count _siteUnits;

    // Cull excess
    while { _cur > _desired } do {
        private _u = _siteUnits deleteAt (_cur - 1);
        if (!isNull _u && { alive _u }) then { deleteVehicle _u; };
        _cur = _cur - 1;
        _totalLive = (_totalLive - 1) max 0;
    };

    // Spawn deficit (respect global cap; one per tick to avoid burst)
    if (_cur < _desired && { _totalLive < _capG }) then {
        private _u = [_siteKey, _sitePos, _clss] call ARC_fnc_civsubLocNpcSpawn;
        if (!isNull _u) then {
            _siteUnits pushBack _u;
            _totalLive = _totalLive + 1;
        };
    };

    _registry set [_siteKey, _siteUnits];
} forEach _sites;

missionNamespace setVariable ["civsub_v1_locnpc_registry", _registry, true];

if (_debug) then {
    diag_log format ["[CIVLOC][TICK] phase=%1 totalLive=%2 sites=%3 bubbleR=%4", _phase, _totalLive, count _sites, _bubbleR];
};

true

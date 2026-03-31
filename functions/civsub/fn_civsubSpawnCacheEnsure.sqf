/*
    ARC_fnc_civsubSpawnCacheEnsure

    Builds/refreshes a per-district spawn cache containing:
      - building interior positions (preferred)
      - roadside positions (secondary)

    Hotfix10:
      - Includes player positions (per district) as settlement anchors so that
        civilians populate where players operate, even if the map label is not
        a registered Location.

    Milestone 1:
      - Cache invalidation is driven by player operating area changes (anchorKey),
        not TTL alone. If players move to a different settlement/area inside the
        same district, the cache rebuilds immediately.
      - Anchor selection is deterministic and bounded:
          1) nearest named location to player operating area within locRadius
          2) player centroid (quantized)
          3) district centroid

    Params:
      0: districtId (string)

    Returns: HashMap with keys:
      - bldPos (array)
      - roadPos (array)
      - ts (number)
      - anchorKey (string)
      - anchorPos (array [x,y,z])
*/

if (!isServer) exitWith {createHashMap};

params [["_did","",[""]]];
if (_did isEqualTo "") exitWith {createHashMap};

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";

private _dbg = missionNamespace getVariable ["civsub_v1_debug", false];

// Phase 2 helpers (defined in civsubInitServer)
private _posIsRoadish = missionNamespace getVariable ["ARC_civsub_fnc_posIsRoadish", { params ["_p"]; isOnRoad _p }];

// Exclusion zones (shared with CivFindSpawnPos fallback)
private _zones = missionNamespace getVariable ["civsub_v1_civ_exclusion_zones", []];
if (!(_zones isEqualType []) || {(count _zones) == 0}) then { _zones = [["mkr_airbaseCenter", 1600]]; };

private _inExclusion = {
    params ["_p"];
    if (!(_p isEqualType []) || {(count _p) < 2}) exitWith {false};
    private _px = _p # 0;
    private _py = _p # 1;
    {
        private _mk = _x # 0;
        private _r  = _x # 1;
        private _mp = getMarkerPos _mk;
        if (_mp isEqualType [] && {(count _mp) >= 2}) then {
            if (([_px, _py] distance2D _mp) < _r) exitWith {true};
        };
    } forEach _zones;
    false
};

// Roadside offset (prevents spawning in the middle of roads)
private _roadOff = missionNamespace getVariable ["civsub_v1_spawn_roadside_offset_m", 4];
if !(_roadOff isEqualType 0) then { _roadOff = 4; };
if (_roadOff < 2) then { _roadOff = 2; };
if (_roadOff > 12) then { _roadOff = 12; };

private _roadsideFromRoad =
{
    params ["_r"];
    private _p0 = getPosATL _r;
    if (!(_p0 isEqualType []) || {(count _p0) < 2}) exitWith { [0,0,0] };
    if ((count _p0) == 2) then { _p0 = [_p0 # 0, _p0 # 1, 0]; };

    private _dir = getDir _r;
    private _con = roadsConnectedTo _r;
    if ((count _con) > 0) then {
        private _p1 = getPosATL (_con # 0);
        if (_p1 isEqualType [] && {(count _p1) >= 2}) then {
            _dir = [_p0, _p1] call BIS_fnc_dirTo;
        };
    };

    private _side = if ((random 1) < 0.5) then { 90 } else { -90 };
    private _tries = 0;
    private _p = [0,0,0];

    while { _tries < 3 } do {
        private _off = _roadOff + (_tries * (_roadOff * 0.75));
        private _sd = _dir + _side;
        private _x = (_p0 # 0) + (sin _sd) * _off;
        private _y = (_p0 # 1) + (cos _sd) * _off;
        private _zASL = getTerrainHeightASL [_x, _y];
        _p = ASLToATL [_x, _y, _zASL];

        if (!(_p isEqualTo [0,0,0]) && { !(surfaceIsWater _p) } && { !([_p] call _inExclusion) } && { !([_p] call _posIsRoadish) }) exitWith {};
        _side = -_side;
        _tries = _tries + 1;
    };

    _p
};


private _cache = missionNamespace getVariable ["civsub_v1_spawn_cache", createHashMap];
if !(_cache isEqualType createHashMap) then { _cache = createHashMap; };

private _row = _cache getOrDefault [_did, createHashMap];
if !(_row isEqualType createHashMap) then { _row = createHashMap; };

private _ttl = missionNamespace getVariable ["civsub_v1_spawn_cache_ttl_s", 600];
if !(_ttl isEqualType 0) then { _ttl = 600; };

private _ts = _row getOrDefault ["ts", 0];
private _needTTL = ((serverTime - _ts) > _ttl);

private _bld = _row getOrDefault ["bldPos", []];
private _road = _row getOrDefault ["roadPos", []];
if !(_bld isEqualType []) then { _bld = []; };
if !(_road isEqualType []) then { _road = []; };

// District metadata
private _d = [_did] call ARC_fnc_civsubDistrictsGetById;
private _dm = createHashMap;
if (_d isEqualType createHashMap) then { _dm = _d; } else { if (_d isEqualType []) then { _dm = [_d] call _hmCreate; }; };

private _center = _dm getOrDefault ["centroid", [0,0]];
private _radius = _dm getOrDefault ["radius_m", 500];
if !(_center isEqualType [] && {(count _center) >= 2}) exitWith { _row };

// Player anchors (server-only) for this district
private _pAnchMap = missionNamespace getVariable ["civsub_v1_spawn_player_anchors", createHashMap];
if !(_pAnchMap isEqualType createHashMap) then { _pAnchMap = createHashMap; };
private _pAnch = _pAnchMap getOrDefault [_did, []];
if !(_pAnch isEqualType []) then { _pAnch = []; };

private _anchorTypes = ["NameVillage","NameCity","NameCityCapital","NameLocal"];
private _locRadius = missionNamespace getVariable ["civsub_v1_spawn_cache_locRadius_m", 1500];
if !(_locRadius isEqualType 0) then { _locRadius = 1500; };

// Determine primary anchor + anchorKey (for invalidation)
private _primaryPos = _center;
private _anchorKey = format ["CENT:%1", _did];
private _playerCent = [];

if ((count _pAnch) > 0) then {
    // Player centroid
    private _sx = 0;
    private _sy = 0;
    {
        if (_x isEqualType [] && {(count _x) >= 2}) then {
            _sx = _sx + (_x # 0);
            _sy = _sy + (_x # 1);
        };
    } forEach _pAnch;
    _playerCent = [_sx / (count _pAnch), _sy / (count _pAnch), 0];

    // Best nearby named location (nearest to any player anchor)
    private _bestLoc = locationNull;
    private _bestPos = [];
    private _bestD = 1e12;

    {
        private _pos = _x;
        if (_pos isEqualType [] && {(count _pos) >= 2}) then {
            private _locs = nearestLocations [_pos, _anchorTypes, _locRadius];
            if ((count _locs) > 0) then {
                private _loc = _locs # 0; // nearestLocations is distance-ordered
                private _lp = locationPosition _loc;
                if (_lp isEqualType [] && {(count _lp) >= 2}) then {
                    private _d2 = _pos distance2D _lp;
                    if (_d2 < _bestD) then {
                        _bestD = _d2;
                        _bestLoc = _loc;
                        _bestPos = _lp;
                    };
                };
            };
        };
    } forEach _pAnch;

    if (!(isNull _bestLoc) && {_bestD <= _locRadius} && {_bestPos isEqualType [] && {(count _bestPos) >= 2}}) then {
        _primaryPos = if ((count _bestPos) == 2) then { [_bestPos#0,_bestPos#1,0] } else { _bestPos };

        private _n = text _bestLoc;
        if (_n isEqualType "") then {
            // text may be empty for some NameLocal entries; fall back to position key
            if (_n isEqualTo "") then {
                _anchorKey = format ["LOC:%1:%2", round (_primaryPos#0), round (_primaryPos#1)];
            } else {
                _anchorKey = format ["LOC:%1", _n];
            };
        };
    } else {
        // No nearby named location; use quantized player centroid as key
        _primaryPos = _playerCent;
        private _g = missionNamespace getVariable ["civsub_v1_spawn_cache_playerGrid_m", 250];
        if !(_g isEqualType 0) then { _g = 250; };
        if (_g < 50) then { _g = 50; };
        _anchorKey = format ["P:%1:%2:%3", _did, floor ((_primaryPos#0) / _g), floor ((_primaryPos#1) / _g)];
    };
};

private _oldKey = _row getOrDefault ["anchorKey", ""]; 
if !(_oldKey isEqualType "") then { _oldKey = ""; };

private _hasPos = ((count _bld + count _road) > 0);
private _need = _needTTL || {!(_anchorKey isEqualTo _oldKey)} || {!_hasPos};

if (!_need) exitWith { _row };

if (_dbg) then {
    diag_log format ["[CIVSUB][CIVS][SPAWNCACHE] rebuild did=%1 oldKey=%2 newKey=%3 primary=%4 hasPos=%5 ttlNeed=%6", _did, _oldKey, _anchorKey, _primaryPos, _hasPos, _needTTL];
};

// Build anchors.
// If players are present, keep anchors bounded to the operating area.
// If no players are present, fall back to centroid-based anchors.
private _anchors = [];

if ((count _pAnch) > 0) then {
    _anchors pushBackUnique _primaryPos;
    if (_playerCent isEqualType [] && {(count _playerCent) >= 2}) then {
        private _pc = if ((count _playerCent) == 2) then { [_playerCent#0,_playerCent#1,0] } else { _playerCent };
        if ((_pc distance2D _primaryPos) > 100) then {
            _anchors pushBackUnique _pc;
        };
    };
} else {
    private _locs = nearestLocations [_center, _anchorTypes, _radius];
    {
        private _p = locationPosition _x;
        if (_p isEqualType [] && {(count _p) >= 2}) then { _anchors pushBackUnique (if ((count _p) == 2) then {[_p#0,_p#1,0]} else {_p}); };
    } forEach _locs;
    _anchors pushBackUnique (if ((count _center) == 2) then {[_center#0,_center#1,0]} else {_center});
};

// Always have at least one anchor
if ((count _anchors) == 0) then { _anchors pushBackUnique (if ((count _center) == 2) then {[_center#0,_center#1,0]} else {_center}); };

// Limit anchors to avoid heavy scans
private _maxAnchors = missionNamespace getVariable ["civsub_v1_spawn_cache_maxAnchors", 6];
if !(_maxAnchors isEqualType 0) then { _maxAnchors = 6; };
if ((count _anchors) > _maxAnchors) then { _anchors resize _maxAnchors; };

private _scanR = missionNamespace getVariable ["civsub_v1_spawn_cache_anchorRadius_m", 350];
if !(_scanR isEqualType 0) then { _scanR = 350; };
if (_scanR > (_radius * 0.7)) then { _scanR = _radius * 0.7; };
if (_scanR < 150) then { _scanR = 150; };

private _bldPos = [];
private _roadPos = [];

{
    private _a = _x;

    // Buildings (prefer enterable buildings with interior positions)
    private _objs = nearestObjects [_a, ["House","House_F","Building","Building_F"], _scanR];
    {
        private _bp = [_x] call BIS_fnc_buildingPositions;
        if (_bp isEqualType [] && {count _bp > 0}) then {
            {
                if (_x isEqualType [] && {(count _x) >= 2}) then {
                    if (!([_x] call _inExclusion)) then { _bldPos pushBackUnique _x; };
                };
            } forEach _bp;
        };
    } forEach _objs;

    // Supplement: indexed building catalog covers non-House/Building typed structures
    // (e.g. Land_GuardBox, Land_GuardHouse, Land_Hospital at the Presidential Palace).
    // Reuses the ARC_enterableBuildings cache loaded by fn_worldPickEnterablePosNear.
    private _catalog = missionNamespace getVariable ["ARC_enterableBuildings", []];
    if (!(_catalog isEqualType []) || { _catalog isEqualTo [] }) then
    {
        _catalog = call compile preprocessFileLineNumbers "data\farabad_enterable_buildings_unique.sqf";
        if (!(_catalog isEqualType [])) then { _catalog = []; };
        missionNamespace setVariable ["ARC_enterableBuildings", _catalog];
    };

    private _ax = _a # 0;
    private _ay = _a # 1;
    private _scanR2 = _scanR * _scanR;
    {
        if (!(_x isEqualType []) || { (count _x) < 2 }) then { continue; };
        private _pos = _x select 1;
        if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { continue; };
        private _dx = (_pos # 0) - _ax;
        private _dy = (_pos # 1) - _ay;
        if ((_dx * _dx + _dy * _dy) > _scanR2) then { continue; };
        if ([_pos] call _inExclusion) then { continue; };
        private _b = nearestBuilding _pos;
        if (isNull _b) then { continue; };
        private _bp = [_b] call BIS_fnc_buildingPositions;
        if (!(_bp isEqualType []) || { count _bp == 0 }) then { continue; };
        {
            if (_x isEqualType [] && {(count _x) >= 2}) then { _bldPos pushBackUnique _x; };
        } forEach _bp;
    } forEach _catalog;

    // Roads
    private _roads = _a nearRoads _scanR;
    {
        private _rp = [_x] call _roadsideFromRoad;
        if (_rp isEqualType [] && {(count _rp) >= 2} && {!(_rp isEqualTo [0,0,0])}) then {
            _roadPos pushBackUnique _rp;
        };
    } forEach _roads;

} forEach _anchors;

// Cap to keep the cache bounded
private _maxB = missionNamespace getVariable ["civsub_v1_spawn_cache_maxBuildingPos", 400];
private _maxR = missionNamespace getVariable ["civsub_v1_spawn_cache_maxRoadPos", 250];
if !(_maxB isEqualType 0) then { _maxB = 400; };
if !(_maxR isEqualType 0) then { _maxR = 250; };

if ((count _bldPos) > _maxB) then { _bldPos resize _maxB; };
if ((count _roadPos) > _maxR) then { _roadPos resize _maxR; };

_row = [[
    ["bldPos", _bldPos],
    ["roadPos", _roadPos],
    ["ts", serverTime],
    ["anchorKey", _anchorKey],
    ["anchorPos", _primaryPos]
]] call _hmCreate;

_cache set [_did, _row];
missionNamespace setVariable ["civsub_v1_spawn_cache", _cache, true];

_row

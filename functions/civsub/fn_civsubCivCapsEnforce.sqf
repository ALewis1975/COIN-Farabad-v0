/*
    ARC_fnc_civsubCivCapsEnforce

    Enforces global and per-district caps by queuing oldest civs for despawn.

    Params:
      0: activeDistrictIds (array)
      1: capGlobalEff (number)
      2: capPerDistrictEff (number)
*/

if (!isServer) exitWith {false};

params [
    ["_active", [], [[]]],
    ["_capGE", 0, [0]],
    ["_capDE", 0, [0]]
];

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; [(_h), _k, _d] call _hg";
private _mapGet   = compile "params ['_h','_k']; _h get _k";
private _keysFn   = compile "params ['_m']; keys _m";

private _ovMap = missionNamespace getVariable ["civsub_v1_civ_cap_overrides_map", createHashMap];
if !(_ovMap isEqualType createHashMap) then { _ovMap = createHashMap; };

private _capByD = missionNamespace getVariable ["civsub_v1_civ_cap_effectiveByDistrict", createHashMap];
if !(_capByD isEqualType createHashMap) then { _capByD = createHashMap; };

private _reg = missionNamespace getVariable ["civsub_v1_civ_registry", createHashMap];
if !(_reg isEqualType createHashMap) then { _reg = createHashMap; };

private _q = missionNamespace getVariable ["civsub_v1_civ_despawnQueue", []];
if !(_q isEqualType []) then { _q = []; };

private _keys = [_reg] call _keysFn;

// Only evict non-protected civilians (detained/captive/pinned civilians must persist)
private _keysEvictable = _keys select {
    private _row = [_reg, _x] call _mapGet;
    if !(_row isEqualType createHashMap) exitWith {false};
    private _u = [_row, "unit", objNull] call _hg;
    if (isNull _u) exitWith {false};
    !([_u] call ARC_fnc_civsubCivIsProtected)
};


// Optional: recycle far-away civilians (within large active districts) so new areas can populate.
// Enable by setting civsub_v1_civ_recycleDistance_m > 0 (recommended start: 1100).
private _recycleDist = missionNamespace getVariable ["civsub_v1_civ_recycleDistance_m", 0];
if (!(_recycleDist isEqualType 0)) then { _recycleDist = 0; };
if (_recycleDist > 0 && { count _keysEvictable > 0 }) then
{
    private _players = allPlayers;
    if ((count _players) > 0) then
    {
        private _cands = [];
        {
            private _k = _x;
            private _row = [_reg, _k] call _mapGet;
            if !(_row isEqualType createHashMap) then { continue; };
            private _u = [_row, "unit", objNull] call _hg;
            if (isNull _u || { !alive _u }) then { continue; };

            private _uPos = getPosATL _u;

            private _minD = 1e12;
            {
                private _pPos = getPosATL _x;
                private _d2 = _pPos distance2D _uPos;
                if (_d2 < _minD) then { _minD = _d2; };
            } forEach _players;

            if (_minD > _recycleDist) then { _cands pushBack [_minD, _k]; };
        } forEach _keysEvictable;

        if ((count _cands) > 0) then
        {
            // Evict farthest first, but limit per tick to prevent mass churn
            _cands sort false; // descending by distance
            private _max = (count _cands) min 12;
            for "_i" from 0 to (_max - 1) do
            {
                private _k = (_cands select _i) select 1;
                _q pushBackUnique _k;
            };
        };
    };
};

// Global cap
if ((count _keys) > _capGE && {count _keysEvictable > 0}) then
{
    // sort by spawnTs ascending
    private _sorted = _keysEvictable apply {
        private _row = [_reg, _x] call _mapGet;
        private _ts = 0;
        if (_row isEqualType createHashMap) then { _ts = [_row, "spawnTs", 0] call _hg; };
        [_ts, _x]
    };
    _sorted sort true;

    private _over = (count _keys) - _capGE;
    if (_over > (count _sorted)) then { _over = count _sorted; };
    for "_i" from 0 to (_over - 1) do {
        private _k = (_sorted select _i) select 1;
        _q pushBackUnique _k;
    };
};

// Per-district cap
private _byD = createHashMap;
{
    private _row = [_reg, _x] call _mapGet;
    if (_row isEqualType createHashMap) then {
        private _did = [_row, "districtId", ""] call _hg; 
        if !(_did isEqualTo "") then {
            private _arr = [_byD, _did, [] call _hg];
            _arr pushBack _x;
            _byD set [_did, _arr];
        };
    };
} forEach _keysEvictable;

{
    private _did = _x;
    private _arr = [_byD, _did] call _mapGet;
    private _capDThis = [_ovMap, _did, ([_capByD, _did, _capDE] call _hg call _hg)];
    if !(_capDThis isEqualType 0) then { _capDThis = _capDE; };
    if (_capDThis < 0) then { _capDThis = 0; };

    if ((count _arr) > _capDThis) then {
        // sort by spawnTs
        private _sorted = _arr apply {
            private _row = [_reg, _x] call _mapGet;
            private _ts = 0;
            if (_row isEqualType createHashMap) then { _ts = [_row, "spawnTs", 0] call _hg; };
            [_ts, _x]
        };
        _sorted sort true;
        private _over = (count _arr) - _capDThis;
        if (_over > (count _sorted)) then { _over = count _sorted; };
        for "_i" from 0 to (_over - 1) do {
            private _k = (_sorted select _i) select 1;
            _q pushBackUnique _k;
        };
    };
} forEach ([_byD] call _keysFn);

missionNamespace setVariable ["civsub_v1_civ_despawnQueue", _q, true];

true
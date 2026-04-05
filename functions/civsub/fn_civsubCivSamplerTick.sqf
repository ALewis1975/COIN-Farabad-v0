/*
    ARC_fnc_civsubCivSamplerTick

    Recomputes active districts based on player positions, then spawns civilians
    to meet caps, and enforces caps.

    Hotfix10:
      - Builds per-district player anchor positions for AREA-based spawn caches.
        Player presence activates a district, but spawn placement comes from
        buildings/roads around settlement anchors (including where players are).
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_civs_enabled", false]) exitWith {false};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _dbg = missionNamespace getVariable ["civsub_v1_debug", false];

private _players = [] call ARC_fnc_civsubBubbleGetPlayers;
private _active = [_players] call ARC_fnc_civsubBubbleGetActiveDistricts;

private _todPolicy = [] call ARC_fnc_dynamicTodRefresh;
private _canSpawnCivil = [_todPolicy, "canSpawnCivil", true] call _hg;
if (!(_canSpawnCivil isEqualType true) && !(_canSpawnCivil isEqualType false)) then { _canSpawnCivil = true; };
private _phase = [_todPolicy, "phase", "DAY"] call _hg;
if (!(_phase isEqualType "")) then { _phase = "DAY"; };
private _tod = [_todPolicy, "tod", dayTime] call _hg;
if (!(_tod isEqualType 0)) then { _tod = dayTime; };

missionNamespace setVariable ["civsub_v1_activeDistrictIds", _active, true];

// Build per-district player anchor positions (server-only; used by spawn cache)
// NOTE: ARC_fnc_civsubDistrictsFindByPos returns a districtId string.
private _pAnch = createHashMap;
{
    if (!isNull _x) then {
        private _pos = getPosATL _x;
        private _did = [_pos] call ARC_fnc_civsubDistrictsFindByPos;
        if !(_did isEqualTo "") then {
            private _arr = [_pAnch, _did, []] call _hg;
            if !(_arr isEqualType []) then { _arr = []; };
            _arr pushBack _pos;
            _pAnch set [_did, _arr];
        };
    };
} forEach _players;

missionNamespace setVariable ["civsub_v1_spawn_player_anchors", _pAnch, false];

// Compute effective caps for this tick
private _caps = [_active] call ARC_fnc_civsubCivCapsCompute; // [capGlobalEff, capPerDistEff]
private _capGE = if ((count _caps) > 0) then { _caps select 0 } else { 0 };
private _capDE = if ((count _caps) > 1) then { _caps select 1 } else { 0 };

private _capByD = missionNamespace getVariable ["civsub_v1_civ_cap_effectiveByDistrict", createHashMap];
if !(_capByD isEqualType createHashMap) then { _capByD = createHashMap; };

private _mCiv = missionNamespace getVariable ["civsub_v1_activity_mul_civ_day", 1.0];
if (_phase isEqualTo "NIGHT") then { _mCiv = missionNamespace getVariable ["civsub_v1_activity_mul_civ_night", 0.55]; };
if (_phase isEqualTo "PEAK") then { _mCiv = missionNamespace getVariable ["civsub_v1_activity_mul_civ_peak", 1.10]; };
if !(_mCiv isEqualType 0) then { _mCiv = 1.0; };
_mCiv = (_mCiv max 0.1) min 2.0;

_capGE = floor (_capGE * _mCiv);
if (_capGE < 0) then { _capGE = 0; };

{
    private _did0 = _x;
    private _cap0 = [_capByD, _did0, _capDE] call _hg;
    if !(_cap0 isEqualType 0) then { _cap0 = _capDE; };
    _cap0 = floor (_cap0 * _mCiv);
    if (_cap0 < 0) then { _cap0 = 0; };
    _capByD set [_did0, _cap0];
} forEach (keys _capByD);

missionNamespace setVariable ["civsub_v1_activity_mul_civ_active", _mCiv, false];
missionNamespace setVariable ["civsub_v1_activity_phase", _phase, false];
missionNamespace setVariable ["civsub_v1_activity_tod", _tod, false];

// Publish sampler decision state for probes
missionNamespace setVariable ["civsub_v1_civ_sampler_last_active", _active, true];
missionNamespace setVariable ["civsub_v1_civ_sampler_last_capGE", _capGE, true];
missionNamespace setVariable ["civsub_v1_civ_sampler_last_capDE", _capDE, true];
missionNamespace setVariable ["civsub_v1_civ_sampler_last_capByDistrict", _capByD, true];

// Spawn up to caps
private _reg = missionNamespace getVariable ["civsub_v1_civ_registry", createHashMap];
if !(_reg isEqualType createHashMap) then {
    _reg = createHashMap;
    missionNamespace setVariable ["civsub_v1_civ_registry", _reg, true];
};

// Count current per district
private _counts = createHashMap;
{
    private _row = _reg get _x;
    if (_row isEqualType createHashMap) then {
        private _did = [_row, "districtId", ""] call _hg;
        if !(_did isEqualTo "") then {
            _counts set [_did, ([_counts, _did, 0] call _hg) + 1];
        };
    };
} forEach (keys _reg);

private _total = count (keys _reg);
missionNamespace setVariable ["civsub_v1_civ_sampler_last_total", _total, true];

if (_dbg) then {
    diag_log format ["[CIVSUB][CIVS][TICK] active=%1 capGE=%2 capDE=%3 total=%4", _active, _capGE, _capDE, _total];
};

// Fill districts in a stable order
{
    if (_total >= _capGE) exitWith {};

    private _did = _x;
    private _cur = [_counts, _did, 0] call _hg;

    private _budget = missionNamespace getVariable ["civsub_v1_civ_spawn_perDistrictPerTick", 1];
    if !(_budget isEqualType 0) then { _budget = 1; };
    if (_budget < 0) then { _budget = 0; };

    private _spawned = 0;

    private _capThis = [_capByD, _did, _capDE] call _hg;
    if !(_capThis isEqualType 0) then { _capThis = _capDE; };
    if (_capThis < 0) then { _capThis = 0; };

    while { _total < _capGE && { _cur < _capThis } && { _spawned < _budget } } do {
        if (!_canSpawnCivil) exitWith {};
        // Count attempt (even if spawn returns objNull)
        missionNamespace setVariable ["civsub_v1_civ_spawn_attempt_count", (missionNamespace getVariable ["civsub_v1_civ_spawn_attempt_count", 0]) + 1, true];
        missionNamespace setVariable ["civsub_v1_civ_sampler_last_attempt_did", _did, true];

        private _u = [_did] call ARC_fnc_civsubCivSpawnInDistrict;

        if (isNull _u) exitWith {
            if ((missionNamespace getVariable ["civsub_v1_civ_lastSpawnFail", ""]) isEqualTo "") then {
                missionNamespace setVariable ["civsub_v1_civ_lastSpawnFail", "spawn_returned_null", true];
            };
            _cur = _capThis;
        };

        _spawned = _spawned + 1;
        _cur = _cur + 1;
        _total = _total + 1;
        _counts set [_did, _cur];
    };

} forEach _active;

// Enforce caps (in case of drift)
[_active, _capGE, _capDE] call ARC_fnc_civsubCivCapsEnforce;

missionNamespace setVariable ["civsub_v1_civ_lastSampler_ts", serverTime, true];

true

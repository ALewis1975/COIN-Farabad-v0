/*
    ARC_fnc_civsubLocNpcSpawn

    Spawns one civilian NPC at a location site.

    Params:
      0: siteKey    (string)  - unique site identifier
      1: sitePos    (array)   - [x,y,z] centroid of the site
      2: npcClasses (array)   - eligible class strings to pick from

    Returns: spawned unit (object) or objNull on failure
*/

if (!isServer) exitWith { objNull };

params [
    ["_siteKey",    "", [""]],
    ["_sitePos",    [0,0,0], [[]]],
    ["_npcClasses", [],      [[]]]
];

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _todPolicy = [] call ARC_fnc_dynamicTodGetPolicy;
private _todPhase = [_todPolicy, "phase", "DAY"] call _hg;
if (!(_todPhase isEqualType "")) then { _todPhase = "DAY"; };

if (_siteKey isEqualTo "")     exitWith { objNull };
if ((count _sitePos) < 2)      exitWith { objNull };
if ((count _npcClasses) == 0)  exitWith { objNull };

// Find a spawn position: scatter up to 15 m from centroid, off-road if possible
private _scatterMin = 2;
private _scatterMax = 15;
private _spawnPos = [0,0,0];
private _found = false;

for "_i" from 1 to 10 do {
    private _r = _scatterMin + random (_scatterMax - _scatterMin);
    private _a = random 360;
    private _p = [_sitePos select 0, _sitePos select 1, 0] getPos [_r, _a];
    _p set [2, 0];

    if (surfaceIsWater _p) then { continue; };
    private _nrm = surfaceNormal _p;
    private _slope = acos (((_nrm vectorDotProduct [0,0,1]) max -1) min 1);
    if (_slope > 25) then { continue; };

    _spawnPos = _p;
    _found = true;
    break;
};

if (!_found) exitWith {
    diag_log format ["[CIVLOC][SPAWN] no valid pos siteKey=%1", _siteKey];
    objNull
};

// Reject if a player is very close (< 20 m)
{
    if ((getPosATL _x) distance2D _spawnPos < 20) exitWith {
        _found = false;
    };
} forEach allPlayers;
if (!_found) exitWith { objNull };

private _cls = selectRandom _npcClasses;
private _grp = createGroup [civilian, true];
private _unit = _grp createUnit [_cls, _spawnPos, [], 0, "NONE"];
if (isNull _unit) exitWith {
    diag_log format ["[CIVLOC][SPAWN] createUnit failed cls=%1 siteKey=%2", _cls, _siteKey];
    deleteGroup _grp;
    objNull
};

// Behaviour
_unit setBehaviour "CARELESS";
_unit setCombatMode "BLUE";
_unit disableAI "AUTOCOMBAT";
_unit disableAI "TARGET";
_unit disableAI "SUPPRESSION";
_unit setSpeedMode "NORMAL";

// Tag
_unit setVariable ["ARC_civloc_siteKey", _siteKey, true];
_unit setVariable ["ARC_civloc_role",    "SITE_NPC", true];
_unit setVariable ["civsub_v1_isCiv",    true,       true];
_unit setVariable ["ARC_dynamic_tod_phase_spawn", _todPhase, true];
_unit setVariable ["ARC_dynamic_tod_profile_spawn", [_todPolicy, "profile", "STANDARD"] call _hg, true];

// Idle wander: move to a random position near the site every 30–60 s
[_unit, _sitePos] spawn {
    params ["_u", "_anchor"];
    while { !isNull _u && { alive _u } } do {
        uiSleep (30 + random 30);
        if (isNull _u || { !alive _u }) exitWith {};
        private _r  = 2 + random 12;
        private _a  = random 360;
        private _wp = _anchor getPos [_r, _a];
        _wp set [2, 0];
        if (!surfaceIsWater _wp) then { _u doMove _wp; };
    };
};

// Cleanup: remove when players stay away for cleanupMinDelay
private _cleanR = missionNamespace getVariable ["civsub_v1_locnpc_cleanupRadius_m", 600];
if (!(_cleanR isEqualType 0)) then { _cleanR = 600; };
private _delay = missionNamespace getVariable ["civsub_v1_locnpc_cleanupMinDelay_s", 120];
if (!(_delay isEqualType 0)) then { _delay = 120; };

[[_unit], _spawnPos, _cleanR, _delay, format ["CIVLOC:%1", _siteKey]] call ARC_fnc_cleanupRegister;

_unit

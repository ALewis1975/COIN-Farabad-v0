/*
    ARC_fnc_iedComplexAttackStage

    IED subsystem: stage a secondary ambush group linked to an IED complex attack.
    Called when threatRecord.execution.hasSecondaryAttack = true and complexity >= 3.

    Params:
      0: ARRAY threatRecord (pairs array)

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_rec", [], [[]]]
];

if ((count _rec) == 0) exitWith {false};

private _kvGet = {
    params ["_pairs", "_key", "_default"];
    if (!(_pairs isEqualType [])) exitWith {_default};
    private _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 2 } && { ((_x select 0) isEqualTo _key) }) exitWith { _idx = _forEachIndex; }; } forEach _pairs;
    if (_idx < 0) exitWith {_default};
    private _v = (_pairs select _idx) select 1;
    if (isNil "_v") exitWith {_default};
    _v
};

private _threatId  = [_rec, "threat_id", ""] call _kvGet;
private _execution = [_rec, "execution", []] call _kvGet;
private _area      = [_rec, "area", []] call _kvGet;

// Guard: secondary attack must be flagged
private _hasSecondary = [_execution, "hasSecondaryAttack", false] call _kvGet;
if (!(_hasSecondary isEqualType true) && !(_hasSecondary isEqualType false)) then { _hasSecondary = false; };
if (!_hasSecondary) exitWith
{
    diag_log format ["[ARC][INFO] ARC_fnc_iedComplexAttackStage: no secondary attack flag threat=%1", _threatId];
    false
};

// Guard: complexity gate
private _complexity = [_execution, "complexity", 0] call _kvGet;
if (!(_complexity isEqualType 0)) then { _complexity = 0; };
if (_complexity < 3) exitWith
{
    diag_log format ["[ARC][INFO] ARC_fnc_iedComplexAttackStage: complexity=%1 < 3, skipping threat=%2", _complexity, _threatId];
    false
};

private _pos = [_area, "pos", [0,0,0]] call _kvGet;
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = [0,0,0]; };
_pos = +_pos; _pos resize 3;

// Pick staging position 150-400m from IED via nearby roads
private _stagePos = _pos;
private _roads = _pos nearRoads 400;
private _candidates = _roads select { (_x distance2D _pos) > 150 };
if ((count _candidates) > 0) then
{
    _stagePos = getPos (_candidates select (floor (random (count _candidates))));
}
else
{
    private _dir = random 360;
    private _dist = 150 + (random 250);
    _stagePos = [_pos select 0 + _dist * sin _dir, _pos select 1 + _dist * cos _dir, 0];
};
_stagePos resize 3;

// Spawn secondary ambush group (OPFOR/east)
private _grp = createGroup [east, true];
_grp setGroupIdGlobal [format ["COBRA Ambush %1", _threatId]];
private _unitCount = 3 + (floor (random 2)); // 3 or 4

private _unitClasses = [
    "O_Soldier_F",
    "O_Soldier_AR_F",
    "O_Soldier_GL_F"
];

for "_unitIdx" from 0 to (_unitCount - 1) do
{
    private _uClass = _unitClasses select (_unitIdx mod (count _unitClasses));
    private _u = _grp createUnit [_uClass, _stagePos, [], 5, "NONE"];
    if (alive _u) then
    {
        _u setPos _stagePos;
        _u setBehaviour "CARELESS";
        _u setCombatMode "BLUE";
    };
};

// Hold waypoint at staging pos
private _wp = _grp addWaypoint [_stagePos, 0];
_wp setWaypointType "HOLD";
_wp setWaypointBehaviour "CARELESS";
_wp setWaypointCombatMode "BLUE";

// Register cleanup label
private _label = format ["COMPLEX_ATK:%1", _threatId];
missionNamespace setVariable [format ["ARC_complexAtkGroup_%1", _threatId], _grp];

// Store group netId in state for detonation activation hook
private _grpNetId = "";
if ((count (units _grp)) > 0) then
{
    _grpNetId = groupID _grp;
};
missionNamespace setVariable [format ["ARC_complexAtkLabel_%1", _threatId], _label];

diag_log format ["[ARC][INFO] ARC_fnc_iedComplexAttackStage: staged groupID=%1 pos=%2 units=%3 threat=%4", _grpNetId, mapGridPosition _stagePos, _unitCount, _threatId];

true

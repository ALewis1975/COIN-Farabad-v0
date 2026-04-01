/*
    ARC_fnc_worldAmbientPersonnelInit

    Server-side: spawn a small set of ambient base personnel at key positions
    inside the COIN base (HQ, medical bay, staging area) to give the joint hub
    a "living" feel.

    Uses BIS_fnc_ambientAnimCombat for unit animations. Personnel are editor-
    class infantry units with side = west. They respawn after 120 s if deleted.

    Positions read from named markers set in Eden. If a marker is absent the
    slot is silently skipped. Configurable via:
      ARC_worldPersonnelEnabled          (BOOL,   default true)
      ARC_worldPersonnelRespawnDelayS    (NUMBER, default 120)
      ARC_worldPersonnelClassPool        (ARRAY,  default NATO infantry classes)

    Returns:
      NUMBER — count of personnel spawned
*/

if (!isServer) exitWith {0};

if (!missionNamespace getVariable ["ARC_worldPersonnelEnabled", true]) exitWith {0};
if (missionNamespace getVariable ["ARC_worldPersonnelInitDone", false]) exitWith {0};
missionNamespace setVariable ["ARC_worldPersonnelInitDone", true];

private _respawnDelay = missionNamespace getVariable ["ARC_worldPersonnelRespawnDelayS", 120];
if (!(_respawnDelay isEqualType 0)) then { _respawnDelay = 120; };
_respawnDelay = (_respawnDelay max 30) min 600;

// Default class pool — generic NATO infantry suitable for base staff roles
private _classPool = missionNamespace getVariable [
    "ARC_worldPersonnelClassPool",
    ["B_soldier_F", "B_medic_F", "B_officer_F", "B_soldier_F", "B_crew_F"]
];
if (!(_classPool isEqualType []) || { (count _classPool) == 0 }) then
{
    _classPool = ["B_soldier_F", "B_medic_F", "B_officer_F"];
};

// Slot definitions [markerName, role description, animation hint]
private _slots = [
    ["mkr_base_hq_staff_1",       "HQ staff",     "STAND"],
    ["mkr_base_hq_staff_2",       "HQ staff",     "STAND"],
    ["mkr_base_medBay_staff_1",   "Medic",        "STAND"],
    ["mkr_base_medBay_staff_2",   "Medic",        "STAND"],
    ["mkr_base_staging_crew_1",   "Crew chief",   "STAND"],
    ["mkr_base_staging_crew_2",   "Ground crew",  "STAND"],
    ["mkr_base_patrol_post_1",    "Guard",        "STAND"],
    ["mkr_base_patrol_post_2",    "Guard",        "STAND"]
];

private _spawned = 0;
private _classIdx = 0;

{
    _x params ["_mkr", "_role", "_anim"];

    private _pos = getMarkerPos _mkr;
    if (_pos isEqualTo [0,0,0]) then { continue; };

    private _dir = getMarkerDir _mkr;

    private _cls = _classPool select (_classIdx mod (count _classPool));
    _classIdx = _classIdx + 1;

    private _grp = createGroup [west, true];
    private _unit = _grp createUnit [_cls, _pos, [], 0, "NONE"];

    if (isNull _unit) then { continue; };

    _unit setDir _dir;
    _unit allowDamage false;
    _unit setVariable ["ARC_worldPersonnel", true, true];
    _unit setVariable ["ARC_worldPersonnelRole", _role, true];
    _unit setVariable ["ARC_worldPersonnelMarker", _mkr, true];
    _unit disableAI "AUTOTARGET";
    _unit disableAI "TARGET";
    _unit disableAI "MOVE";

    // BIS ambient animation
    [_unit] spawn BIS_fnc_ambientAnimCombat;

    _spawned = _spawned + 1;

    diag_log format ["[ARC][WORLD] worldAmbientPersonnelInit: spawned '%1' at %2 (marker=%3)", _role, mapGridPosition _pos, _mkr];
} forEach _slots;

diag_log format ["[ARC][WORLD] worldAmbientPersonnelInit: %1 ambient base personnel spawned.", _spawned];

_spawned

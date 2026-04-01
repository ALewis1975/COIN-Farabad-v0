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

    // Behavioural depth (Roadmap #13) ─────────────────────────────────────────
    // Guard posts: simple two-point patrol (10-15 m radius) that loops forever.
    if (_role isEqualTo "Guard") then
    {
        private _guardUnit = _unit;
        private _originPos = _pos;
        [_guardUnit, _originPos] spawn
        {
            params ["_u", "_origin"];
            while { alive _u } do
            {
                // Pick a secondary position 10-15 m away in a random direction
                private _angle = random 360;
                private _dist  = 10 + (random 5);  // 10-15 m
                private _secondary = [_origin # 0 + (_dist * sin _angle),
                                      _origin # 1 + (_dist * cos _angle),
                                      _origin # 2];
                _u enableAI "MOVE";
                _u doMove _secondary;
                waitUntil { sleep 2; !alive _u || { (_u distance _secondary) < 2 } };
                _u disableAI "MOVE";
                sleep (15 + (random 10));  // pause 15-25 s at secondary

                if (!alive _u) exitWith {};

                _u enableAI "MOVE";
                _u doMove _origin;
                waitUntil { sleep 2; !alive _u || { (_u distance _origin) < 2 } };
                _u disableAI "MOVE";
                sleep (15 + (random 10));
            };
        };
    };

    // Medical bay: periodically re-trigger ambient animation to vary the idle pose.
    if (_role isEqualTo "Medic") then
    {
        private _medicUnit = _unit;
        [_medicUnit] spawn
        {
            params ["_u"];
            while { alive _u } do
            {
                sleep (60 + (random 60));  // 60-120 s interval
                if (alive _u) then { [_u] spawn BIS_fnc_ambientAnimCombat; };
            };
        };
    };

    _spawned = _spawned + 1;

    diag_log format ["[ARC][WORLD] worldAmbientPersonnelInit: spawned '%1' at %2 (marker=%3)", _role, mapGridPosition _pos, _mkr];
} forEach _slots;

// Threat-pressure watcher — polls insurgentPressure every 30 s and calls
// ARC_fnc_worldThreatStateReact when the base posture needs to change.
// Hysteresis band: elevate to HIGH above 0.60, return to NORMAL below 0.40.
[] spawn
{
    while { true } do
    {
        sleep 30;
        private _pressure = ["insurgentPressure", 0.35] call ARC_fnc_stateGet;
        if (!(_pressure isEqualType 0)) then { _pressure = 0.35; };

        private _curPosture = missionNamespace getVariable ["ARC_worldBasePosture", "NORMAL"];
        if (!(_curPosture isEqualType "")) then { _curPosture = "NORMAL"; };

        if (_pressure > 0.60) then
        {
            if (!(_curPosture isEqualTo "HIGH") && { !(_curPosture isEqualTo "CRITICAL") }) then
            {
                diag_log "[ARC][WORLD] worldAmbientPersonnelInit: HIGH THREAT — calling worldThreatStateReact.";
                ["HIGH"] call ARC_fnc_worldThreatStateReact;
            };
        }
        else
        {
            if (_pressure < 0.40) then
            {
                if (!(_curPosture isEqualTo "NORMAL")) then
                {
                    diag_log "[ARC][WORLD] worldAmbientPersonnelInit: pressure normalised — calling worldThreatStateReact.";
                    ["NORMAL"] call ARC_fnc_worldThreatStateReact;
                };
            };
        };
    };
};

diag_log format ["[ARC][WORLD] worldAmbientPersonnelInit: %1 ambient base personnel spawned.", _spawned];

_spawned

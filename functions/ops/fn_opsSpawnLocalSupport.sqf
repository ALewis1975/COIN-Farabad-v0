/*
    ARC_fnc_opsSpawnLocalSupport

    Server: Spawn host-nation / local friendly forces and civilian scene actors at an objective.

    Intended for tasks involving civilian infrastructure controlled by friendly/local forces.
    Spawns a small garrison element (in nearby buildings), a small patrol element, and
    task-relevant CIVSUB civilians for civil distribution and checkpoint access-control scenes.

    Params:
        0: STRING - taskId
        1: STRING - incidentType (e.g. "CIVIL")
        2: STRING - incidentMarker (Eden marker id, if available)
        3: STRING - incidentDisplayName
        4: ARRAY  - center pos ATL [x,y,z]
        5: NUMBER - suggested radius (meters) (default 120)

    Returns:
        ARRAY - netId strings for spawned units
*/

if (!isServer) exitWith {[]};

params [
    ["_taskId", "", [""]],
    ["_typeU", "", [""]],
    ["_marker", "", [""]],
    ["_disp", "", [""]],
    ["_posATL", [], [[]]],
    ["_radius", 120, [0]]
];

if (_taskId isEqualTo "") exitWith {[]};
if (!(_posATL isEqualType []) || { (count _posATL) < 2 }) exitWith {[]};

private _todPolicy = [] call ARC_fnc_dynamicTodGetPolicy;
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _canSpawnOps = [_todPolicy, "canSpawnOps", true] call _hg;
if (!(_canSpawnOps isEqualType true) && !(_canSpawnOps isEqualType false)) then { _canSpawnOps = true; };
if (!_canSpawnOps) exitWith {[]};
private _todPhase = [_todPolicy, "phase", "DAY"] call _hg;
if (!(_todPhase isEqualType "")) then { _todPhase = "DAY"; };

private _enabled = missionNamespace getVariable ["ARC_localSupportEnabled", true];
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {[]};

private _persistInAO = missionNamespace getVariable ["ARC_localSupportPersistInAO", false];
if (!(_persistInAO isEqualType true) && !(_persistInAO isEqualType false)) then { _persistInAO = false; };

private _dynSim = missionNamespace getVariable ["ARC_localSupportDynamicSimEnabled", true];
if (!(_dynSim isEqualType true) && !(_dynSim isEqualType false)) then { _dynSim = true; };

// Optional LAMBS behaviors for friendly support units.
// Safe to run without the mod; we guard isNil before spawning tasks.
private _useLambs = missionNamespace getVariable ["ARC_supportUseLAMBS", true];
if (!(_useLambs isEqualType true) && !(_useLambs isEqualType false)) then { _useLambs = true; };

private _type = toUpper _typeU;
private _pos = +_posATL; _pos resize 3;

private _eligible = missionNamespace getVariable ["ARC_localSupportEligibleTypes", ["CIVIL","CHECKPOINT","DEFEND"]];
if (!(_eligible isEqualType [])) then { _eligible = ["CIVIL","CHECKPOINT","DEFEND"]; };
_eligible = _eligible apply { toUpper _x };
// IED cordons are authoritative for Farabad COIN. Even if a mission overrides the allow-list,
// IED must remain eligible.
// TNP partnered-ops leads (Lane C / C3) are tagged TNP_PARTNERED and carried onto the active
// incident as activeLeadTag. Such incidents must always stand up a host-nation partnered
// element (police/army garrison + patrol) regardless of the incident type, so the PATROL
// variant gets a partnered presence too, not just the already-eligible CHECKPOINT variant.
private _activeLeadTag = ["activeLeadTag", ""] call ARC_fnc_stateGet;
if (!(_activeLeadTag isEqualType "")) then { _activeLeadTag = ""; };
private _isTnpPartnered = (toUpper _activeLeadTag) isEqualTo "TNP_PARTNERED";
if !((_type in _eligible) || { _type isEqualTo "IED" } || _isTnpPartnered) exitWith {[]};

// Keep the Airbase/JBF clean by default, but allow explicit civic checkpoint scenes.
private _zone = [_pos] call ARC_fnc_worldGetZoneForPos;
private _zoneU = toUpper _zone;
private _airbaseAllowTypes = missionNamespace getVariable ["ARC_localSupportAirbaseAllowTypes", ["CHECKPOINT"]];
if (!(_airbaseAllowTypes isEqualType [])) then { _airbaseAllowTypes = ["CHECKPOINT"]; };
_airbaseAllowTypes = _airbaseAllowTypes apply { toUpper _x };
if (_zoneU isEqualTo "AIRBASE" && { !(_type in _airbaseAllowTypes) }) exitWith {[]};

private _excludeMarkers = missionNamespace getVariable ["ARC_localSupportExcludeMarkers", ["mkr_airbaseCenter","ARC_m_base_toc","ARC_convoy_start"]];
if (!(_excludeMarkers isEqualType [])) then { _excludeMarkers = ["mkr_airbaseCenter","ARC_m_base_toc","ARC_convoy_start"]; };
if (_marker in _excludeMarkers) exitWith {[]};

// Spawn rules:
//   - CIVIL / CHECKPOINT tasks: assume local forces already on scene.
//   - DEFEND tasks: spawn locals only on known infrastructure markers (avoid military compounds).
private _allow = false;

if (_type in ["CIVIL", "CHECKPOINT"]) then
{
    _allow = true;
}
else
{
    private _allowMarkers = missionNamespace getVariable ["ARC_localSupportMarkers", []];
    if (!(_allowMarkers isEqualType []) || { (count _allowMarkers) isEqualTo 0 }) then
    {
        // Default allow-list (civilian/industrial infrastructure under local control)
        _allowMarkers = [
            "ARC_loc_GreenZone",
            "ARC_loc_GrandMosque",
            "ARC_loc_BelleFoilleHotel",
            "ARC_loc_hospital",
            "ARC_loc_industrial022",
            "ARC_loc_KarkanakPrison",
            "ARC_loc_SolarFarm",
            "ARC_loc_PortFarabad",
            "ARC_loc_PresidentialPalace",
            "ARC_loc_EmbassyCompound",
            "ARC_loc_AwenaResevoir",
            "ARC_loc_JaziraOilRefinery",
            "ARC_loc_OilProcessing",
            "ARC_loc_JaziraOilField"
        ];
    };

    _allow = (_marker in _allowMarkers);

    // Fallback: if the marker isn't in the allow-list, allow if the display name strongly implies
    // local-controlled infrastructure.
    if (!_allow) then
    {
        private _dn = toLower _disp;
        _allow =
            (_dn find "hospital") >= 0
            || (_dn find "mosque") >= 0
            || (_dn find "hotel") >= 0
            || (_dn find "palace") >= 0
            || (_dn find "embassy") >= 0
            || (_dn find "port") >= 0
            || (_dn find "prison") >= 0
            || (_dn find "reservoir") >= 0
            || (_dn find "refinery") >= 0
            || (_dn find "oil") >= 0
            || (_dn find "solar") >= 0
            || (_dn find "infrastructure") >= 0;
    };
};

if (!_allow) exitWith {[]};

// Presence radius (spawning + reuse)
private _presenceR = missionNamespace getVariable [format ["ARC_localSupportRadiusM_%1", _type], (_radius max 80) min 250];
if (!(_presenceR isEqualType 0)) then { _presenceR = (_radius max 80) min 250; };
_presenceR = (_presenceR max 50) min 500;

private _out = [];

// -----------------------------------------------------------------------------
// Task-scene civilians
// -----------------------------------------------------------------------------
private _sceneCivsEnabled = missionNamespace getVariable ["ARC_localSupportSceneCivsEnabled", true];
if (!(_sceneCivsEnabled isEqualType true) && !(_sceneCivsEnabled isEqualType false)) then { _sceneCivsEnabled = true; };

private _sceneCivTypes = missionNamespace getVariable ["ARC_localSupportSceneCivTypes", ["CIVIL","CHECKPOINT"]];
if (!(_sceneCivTypes isEqualType [])) then { _sceneCivTypes = ["CIVIL","CHECKPOINT"]; };
_sceneCivTypes = _sceneCivTypes apply { toUpper _x };

if (_sceneCivsEnabled && { _type in _sceneCivTypes }) then
{
    private _sceneCivN = missionNamespace getVariable [format ["ARC_localSupportSceneCivCount_%1", _type], -1];
    if (!(_sceneCivN isEqualType 0) || { _sceneCivN < 0 }) then
    {
        _sceneCivN = switch (_type) do
        {
            case "CHECKPOINT": { 6 };
            case "CIVIL":      { 8 };
            default             { 0 };
        };
    };
    _sceneCivN = (_sceneCivN max 0) min 24;

    private _sceneR = missionNamespace getVariable ["ARC_localSupportSceneCivRadiusM", (_presenceR min 90)];
    if (!(_sceneR isEqualType 0)) then { _sceneR = (_presenceR min 90); };
    _sceneR = (_sceneR max 20) min 180;

    private _existingScene = allUnits select {
        alive _x
        && { !isPlayer _x }
        && { side _x isEqualTo civilian }
        && { (_x getVariable ["ARC_isLocalSupportSceneCiv", false]) }
        && { (_x distance2D _pos) <= _presenceR }
    };

    if ((count _existingScene) >= ((_sceneCivN min 2) max 1)) then
    {
        {
            _x setVariable ["ARC_localSupportTaskId", _taskId, true];
            _out pushBackUnique (netId _x);
        } forEach _existingScene;
        _sceneCivN = 0;
    };

    if (_sceneCivN > 0) then
    {
        private _civPoolDefault = missionNamespace getVariable ["civsub_v1_civ_classPool", ["C_man_1"]];
        if (!(_civPoolDefault isEqualType [])) then { _civPoolDefault = ["C_man_1"]; };

        private _civClasses = missionNamespace getVariable ["ARC_localSupportSceneCivClassPool", _civPoolDefault];
        if (!(_civClasses isEqualType [])) then { _civClasses = _civPoolDefault; };
        _civClasses = _civClasses select {
            isClass (configFile >> "CfgVehicles" >> _x)
            && { (getNumber (configFile >> "CfgVehicles" >> _x >> "side")) isEqualTo 3 }
            && { _x isKindOf "Man" }
        };
        if ((count _civClasses) isEqualTo 0) then
        {
            _civClasses = ["C_man_1"] select { isClass (configFile >> "CfgVehicles" >> _x) };
        };

        if ((count _civClasses) > 0) then
        {
            private _grpC = createGroup [civilian, true];
            _grpC setVariable ["ARC_isLocalSupportSceneCivGroup", true, true];
            _grpC setVariable ["ARC_localSupportTaskId", _taskId, true];
            _grpC setVariable ["ARC_localSupportType", _type, true];

            for "_i" from 1 to _sceneCivN do
            {
                private _spawnPos = [_pos, 8, _sceneR, 1, 0, 0.35, 0, [], [_pos, _pos]] call BIS_fnc_findSafePos;
                if (!(_spawnPos isEqualType []) || { (count _spawnPos) < 2 }) then { _spawnPos = _pos; };
                private _cls = selectRandom _civClasses;
                private _u = _grpC createUnit [_cls, _spawnPos, [], 0, "NONE"];
                _u setVariable ["ARC_isLocalSupportSceneCiv", true, true];
                _u setVariable ["ARC_localSupportTaskId", _taskId, true];
                _u setVariable ["ARC_localSupportType", _type, true];
                removeAllWeapons _u;
                removeVest _u;
                removeBackpack _u;
                _out pushBackUnique (netId _u);
            };

            _grpC setBehaviourStrong "SAFE";
            _grpC setCombatMode "BLUE";
            private _wp = _grpC addWaypoint [_pos, 0];
            _wp setWaypointType "HOLD";
            _wp setWaypointBehaviour "SAFE";
            _wp setWaypointCombatMode "BLUE";
        };
    };
};

_out
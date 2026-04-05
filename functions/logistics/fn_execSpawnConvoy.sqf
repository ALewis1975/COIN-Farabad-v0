/*
    Spawn a friendly convoy.

    Design intent (simplified):
      - Vehicles spawn one-by-one on a single spawn pad.
      - Minimum pause between spawns (ARC_convoySpawnIntervalSec, default 5s).
      - Before each spawn, ensure the pad is clear; if blocked, wait another interval.
      - As vehicles spawn, they join a single group and begin moving toward the convoy link-up point.

    Returns: array of vehicle netIds (lead vehicle first). Empty array on failure.

    Notes:
      - This function is intended to run in a scheduled environment (it uses sleep).
      - Caller should prevent concurrent spawns (see execTickConvoy).
*/

params [
    ["_incidentType", "LOGISTICS", [""]],
    ["_spawnPos", [0,0,0], [[]]],
    ["_destPos", [0,0,0], [[]]],
    ["_speedKph", 25, [0]],
    ["_spawnDir", 0, [0]],
    // Optional: tag convoy vehicles so we can rehydrate/cleanup safely if state is lost.
    ["_taskId", "", [""]]
];

private _callerOwner = remoteExecutedOwner;
if (!isServer) exitWith
{
    private _clientOwner = clientOwner;
    private _ownerTxt = if (_clientOwner isEqualType 0) then { str _clientOwner } else { "local" };
    private _ctxTaskId = if (_taskId isEqualType "") then { _taskId } else { "" };

    diag_log format ["[ARC][CONVOY][AUTH] Rejected non-server call to execSpawnConvoy (task=%1, clientOwner=%2). Relaying request to server.", _ctxTaskId, _ownerTxt];

    // Non-authoritative callers must never mutate shared convoy state directly.
    // Relay to the server path; return value is intentionally empty because remoteExecCall is async.
    [_incidentType, _spawnPos, _destPos, _speedKph, _spawnDir, _taskId] remoteExecCall ["ARC_fnc_execSpawnConvoy", 2];
    []
};

if (!(_callerOwner isEqualType 0)) then { _callerOwner = -1; };

private _incidentTypeU = toUpper _incidentType;
private _debug = missionNamespace getVariable ["ARC_convoyDebug", false];
private _todPolicy = [] call ARC_fnc_dynamicTodGetPolicy;
private _hgTod = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _canSpawnOps = [_todPolicy, "canSpawnOps", true] call _hgTod;
if (!(_canSpawnOps isEqualType true) && !(_canSpawnOps isEqualType false)) then { _canSpawnOps = true; };
if (!_canSpawnOps) exitWith {[]};
private _todPhase = [_todPolicy, "phase", "DAY"] call _hgTod;
if (!(_todPhase isEqualType "")) then { _todPhase = "DAY"; };

private _log = {
    params [["_msg", "", [""]], ["_args", [], [[]]], ["_lvl", "WARN", [""]]];
    if (!isNil "ARC_fnc_log") then { ["CONVOY", _msg, _args, _lvl] call ARC_fnc_log; }
    else { diag_log (if ((count _args) > 0) then { format ([_msg] + _args) } else { _msg }); };
};

// Spawn vehicles with a conservative cadence so each one has time to clear the spawn marker.
// Large convoys at tight spawn pads (ex: Airbase perimeter road) need this to avoid pileups.
private _interval = missionNamespace getVariable ["ARC_convoySpawnIntervalSec", 10];
if (!(_interval isEqualType 0)) then { _interval = 10; };
_interval = (_interval max 10) min 30;

// Desired convoy spacing (also used to ensure the initial spawn forms a column cleanly).
private _sepDesired = missionNamespace getVariable ["ARC_convoySpacingPreLinkupM", 25];
if (!(_sepDesired isEqualType 0)) then { _sepDesired = 25; };
_sepDesired = (_sepDesired max 10) min 80;

// Persist current convoy spacing to state (used by execTickConvoy for link-up / depart).
["activeConvoySpacingM", _sepDesired] call ARC_fnc_stateSet;

private _padClearR = missionNamespace getVariable ["ARC_convoySpawnPadClearRadiusM", 18];
if (!(_padClearR isEqualType 0)) then { _padClearR = 18; };

private _enforceCrewSide = missionNamespace getVariable [
    "ARC_convoyEnforceCrewSideWest",
    missionNamespace getVariable ["ARC_convoyEnforceCrewSide", true]
];
if (!(_enforceCrewSide isEqualType true) && !(_enforceCrewSide isEqualType false)) then { _enforceCrewSide = true; };
if (_debug) then
{
    ["[ARC][CONVOY][BOOT] enforceCrewSide=%1", [_enforceCrewSide], "WARN"] call _log;
};

// If the pad-clear radius is too small, vehicles spawn too tightly and the convoy "blooms" into a blob
// before it settles into formation. Nudge the radius toward the desired convoy spacing.
private _minClear = ((_sepDesired * 0.65) max 18) min 90;
_padClearR = (_padClearR max _minClear) min 120;

_spawnPos = +_spawnPos; _spawnPos resize 3;
_destPos = +_destPos; _destPos resize 3;

// Link-up: read from state (planned by execInitActive). If missing/too close, fall back.
private _linkupPos = ["activeConvoyLinkupPos", []] call ARC_fnc_stateGet;
if (!(_linkupPos isEqualType []) || { (count _linkupPos) < 2 }) then { _linkupPos = []; };
if (_linkupPos isNotEqualTo []) then { _linkupPos = +_linkupPos; _linkupPos resize 3; };

private _legPos = _linkupPos;
if (!(_legPos isEqualType []) || { (count _legPos) < 2 } || { (_spawnPos distance2D _legPos) < 60 }) then
{
    // Ensure the first leg moves vehicles off the pad.
    _legPos = _spawnPos getPos [150, _spawnDir];
    _legPos resize 3;
};

// --- Vehicle class selection -------------------------------------------------
private _classes = [];

// Base pools (can be overridden via missionNamespace in bootstrapServer)
private _poolLog  = missionNamespace getVariable ["ARC_convoyVehiclesLogistics", []];
private _poolEsc  = missionNamespace getVariable ["ARC_convoyVehiclesEscort", []];
private _poolLead = missionNamespace getVariable ["ARC_convoyVehiclesLead", []];

// Hard fallback pools (desert US Army only)
if (!(_poolLog isEqualType []) || { (count _poolLog) == 0 }) then { _poolLog = ["rhsusf_m978a4_bkit_usarmy_d", "rhsusf_m977a4_ammo_bkit_usarmy_d", "rhsusf_m977a4_repair_bkit_usarmy_d"]; };
if (!(_poolEsc isEqualType []) || { (count _poolEsc) == 0 }) then { _poolEsc = ["rhsusf_M1232_M2_usarmy_d", "rhsusf_M1232_MK19_usarmy_d"]; };
if (!(_poolLead isEqualType []) || { (count _poolLead) == 0 }) then { _poolLead = ["rhsusf_M1232_M2_usarmy_d", "rhsusf_M1232_MK19_usarmy_d"]; };

// Role matrix pool resolution (allows missionNamespace to redirect role->pool keys).
private _roleMatrix = missionNamespace getVariable ["ARC_convoyRoleMatrixPoolKeys", []];
if (!(_roleMatrix isEqualType [])) then { _roleMatrix = []; };

// Convoy role plan (prepared by execInitActive): stable identifiers describing bundle/context.
private _rolePlan = ["activeConvoyRolePlan", []] call ARC_fnc_stateGet;
if (!(_rolePlan isEqualType [])) then { _rolePlan = []; };

private _rolePlanGet = {
    params ["_pairs", "_key", "_default"];
    if !(_pairs isEqualType []) exitWith {_default};
    private _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 2 } && { ((_x # 0) isEqualType "") && { (toLower (_x # 0)) isEqualTo (toLower _key) } }) exitWith { _idx = _forEachIndex; }; } forEach _pairs;
    if (_idx < 0) exitWith {_default};
    (_pairs # _idx) # 1
};

private _roleBundleId = [_rolePlan, "bundleId", ""] call _rolePlanGet;
if (!(_roleBundleId isEqualType "")) then { _roleBundleId = ""; };
_roleBundleId = toUpper _roleBundleId;

// Authoritative bundle matrix (bundleId -> [vehicle classes...]).
private _bundleMatrix = missionNamespace getVariable ["ARC_convoyBundleClassMatrix", []];
if (!(_bundleMatrix isEqualType [])) then { _bundleMatrix = []; };

private _bundleClassPool = [];
if (_roleBundleId isNotEqualTo "") then
{
    private _idxBundle = -1;
    { if ((_x isEqualType []) && { (count _x) >= 2 } && { ((_x # 0) isEqualType "") } && { (toUpper (_x # 0)) isEqualTo _roleBundleId }) exitWith { _idxBundle = _forEachIndex; }; } forEach _bundleMatrix;

    if (_idxBundle >= 0) then
    {
        private _rawPool = (_bundleMatrix # _idxBundle) # 1;
        if (_rawPool isEqualType []) then
        {
            {
                if (_x isEqualType "" && { isClass (configFile >> "CfgVehicles" >> _x) }) then
                {
                    _bundleClassPool pushBackUnique _x;
                };
            } forEach _rawPool;
        };
    };
};

// Incident metadata (used for VIP motorcades, supply-kind selection, etc.)
private _incidentMarker = ["activeIncidentMarker", ""] call ARC_fnc_stateGet;
if (!(_incidentMarker isEqualType "")) then { _incidentMarker = ""; };

private _incidentName = ["activeIncidentName", ""] call ARC_fnc_stateGet;
if (!(_incidentName isEqualType "")) then { _incidentName = ""; };

private _isVIP = false;
if (_incidentTypeU isEqualTo "ESCORT") then
{
    // Prefer explicit role plan flag when available; keep legacy detection as fallback.
    private _vipFromPlan = [_rolePlan, "vipEscort", false] call _rolePlanGet;
    if (!(_vipFromPlan isEqualType true) && !(_vipFromPlan isEqualType false)) then { _vipFromPlan = false; };
    _isVIP = _vipFromPlan;

    if (!_isVIP) then
    {
        // VIP escort convoys are only generated for select escort incidents (option A).
        if (_incidentMarker in ["ARC_loc_PresidentialPalace", "ARC_loc_EmbassyCompound"]) then
        {
            _isVIP = true;
        }
        else
        {
            private _nU = toUpper _incidentName;
            if ((_nU find "MOTORCADE") >= 0 || { (_nU find "DIPLOMATIC") >= 0 } || { (_nU find "VIP") >= 0 }) then
            {
                _isVIP = true;
            };
        };
    };
};

// Supply kind for logistics convoys (set in execInitActive)
private _supplyKind = ["activeConvoySupplyKind", ""] call ARC_fnc_stateGet;
if (!(_supplyKind isEqualType "")) then { _supplyKind = ""; };
_supplyKind = toUpper _supplyKind;
if (_supplyKind isEqualTo "") then
{
    private _supplyFromPlan = [_rolePlan, "supplyKind", ""] call _rolePlanGet;
    if (_supplyFromPlan isEqualType "") then { _supplyKind = toUpper _supplyFromPlan; };
};

// SUV / Police pools for ESCORT convoys (BLUFOR-only vehicles; crews come from the vehicle's native faction)
private _poolSUV = missionNamespace getVariable ["ARC_convoyVehiclesEscortSUV", [
    "UK3CB_ION_B_Desert_SUV",
    "UK3CB_ION_B_Desert_SUV_Armed",
    "UK3CB_ION_B_Desert_SUV_Armoured",
    "UK3CB_TKA_B_SUV_Armed",
    "UK3CB_TKA_B_SUV_Armoured",
    "d3s_escalade_20_FSB",
    "d3s_escalade_16_EMS",
    "d3s_escalade_16_cop",
    "UK3CB_TKP_B_Hilux_Open",
    "UK3CB_TKP_B_Hilux_Closed",
    "UK3CB_TKP_B_Offroad",
    "UK3CB_TKP_B_Offroad_M2",
    "UK3CB_TKC_B_SUV",
    "UK3CB_TKC_B_SUV_Armoured"
]];

private _poolVIP = missionNamespace getVariable ["ARC_convoyVehiclesEscortVIP", [
    "UK3CB_ION_B_Desert_SUV",
    "UK3CB_ION_B_Desert_SUV_Armed",
    "UK3CB_ION_B_Desert_SUV_Armoured"
]];

// Convoy group side is also used as a class policy gate (vehicle crew must be join-compatible).
private _grpSide = missionNamespace getVariable ["ARC_convoySide", west];
if !(typeName _grpSide isEqualTo "SIDE") then { _grpSide = west; };

private _sideToNumber = {
    params ["_s"];
    if (_s isEqualTo west) exitWith {1};
    if (_s isEqualTo east) exitWith {0};
    if (_s isEqualTo resistance) exitWith {2};
    if (_s isEqualTo civilian) exitWith {3};
    -1
};

private _allowedVehicleSides = missionNamespace getVariable ["ARC_convoyAllowedVehicleSides", []];
private _allowedCrewSides = missionNamespace getVariable ["ARC_convoyAllowedCrewSides", [1]];
private _allowedVehicleFactions = missionNamespace getVariable ["ARC_convoyAllowedVehicleFactions", []];
private _allowedCrewFactions = missionNamespace getVariable ["ARC_convoyAllowedCrewFactions", []];

if !(_allowedVehicleSides isEqualType []) then { _allowedVehicleSides = [1]; };
if !(_allowedCrewSides isEqualType []) then { _allowedCrewSides = [1]; };
if !(_allowedVehicleFactions isEqualType []) then { _allowedVehicleFactions = []; };
if !(_allowedCrewFactions isEqualType []) then { _allowedCrewFactions = []; };

private _groupSideNum = [_grpSide] call _sideToNumber;

// Policy validator for convoy classes.
private _isValidPolicyVehicle = {
    params ["_cls"];
    if !(_cls isEqualType "") exitWith {false};
    private _cfgVeh = configFile >> "CfgVehicles" >> _cls;
    if !(isClass _cfgVeh) exitWith {false};

    private _vehSide = getNumber (_cfgVeh >> "side");
    if ((count _allowedVehicleSides) > 0 && { !(_vehSide in _allowedVehicleSides) }) exitWith {false};

    private _vehFaction = getText (_cfgVeh >> "faction");
    if ((count _allowedVehicleFactions) > 0 && { !(_vehFaction in _allowedVehicleFactions) }) exitWith {false};

    private _crewCls = getText (_cfgVeh >> "crew");
    if (_crewCls isEqualTo "") exitWith {false};
    private _cfgCrew = configFile >> "CfgVehicles" >> _crewCls;
    if !(isClass _cfgCrew) exitWith {false};

    private _crewSide = getNumber (_cfgCrew >> "side");
    if ((count _allowedCrewSides) > 0 && { !(_crewSide in _allowedCrewSides) }) exitWith {false};

    private _crewFaction = getText (_cfgCrew >> "faction");
    if ((count _allowedCrewFactions) > 0 && { !(_crewFaction in _allowedCrewFactions) }) exitWith {false};

    // Crew must be side-compatible with the convoy group for joinSilent to work reliably.
    if (_groupSideNum >= 0 && { !(_crewSide isEqualTo _groupSideNum) }) exitWith {false};

    private _c = toLower _cls;

    // Explicit removals (keeps pools from accidentally reintroducing them).
    if ((_c find "stryker") >= 0) exitWith {false};
    if ((_c find "m113") >= 0) exitWith {false};

    // Generic tracked filter (covers M113s, M88, etc. even if classname isn't obvious).
    private _sim = toLower (getText (configFile >> "CfgVehicles" >> _cls >> "simulation"));
    if (_sim isEqualTo "tankx") exitWith {false};

    if (_cls isKindOf "Tank") exitWith {false};
    if (_cls isKindOf "Tracked_APC_F") exitWith {false};

    true
};

private _filterPool = {
    params ["_poolIn"];
    if !(_poolIn isEqualType []) exitWith {[]};
    _poolIn select { [_x] call _isValidPolicyVehicle }
};

private _pickFrom = {
    params ["_poolIn"];
    private _pool = [_poolIn] call _filterPool;
    if ((count _pool) == 0) exitWith {""};
    _pool select (floor (random (count _pool)))
};

private _getRoleKeyList = {
    params ["_roleName"];
    private _r = toLower _roleName;
    private _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 2 } && { ((_x # 0) isEqualType "") && { (toLower (_x # 0)) isEqualTo _r } }) exitWith { _idx = _forEachIndex; }; } forEach _roleMatrix;
    if (_idx < 0) exitWith {[]};
    private _keys = (_roleMatrix # _idx) # 1;
    if !(_keys isEqualType []) exitWith {[]};
    _keys select { _x isEqualType "" }
};

private _collectPoolsByKeys = {
    params ["_keys"];
    private _out = [];
    {
        if (_x isEqualType "") then
        {
            private _pool = missionNamespace getVariable [_x, []];
            if (_pool isEqualType []) then
            {
                {
                    if (_x isEqualType "" && { isClass (configFile >> "CfgVehicles" >> _x) }) then
                    {
                        _out pushBackUnique _x;
                    };
                } forEach _pool;
            };
        };
    } forEach _keys;
    _out
};

private _resolveRolePool = {
    params ["_roleName", "_legacyPool"];
    private _keys = [_roleName] call _getRoleKeyList;
    private _resolved = [_keys] call _collectPoolsByKeys;

    // Hard fallback: if matrix role resolves empty, keep legacy behavior.
    if ((count _resolved) == 0 && { _legacyPool isEqualType [] }) then
    {
        {
            if (_x isEqualType "" && { isClass (configFile >> "CfgVehicles" >> _x) }) then
            {
                _resolved pushBackUnique _x;
            };
        } forEach _legacyPool;
    };
    _resolved
};

private _bundleOrLegacy = {
    params ["_legacyPool"];
    if ((count _bundleClassPool) > 0) exitWith { +_bundleClassPool };

    private _out = [];
    if (_legacyPool isEqualType []) then
    {
        {
            if (_x isEqualType "" && { isClass (configFile >> "CfgVehicles" >> _x) }) then
            {
                _out pushBackUnique _x;
            };
        } forEach _legacyPool;
    };
    _out
};

private _poolLeadRole = ["lead", _poolLead] call _resolveRolePool;
private _poolEscRole = ["escort", _poolEsc] call _resolveRolePool;
private _poolLogRole = ["logistics", _poolLog] call _resolveRolePool;

private _poolLeadSelect = [_poolLeadRole] call _bundleOrLegacy;
private _poolEscSelect = [_poolEscRole] call _bundleOrLegacy;
private _poolLogSelect = [_poolLogRole] call _bundleOrLegacy;

// Startup breadcrumbs (low-volume): capture role bundle + resolved class pools used for this spawn pass.
private _roleBundleLog = if (_roleBundleId isEqualTo "") then {"<none>"} else {_roleBundleId};
private _classesPreview = [
    ["lead", +_poolLeadSelect],
    ["escort", +_poolEscSelect],
    ["logistics", +_poolLogSelect]
];
["[ARC][CONVOY][BOOT] task=%1 type=%2 bundle=%3 supply=%4 vip=%5 rolePools=%6", [_taskId, _incidentTypeU, _roleBundleLog, _supplyKind, _isVIP, _classesPreview], "WARN"] call _log;

// Build the convoy class list.
switch (_incidentTypeU) do
{
    case "LOGISTICS":
    {
        // Lead + 3-5 logistics + tail escort
        private _lead = [_poolLeadSelect] call _pickFrom;
        if (_lead isNotEqualTo "") then { _classes pushBack _lead; };

        // Role-based selection from the matrix pool keys, with legacy fallbacks preserved.
        private _poolGen = +_poolLogSelect;
        private _poolSup = +_poolLogSelect;
        private _poolHQ = +_poolLogSelect;
        private _poolMaint = +_poolLogSelect;

        private _logRoleKeys = ["logistics"] call _getRoleKeyList;
        if ((count _logRoleKeys) > 0) then
        {
            private _fromKey = {
                params ["_key", "_fallback"];
                private _resolved = [[_key]] call _collectPoolsByKeys;
                if ((count _resolved) == 0) exitWith { +_fallback };
                _resolved
            };

            _poolGen = ["ARC_rhsConvoyCargoPool_general", _poolLogSelect] call _fromKey;
            _poolHQ = ["ARC_rhsConvoyCargoPool_hq", _poolLogSelect] call _fromKey;
            _poolMaint = ["ARC_rhsConvoyCargoPool_maint", _poolLogSelect] call _fromKey;

            _poolSup = switch (_supplyKind) do
            {
                case "FUEL": { ["ARC_rhsConvoyCargoPool_fuel", _poolLogSelect] call _fromKey };
                case "AMMO": { ["ARC_rhsConvoyCargoPool_ammo", _poolLogSelect] call _fromKey };
                case "MED":  { ["ARC_rhsConvoyCargoPool_med", _poolLogSelect] call _fromKey };
                default        { +_poolLogSelect };
            };
        };

        private _count = 3 + floor (random 3); // 3..5
        for "_i" from 1 to _count do
        {
            private _roll = random 1;
            private _pickPool = _poolGen;

            // Small chance to inject maint / HQ flavors.
            if (_roll < 0.10 && { _poolMaint isEqualType [] } && { (count _poolMaint) > 0 }) then
            {
                _pickPool = _poolMaint;
            }
            else
            {
                if (_roll < 0.18 && { _poolHQ isEqualType [] } && { (count _poolHQ) > 0 }) then
                {
                    _pickPool = _poolHQ;
                }
                else
                {
                    // Mostly supply-kind vehicles, with some general cargo mixed in.
                    _pickPool = if ((random 1) < 0.65) then { _poolSup } else { _poolGen };
                };
            };

            private _c = [_pickPool] call _pickFrom;
            if (_c isNotEqualTo "") then { _classes pushBack _c; };
        };

        private _tail = [_poolEscSelect] call _pickFrom;
        if (_tail isNotEqualTo "") then { _classes pushBack _tail; };
    };

    case "ESCORT":
    {
        // Lead + 2-4 escort vehicles (VIP variants bias toward SUVs/PMCs)
        private _lead = [_poolLeadSelect] call _pickFrom;
        if (_lead isNotEqualTo "") then { _classes pushBack _lead; };

        private _count = if (_isVIP) then { 3 + floor (random 3) } else { 2 + floor (random 3) }; // VIP 3..5, normal 2..4
        private _pSUV = if (_isVIP) then { 0.75 } else { 0.35 };
        private _minSUV = if (_isVIP) then { 2 } else { 0 };
        private _pickedSUV = 0;

        for "_i" from 1 to _count do
        {
            private _remaining = (_count - _i) + 1;
            private _need = _minSUV - _pickedSUV;
            private _forceSUV = (_need > 0) && { _remaining <= _need };

            private _useSUV = _forceSUV || { (random 1) < _pSUV };

            private _poolUse = _poolEscRole;
            if (_useSUV) then
            {
                // VIP: bias toward ION SUVs (PMC crews). Otherwise use the broader SUV/Police pool.
                _poolUse = if (_isVIP && { (random 1) < 0.70 }) then { _poolVIP } else { _poolSUV };
            };

            private _c = [_poolUse] call _pickFrom;
            if (_c isNotEqualTo "") then
            {
                _classes pushBack _c;
                if (_useSUV) then { _pickedSUV = _pickedSUV + 1; };
            };
        };
    };

    default
    {
        // Safe fallback: escort style
        private _lead = [_poolLeadSelect] call _pickFrom;
        if (_lead isNotEqualTo "") then { _classes pushBack _lead; };
        private _c = [_poolEscSelect] call _pickFrom;
        if (_c isNotEqualTo "") then { _classes pushBack _c; };
        private _c2 = [_poolEscSelect] call _pickFrom;
        if (_c2 isNotEqualTo "") then { _classes pushBack _c2; };
    };
};

if ((count _classes) == 0) exitWith
{
    ["[ARC][CONVOY] No convoy vehicle classes available.", [], "WARN"] call _log;
    []
};

// Startup breadcrumbs (low-volume): final selected class list after policy filtering.
["[ARC][CONVOY][BOOT] task=%1 type=%2 selectedClassesAfterFiltering=%3 count=%4", [_taskId, _incidentTypeU, _classes, count _classes], "WARN"] call _log;

// --- Sequential spawn --------------------------------------------------------
private _vehicles = [];
private _wp = objNull;

// Create a dedicated convoy group up-front.
// Relying on the first vehicle's auto-created crew group is fragile (it can leave
// each vehicle in its own separate group if any join step fails).
private _grp = createGroup [_grpSide, true];
if (isNull _grp) then
{
    ["[ARC][CONVOY] Failed to create convoy group. Falling back to WEST.", [], "WARN"] call _log;
    _grp = createGroup [west, true];
};
_grp setFormation "COLUMN";
_grp setCombatMode "BLUE";
_grp setBehaviour "SAFE";
_grp setSpeedMode "LIMITED";

// Tag the group so watchdog/rehydration can recognize the current convoy.
if (_taskId isNotEqualTo "") then { _grp setVariable ["ARC_convoyTaskId", _taskId, true]; };
_grp setVariable ["ARC_convoyIncidentType", _incidentTypeU, true];
_grp setVariable ["ARC_dynamic_tod_phase_spawn", _todPhase, true];
_grp setVariable ["ARC_dynamic_tod_profile_spawn", [_todPolicy, "profile", "STANDARD"] call _hgTod, true];

// Convoy ORBAT designation profile (drives groupId/callsigns via ARC_fnc_groupSetDesignation).
// Profiles are defined in bootstrapServer: LONGHAUL/PROVIDER/LIFELINE... (LOGISTICS) and LAWDAWG/SAPPER... (ESCORT).
private _profiles = if (_incidentTypeU isEqualTo "ESCORT") then
{
    missionNamespace getVariable ["ARC_orbatConvoyProfiles_escort", []]
}
else
{
    missionNamespace getVariable ["ARC_orbatConvoyProfiles_logistics", []]
};

private _pickProfileByCallsign = {
    params ["_ps", "_callsign"];
    if (!(_ps isEqualType []) || { (count _ps) == 0 }) exitWith {[]};
    if (!(_callsign isEqualType "")) exitWith {[]};
    private _cU = toUpper _callsign;

    private _idx = -1;
    { if ((_x isEqualType []) && { (count _x) >= 3 } && { (toUpper (_x # 2)) isEqualTo _cU }) exitWith { _idx = _forEachIndex; }; } forEach _ps;
    if (_idx < 0) exitWith {[]};
    _ps # _idx
};

private _profile = [];

// Prefer "intentional" profile selection where we have a clear semantic match.
if (_incidentTypeU isEqualTo "LOGISTICS") then
{
    switch (_supplyKind) do
    {
        case "FUEL": { _profile = [_profiles, "PROVIDER"] call _pickProfileByCallsign; };
        case "AMMO": { _profile = [_profiles, "LONGHAUL"] call _pickProfileByCallsign; };
        case "MED":  { _profile = [_profiles, "ANGEL"] call _pickProfileByCallsign; };
        default { /* fall back to random below */ };
    };

    if (_roleBundleId isEqualTo "LOGI_FUEL") then { _profile = [_profiles, "PROVIDER"] call _pickProfileByCallsign; };
    if (_roleBundleId isEqualTo "LOGI_AMMO") then { _profile = [_profiles, "LONGHAUL"] call _pickProfileByCallsign; };
    if (_roleBundleId isEqualTo "LOGI_MEDICAL") then { _profile = [_profiles, "ANGEL"] call _pickProfileByCallsign; };
};

if (_incidentTypeU isEqualTo "ESCORT") then
{
    if (_isVIP || { _roleBundleId isEqualTo "ESCORT_VIP" }) then
    {
        _profile = [_profiles, "LAWDAWG"] call _pickProfileByCallsign;
    }
    else
    {
        private _nU = toUpper _incidentName;
        if ((_nU find "MINE") >= 0 || { (_nU find "CLEAR") >= 0 }) then
        {
            _profile = [_profiles, "SAPPER"] call _pickProfileByCallsign;
        };
    };
};

// Fallback: random within the correct profile set.
if (_profile isEqualTo [] && { _profiles isEqualType [] } && { (count _profiles) > 0 }) then
{
    _profile = _profiles select (floor (random (count _profiles)));
};

if (_profile isEqualType [] && { (count _profile) >= 3 }) then
{
    _grp setVariable ["ARC_designationProfile", _profile, true];
};

private _leadLeader = objNull;
private _prevDrv = objNull;
private _prevPos = _spawnPos;

private _isPadOccupied = {
    params ["_pos", "_r"];
    private _near = nearestObjects [_pos, ["LandVehicle"], _r];
    private _foundAlive = false;
    { if (alive _x) exitWith { _foundAlive = true; }; } forEach _near;
    _foundAlive
};


private _forceRoad = missionNamespace getVariable ["ARC_convoyForceFollowRoad", true];
if (!(_forceRoad isEqualType true) && !(_forceRoad isEqualType false)) then { _forceRoad = true; };

// Spawn pad kick: optionally force newly spawned vehicles to move off the pad quickly.
// This prevents long pad-blocking stalls where subsequent vehicles cannot spawn.
private _padKick = missionNamespace getVariable ["ARC_convoySpawnPadKickEnabled", true];
if (!(_padKick isEqualType true) && !(_padKick isEqualType false)) then { _padKick = true; };

private _padKickTimeout = missionNamespace getVariable ["ARC_convoySpawnPadKickTimeoutSec", 8];
if (!(_padKickTimeout isEqualType 0)) then { _padKickTimeout = 8; };
_padKickTimeout = (_padKickTimeout max 2) min 30;


// Spawn staging parameters. These exist to prevent newly spawned vehicles from accelerating past the
// vehicle in front while the convoy is still assembling on the spawn pad.
private _stageEnabled = missionNamespace getVariable ["ARC_convoySpawnStagingEnabled", true];
if (!(_stageEnabled isEqualType true) && !(_stageEnabled isEqualType false)) then { _stageEnabled = true; };

private _spawnKph = missionNamespace getVariable ["ARC_convoySpawnStageSpeedKph", 12];
if (!(_spawnKph isEqualType 0)) then { _spawnKph = 12; };
_spawnKph = (_spawnKph max 6) min ((_speedKph min 25) max 6);

private _stagePos = [];
if (_stageEnabled) then
{
    private _snapR = missionNamespace getVariable ["ARC_convoySpawnStageRoadSnapM", 80];
    if (!(_snapR isEqualType 0)) then { _snapR = 80; };
    _snapR = (_snapR max 20) min 200;

    private _maxStageDist = missionNamespace getVariable ["ARC_convoySpawnStageMaxDistM", 350];
    if (!(_maxStageDist isEqualType 0)) then { _maxStageDist = 350; };
    _maxStageDist = (_maxStageDist max 150) min 1500;

    // Ensure the staging chain can clear the pad for the whole convoy.
    private _minNeed = (_padClearR + 5) * (count _classes);
    if (_maxStageDist < _minNeed) then { _maxStageDist = _minNeed; };

    private _stageSpacingUser = missionNamespace getVariable ["ARC_convoySpawnStageSpacingM", -1];
    if (!(_stageSpacingUser isEqualType 0)) then { _stageSpacingUser = -1; };

    private _autoSpacing = ((_sepDesired max (_padClearR + 5)) min 45);
    private _capSpacing = _maxStageDist / ((count _classes) max 1);

    private _spacing = if (_stageSpacingUser > 0) then { _stageSpacingUser } else { _autoSpacing };
    _spacing = (_spacing max (_padClearR + 5)) min _capSpacing;

    private _fn_snap = {
        params ["_p", "_r"];
        private _near = _p nearRoads _r;
        if ((count _near) == 0) exitWith { _p };
        private _best = _near # 0;
        private _bestD = (getPosATL _best) distance2D _p;
        {
            private _d = (getPosATL _x) distance2D _p;
            if (_d < _bestD) then { _bestD = _d; _best = _x; };
        } forEach _near;
        private _q = getPosATL _best;
        _q resize 3;
        _q
    };

    private _n = count _classes;
    for "_i" from 0 to (_n - 1) do
    {
        private _dist = _spacing * (_n - _i);
        private _p = _spawnPos getPos [_dist, _spawnDir];
        _p resize 3;
        _p = [_p, _snapR] call _fn_snap;
        _stagePos pushBack _p;
    };

    if (_debug) then
    {
        ["[ARC][CONVOY] Spawn staging enabled: n=%1, spacing=%2m, kph=%3.", [count _classes, _spacing, _spawnKph], "WARN"] call _log;
    };
};

{
    private _class = _x;

    // Validate vehicle class early (prevents silent partial convoys when a classname is missing).
    // Avoid 'continue' for broad compatibility.
    if !(isClass (configFile >> "CfgVehicles" >> _class)) then
    {
        ["[ARC][CONVOY] Invalid vehicle classname (CfgVehicles missing): %1", [_class], "WARN"] call _log;
    }
    else
    {
        // Wait for spawn pad to clear (check once per interval).
        private _guard = 0;
        while { ([_spawnPos, _padClearR] call _isPadOccupied) && { _guard < 60 } } do
        {
            _guard = _guard + 1;
            sleep _interval;
        };

        private _veh = createVehicle [_class, _spawnPos, [], 0, "NONE"];
        if (isNull _veh) then
        {
            ["[ARC][CONVOY] Failed to create vehicle: %1", [_class], "WARN"] call _log;
        }
        else
        {
            _veh setDir _spawnDir;
            _veh setPosATL (_spawnPos vectorAdd [0,0,0.25]); // slight Z lift to reduce ground clipping
            _veh allowDamage false;
            _veh setVariable ["ARC_isConvoyVeh", true, true];
            _veh setVariable ["ARC_dynamic_tod_phase_spawn", _todPhase, true];
            _veh setVariable ["ARC_dynamic_tod_profile_spawn", [_todPolicy, "profile", "STANDARD"] call _hgTod, true];

            // Tag this vehicle so we can rehydrate and enforce one-convoy-at-a-time.
            if (_taskId isNotEqualTo "") then { _veh setVariable ["ARC_convoyTaskId", _taskId, true]; };
            _veh setVariable ["ARC_convoyIndex", _forEachIndex, true];
            private _role = "CARGO";
            if (_forEachIndex isEqualTo 0) then { _role = "LEAD"; };
            if (_forEachIndex isEqualTo ((count _classes) - 1)) then { _role = "TAIL"; };
            _veh setVariable ["ARC_convoyRole", _role, true];

            // Crew + group join (hardened: validate runtime crew side + join success)
            createVehicleCrew _veh;

            private _crew = crew _veh;
            private _drv = driver _veh;
            if (isNull _drv) then { _drv = effectiveCommander _veh; };

            // Remember temporary crew group so we can delete it once empty (avoids extra groups on map).
            private _oldGrp = if (!isNull _drv) then { group _drv } else { grpNull };

            // Some mod vehicles can spawn with unexpected crew side (or refuse to join), which results in
            // multiple groups moving to link-up. When enforcing crew-side, delete the vehicle instead.
            private _crewOk = true;
            if (_enforceCrewSide) then
            {
                if (isNull _drv) then
                {
                    _crewOk = false;
                }
                else
                {
                    _crewOk = (side _drv) isEqualTo _grpSide;
                };
            };

            if (!_crewOk) then
            {
                if (_debug) then
                {
                    private _s = if (!isNull _drv) then { str (side _drv) } else { "NULL_DRIVER" };
                    ["[ARC][CONVOY] Skipping %1 due to crew side mismatch (%2).", [_class, _s], "WARN"] call _log;
                };

                { if (!isNull _x) then { deleteVehicle _x; }; } forEach _crew;
                if (!isNull _veh) then { deleteVehicle _veh; };
                if (!isNull _oldGrp && { (count units _oldGrp) == 0 }) then { deleteGroup _oldGrp; };
            }
            else
            {
                // joinSilent expects an array of units.
                // Never join player-controlled units into the convoy group (prevents TOC role/ops loss if a player takes the wheel).
                private _crewAI = _crew select { !isPlayer _x };
                if ((count _crewAI) > 0) then { _crewAI joinSilent _grp; };

                // Verify join succeeded. If it didn't, we will also skip to prevent multi-group convoys.
                private _joinedOk = true;
                if (_enforceCrewSide && { !isNull _drv } && { !(isPlayer _drv) } && { !(group _drv isEqualTo _grp) }) then
                {
                    _joinedOk = false;
                };

                if (!_joinedOk) then
                {
                    if (_debug) then
                    {
                        ["[ARC][CONVOY] Skipping %1 because crew could not join convoy group.", [_class], "WARN"] call _log;
                    };

                    { if (!isNull _x) then { deleteVehicle _x; }; } forEach _crew;
                    if (!isNull _veh) then { deleteVehicle _veh; };
                    if (!isNull _oldGrp && { (count units _oldGrp) == 0 }) then { deleteGroup _oldGrp; };
                }
                else
                {
                    // Clean up old crew group once empty.
                    if (!isNull _oldGrp && { !(_oldGrp isEqualTo _grp) } && { (count units _oldGrp) == 0 }) then
                    {
                        deleteGroup _oldGrp;
                    };

                    // Establish a stable leader.
                    if (isNull _leadLeader) then
                    {
                        _leadLeader = _drv;

                        // Ensure leader belongs to convoy group.
                        if !(group _leadLeader isEqualTo _grp) then { if (!isPlayer _leadLeader) then { [_leadLeader] joinSilent _grp; }; };

                        // Make the lead driver the group leader (formation consistency).
                        if (!isNull _leadLeader && { (group _leadLeader) isEqualTo _grp } && { leader _grp != _leadLeader }) then { _grp selectLeader _leadLeader; };
                    };

                    // Spawn staging: move each vehicle to a unique staging slot so the convoy forms cleanly.
                    if (!isNull _drv) then
                    {
                        // Chain-follow during staging so newly spawned vehicles don't overtake.
                        if (!isNull _prevDrv && { _drv != _prevDrv }) then { _drv doFollow _prevDrv; };

                        private _tgt = _legPos;
                        if (_stageEnabled && { (count _stagePos) > _forEachIndex }) then { _tgt = _stagePos # _forEachIndex; };

                        // Per-vehicle caps are more reliable during doMove than group speedMode alone.
                        _veh limitSpeed _spawnKph;
                        _veh setConvoySeparation _sepDesired;

                        // Keep vehicles on the road network from the first movement order.
                        if (_forceRoad) then { _drv forceFollowRoad true; };

                        _drv doMove _tgt;

                    // Ensure the vehicle clears the spawn pad so subsequent vehicles can spawn.
                    if (_padKick) then
                    {
                        _veh engineOn true;
                        _veh forceSpeed 12;
                        private _t0 = time;
                        waitUntil
                        {
                            uiSleep 0.25;
                            isNull _veh || { (_veh distance2D _spawnPos) > (_padClearR * 0.95) } || { (time - _t0) > _padKickTimeout }
                        };
                        if (!isNull _veh) then
                        {
                            _veh forceSpeed -1;
                        };
                    };

                    };

                    // Update previous (used for staging chaining).
                    _prevDrv = _drv;
                    _prevPos = getPosATL _veh;

                    // Re-enable damage after short grace window.
                    [_veh] spawn
                    {
                        params ["_v"];
                        uiSleep 10;
                        if (!isNull _v) then { _v allowDamage true; };
                    };

                    if (_debug) then
                    {
                        ["[ARC][CONVOY] Spawned %1 at %2, crew %3, grp %4.", [_class, mapGridPosition (getPosATL _veh), count _crew, groupId _grp], "WARN"] call _log;
                    };

                    _vehicles pushBack _veh;
                };
            };
        };

        // Enforce minimum spacing between spawns
        sleep _interval;
    };
} forEach _classes;

// Finalize group config / designation
if (!isNull _grp) then
{
    // Ensure stable convoy spacing
    private _sep = _sepDesired;
    if (!(_sep isEqualType 0)) then { _sep = 25; };
    _sep = (_sep max 10) min 80;

    // setConvoySeparation is an Object command (vehicle), not a Group command.
    // Apply to every spawned convoy vehicle (recommended by BI).
    { _x setConvoySeparation _sep; } forEach _vehicles;

    // Assign a readable designation
    private _role = if (_incidentTypeU isEqualTo "ESCORT") then {"ESCORT"} else {"LOGISTICS"};
    [_grp, _role] call ARC_fnc_groupSetDesignation;
};



// VIP / Presidential escorts: seat VIP + guards as passengers (no extra escort groups/vehicles).
if (_incidentTypeU isEqualTo "ESCORT" && { _isVIP } && { !isNull _grp } && { (count _vehicles) > 0 }) then
{
    private _vipPassengersEnabled = missionNamespace getVariable ["ARC_convoyVipPassengersEnabled", true];
    if (!(_vipPassengersEnabled isEqualType true) && !(_vipPassengersEnabled isEqualType false)) then { _vipPassengersEnabled = true; };

    if (_vipPassengersEnabled) then
    {
        private _pickFirstExisting = {
            params ["_cand"];
            if !(_cand isEqualType []) exitWith {""};
            private _out = "";
            {
                if (_x isEqualType "" && { isClass (configFile >> "CfgVehicles" >> _x) }) exitWith { _out = _x; };
            } forEach _cand;
            _out
        };

        private _vipUnitClasses = missionNamespace getVariable ["ARC_convoyVipUnitClasses", [
            // RHS preferred, vanilla fallback
            "rhsusf_army_ocp_officer",
            "rhsusf_army_ucp_officer",
            "B_officer_F"
        ]];

        private _guardUnitClasses = missionNamespace getVariable ["ARC_convoyVipGuardUnitClasses", [
            // RHS preferred, vanilla fallback
            "rhsusf_army_ocp_rifleman",
            "rhsusf_army_ucp_rifleman",
            "B_soldier_F"
        ]];

        private _vipCls = [_vipUnitClasses] call _pickFirstExisting;
        private _guardCls = [_guardUnitClasses] call _pickFirstExisting;

        private _guardCount = missionNamespace getVariable ["ARC_convoyVipGuardCount", 4];
        if (!(_guardCount isEqualType 0)) then { _guardCount = 4; };
        _guardCount = (_guardCount max 0) min 20;

        private _leadVeh = _vehicles # 0;
        private _tailVeh = _vehicles # ((count _vehicles) - 1);

        // Choose a VIP vehicle: prefer a middle vehicle with cargo seats (keeps lead/tail as security cars).
        private _vipVeh = objNull;
        if ((count _vehicles) > 2) then
        {
            for "_i" from 1 to ((count _vehicles) - 2) do
            {
                private _v = _vehicles # _i;
                if (!isNull _v && { (_v emptyPositions "cargo") > 0 }) exitWith { _vipVeh = _v; };
            };
        };

        if (isNull _vipVeh) then
        {
            // Fallback: any convoy vehicle with cargo seats.
            {
                if (!isNull _x && { (_x emptyPositions "cargo") > 0 }) exitWith { _vipVeh = _x; };
            } forEach _vehicles;
        };

        // Spawn VIP (WEST) and seat as cargo.
        if (_vipCls isNotEqualTo "" && { !isNull _vipVeh }) then
        {
            private _vip = _grp createUnit [_vipCls, _spawnPos, [], 0, "NONE"];
            if (!isNull _vip) then
            {
                _vip setRank "PRIVATE"; // reduce chance of taking group lead if drivers die
                _vip setVariable ["ARC_isConvoyVIP", true, true];
                _vip setVariable ["ARC_dynamic_tod_phase_spawn", _todPhase, true];
                _vip setVariable ["ARC_dynamic_tod_profile_spawn", [_todPolicy, "profile", "STANDARD"] call _hgTod, true];
                _vip assignAsCargo _vipVeh;
                _vip moveInCargo _vipVeh;
            };
        };

        // Spawn guards and distribute: VIP vehicle, lead, tail, then fill remaining cargo seats.
        if (_guardCls isNotEqualTo "" && { _guardCount > 0 }) then
        {
            private _preferred = [];
            if (!isNull _vipVeh) then { _preferred pushBack _vipVeh; _preferred pushBack _vipVeh; };
            if (!isNull _leadVeh) then { _preferred pushBack _leadVeh; };
            if (!isNull _tailVeh && { !(_tailVeh isEqualTo _leadVeh) }) then { _preferred pushBack _tailVeh; };

            private _fillList = +_preferred;
            { _fillList pushBack _x; } forEach _vehicles;

            for "_g" from 1 to _guardCount do
            {
                private _u = _grp createUnit [_guardCls, _spawnPos, [], 0, "NONE"];
                if (isNull _u) then { continue; };

                _u setRank "PRIVATE";
                _u setVariable ["ARC_isConvoyVIPGuard", true, true];
                _u setVariable ["ARC_dynamic_tod_phase_spawn", _todPhase, true];
                _u setVariable ["ARC_dynamic_tod_profile_spawn", [_todPolicy, "profile", "STANDARD"] call _hgTod, true];

                private _seated = false;
                {
                    private _v = _x;
                    if (isNull _v) then { continue; };
                    if ((_v emptyPositions "cargo") > 0) exitWith
                    {
                        _u assignAsCargo _v;
                        _u moveInCargo _v;
                        _seated = (vehicle _u) isEqualTo _v;
                    };
                } forEach _fillList;

                if (!_seated) then { deleteVehicle _u; };
            };
        };
    };
};

// Return netIds (lead first)
(_vehicles apply { netId _x })

/*
    File: functions/ambiance/fn_airbasePlaneDepart.sqf
    Author: ARC / Ambient Airbase Subsystem

    Description:
      Executes a fixed-wing or rotary-wing departure:
        1) Crew (already placed in 3DEN / respawned from templates) exits idle state
        2) Crew walks to aircraft and boards using assignAs* + orderGetIn (NO moveIn*)
        3) 15s prep delay
        4) Taxi path playback via BIS_fnc_unitPlay
        5) AI-controlled takeoff / climb-out via runway markers
        6) Delete aircraft + associated crew once it reaches the despawn marker

    Notes:
      - This function is intentionally server-only.
      - This function blocks until the aircraft despawns (or times out), which keeps the
        airbase queue strictly sequential.
*/

if (!isServer) exitWith { false };
if !(["airbasePlaneDepart"] call ARC_fnc_airbaseRuntimeEnabled) exitWith {false};

params ["_fid", "_asset"];
if (isNil "_asset") exitWith { false };
if (!(_asset isEqualType createHashMap)) exitWith { false };

private _debug    = missionNamespace getVariable ["airbase_v1_debug", false];
private _debugOps = missionNamespace getVariable ["airbase_v1_debugOpsLog", false];
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _veh = [_asset, "veh", objNull] call _hg;
if (isNil "_veh") then { _veh = objNull; };
if (isNull _veh) exitWith {
    _asset set ["state", "PARKED"];
    _asset set ["activeFlight", ""];
    false
};

private _vehType = typeOf _veh;
private _vehVar  = [_asset, "vehVar", ""] call _hg;
private _crewVars = [_asset, "crewVars", []] call _hg;
if (!(_crewVars isEqualType [])) then { _crewVars = []; };
private _isHeli  = (_veh isKindOf "Helicopter");
// UAS / RPAS detection: fixed-wing UAVs (e.g. RQ-4A Global Hawk) need ISR loiter
// treatment rather than a standard fly-to-despawn departure.
// Detect by type name; covers USAF_RQ4A and any mod variant containing "RQ4".
private _isUAS   = (!_isHeli) && { (_vehType find "RQ4") >= 0 || { (toLower _vehType) find "uav" >= 0 } };
// Keep EC-130 detection here because taxi prep needs it for pre-taxi fuel restore.
private _isEC130 = (_vehType find "aws_C130_AEW") >= 0;

// --- helpers ---
private _fnNormalize = {
    params ["_data"];
    if (!(_data isEqualType [])) exitWith { [] };

    // Some recorder exports wrap frames as [frames]
    if ((count _data) == 1 && { (_data select 0) isEqualType [] } && { (count (_data select 0)) > 0 } && { ((_data select 0) select 0) isEqualType [] }) exitWith {
        _data select 0
    };

    _data
};

private _fnUnitPlayBlocking = {
    params ["_vehL", "_framesL"];
    if (isNull _vehL) exitWith { false };
    if ((count _framesL) == 0) exitWith { false };

    _vehL enableSimulationGlobal true;
    _vehL allowDamage false;
    _vehL engineOn true;
    if (_vehL isKindOf "Air") then { _vehL setCollisionLight true; _vehL setPilotLight true; };
    _vehL setVelocity [0,0,0];
    _vehL setVelocityModelSpace [0,0,0];

    private _duration = 0;
    private _last = _framesL select ((count _framesL) - 1);
    if (_last isEqualType [] && { (count _last) > 0 } && { (_last select 0) isEqualType 0 }) then {
        _duration = (_last select 0);
    };
    private _tEnd = time + (_duration + 10);

    private _h = [_vehL, _framesL] spawn BIS_fnc_unitPlay;
    waitUntil {
        sleep 0.25;
        isNull _vehL || {!alive _vehL} || {scriptDone _h} || {time > _tEnd}
    };

    !(isNull _vehL) && {alive _vehL}
};

private _fnEnsureTaxiEngineOn = {
    params ["_vehL", "_pilotL", "_debugL"];
    if (isNull _vehL || {!alive _vehL}) exitWith { false };

    _vehL engineOn true;
    if (!isNull _pilotL && {alive _pilotL}) then {
        _pilotL action ["EngineOn", _vehL];
    };

    private _tEngine = time + 8;
    waitUntil {
        sleep 0.25;
        isNull _vehL || {!alive _vehL} || {isEngineOn _vehL} || {time > _tEngine}
    };

    if (isNull _vehL || {!alive _vehL}) exitWith { false };
    private _engineOk = isEngineOn _vehL;
    if (!_engineOk && {_debugL}) then {
        diag_log format ["[AIRBASESUB] %1 engine failed to start before taxi (%2)", _fid, typeOf _vehL];
    };
    _engineOk
};

private _fnSeatScan = {
    params ["_vehL"];
    private _hasCommander = false;
    private _hasGunner = false;
    private _gunnerTurretPaths = [];

    private _fc = fullCrew [_vehL, "", true];
    {
        private _role = _x param [1, ""];
        private _tp   = _x param [3, []];
        if (_role isEqualTo "commander") then { _hasCommander = true; };
        if (_role isEqualTo "gunner") then {
            _hasGunner = true;
            _gunnerTurretPaths pushBack _tp;
        };
    } forEach _fc;

    [_hasCommander, _hasGunner, _gunnerTurretPaths]
};

private _fnAbortToIdle = {
    params ["_crewL", "_vehL"];

    {
        if (isNull _x) then { continue; };
        if (!alive _x) then { continue; };

        // If anyone partially boarded, get them out so we return to a clean idle state.
        if ((vehicle _x) isEqualTo _vehL) then {
            unassignVehicle _x;
            doGetOut _x;
        } else {
            unassignVehicle _x;
        };

        _x forceWalk false;
    } forEach _crewL;

    // Give AI a moment to step out before re-idling
    sleep 2;
    [_crewL] call ARC_fnc_airbaseCrewIdleStart;
};

private _fnGetDirectionBetween = {
    params [
        ["_fromPos", [], [[]]],
        ["_toPos", [], [[]]],
        ["_fallbackDir", 0, [0]]
    ];
    if ((count _fromPos) < 2) exitWith { _fallbackDir };
    if ((count _toPos) < 2) exitWith { _fallbackDir };

    private _dir = _fallbackDir;

    private _dx = (_toPos select 0) - (_fromPos select 0);
    private _dy = (_toPos select 1) - (_fromPos select 1);
    if (((abs _dx) + (abs _dy)) > 0.1) then {
        _dir = _dx atan2 _dy;
        if (_dir < 0) then { _dir = _dir + 360; };
    };

    _dir
};

private _fnSetRunwayClimbVelocity = {
    params [
        ["_vehLocal", objNull, [objNull]],
        ["_dir", 0, [0]],
        ["_fwdMps", 0, [0]],
        ["_upMps", 0, [0]]
    ];
    if (isNull _vehLocal) exitWith { false };
    if (!(_dir isEqualType 0)) exitWith { false };
    if (!(_fwdMps isEqualType 0)) exitWith { false };
    if (!(_upMps isEqualType 0)) exitWith { false };

    _vehLocal setDir _dir;
    _vehLocal setVelocity [
        (sin _dir) * _fwdMps,
        (cos _dir) * _fwdMps,
        _upMps
    ];

    true
};

private _fnRecoverCrewSeats = {
    params [
        ["_crewLocal", [], [[]]],
        ["_vehLocal", objNull, [objNull]],
        ["_pilotLocal", objNull, [objNull]]
    ];
    if (isNull _vehLocal) exitWith { 0 };

    private _fixed = 0;
    {
        private _unit = _x;
        if (isNull _unit) then { continue; };
        if (!alive _unit) then { continue; };
        if ((vehicle _unit) isEqualTo _vehLocal) then { continue; };

        private _role = assignedVehicleRole _unit;
        private _roleName = "";
        if ((count _role) > 0 && { (_role select 0) isEqualType "" }) then {
            _roleName = toLower (_role select 0);
        };

        switch (_roleName) do {
            case "driver": { _unit moveInDriver _vehLocal; };
            case "commander": { _unit moveInCommander _vehLocal; };
            case "gunner": { _unit moveInGunner _vehLocal; };
            case "turret": {
                if ((count _role) > 1 && { (_role select 1) isEqualType [] }) then {
                    _unit moveInTurret [_vehLocal, (_role select 1)];
                } else {
                    _unit moveInAny _vehLocal;
                };
            };
            case "cargo": { _unit moveInCargo _vehLocal; };
            default { _unit moveInAny _vehLocal; };
        };

        if ((vehicle _unit) isEqualTo _vehLocal) then { _fixed = _fixed + 1; };
    } forEach _crewLocal;

    if (!isNull _pilotLocal && { alive _pilotLocal } && { !((driver _vehLocal) isEqualTo _pilotLocal) }) then {
        _pilotLocal moveInDriver _vehLocal;
        if ((driver _vehLocal) isEqualTo _pilotLocal) then { _fixed = _fixed + 1; };
    };

    _fixed
};

private _fnPreparePlane6TaxiSpawn = {
    params [
        ["_assetLocal", createHashMap, [createHashMap]],
        ["_vehLocal", objNull, [objNull]],
        ["_vehTypeLocal", "", [""]],
        ["_vehVarLocal", "", [""]],
        ["_crewVarsLocal", [], [[]]]
    ];

    if (isNull _vehLocal) exitWith { [false, objNull, []] };
    if (_vehTypeLocal isEqualTo "") exitWith { [false, objNull, []] };

    private _spawnMarker = "ARC_m_base_uas_spawn";
    private _spawnPos = getMarkerPos _spawnMarker;
    private _spawnDir = markerDir _spawnMarker;
    if (!(_spawnPos isEqualType []) || { (count _spawnPos) < 2 } || { _spawnPos isEqualTo [0,0,0] }) then {
        _spawnPos = [_assetLocal, "startPos", getPosATL _vehLocal] call _hg;
        _spawnDir = [_assetLocal, "startDir", getDir _vehLocal] call _hg;
        diag_log format ["[ARC][WARN] ARC_fnc_airbasePlaneDepart: marker %1 missing/invalid; fallback spawn used for plane6", _spawnMarker];
    };
    if (!(_spawnDir isEqualType 0)) then { _spawnDir = getDir _vehLocal; };

    private _trackedCrew = [_assetLocal, "crew", []] call _hg;
    if (!(_trackedCrew isEqualType [])) then { _trackedCrew = []; };
    private _vehCrew = crew _vehLocal;
    private _oldCrew = [];
    {
        if (isNull _x) then { continue; };
        if ((_oldCrew find _x) < 0) then { _oldCrew pushBack _x; };
    } forEach (_trackedCrew + _vehCrew);

    { deleteVehicle _x; } forEach _oldCrew;
    deleteVehicle _vehLocal;

    private _newVeh = createVehicle [_vehTypeLocal, _spawnPos, [], 0, "NONE"];
    _newVeh setPosATL _spawnPos;
    _newVeh setDir _spawnDir;
    _newVeh setVelocity [0,0,0];
    _newVeh setVelocityModelSpace [0,0,0];
    _newVeh enableSimulationGlobal true;
    _newVeh allowDamage true;

    if (_vehVarLocal != "") then {
        missionNamespace setVariable [_vehVarLocal, _newVeh, true];
    };

    private _templates = [_assetLocal, "crewTemplates", []] call _hg;
    if (!(_templates isEqualType [])) then { _templates = []; };
    private _crewSide = [_assetLocal, "crewSide", west] call _hg;
    private _newCrew = [];

    if ((count _templates) > 0) then {
        private _grpCrew = createGroup [_crewSide, true];
        _grpCrew setGroupIdGlobal ["99 ERS | HORIZON-1 (RQ-4)"];
        {
            private _row = _x;
            if (!(_row isEqualType []) || { (count _row) < 2 }) then { continue; };
            private _vName = _row param [0, ""];
            private _class = _row param [1, ""];
            private _loadout = _row param [2, []];
            if (_class isEqualTo "") then { continue; };

            private _u = _grpCrew createUnit [_class, _spawnPos, [], 0, "NONE"];
            _u setPosATL _spawnPos;
            _u setDir _spawnDir;
            if (_loadout isEqualType [] && { (count _loadout) > 0 }) then {
                _u setUnitLoadout _loadout;
            };

            if (_vName isEqualTo "" && { _forEachIndex < (count _crewVarsLocal) }) then {
                _vName = _crewVarsLocal select _forEachIndex;
            };
            if (!(_vName isEqualTo "")) then {
                missionNamespace setVariable [_vName, _u, true];
            };

            if (_forEachIndex isEqualTo 0) then { _u moveInDriver _newVeh; } else { _u moveInAny _newVeh; };
            _newCrew pushBack _u;
        } forEach _templates;
    };

    if ((count _newCrew) == 0) then {
        createVehicleCrew _newVeh;
        _newCrew = crew _newVeh;
        if ((count _newCrew) > 0) then {
            private _grpCrewFallback = group (_newCrew select 0);
            _grpCrewFallback setGroupIdGlobal ["99 ERS | HORIZON-1 (RQ-4)"];
            {
                if (_forEachIndex < (count _crewVarsLocal)) then {
                    private _cv = _crewVarsLocal select _forEachIndex;
                    if (!(_cv isEqualTo "")) then { missionNamespace setVariable [_cv, _x, true]; };
                };
            } forEach _newCrew;
        };
    };

    _assetLocal set ["veh", _newVeh];
    _assetLocal set ["crew", _newCrew];

    [!isNull _newVeh && { (count _newCrew) > 0 }, _newVeh, _newCrew]
};

// --- resolve crew ---
if (_vehVar isEqualTo "plane6") then {
    private _prep = [_asset, _veh, _vehType, _vehVar, _crewVars] call _fnPreparePlane6TaxiSpawn;
    if !(_prep param [0, false]) exitWith {
        diag_log format ["[ARC][WARN] ARC_fnc_airbasePlaneDepart: plane6 taxi spawn prep failed for %1", _fid];
        _asset set ["state", "PARKED"];
        _asset set ["activeFlight", ""];
        false
    };
    _veh = _prep param [1, objNull];
    _vehType = typeOf _veh;
};

private _crew = [_asset, "crew", []] call _hg;
if (!(_crew isEqualType [])) then { _crew = []; };
private _crewLive = _crew select { !isNull _x && alive _x };

if ((count _crewLive) == 0) exitWith {
    if (_debug) then { diag_log format ["[AIRBASESUB] %1 %2 has no live crew", _fid, _vehType]; };
    _asset set ["state", "PARKED"];
    _asset set ["activeFlight", ""];
    false
};

private _pilot = _crewLive select 0;
if (isNull _pilot) exitWith {
    _asset set ["state", "PARKED"];
    _asset set ["activeFlight", ""];
    false
};

// Ensure all crew are in the pilot's group so doMove/waypoints apply to the vehicle.
private _grp = group _pilot;
{
    if (!isNull _x && {alive _x} && {!((group _x) isEqualTo _grp)}) then {
        [_x] joinSilent _grp;
    };
} forEach _crewLive;
if (!((leader _grp) isEqualTo _pilot)) then { _grp selectLeader _pilot; };

// Validate despawn marker before disturbing idle crew. If this check runs after
// taxi playback, rotary-wing aircraft may already be airborne and abort-to-idle
// can eject crew into frozen ambient animations.
private _despawnMkr = missionNamespace getVariable ["airbase_v1_plane_despawn_marker", "plane_despawn"];
private _despawnPos = getMarkerPos _despawnMkr;
private _despawnX = _despawnPos select 0;
private _despawnY = _despawnPos select 1;
private _ws = worldSize;
private _despawnOffMap = (_despawnPos isEqualTo [0,0,0]) || { _despawnX < 0 } || { _despawnY < 0 } || { _despawnX > _ws } || { _despawnY > _ws };
if (_despawnOffMap) then {
    private _rawDespawnPos = +_despawnPos;
    private _edgeMargin = 250;
    private _maxCoord = (_ws - _edgeMargin) max _edgeMargin;

    if (_despawnPos isEqualTo [0,0,0]) then {
        private _basePos = getMarkerPos "mkr_airbaseCenter";
        if (_basePos isEqualTo [0,0,0]) then { _basePos = [_ws / 2, _ws / 2, 0]; };
        _despawnX = (_basePos select 0) + 2500;
        _despawnY = _basePos select 1;
    };

    _despawnX = (_despawnX max _edgeMargin) min _maxCoord;
    _despawnY = (_despawnY max _edgeMargin) min _maxCoord;
    _despawnPos = [_despawnX, _despawnY, 0];

    diag_log format ["[AIRBASESUB] %1 WARN: despawn marker '%2' resolved off-map (pos=%3); using on-map fallback %4.", _fid, _despawnMkr, _rawDespawnPos, _despawnPos];
};

// Stop idle animations and order a real walk-up boarding (NO moveIn)
_veh lock false;

{
    private _u = _x;
    [_u] call ARC_fnc_airbaseCrewIdleStop;
    _u forceWalk true;
    _u setBehaviour "SAFE";
    _u setCombatMode "BLUE";
    unassignVehicle _u;
} forEach _crewLive;

private _scan = [_veh] call _fnSeatScan;
_scan params ["_hasCommander", "_hasGunner", "_gunnerTurretPaths"];

// Assign seats
_pilot assignAsDriver _veh;
[_pilot] orderGetIn true;

// Track whether index-1 consumed the first gunner turret path (so index-2+ offset correctly).
private _u2UsedGunner = false;
if ((count _crewLive) > 1) then {
    private _u2 = _crewLive select 1;
    if (_isHeli && {_hasCommander}) then {
        _u2 assignAsCommander _veh;
    } else {
        if (_hasGunner) then { _u2 assignAsGunner _veh; _u2UsedGunner = true; } else { _u2 assignAsCargo _veh; };
    };
    [_u2] orderGetIn true;
};

// Crew beyond index 1 go to door-gun turret seats where available, else cargo.
// If index 1 already took the first gunner turret path, start from path index 1.
private _turretStartIdx = if (_u2UsedGunner) then { 1 } else { 0 };
for "_i" from 2 to ((count _crewLive) - 1) do {
    private _ux = _crewLive select _i;
    private _tpIdx = (_i - 2) + _turretStartIdx;
    if (_tpIdx < (count _gunnerTurretPaths)) then {
        _ux assignAsTurret [_veh, _gunnerTurretPaths select _tpIdx];
    } else {
        _ux assignAsCargo _veh;
    };
    [_ux] orderGetIn true;
};

private _boardTimeout = missionNamespace getVariable ["airbase_v1_boardTimeout_s", 180];
if (!(_boardTimeout isEqualType 0) || { _boardTimeout < 30 }) then { _boardTimeout = 180; };

private _tBoard0 = time;
waitUntil {
    sleep 1;
    (isNil "_veh") || {isNull _veh} || {!alive _veh} || {isNil "_pilot"} || {!alive _pilot} ||
    {(driver _veh) isEqualTo _pilot && { ({ (vehicle _x) isEqualTo _veh || {!alive _x} } count _crewLive) == (count _crewLive) }} ||
    {(time - _tBoard0) > _boardTimeout}
};

private _boardOk = !(isNil "_veh") && {!(isNull _veh)} && {alive _veh} && {!(isNil "_pilot")} && {alive _pilot} && {(driver _veh) isEqualTo _pilot} && { ({ (vehicle _x) isEqualTo _veh || {!alive _x} } count _crewLive) == (count _crewLive) };

{ if (!isNull _x) then { _x forceWalk false; }; } forEach _crewLive;

if (!_boardOk) exitWith {
    if (_debug) then { diag_log format ["[AIRBASESUB] %1 boarding FAILED for %2", _fid, _vehType]; };

    [_crewLive, _veh] call _fnAbortToIdle;

    _asset set ["state", "PARKED"];
    _asset set ["activeFlight", ""];
    false
};

// Prep delay (simulate checks / engine spool)
private _prepDelay = missionNamespace getVariable ["airbase_v1_prepDelay_s", 300];
if (!(_prepDelay isEqualType 0) || { _prepDelay < 0 }) then { _prepDelay = 15; };
if (_prepDelay > 0) then { sleep _prepDelay; };

// --- taxi playback ---
private _taxiVar = [_asset, "taxiPathVar", ""] call _hg;
private _taxiData = missionNamespace getVariable [_taxiVar, []];
private _taxiFrames = [_taxiData] call _fnNormalize;

// Rotary-wing: hover-taxi (lift capture frames so wheels are just off the ground)
if (_isHeli) then {
    private _hoverM = missionNamespace getVariable ["airbase_v1_rw_taxi_hover_m", 1.5];
    if (!(_hoverM isEqualType 0) || { _hoverM < 0 }) then { _hoverM = 1.5; };

    if (_hoverM > 0) then {
        private _adj = [];
        {
            private _f = _x;
            if (_f isEqualType [] && { (count _f) >= 2 } && { (_f select 1) isEqualType [] } && { (count (_f select 1)) >= 3 }) then {
                private _pos = +(_f select 1);
                _pos set [2, (_pos select 2) + _hoverM];
                private _nf = +_f;
                _nf set [1, _pos];
                _adj pushBack _nf;
            } else {
                _adj pushBack _f;
            };
        } forEach _taxiFrames;
        _taxiFrames = _adj;
    };
};

if ((count _taxiFrames) == 0) exitWith {
    if (_debug) then { diag_log format ["[AIRBASESUB] %1 taxi path empty (%2)", _fid, _taxiVar]; };

    // Return crew to idle and reset state.
    [_crewLive, _veh] call _fnAbortToIdle;
    _asset set ["state", "PARKED"];
    _asset set ["activeFlight", ""];

    false
};

if (_isEC130) then { _veh setFuel 1; };
if !([_veh, _pilot, _debug] call _fnEnsureTaxiEngineOn) exitWith {
    [_crewLive, _veh] call _fnAbortToIdle;
    _asset set ["state", "PARKED"];
    _asset set ["activeFlight", ""];
    false
};
if (_veh isKindOf "Air") then { _veh setCollisionLight true; _veh setPilotLight true; };

// Disable AI for ALL crew during unitPlay so no crew member (including co-pilot/commander)
// can issue competing movement commands and cause the helicopter to bank or deviate.
{
    _x disableAI "PATH";
    _x disableAI "MOVE";
    _x disableAI "FSM";
    _x setBehaviour "CARELESS";
    _x setCombatMode "BLUE";
} forEach _crewLive;

private _okTaxi = [_veh, _taxiFrames] call _fnUnitPlayBlocking;

// Rotary-wing handoff: commit the helicopter to a hover *before* AI is re-enabled
// and *before* the physics engine can drop a near-zero-velocity helo into the ground.
// BIS_fnc_unitPlay restores the vehicle to the last frame's velocity (typically ~0
// for taxi recordings), so without an immediate hover directive the helo dips,
// clips terrain, and the AI crew bails out. (Crew bailout from a "crashing" helo
// also produces the apparent mid-air freeze when their parachute deploys at low alt.)
if (_isHeli && {!isNull _veh} && {alive _veh} && {_okTaxi}) then {
    private _altLowHandoff = missionNamespace getVariable ["airbase_v1_rw_takeoff_alt_low_m", 3];
    if (!(_altLowHandoff isEqualType 0) || { _altLowHandoff < 2 }) then { _altLowHandoff = 3; };
    private _handoffFwdMps = missionNamespace getVariable ["airbase_v1_rw_handoff_forward_mps", 6];
    if (!(_handoffFwdMps isEqualType 0) || { _handoffFwdMps < 0 }) then { _handoffFwdMps = 6; };
    private _handoffUpMps = missionNamespace getVariable ["airbase_v1_rw_handoff_up_mps", 3];
    if (!(_handoffUpMps isEqualType 0) || { _handoffUpMps < 0 }) then { _handoffUpMps = 3; };

    _veh enableSimulationGlobal true;
    _veh engineOn true;
    _veh land "NONE";
    _veh flyInHeight _altLowHandoff;
    // Forward velocity in vehicle model space keeps the helo aligned to its current
    // heading; upward component ensures positive lift through the handoff frame.
    _veh setVelocityModelSpace [0, _handoffFwdMps, _handoffUpMps];

    if (_debugOps) then {
        ["OPS", format ["AIRBASE: %1 helo taxi->takeoff handoff (alt=%2m fwd=%3 up=%4)", _fid, _altLowHandoff, _handoffFwdMps, _handoffUpMps], getPosATL _veh, 0, [
            ["vehType", _vehType]
        ]] call ARC_fnc_intelLog;
    };
};

{ _x enableAI "PATH"; _x enableAI "MOVE"; _x enableAI "FSM"; } forEach _crewLive;

private _recoveredSeats = [_crewLive, _veh, _pilot] call _fnRecoverCrewSeats;
if (_debugOps && { _recoveredSeats > 0 }) then {
    ["OPS", format ["AIRBASE: %1 recovered %2 crew seat(s) after taxi playback", _fid, _recoveredSeats], getPosATL _veh, 0, [
        ["vehType", _vehType],
        ["isHeli", _isHeli]
    ]] call ARC_fnc_intelLog;
};

_veh enableSimulationGlobal true;
_veh engineOn true;
if (_veh isKindOf "Air") then { _veh setCollisionLight true; _veh setPilotLight true; };

if (!_okTaxi) exitWith {
    if (_debug) then { diag_log format ["[AIRBASESUB] %1 taxi playback failed/aborted (%2)", _fid, _vehType]; };

    // If the taxi phase failed, abort to idle instead of deleting.
    [_crewLive, _veh] call _fnAbortToIdle;
    _asset set ["state", "PARKED"];
    _asset set ["activeFlight", ""];

    false
};

// --- special case: EC-130 loiter (do not despawn) ---
// Uses `_isEC130` defined with the early vehicle-type flags so taxi prep can also apply EC-130-specific handling.
if (_isEC130) exitWith {
    _veh setVehicleRadar 1;
    _veh setVehicleReportRemoteTargets true;
    _veh setVehicleReceiveRemoteTargets true;
    _veh setVehicleReportOwnPosition true;
    { _veh enableVehicleSensor [_x, true]; } forEach (listVehicleSensors _veh);

    private _center = [worldSize / 2, worldSize / 2, 0];
    _veh flyInHeight 1829; // 6000 ft

    while { (count (waypoints _grp)) > 0 } do { deleteWaypoint ((waypoints _grp) select 0); };
    private _wp = _grp addWaypoint [_center, 0];
    _wp setWaypointType "LOITER";
    _wp setWaypointLoiterType "CIRCLE_L";
    _wp setWaypointLoiterRadius 5000;
    _wp setWaypointSpeed "NORMAL";
    _wp setWaypointBehaviour "SAFE";

    if (_debugOps) then {
        ["OPS", format ["AIRBASE: %1 EC-130 on-station loiter", _fid], _center, 0, [
            ["vehType", _vehType],
            ["radius_m", 5000],
            ["alt_m", 1829]
        ]] call ARC_fnc_intelLog;
    };

    true
};

// --- UAS / RPAS loiter (ISR platforms: RQ-4A etc.) ---
// UAS assets provide persistent ISR coverage and should not depart.
// After taxi, they climb to operational altitude and loiter over the AO centre,
// mirroring the EC-130 treatment. Sensors are activated for realism.
if (_isUAS) exitWith {
    _veh setVehicleRadar 1;
    _veh setVehicleReportRemoteTargets true;
    _veh setVehicleReceiveRemoteTargets true;
    _veh setVehicleReportOwnPosition true;
    { _veh enableVehicleSensor [_x, true]; } forEach (listVehicleSensors _veh);

    private _uasAlt = missionNamespace getVariable ["airbase_v1_uas_loiter_alt_m", 6096]; // 20,000 ft
    if (!(_uasAlt isEqualType 0) || { _uasAlt < 500 }) then { _uasAlt = 6096; };

    private _uasRadius = missionNamespace getVariable ["airbase_v1_uas_loiter_radius_m", 8000];
    if (!(_uasRadius isEqualType 0) || { _uasRadius < 1000 }) then { _uasRadius = 8000; };

    private _uasCenter = [worldSize / 2, worldSize / 2, 0];

    _veh engineOn true;
    _veh land "NONE";
    _veh flyInHeight _uasAlt;

    while { (count (waypoints _grp)) > 0 } do { deleteWaypoint ((waypoints _grp) select 0); };
    private _wpU = _grp addWaypoint [_uasCenter, 0];
    _wpU setWaypointType "LOITER";
    _wpU setWaypointLoiterType "CIRCLE_L";
    _wpU setWaypointLoiterRadius _uasRadius;
    _wpU setWaypointSpeed "NORMAL";
    _wpU setWaypointBehaviour "SAFE";

    if (_debugOps) then {
        ["OPS", format ["AIRBASE: %1 UAS on-station loiter (ISR)", _fid], _uasCenter, 0, [
            ["vehType", _vehType],
            ["alt_m", _uasAlt],
            ["radius_m", _uasRadius]
        ]] call ARC_fnc_intelLog;
    };

    diag_log format ["[AIRBASESUB] %1 UAS (%2) on-station loiter — alt=%3 m radius=%4 m", _fid, _vehType, _uasAlt, _uasRadius];
    true
};

// --- takeoff / fly-out ---
while { (count (waypoints _grp)) > 0 } do { deleteWaypoint ((waypoints _grp) select 0); };
_grp setSpeedMode "FULL";
_grp setBehaviour "CARELESS";
_grp setCombatMode "BLUE";

private _cruiseAlt = 3048; // 10,000 ft default for FW
if (_isHeli) then {
    _cruiseAlt = missionNamespace getVariable ["airbase_v1_rw_depart_alt_m", 152];
    if (!(_cruiseAlt isEqualType 0) || { _cruiseAlt < 20 }) then { _cruiseAlt = 152; };
};

private _kickPos = _despawnPos;
private _takeoffKickDir = getDir _veh;
private _takeoffKickFwdMps = 18;
private _takeoffKickUpMps = 5;

if (_isHeli) then {
    private _rwClimbStepAlt = missionNamespace getVariable ["airbase_v1_rw_climb_step_alt_m", 30];
    if (!(_rwClimbStepAlt isEqualType 0) || { _rwClimbStepAlt < 10 }) then { _rwClimbStepAlt = 30; };
    private _rwClimbStepIntervalS = missionNamespace getVariable ["airbase_v1_rw_climb_step_interval_s", 4];
    if (!(_rwClimbStepIntervalS isEqualType 0) || { _rwClimbStepIntervalS < 1 }) then { _rwClimbStepIntervalS = 4; };
    private _rwClimbKickFwd = missionNamespace getVariable ["airbase_v1_rw_climb_kick_forward_mps", 18];
    if (!(_rwClimbKickFwd isEqualType 0) || { _rwClimbKickFwd < 6 }) then { _rwClimbKickFwd = 18; };
    private _rwClimbKickUp = missionNamespace getVariable ["airbase_v1_rw_climb_kick_up_mps", 5];
    if (!(_rwClimbKickUp isEqualType 0) || { _rwClimbKickUp < 1 }) then { _rwClimbKickUp = 5; };
    _takeoffKickFwdMps = _rwClimbKickFwd;
    _takeoffKickUpMps = _rwClimbKickUp;
    private _rwClimbProfileTimeoutS = missionNamespace getVariable ["airbase_v1_rw_climb_profile_timeout_s", 240];
    if (!(_rwClimbProfileTimeoutS isEqualType 0) || { _rwClimbProfileTimeoutS < 30 }) then { _rwClimbProfileTimeoutS = 240; };

    private _mkrOut = missionNamespace getVariable ["airbase_v1_rw_outbound_marker", "AEON_Right_270_Outbound"]; 
    if (!(_mkrOut isEqualType "") || { _mkrOut isEqualTo "" }) then { _mkrOut = "AEON_Right_270_Outbound"; };

    private _mkrClear = missionNamespace getVariable ["airbase_v1_rw_outbound_clear_marker", "AEON_Right_270_Outbound_Clear"]; 
    if (!(_mkrClear isEqualType "") || { _mkrClear isEqualTo "" }) then { _mkrClear = "AEON_Right_270_Outbound_Clear"; };

    private _outPos = getMarkerPos _mkrOut;
    private _clearPos = getMarkerPos _mkrClear;

    private _hasOut = !(_outPos isEqualTo [0,0,0]);
    private _hasClear = !(_clearPos isEqualTo [0,0,0]);

    if (_hasOut) then { _kickPos = _outPos; };

    private _runwayDir = if (_hasOut && { _hasClear }) then { [_outPos, _clearPos, _takeoffKickDir] call _fnGetDirectionBetween } else { _takeoffKickDir };
    _takeoffKickDir = _runwayDir;

    _veh engineOn true;
    _veh land "NONE";

    // Lift off the deck to a safe altitude IMMEDIATELY, then climb. Previously the helo
    // was commanded to fly at ~3 m (_altLow) toward the fixed-wing outbound marker and
    // only began climbing once it reached that marker. That left the attack helo skimming
    // the ground, banking hard toward the offset marker, and striking terrain obstacles
    // (rocks, perimeter fence) before it ever gained altitude. Starting the climb from the
    // helo's current position keeps it clear of ground hazards during the outbound transit.
    private _rwLiftAlt = (_rwClimbStepAlt min _cruiseAlt) max 8;
    _veh flyInHeight _rwLiftAlt;

    if (_hasOut) then {
        private _wpO = _grp addWaypoint [_outPos, 0];
        _wpO setWaypointType "MOVE";
        _wpO setWaypointSpeed "NORMAL";
        _wpO setWaypointBehaviour "CARELESS";
        _wpO setWaypointCombatMode "BLUE";
        // Setting 0 here is unreliable (often treated like default). Use a near-zero radius.
        private _wpRad = missionNamespace getVariable ["airbase_v1_rw_outbound_wpRadius_m", 15];
        if (!(_wpRad isEqualType 0) || { _wpRad < 3 }) then { _wpRad = 15; };
        _wpO setWaypointCompletionRadius _wpRad;
    };

    // Progressive climb begins immediately (no longer gated on first reaching the outbound
    // marker), so the helo gains altitude during the outbound transit instead of skimming.
    [_fid, _veh, _cruiseAlt, _rwClimbStepAlt, _rwClimbStepIntervalS, _rwClimbKickFwd, _rwClimbKickUp, _rwClimbProfileTimeoutS, _runwayDir, _fnSetRunwayClimbVelocity, _debugOps] spawn {
        params ["_fidL", "_vehL", "_altTargetL", "_stepAltL", "_stepIntervalSL", "_kickForwardL", "_kickUpL", "_profileTimeoutSL", "_runwayDirL", "_setRunwayClimbVelocityL", "_dbgOpsL"];
        if (isNull _vehL || {!alive _vehL}) exitWith {};

        _vehL land "NONE";
        private _cmdAlt = (_stepAltL min _altTargetL) max 8;
        _vehL flyInHeight _cmdAlt;
        [_vehL, _runwayDirL, _kickForwardL, _kickUpL] call _setRunwayClimbVelocityL;

        private _tRamp0 = time;
        // Timeout keeps the helper from running forever; when reached, AI continues on existing waypoints at last commanded altitude.
        while { !isNull _vehL && {alive _vehL} && {_cmdAlt < _altTargetL} && {(time - _tRamp0) < _profileTimeoutSL} } do {
            sleep _stepIntervalSL;
            _cmdAlt = (_cmdAlt + _stepAltL) min _altTargetL;
            _vehL land "NONE";
            _vehL flyInHeight _cmdAlt;
            [_vehL, _runwayDirL, _kickForwardL, _kickUpL] call _setRunwayClimbVelocityL;
        };

        private _timedOut = ((time - _tRamp0) >= _profileTimeoutSL) && { _cmdAlt < _altTargetL };
        if (_dbgOpsL) then {
            private _altNow = (getPosATL _vehL) select 2;
            private _status = if (_timedOut) then { "TIMED OUT" } else { "complete" };
            ["OPS", format ["AIRBASE: %1 helo climb profile %2 (alt=%3m cmd=%4m target=%5m)", _fidL, _status, round _altNow, round _cmdAlt, _altTargetL], getPosATL _vehL, 0, [
                ["timedOut", _timedOut]
            ]] call ARC_fnc_intelLog;
        };
    };

    if (_hasClear) then {
        private _wpC = _grp addWaypoint [_clearPos, 0];
        _wpC setWaypointType "MOVE";
        _wpC setWaypointSpeed "FULL";
        _wpC setWaypointBehaviour "CARELESS";
        _wpC setWaypointCombatMode "BLUE";
        _wpC setWaypointCompletionRadius 75;
    };

    private _wpD = _grp addWaypoint [_despawnPos, 0];
    _wpD setWaypointType "MOVE";
    _wpD setWaypointSpeed "FULL";
    _wpD setWaypointBehaviour "CARELESS";
    _wpD setWaypointCombatMode "BLUE";
    _wpD setWaypointCompletionRadius 100;

} else {
    // Fixed-wing outbound markers
    private _mkrOut = missionNamespace getVariable ["airbase_v1_fw_depart_outbound_marker", "AEON_Right_270_Outbound"]; 
    if (!(_mkrOut isEqualType "") || { _mkrOut isEqualTo "" }) then { _mkrOut = "AEON_Right_270_Outbound"; };

    private _mkrClear = missionNamespace getVariable ["airbase_v1_fw_depart_outbound_clear_marker", "AEON_Right_270_Outbound_Clear"]; 
    if (!(_mkrClear isEqualType "") || { _mkrClear isEqualTo "" }) then { _mkrClear = "AEON_Right_270_Outbound_Clear"; };

    private _fallbackM = missionNamespace getVariable ["airbase_v1_fw_depart_outbound_clear_fallback_m", 1400];
    if (!(_fallbackM isEqualType 0) || { _fallbackM < 200 }) then { _fallbackM = 1400; };

    private _outPos = getMarkerPos _mkrOut;
    private _clearPos = getMarkerPos _mkrClear;

    private _hasOut = !(_outPos isEqualTo [0,0,0]);
    private _hasClear = !(_clearPos isEqualTo [0,0,0]);

    if (_hasOut) then { _kickPos = _outPos; };

    if (!_hasClear && { _hasOut }) then {
        // Compute a runway-end point forward of outbound marker if clear marker is missing.
        private _dir = markerDir _mkrOut;
        _clearPos = [
            (_outPos select 0) + (sin _dir) * _fallbackM,
            (_outPos select 1) + (cos _dir) * _fallbackM,
            0
        ];
        _hasClear = true;
    };

    _veh engineOn true;
    _veh land "NONE";
    _veh flyInHeight _cruiseAlt;

    if (_hasOut) then {
        private _wpO = _grp addWaypoint [_outPos, 0];
        _wpO setWaypointType "MOVE";
        _wpO setWaypointSpeed "NORMAL";
        _wpO setWaypointBehaviour "CARELESS";
        _wpO setWaypointCombatMode "BLUE";
        _wpO setWaypointCompletionRadius 1;
    };

    if (_hasClear) then {
        private _wpC = _grp addWaypoint [_clearPos, 0];
        _wpC setWaypointType "MOVE";
        _wpC setWaypointSpeed "FULL";
        _wpC setWaypointBehaviour "CARELESS";
        _wpC setWaypointCombatMode "BLUE";
        // Planes may already be airborne passing this point.
        _wpC setWaypointCompletionRadius 250;
    };

    private _wpD = _grp addWaypoint [_despawnPos, 0];
    _wpD setWaypointType "MOVE";
    _wpD setWaypointSpeed "FULL";
    _wpD setWaypointBehaviour "CARELESS";
    _wpD setWaypointCombatMode "BLUE";
    _wpD setWaypointCompletionRadius 150;
};

private _outboundWps = waypoints _grp;
if ((count _outboundWps) > 0) then {
    _grp setCurrentWaypoint (_outboundWps select 0);
};

// Post-taxi takeoff watchdog: unitPlay can leave AI stuck at taxi end.
private _kickEnabled = missionNamespace getVariable ["airbase_v1_takeoffKickEnabled", true];
private _kickTimeout = missionNamespace getVariable ["airbase_v1_takeoffKickTimeout_s", 45];
if (!(_kickTimeout isEqualType 0) || { _kickTimeout < 10 }) then { _kickTimeout = 45; };

if (_kickEnabled) then {
    [_fid, _veh, _pilot, _grp, _kickPos, _takeoffKickDir, _takeoffKickFwdMps, _takeoffKickUpMps, _fnSetRunwayClimbVelocity, _isHeli, _kickTimeout, _debugOps] spawn {
        params ["_fidL", "_vehL", "_pilotL", "_grpL", "_kickPosL", "_kickDirL", "_kickFwdMpsL", "_kickUpMpsL", "_setRunwayClimbVelocityL", "_isHeliL", "_timeoutS", "_debugOpsL"];
        if (isNull _vehL || {!alive _vehL}) exitWith {};
        private _tStart = time;
        private _d0 = _vehL distance2D _kickPosL;

        waitUntil {
            sleep 2;
            isNull _vehL || {!alive _vehL} ||
            {(speed _vehL) > 5} ||
            {(_vehL distance2D _kickPosL) < (_d0 - 10)} ||
            {(time - _tStart) > _timeoutS}
        };

        if (isNull _vehL || {!alive _vehL}) exitWith {};

        // Still basically not moving
        if ((speed _vehL) <= 5 && {(_vehL distance2D _kickPosL) >= (_d0 - 10)}) then {
            _vehL engineOn true;

            if (_isHeliL) then {
                _vehL land "NONE";
                _vehL flyInHeight 10;
                [_vehL, _kickDirL, _kickFwdMpsL, _kickUpMpsL] call _setRunwayClimbVelocityL;
                _pilotL doMove _kickPosL;
            } else {
                _vehL land "NONE";
                _vehL flyInHeight 50;
                _vehL forceSpeed 80;
                _vehL setVelocityModelSpace [0, 35, 0];
                _pilotL doMove _kickPosL;
            };

            _grpL setSpeedMode "FULL";
            _grpL setBehaviour "CARELESS";
            _grpL setCombatMode "BLUE";
            private _kickWps = waypoints _grpL;
            if ((count _kickWps) > 0) then {
                _grpL setCurrentWaypoint (_kickWps select 0);
            };

            if (_debugOpsL) then {
                ["OPS", format ["AIRBASE: %1 TAKEOFF KICK applied", _fidL], getPosATL _vehL, 0, [
                    ["isHeli", _isHeliL],
                    ["kickPos", _kickPosL]
                ]] call ARC_fnc_intelLog;
            };
        };
    };
};

// --- wait for despawn ---
private _t0 = time;
waitUntil {
    sleep 1;
    (isNil "_veh") || {isNull _veh} || {!alive _veh} ||
    {(_veh distance2D _despawnPos) < 300} ||
    {(time - _t0) > 1200}
};

// Delete aircraft + ALL associated crew (including any that got left behind).
private _toDeleteRaw = [];
_toDeleteRaw append _crewLive;
if (!isNull _veh) then { _toDeleteRaw append (crew _veh); };

private _toDelete = [];
{
    if (!isNull _x) then { _toDelete pushBackUnique _x; };
} forEach _toDeleteRaw;

{ if (!isNull _x) then { deleteVehicle _x; }; } forEach _toDelete;
if (!isNull _veh) then { deleteVehicle _veh; };

// Clear missionNamespace vars so a clean respawn can occur on return.
private _vehVar = [_asset, "vehVar", ""] call _hg;
if (_vehVar != "") then { missionNamespace setVariable [_vehVar, objNull, true]; };

private _crewVars = [_asset, "crewVars", []] call _hg;
{
    if (_x isEqualType "") then { missionNamespace setVariable [_x, objNull, true]; };
} forEach _crewVars;

// Turnaround timer (return arrival queued by tick once it expires)
private _turnMin = missionNamespace getVariable ["airbase_v1_turnaroundMin_s", 1200];
private _turnJit = missionNamespace getVariable ["airbase_v1_turnaroundJit_s", 1200];
private _returnAt = serverTime + _turnMin + (random _turnJit);

_asset set ["veh", objNull];
_asset set ["crew", []];
_asset set ["state", "COOLDOWN"]; 
_asset set ["activeFlight", _fid];
_asset set ["availableAt", _returnAt];

if (_debugOps) then {
    ["OPS", format ["AIRBASE: %1 departed (%2) - return ETA in ~%3s", _fid, _vehType, round (_returnAt - serverTime)], _despawnPos, 0, [
        ["assetId", ([_asset, "id", ""] call _hg)],
        ["vehType", _vehType],
        ["returnAt", _returnAt]
    ]] call ARC_fnc_intelLog;
};

true

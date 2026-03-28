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
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _debugOps = missionNamespace getVariable ["airbase_v1_debugOpsLog", false];

private _veh = [_asset, "veh", objNull] call _hg;
if (isNull _veh) exitWith {
    _asset set ["state", "PARKED"];
    _asset set ["activeFlight", ""];
    false
};

private _vehType = typeOf _veh;
private _isHeli  = (_veh isKindOf "Helicopter");

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

private _fnSeatScan = {
    params ["_vehL"];
    private _hasCommander = false;
    private _hasGunner = false;

    private _fc = fullCrew [_vehL, "", true];
    {
        private _role = _x param [1, ""]; // role string
        if (_role isEqualTo "commander") then { _hasCommander = true; };
        if (_role isEqualTo "gunner") then { _hasGunner = true; };
    } forEach _fc;

    [_hasCommander, _hasGunner]
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

// --- resolve crew ---
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
_scan params ["_hasCommander", "_hasGunner"]; 

// Assign seats
_pilot assignAsDriver _veh;
[_pilot] orderGetIn true;

if ((count _crewLive) > 1) then {
    private _u2 = _crewLive select 1;
    if (_isHeli && {_hasCommander}) then {
        _u2 assignAsCommander _veh;
    } else {
        if (_hasGunner) then { _u2 assignAsGunner _veh; } else { _u2 assignAsCargo _veh; };
    };
    [_u2] orderGetIn true;
};

for "_i" from 2 to ((count _crewLive) - 1) do {
    private _ux = _crewLive select _i;
    _ux assignAsCargo _veh;
    [_ux] orderGetIn true;
};

private _boardTimeout = missionNamespace getVariable ["airbase_v1_boardTimeout_s", 180];
if (!(_boardTimeout isEqualType 0) || { _boardTimeout < 30 }) then { _boardTimeout = 180; };

private _tBoard0 = time;
waitUntil {
    sleep 1;
    isNull _veh || {!alive _veh} || {!alive _pilot} ||
    ((driver _veh) isEqualTo _pilot && { ({ (vehicle _x) isEqualTo _veh || {!alive _x} } count _crewLive) == (count _crewLive) }) ||
    ((time - _tBoard0) > _boardTimeout)
};

private _boardOk = !(isNull _veh) && {alive _veh} && {alive _pilot} && {(driver _veh) isEqualTo _pilot} && { ({ (vehicle _x) isEqualTo _veh || {!alive _x} } count _crewLive) == (count _crewLive) };

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

_veh engineOn true;
if (_veh isKindOf "Air") then { _veh setCollisionLight true; _veh setPilotLight true; };

_pilot disableAI "PATH";
_pilot disableAI "MOVE";
_pilot disableAI "FSM";
_pilot setBehaviour "CARELESS";
_pilot setCombatMode "BLUE";

private _okTaxi = [_veh, _taxiFrames] call _fnUnitPlayBlocking;

_pilot enableAI "PATH";
_pilot enableAI "MOVE";
_pilot enableAI "FSM";

_veh enableSimulationGlobal true;
_veh engineOn true;
if (_veh isKindOf "Air") then { _veh setCollisionLight true; _veh setPilotLight true; };

// If a rotary-wing asset is still skimming the ground at taxi end, nudge it into a hover before outbound waypoints.
if (_isHeli) then
{
    private _a0 = (getPosATL _veh) select 2;
    if (_a0 < 1.5) then
    {
        _veh land "NONE";
        _veh flyInHeight 5;
        _veh setVelocityModelSpace [0, 6, 9];
    };
};

if (!_okTaxi) exitWith {
    if (_debug) then { diag_log format ["[AIRBASESUB] %1 taxi playback failed/aborted (%2)", _fid, _vehType]; };

    // If the taxi phase failed, abort to idle instead of deleting.
    [_crewLive, _veh] call _fnAbortToIdle;
    _asset set ["state", "PARKED"];
    _asset set ["activeFlight", ""];

    false
};

// --- special case: EC-130 loiter (do not despawn) ---
private _isEC130 = (_vehType find "aws_C130_AEW") >= 0;
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

// --- takeoff / fly-out ---
private _despawnMkr = missionNamespace getVariable ["airbase_v1_plane_despawn_marker", "plane_despawn"]; 
private _despawnPos = getMarkerPos _despawnMkr;

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

if (_isHeli) then {
    private _altLow = missionNamespace getVariable ["airbase_v1_rw_takeoff_alt_low_m", 3];
    if (!(_altLow isEqualType 0) || { _altLow < 0 }) then { _altLow = 3; };

    private _mkrOut = missionNamespace getVariable ["airbase_v1_rw_outbound_marker", "AEON_Right_270_Outbound"]; 
    if (!(_mkrOut isEqualType "") || { _mkrOut isEqualTo "" }) then { _mkrOut = "AEON_Right_270_Outbound"; };

    private _mkrClear = missionNamespace getVariable ["airbase_v1_rw_outbound_clear_marker", "AEON_Right_270_Outbound_Clear"]; 
    if (!(_mkrClear isEqualType "") || { _mkrClear isEqualTo "" }) then { _mkrClear = "AEON_Right_270_Outbound_Clear"; };

    private _outPos = getMarkerPos _mkrOut;
    private _clearPos = getMarkerPos _mkrClear;

    private _hasOut = !(_outPos isEqualTo [0,0,0]);
    private _hasClear = !(_clearPos isEqualTo [0,0,0]);

    if (_hasOut) then { _kickPos = _outPos; };

    _veh engineOn true;
    _veh land "NONE";
    _veh flyInHeight _altLow;

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

        private _climbTrig = missionNamespace getVariable ["airbase_v1_rw_climb_trigger_dist_m", 15];
        if (!(_climbTrig isEqualType 0) || { _climbTrig < 3 }) then { _climbTrig = 15; };

        // Near runway start marker: begin climb to departure altitude (default ~500ft).
        [_fid, _veh, _outPos, _cruiseAlt, _climbTrig, _debugOps] spawn {
            params ["_fidL", "_vehL", "_outPosL", "_altTargetL", "_trigL", "_dbgOpsL"];
            private _t0 = time;
            waitUntil {
                sleep 1;
                isNull _vehL || {!alive _vehL} ||
                ((_vehL distance2D _outPosL) < _trigL) ||
                ((time - _t0) > 180)
            };
            if (isNull _vehL || {!alive _vehL}) exitWith {};

            _vehL land "NONE";
            _vehL flyInHeight _altTargetL;

            // Nudge climb: AI sometimes skims the runway after a unitPlay taxi.
            _vehL setVelocityModelSpace [0, 25, 10];

            // If it's still low after a few seconds, nudge again.
            sleep 5;
            if (!isNull _vehL && {alive _vehL}) then {
                private _altNow = (getPosATL _vehL) select 2;
                if (_altNow < (10 max (_altTargetL * 0.25))) then {
                    _vehL land "NONE";
                    _vehL flyInHeight _altTargetL;
                    _vehL setVelocityModelSpace [0, 25, 12];

                    if (_dbgOpsL) then {
                        ["OPS", format ["AIRBASE: %1 climb nudge (alt=%2m target=%3m)", _fidL, round _altNow, _altTargetL], getPosATL _vehL, 0, []] call ARC_fnc_intelLog;
                    };
                };
            };
        };
    } else {
        // Missing outbound marker: start climbing immediately.
        _veh flyInHeight _cruiseAlt;
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

// Post-taxi takeoff watchdog: unitPlay can leave AI stuck at taxi end.
private _kickEnabled = missionNamespace getVariable ["airbase_v1_takeoffKickEnabled", true];
private _kickTimeout = missionNamespace getVariable ["airbase_v1_takeoffKickTimeout_s", 45];
if (!(_kickTimeout isEqualType 0) || { _kickTimeout < 10 }) then { _kickTimeout = 45; };

if (_kickEnabled) then {
    [_fid, _veh, _pilot, _grp, _kickPos, _isHeli, _kickTimeout, _debugOps] spawn {
        params ["_fidL", "_vehL", "_pilotL", "_grpL", "_kickPosL", "_isHeliL", "_timeoutS", "_debugOpsL"];
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
                _vehL flyInHeight 5;
                _vehL setVelocityModelSpace [0, 10, 10];
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
    isNull _veh || {!alive _veh} ||
    ((_veh distance2D _despawnPos) < 300) ||
    ((time - _t0) > 1200)
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

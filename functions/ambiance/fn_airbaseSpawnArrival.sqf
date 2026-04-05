/*
    File: functions/ambiance/fn_airbaseSpawnArrival.sqf
    Author: ARC / Ambient Airbase Subsystem
    Description:
      Spawns an inbound aircraft, lands it, taxis to the taxi-out point, and deletes it.
      If the arrival is a RETURN for a specific assetId, it then respawns that parked aircraft + crew.
*/

if (!isServer) exitWith { false };
if !(["airbaseSpawnArrival"] call ARC_fnc_airbaseRuntimeEnabled) exitWith {false};

params ["_fid"];

private _debugOps = missionNamespace getVariable ["airbase_v1_debugOpsLog", false];

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

// Pull record
private _recs = ["airbase_v1_records", []] call ARC_fnc_stateGet;
private _idx = -1;
{ if ((_x param [0,""]) isEqualTo _fid) exitWith { _idx = _forEachIndex; }; } forEach _recs;
private _rec = if (_idx >= 0) then { _recs select _idx } else { [] };

private _category = _rec param [3, "FW"];
private _detail   = _rec param [4, "INBOUND"]; // assetId for return, or "INBOUND"

private _rt = missionNamespace getVariable ["airbase_v1_rt", createHashMap];
private _assets = [_rt, "assets", []] call _hg;

private _asset = createHashMap;
private _isReturn = false;
private _vehType = "";

if (!(_detail isEqualTo "INBOUND")) then {
    private _aIdx = -1;
    { if (([_x, "id", ""] call _hg) isEqualTo _detail) exitWith { _aIdx = _forEachIndex; }; } forEach _assets;
    if (_aIdx >= 0) then {
        _asset = _assets select _aIdx;
        _isReturn = true;
        _vehType = [_asset, "startVehType", ""] call _hg;
        _category = [_asset, "category", _category] call _hg;
    };
};

if (_vehType isEqualTo "") then {
    // Default to a random type derived from known assets in the same category
    private _pool = [];
    {
        if (([_x, "category", "FW"] call _hg) isEqualTo _category) then {
            private _t = [_x, "startVehType", ""] call _hg;
            if (_t != "") then { _pool pushBackUnique _t; };
        };
    } forEach _assets;

    if ((count _pool) > 0) then {
        _vehType = selectRandom _pool;
    } else {
        _vehType = if (_category isEqualTo "RW") then { "B_Heli_Transport_01_F" } else { "B_T_VTOL_01_vehicle_F" };
    };
};

// Markers
private _mSpawn = [_rt, "arrivalSpawnMarker", "mkr_arrivalSpawn"] call _hg;
private _mRwyS  = [_rt, "arrivalRunwayStartMarker", "mkr_arrivalRunwayStart"] call _hg;
private _mRwyE  = [_rt, "arrivalRunwayStopMarker", "mkr_arrivalRunwayStop"] call _hg;
private _mTaxi  = [_rt, "arrivalRunwayTaxiOutMarker", "mkr_arrivalRunwayTaxiOut"] call _hg;

private _spawnPos = getMarkerPos _mSpawn;
private _rwyStart = getMarkerPos _mRwyS;
private _rwyStop  = getMarkerPos _mRwyE;
private _taxiOut  = getMarkerPos _mTaxi;
private _runwayDir = markerDir _mRwyS;

private _airportId = [_rt, "airportId", 0] call _hg;

private _altSpawn = if (_category isEqualTo "RW") then { 250 } else { 3048 }; // 10,000 ft for fixed-wing arrivals
private _rwFinalApproachAlt = missionNamespace getVariable ["airbase_v1_rw_arrival_final_approach_alt_m", 35];
if (!(_rwFinalApproachAlt isEqualType 0) || { _rwFinalApproachAlt < 10 }) then { _rwFinalApproachAlt = 35; };
private _rwFinalApproachDist = missionNamespace getVariable ["airbase_v1_rw_arrival_final_approach_dist_m", 600];
if (!(_rwFinalApproachDist isEqualType 0) || { _rwFinalApproachDist < 150 }) then { _rwFinalApproachDist = 600; };
private _rwFlareApproachAlt = missionNamespace getVariable ["airbase_v1_rw_arrival_flare_alt_m", 8];
if (!(_rwFlareApproachAlt isEqualType 0) || { _rwFlareApproachAlt < 3 }) then { _rwFlareApproachAlt = 8; };
private _rwFlareApproachDist = missionNamespace getVariable ["airbase_v1_rw_arrival_flare_dist_m", 180];
if (!(_rwFlareApproachDist isEqualType 0) || { _rwFlareApproachDist < 50 }) then { _rwFlareApproachDist = 180; };
private _rwApproachTickS = missionNamespace getVariable ["airbase_v1_rw_arrival_approach_tick_s", 2];
if (!(_rwApproachTickS isEqualType 0) || { _rwApproachTickS < 1 }) then { _rwApproachTickS = 2; };

// Spawn inbound vehicle
private _veh = createVehicle [_vehType, _spawnPos, [], 0, "FLY"];
if (isNull _veh) exitWith { false };

_veh setDir _runwayDir;
_veh setPosASL [(_spawnPos select 0), (_spawnPos select 1), _altSpawn];
_veh allowDamage false;
_veh engineOn true;
if (_veh isKindOf "Air") then { _veh setCollisionLight true; _veh setPilotLight true; };

// Crew (no moveIn*; spawn crew already inside the aircraft)
createVehicleCrew _veh;
private _pilot = driver _veh;
private _grp = group _pilot;

if (isNull _pilot) exitWith {
    if (!isNull _veh) then { deleteVehicle _veh; };
    false
};

_pilot setBehaviour "CARELESS";
_pilot setCombatMode "BLUE";

// Waypoints: approach -> runway stop -> taxi out
private _wp0 = _grp addWaypoint [_rwyStart, 0];
_wp0 setWaypointType "MOVE";
_wp0 setWaypointSpeed "FULL";
_wp0 setWaypointCompletionRadius 80;

if (_veh isKindOf "Helicopter") then {
    _wp0 setWaypointStatements ["true", "vehicle this land 'NONE';"];

    [_veh, _rwyStart, _rwFinalApproachDist, _rwFinalApproachAlt, _rwFlareApproachDist, _rwFlareApproachAlt, _rwApproachTickS] spawn {
        params ["_v", "_rwy", "_finalD", "_finalAlt", "_flareD", "_flareAlt", "_tickS"];
        private _t0 = time;
        while { !isNull _v && { alive _v } } do
        {
            private _d = _v distance2D _rwy;
            if (_d <= _flareD) then {
                _v flyInHeight _flareAlt;
            } else {
                if (_d <= _finalD) then {
                    _v flyInHeight _finalAlt;
                };
            };

            if (_d < (_flareD * 0.5)) exitWith {};
            if ((time - _t0) > 900) exitWith {};
            sleep _tickS;
        };
    };
} else {
    _wp0 setWaypointStatements ["true", format ["vehicle this landAt %1;", _airportId]];
};

// Direct descent controller: step the desired altitude down as the aircraft approaches the runway.
if (!(_veh isKindOf "Helicopter")) then
{
    private _k = missionNamespace getVariable ["airbase_v1_arrivalDescentCoef", 0.12];
    if (!(_k isEqualType 0) || { _k <= 0 }) then { _k = 0.12; };
    private _minAlt = missionNamespace getVariable ["airbase_v1_arrivalMinAlt_m", 80];
    if (!(_minAlt isEqualType 0) || { _minAlt < 30 }) then { _minAlt = 80; };

    [_veh, _rwyStart, _altSpawn, _k, _minAlt] spawn
    {
        params ["_v", "_rwy", "_maxAlt", "_coef", "_minA"];
        while { !isNull _v && { alive _v } } do
        {
            private _d = _v distance2D _rwy;
            // Linear approximation: desired AGL is proportional to remaining distance.
            private _alt = (_d * _coef) min _maxAlt;
            _alt = _alt max _minA;
            _v flyInHeight _alt;

            if (_d < 1200) exitWith {};
            sleep 4;
        };
    };
};

private _wp1 = _grp addWaypoint [_rwyStop, 0];
_wp1 setWaypointType "MOVE";
_wp1 setWaypointSpeed "LIMITED";
_wp1 setWaypointCompletionRadius (if (_veh isKindOf "Helicopter") then { 80 } else { 200 });

if (_veh isKindOf "Helicopter") then {
    _wp1 setWaypointStatements ["true", "vehicle this land 'LAND';"];
};

private _wp2 = _grp addWaypoint [_taxiOut, 0];
_wp2 setWaypointType "MOVE";
_wp2 setWaypointSpeed "LIMITED";
_wp2 setWaypointCompletionRadius 25;

// Wait for taxi-out / timeout
private _t0 = time;
waitUntil {
    sleep 1;
    isNull _veh ||
    !alive _veh ||
    ((_veh distance2D _taxiOut) < 40) ||
    ((time - _t0) > 1800)
};

// Cleanup inbound
if (!isNull _veh) then {
    { if (!isNull _x) then { deleteVehicle _x; }; } forEach (crew _veh);
    deleteVehicle _veh;
};
if (!isNull _pilot) then { deleteVehicle _pilot; };
if (!isNull _grp) then { deleteGroup _grp; };

if (_debugOps) then {
    ["OPS", format ["AIRBASE: arrival %1 complete (%2)", _fid, _vehType], _taxiOut, 0, [
        ["mode", if (_isReturn) then {"RETURN"} else {"RANDOM"}],
        ["category", _category],
        ["vehType", _vehType],
        ["assetId", if (_isReturn) then {_detail} else {"INBOUND"}]
    ]] call ARC_fnc_intelLog;
};

// If this was a return, respawn the parked aircraft + crew back on the flightline
if (_isReturn) then {
    private _okRestore = [_asset] call ARC_fnc_airbaseRestoreParkedAsset;

    if (_debugOps && {!_okRestore}) then {
        ["OPS", format ["AIRBASE: restore parked asset FAILED (%1)", ([_asset, "id", ""] call _hg)], _taxiOut, 0, []] call ARC_fnc_intelLog;
    };

    missionNamespace setVariable ["airbase_v1_rt", _rt, true];
};


true

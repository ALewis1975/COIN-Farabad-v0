/*
    ARC_fnc_vbiedSpawnTick

    Phase 3 (VBIED v1): parked VBIED execution scaffolding.

    Server-authoritative.
    - Only applies when active incident type is IED and objectiveKind is VBIED_VEHICLE.
    - Creates a proximity trigger around the parked vehicle.
    - Creates a compact device record stored in state + debug published array.

    Device record format:
      [id, kind, vehNetId, createdAt, posATL, triggerType, triggerRadiusM, state, metaPairs]
*/

if (!isServer) exitWith {false};

private _enabled = missionNamespace getVariable ["ARC_vbiedPhase3_enabled", true];
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {false};

private _incTypeU = toUpper (["activeIncidentType", ""] call ARC_fnc_stateGet);
if (_incTypeU isNotEqualTo "IED") exitWith {false};

private _objKind = ["activeObjectiveKind", ""] call ARC_fnc_stateGet;
if (!(_objKind isEqualType "")) then { _objKind = ""; };
if ((toUpper _objKind) isNotEqualTo "VBIED_VEHICLE") exitWith {false};

// ── Escalation-tier gate (VBIED requires tier ≥ 2 / HIGH_RISK) ────────────
// Mirrors fn_threatGovernorCheck line 88: VBIED _tierMin = 2.
// Prevents execution-layer bypass if an incident reaches this path without
// passing through the scheduler (e.g. direct mission event or debug spawn).
private _districtId = ["activeIncidentCivsubDistrictId", ""] call ARC_fnc_stateGet;
if (!(_districtId isEqualType "")) then { _districtId = ""; };
if (!(_districtId isEqualTo "")) then
{
    private _secLevel = missionNamespace getVariable [format ["ARC_district_%1_secLevel", _districtId], "NORMAL"];
    if (!(_secLevel isEqualType "")) then { _secLevel = "NORMAL"; };
    private _tier = 0;
    if (_secLevel isEqualTo "ELEVATED") then { _tier = 1; };
    if (_secLevel isEqualTo "HIGH_RISK") then { _tier = 2; };
    if (_tier < 2) exitWith
    {
        diag_log format ["[ARC][THREAT] ARC_fnc_vbiedSpawnTick: ESCALATION_TIER deny district=%1 tier=%2 required=2", _districtId, _tier];
        false
    };
};

private _vehNid = ["activeObjectiveNetId", ""] call ARC_fnc_stateGet;
if (!(_vehNid isEqualType "")) then { _vehNid = ""; };
if (_vehNid isEqualTo "") exitWith {false};

private _veh = objectFromNetId _vehNid;
if (isNull _veh) exitWith {false};

// Ensure we capture non-detonation destruction outcomes (ex: destroyed by fire, demolition, physics).
private _ehAdded = _veh getVariable ["ARC_vbiedKilledEHAdded", false];
if (!(_ehAdded isEqualType true) && !(_ehAdded isEqualType false)) then { _ehAdded = false; };
if (!_ehAdded) then
{
    _veh setVariable ["ARC_vbiedKilledEHAdded", true, true];
    _veh addEventHandler ["Killed", {
        params ["_v", "_killer", "_instigator"];
        private _nid = netId _v;
        [_nid, _killer, _instigator] call ARC_fnc_vbiedServerOnDestroyed;
    }];
};

// ---------------------------------------------------------------------------
// Phase 3.1 (VBIED Defuse Window): server-tick monitor
// - Two-stage model: detect -> window -> detonate
// - Allows qualified EOD to approach and defuse without instant detonation
// - Does NOT create a trigger object (avoids string/trigger regressions)
// ---------------------------------------------------------------------------

// Cooldown governor (rare threat)
private _cool = missionNamespace getVariable ["ARC_vbiedCooldownSeconds", 1800];
if (!(_cool isEqualType 0) || { _cool < 0 }) then { _cool = 1800; };
_cool = (_cool max 60) min 21600;

private _last = ["activeVbiedLastArmedAt", -1] call ARC_fnc_stateGet;
if (!(_last isEqualType 0)) then { _last = -1; };
if (_last >= 0 && { (serverTime - _last) < _cool }) exitWith {false};

// State guards
private _safe = ["activeVbiedSafe", false] call ARC_fnc_stateGet;
if (!(_safe isEqualType true) && !(_safe isEqualType false)) then { _safe = false; };
if (_safe) exitWith {true};

private _det = ["activeVbiedDetonated", false] call ARC_fnc_stateGet;
if (!(_det isEqualType true) && !(_det isEqualType false)) then { _det = false; };
if (_det) exitWith {true};

// Tuning knobs (missionNamespace overrides)
private _outerR = missionNamespace getVariable ["ARC_vbiedOuterRadiusM", 20];
if (!(_outerR isEqualType 0) || { _outerR <= 0 }) then { _outerR = 20; };
_outerR = (_outerR max 10) min 60;

private _rushKmh = missionNamespace getVariable ["ARC_vbiedRushSpeedKmh", 8];
if (!(_rushKmh isEqualType 0) || { _rushKmh <= 0 }) then { _rushKmh = 8; };
_rushKmh = (_rushKmh max 4) min 25;

private _win = missionNamespace getVariable ["ARC_vbiedDefuseWindowSeconds", 60];
if (!(_win isEqualType 0) || { _win <= 0 }) then { _win = 60; };
_win = (_win max 20) min 900;

private _workD = missionNamespace getVariable ["ARC_vbiedDefuseWorkDistanceM", 4];
if (!(_workD isEqualType 0) || { _workD <= 0 }) then { _workD = 4; };
_workD = (_workD max 2) min 8;

private _enableDef = missionNamespace getVariable ["ARC_vbiedDefuseActionEnabled", true];
if (!(_enableDef isEqualType true) && !(_enableDef isEqualType false)) then { _enableDef = true; };

// Positions
private _pos = getPosATL _veh; _pos = +_pos; _pos resize 3;
_pos set [2, 0];

// Ensure device id
private _id = ["activeVbiedDeviceId", ""] call ARC_fnc_stateGet;
if (!(_id isEqualType "")) then { _id = ""; };
if (_id isEqualTo "") then
{
    private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
    if (!(_taskId isEqualType "")) then { _taskId = ""; };
    _id = format ["VBIED_%1_%2", _taskId, floor (serverTime * 10)];
    ["activeVbiedDeviceId", _id] call ARC_fnc_stateSet;
};

// Expose basics for debug/UX
["activeVbiedVehicleNetId", _vehNid] call ARC_fnc_stateSet;
["activeVbiedTriggerEnabled", true] call ARC_fnc_stateSet;
["activeVbiedTriggerRadiusM", _outerR] call ARC_fnc_stateSet;
["activeVbiedLastArmedAt", serverTime] call ARC_fnc_stateSet;

// Publish a compact device record once (debug/history)
private _rec0 = ["activeVbiedDeviceRecord", []] call ARC_fnc_stateGet;
if !(_rec0 isEqualType [] && { (count _rec0) >= 5 }) then
{
    private _meta = [["event","VBIED_ARMED"],["trigger","WINDOW"],["radius",_outerR],["windowSec",_win]];
    private _rec = [_id, "VBIED_VEHICLE", _vehNid, serverTime, _pos, "WINDOW", _outerR, "ARMED", _meta];
    ["activeVbiedDeviceRecord", _rec] call ARC_fnc_stateSet;

    private _cap = missionNamespace getVariable ["ARC_vbiedPhase3_recordsCap", 12];
    if (!(_cap isEqualType 0) || { _cap <= 0 }) then { _cap = 12; };
    _cap = (_cap max 6) min 40;
    private _arr = missionNamespace getVariable ["ARC_vbiedPhase3_deviceRecords", []];
    if (!(_arr isEqualType [])) then { _arr = []; };
    _arr pushBack _rec;
    if ((count _arr) > _cap) then { _arr = _arr select [((count _arr) - _cap) max 0]; };
    missionNamespace setVariable ["ARC_vbiedPhase3_deviceRecords", _arr, true];
};

// If client-side defuse action sets this flag, mark safe (server authoritative enough for PvE)
private _defused = _veh getVariable ["ARC_vbiedDefused", false];
if (!(_defused isEqualType true) && !(_defused isEqualType false)) then { _defused = false; };
if (_defused) exitWith
{
    ["activeVbiedSafe", true] call ARC_fnc_stateSet;
    missionNamespace setVariable ["ARC_activeVbiedSafe", true, true];
    ["activeVbiedTriggerEnabled", false] call ARC_fnc_stateSet;
    private _grid = mapGridPosition _pos;
    ["TECHINT", format ["VBIED rendered safe at %1.", _grid], _pos, [["event","VBIED_SAFE"],["deviceId",_id],["grid",_grid]]] call ARC_fnc_intelLog;
    true
};

// Add hold-action once (client-local). We gate by proximity + toolkit/defusal kit.
if (_enableDef) then
{
    private _added = _veh getVariable ["ARC_vbiedHoldAdded", false];
    if (!(_added isEqualType true) && !(_added isEqualType false)) then { _added = false; };
    if (!_added) then
    {
        _veh setVariable ["ARC_vbiedHoldAdded", true, true];

        // Parameters for BIS_fnc_holdActionAdd (executed locally on each client)
        private _params = [
            _veh,
            "Disable firing circuit",
            "",
            "",
            // show condition
            format ["(_this distance2D _target) <= %1 && {!( _target getVariable ['ARC_vbiedDefused',false])} && {('ToolKit' in items _this) || ('ACE_DefusalKit' in items _this)}", _workD],
            // progress condition
            format ["(_this distance2D _target) <= %1 && {!( _target getVariable ['ARC_vbiedDefused',false])}", _workD],
            {},
            {},
            // completion: mark defused (broadcast) and mark the objective complete (server-authoritative close-ready)
            {
                params ["_target", "_caller", "_actionId", "_arguments"];
                _target setVariable ["ARC_vbiedDefused", true, true];
                ["VBIED_VEHICLE", _target, _caller, "Suspicious vehicle rendered safe.", "", "COMPLETE"] remoteExec ["ARC_fnc_execObjectiveComplete", 2];
            },
            {},
            [],
            12,
            0,
            false,
            false
        ];

        _params remoteExec ["BIS_fnc_holdActionAdd", 0, _veh];
    };
};

// Detection: nearest WEST man within outer radius
private _nearMen = nearestObjects [_pos, ["Man"], _outerR];
private _cand = objNull;
private _bestD = 1e9;
{
    if (isPlayer _x) then { };
    private _sd = side (group _x);
    if (_sd isEqualTo west) then
    {
        private _d = _pos distance2D _x;
        if (_d < _bestD) then { _bestD = _d; _cand = _x; };
    };
} forEach _nearMen;

if (isNull _cand) exitWith {true};

// Rush gate (km/h)
private _kmh = (speed _cand) max 0;
if (_kmh >= _rushKmh) exitWith
{
    ["activeVbiedDetCause", "RUSH"] call ARC_fnc_stateSet;
    [_id] call ARC_fnc_vbiedServerDetonate;
    true
};

// Alert/window state
private _alert = ["activeVbiedAlerted", false] call ARC_fnc_stateGet;
if (!(_alert isEqualType true) && !(_alert isEqualType false)) then { _alert = false; };
private _t0 = ["activeVbiedAlertAt", -1] call ARC_fnc_stateGet;
if (!(_t0 isEqualType 0)) then { _t0 = -1; };

if (!_alert) then
{
    ["activeVbiedAlerted", true] call ARC_fnc_stateSet;
    ["activeVbiedAlertAt", serverTime] call ARC_fnc_stateSet;
    ["activeVbiedPauseAccum", 0] call ARC_fnc_stateSet;
    ["activeVbiedPauseSince", -1] call ARC_fnc_stateSet;
    _t0 = serverTime;
};

// Pause window when a qualified EOD is within 10m and moving slowly (prevents unfair "timer punished me for doing EOD")
private _pauseAccum = ["activeVbiedPauseAccum", 0] call ARC_fnc_stateGet;
if (!(_pauseAccum isEqualType 0) || { _pauseAccum < 0 }) then { _pauseAccum = 0; };
private _pauseSince = ["activeVbiedPauseSince", -1] call ARC_fnc_stateGet;
if (!(_pauseSince isEqualType 0)) then { _pauseSince = -1; };

private _qual = (('ToolKit' in items _cand) || ('ACE_DefusalKit' in items _cand));
private _slow = ((speed _cand) max 0) <= 4;
private _inInspect = (_bestD <= 10);
private _shouldPause = _qual && _slow && _inInspect;

if (_shouldPause) then
{
    if (_pauseSince < 0) then { ["activeVbiedPauseSince", serverTime] call ARC_fnc_stateSet; _pauseSince = serverTime; };
}
else
{
    if (_pauseSince >= 0) then
    {
        _pauseAccum = _pauseAccum + (serverTime - _pauseSince);
        ["activeVbiedPauseAccum", _pauseAccum] call ARC_fnc_stateSet;
        ["activeVbiedPauseSince", -1] call ARC_fnc_stateSet;
        _pauseSince = -1;
    };
};

private _elapsed = (serverTime - _t0) - _pauseAccum;
if (_pauseSince >= 0) then { _elapsed = (serverTime - _t0) - (_pauseAccum + (serverTime - _pauseSince)); };

private _remain = _win - _elapsed;
["activeVbiedWindowRemaining", _remain] call ARC_fnc_stateSet;

if (_remain <= 0) exitWith
{
    ["activeVbiedDetCause", "TIMER"] call ARC_fnc_stateSet;
    [_id] call ARC_fnc_vbiedServerDetonate;
    true
};

// Phase 5: disposal logistics check (evidence delivery)
[] call ARC_fnc_iedServerCheckDisposal;

true


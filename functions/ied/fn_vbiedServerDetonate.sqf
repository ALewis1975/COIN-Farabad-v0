/*
    ARC_fnc_vbiedServerDetonate

    Phase 3 (VBIED v1): trigger-fired detonation handler.

    Params:
      0: STRING - deviceId (from trigger)

    Behavior:
      - Idempotent via state guard
      - Deletes trigger
      - Creates a best-effort explosion
      - Delegates to ARC_fnc_iedHandleDetonation with objKind VBIED_VEHICLE
*/

if (!isServer) exitWith {false};

params [
    ["_deviceId", "", [""]]
];

// _deviceId is a server-controlled token (set by spawn ticks); explicit type guard is sufficient.
if (!(_deviceId isEqualType "")) then { _deviceId = ""; };
if (_deviceId isEqualTo "") exitWith {false};

// Dedicated MP hardening: log remote invocation source.
if (!isNil "remoteExecutedOwner") then
{
    private _reo = remoteExecutedOwner;
    if (_reo > 0) then
    {
        diag_log format ["[ARC][SEC] ARC_fnc_vbiedServerDetonate: invoked via remoteExec from owner=%1 deviceId=%2", _reo, _deviceId];

        // S1 + S3: client-driven detonate must correspond to a TOC-approved EOD disposition
        // for the active task. Server-internal callers (proximity tick, driven-spawn tick)
        // have no remoteExecutedOwner and bypass this gate.
        private _activeTaskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
        if (!(_activeTaskId isEqualType "")) then { _activeTaskId = ""; };
        private _appr = missionNamespace getVariable ["ARC_pub_eodDispoApprovals", []];
        if (!(_appr isEqualType [])) then { _appr = []; };
        private _approved = false;
        {
            if (!(_x isEqualType []) || { (count _x) < 3 }) then { continue; };
            private _aTask = _x select 0;
            private _aReq  = _x select 2;
            if (!(_aTask isEqualType "") || { !(_aReq isEqualType "") }) then { continue; };
            if (!(_aTask isEqualTo _activeTaskId)) then { continue; };
            if (!((toUpper _aReq) isEqualTo "DET_IN_PLACE")) then { continue; };
            _approved = true;
        } forEach _appr;
        if (!_approved) exitWith
        {
            diag_log format ["[ARC][SEC] ARC_fnc_vbiedServerDetonate: VBIED_DETONATE_DENIED no TOC EOD approval for active task. owner=%1 taskId=%2 deviceId=%3",
                _reo, _activeTaskId, _deviceId];
            false
        };
    };
};

private _done = ["activeVbiedDetonated", false] call ARC_fnc_stateGet;
if (!(_done isEqualType true) && !(_done isEqualType false)) then { _done = false; };
if (_done) exitWith {true};

// If rendered safe, never detonate
private _safe = ["activeVbiedSafe", false] call ARC_fnc_stateGet;
if (!(_safe isEqualType true) && !(_safe isEqualType false)) then { _safe = false; };
if (_safe) exitWith {true};


// Resolve detonation pos — prefer the live VBIED vehicle position (driven VBIEDs
// move; the stored objective pos can be stale by up to the trigger radius).
private _pos = [];
private _vehNidCands = [_deviceId];
private _parkedNid = ["activeVbiedVehicleNetId", ""] call ARC_fnc_stateGet;
if (_parkedNid isEqualType "" && { !(_parkedNid isEqualTo "") }) then { _vehNidCands pushBack _parkedNid; };
private _drivenNid = missionNamespace getVariable ["ARC_vbiedDrivenNetId", ""];
if (_drivenNid isEqualType "" && { !(_drivenNid isEqualTo "") }) then { _vehNidCands pushBack _drivenNid; };
{
    if (_x isEqualType "" && { !(_x isEqualTo "") }) then
    {
        private _vehCand = objectFromNetId _x;
        if (!isNull _vehCand && { (_pos isEqualTo []) }) then { _pos = getPosATL _vehCand; };
    };
} forEach _vehNidCands;

// Fallback: stored objective pos, then device record
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then
{
    _pos = ["activeObjectivePos", []] call ARC_fnc_stateGet;
};
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then
{
    private _rec = ["activeVbiedDeviceRecord", []] call ARC_fnc_stateGet;
    if (_rec isEqualType [] && { (count _rec) >= 5 }) then { _pos = _rec select 4; };
};
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = [0,0,0]; };
_pos = +_pos; _pos resize 3;
if (!((_pos select 2) isEqualType 0)) then { _pos set [2, 0]; };

// Remove trigger
private _trgNid = ["activeVbiedTriggerNetId", ""] call ARC_fnc_stateGet;
if (_trgNid isEqualType "" && { !(_trgNid isEqualTo "") }) then
{
    private _trg = objectFromNetId _trgNid;
    if (!isNull _trg) then { deleteVehicle _trg; };
};

["activeVbiedDetonated", true] call ARC_fnc_stateSet;
["activeVbiedTriggerEnabled", false] call ARC_fnc_stateSet;
["activeVbiedDetonatedAt", serverTime] call ARC_fnc_stateSet;

// Best-effort explosion. (Gameplay abstraction; no construction details.)
private _cls = missionNamespace getVariable ["ARC_vbiedExplosionClass", "Bo_Mk82"]; // vanilla bomb explosion proxy
if (!(_cls isEqualType "") || { _cls isEqualTo "" }) then { _cls = "Bo_Mk82"; };
if !(isClass (configFile >> "CfgVehicles" >> _cls)) then { _cls = "Bo_Mk82"; };

private _boom = createVehicle [_cls, _pos, [], 0, "NONE"];
_boom setPosATL _pos;

// Delegate to existing detonation pipeline. _c is server-controlled (set by stateSet
// in spawn ticks); upper-case normalize without trim (compat-clean).
private _c = ["activeVbiedDetCause", "PROX_TRIGGER"] call ARC_fnc_stateGet;
if (!(_c isEqualType "")) then { _c = "PROX_TRIGGER"; };
_c = toUpper _c;
if (_c isEqualTo "") then { _c = "PROX_TRIGGER"; };
[_pos, "VBIED_VEHICLE", format ["VBIED_%1", _c]] call ARC_fnc_iedHandleDetonation;

true

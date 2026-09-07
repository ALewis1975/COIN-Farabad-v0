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

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
private _threatId = ["activeIedThreatId", ""] call ARC_fnc_stateGet;
private _currentId = ["activeVbiedDeviceId", ""] call ARC_fnc_stateGet;
private _parkedNid = ["activeVbiedVehicleNetId", ""] call ARC_fnc_stateGet;
private _drivenNid = missionNamespace getVariable ["ARC_vbiedDrivenNetId", ""];
private _isDriven = !(_drivenNid isEqualTo "") && { _deviceId isEqualTo _drivenNid };
private _vehicleNid = if (_isDriven) then { _drivenNid } else { _parkedNid };
private _vehicle = objectFromNetId _vehicleNid;
private _validDevice = !(_taskId isEqualTo "") && { !isNull _vehicle } &&
    { _isDriven || { !(_currentId isEqualTo "") && { _deviceId isEqualTo _currentId } } } &&
    { (_vehicle getVariable ["ARC_threatTaskId", ""]) isEqualTo _taskId } &&
    { (_vehicle getVariable ["ARC_threatId", ""]) isEqualTo _threatId };
if (!_validDevice) exitWith
{
    diag_log format ["[ARC][SEC] VBIED_DETONATE_DENIED stale device/task id=%1 task=%2 owner=%3 ts=%4", _deviceId, _taskId, remoteExecutedOwner, serverTime];
    false
};
// Server-local triggers retain their authority. Remote clients must own a
// real accepting-group player and the current, unexpired server approval.
private _reoOwner = remoteExecutedOwner;
private _remoteClient = isRemoteExecuted && { _reoOwner != 2 };
private _detonationAuthorized = if (_remoteClient) then
{
    private _caller = objNull;
    { if (isPlayer _x && { (owner _x) isEqualTo _reoOwner }) exitWith { _caller = _x; }; } forEach allPlayers;
    if (!([_caller, "ARC_fnc_vbiedServerDetonate", "Detonation rejected: sender mismatch.", "VBIED_DETONATE_DENIED", true, _reoOwner] call ARC_fnc_rpcValidateSender)) exitWith { false };
    private _groupId = groupId (group _caller);
    private _acceptedGroup = ["activeIncidentAcceptedByGroup", ""] call ARC_fnc_stateGet;
    if (_groupId isEqualTo "" || { !(_groupId isEqualTo _acceptedGroup) }) exitWith { false };
    private _appr = ["eodDispoApprovals", []] call ARC_fnc_stateGet;
    if (!(_appr isEqualType [])) exitWith { false };
    private _approved = false;
    {
        if (!(_x isEqualType []) || { (count _x) < 6 }) then { continue; };
        _x params ["_aTask", "_aGroup", "_aReq", "", "", "_expires"];
        if (!(_aReq isEqualType "") || { !(_expires isEqualType 0) }) then { continue; };
        if (_aTask isEqualTo _taskId && { _aGroup isEqualTo _groupId } && { (toUpper _aReq) isEqualTo "DET_IN_PLACE" } && { _expires >= serverTime }) exitWith { _approved = true; };
    } forEach _appr;
    _approved
} else { true };
if (!_detonationAuthorized) exitWith
{
    diag_log format ["[ARC][SEC] ARC_fnc_vbiedServerDetonate: VBIED_DETONATE_DENIED owner=%1 taskId=%2 deviceId=%3 ts=%4", _reoOwner, _taskId, _deviceId, serverTime];
    ["ARC_fnc_vbiedServerDetonate", "VBIED_DETONATE_DENIED", _reoOwner] call ARC_fnc_securityDenyRecord;
    false
};

private _done = ["activeVbiedDetonated", false] call ARC_fnc_stateGet;
if (!(_done isEqualType true) && !(_done isEqualType false)) then { _done = false; };
if (_done) exitWith {true};

// If rendered safe, never detonate
private _safe = ["activeVbiedSafe", false] call ARC_fnc_stateGet;
if (!(_safe isEqualType true) && !(_safe isEqualType false)) then { _safe = false; };
if (_safe) exitWith {true};


// Position comes only from the validated live vehicle, never an arbitrary input ID.
private _pos = getPosATL _vehicle;
_pos = +_pos; _pos resize 3;
if (isNil { _pos select 2 } || { !((_pos select 2) isEqualType 0) }) then { _pos set [2, 0]; };

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

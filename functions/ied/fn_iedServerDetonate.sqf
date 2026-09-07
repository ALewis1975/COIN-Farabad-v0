/*
    ARC_fnc_iedServerDetonate

    Server-only: detonates the active IED device, then hands off to the existing detonation handler
    (ARC_fnc_iedHandleDetonation) which drives the command cycle and closeout availability.

    Params:
      0: STRING - deviceId

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_deviceId", "", [""]]
];

// _deviceId is a server-controlled token (set by spawn ticks); explicit type guard is sufficient.
if (!(_deviceId isEqualType "")) then { _deviceId = ""; };
if (_deviceId isEqualTo "") exitWith {false};

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
private _currentId = ["activeIedDeviceId", ""] call ARC_fnc_stateGet;
private _currentKind = ["activeObjectiveKind", ""] call ARC_fnc_stateGet;
if (_taskId isEqualTo "" || { !(_deviceId isEqualTo _currentId) } || { !(_currentKind isEqualTo "IED_DEVICE") }) exitWith
{
    diag_log format ["[ARC][SEC] IED_DETONATE_DENIED stale device/task id=%1 task=%2 owner=%3 ts=%4", _deviceId, _taskId, remoteExecutedOwner, serverTime];
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
    if (!([_caller, "ARC_fnc_iedServerDetonate", "Detonation rejected: sender mismatch.", "IED_DETONATE_DENIED", true, _reoOwner] call ARC_fnc_rpcValidateSender)) exitWith { false };
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
    diag_log format ["[ARC][SEC] ARC_fnc_iedServerDetonate: IED_DETONATE_DENIED owner=%1 taskId=%2 deviceId=%3 ts=%4", _reoOwner, _taskId, _deviceId, serverTime];
    ["ARC_fnc_iedServerDetonate", "IED_DETONATE_DENIED", _reoOwner] call ARC_fnc_securityDenyRecord;
    false
};

// Guard: only detonate once per incident.
private _handled = ["activeIedDetonationHandled", false] call ARC_fnc_stateGet;
if (_handled isEqualType true && { _handled }) exitWith {false};

private _nid = ["activeObjectiveNetId", ""] call ARC_fnc_stateGet;
if (!(_nid isEqualType "")) then { _nid = ""; };

private _obj = objNull;
if (_nid isEqualType "" && { !(_nid isEqualTo "") }) then { _obj = objectFromNetId _nid; };
if (isNull _obj || { !((_obj getVariable ["ARC_ied_deviceId", ""]) isEqualTo _deviceId) }) exitWith { false };

private _pos = if (!isNull _obj) then { getPosATL _obj } else { ["activeObjectivePos", []] call ARC_fnc_stateGet };
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = ["activeExecPos", []] call ARC_fnc_stateGet; };
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = [0,0,0]; };
_pos = +_pos; _pos resize 3; _pos set [2, 0];

// Explosion effect (best-effort, class-safe)
private _boom = "Bo_Mk82";
if !(isClass (configFile >> "CfgVehicles" >> _boom)) then { _boom = "Bo_GBU12_LGB"; };
if !(isClass (configFile >> "CfgVehicles" >> _boom)) then { _boom = "Bo_Mk82"; };

createVehicle [_boom, _pos, [], 0, "CAN_COLLIDE"];

// Remove trigger immediately (prevents double fire)
private _trg = missionNamespace getVariable ["ARC_activeIedTrigger", objNull];
if (!isNull _trg) then { deleteVehicle _trg; };
missionNamespace setVariable ["ARC_activeIedTrigger", objNull];
missionNamespace setVariable ["ARC_activeIedTriggerDeviceId", ""];
["activeIedTriggerEnabled", false] call ARC_fnc_stateSet;

// Best-effort remove the IED prop (objective can also be destroyed by the blast)
if (!isNull _obj) then
{
    // Chain devices: start the staggered secondary detonation sequence before the
    // primary prop is removed (idempotent; the Killed EH path shares the guard).
    private _chainNids = _obj getVariable ["ARC_chainDeviceNetIds", []];
    if (!(_chainNids isEqualType [])) then { _chainNids = []; };
    if ((count _chainNids) > 0) then
    {
        [_nid, _chainNids] call ARC_fnc_iedChainDetonate;
    };

    // If the class doesn't accept damage well, deleting is still correct for Phase 1.
    deleteVehicle _obj;
};

// Complex attack: activate the staged ambush group (if any) against the blast site.
private _cxThreatId = ["activeIedThreatId", ""] call ARC_fnc_stateGet;
if (!(_cxThreatId isEqualType "")) then { _cxThreatId = ""; };
if (!(_cxThreatId isEqualTo "")) then
{
    private _cxGrp = missionNamespace getVariable [format ["ARC_complexAtkGroup_%1", _cxThreatId], grpNull];
    if (!(_cxGrp isEqualType grpNull)) then { _cxGrp = grpNull; };
    if (!isNull _cxGrp && { (count (units _cxGrp)) > 0 }) then
    {
        _cxGrp setBehaviour "COMBAT";
        _cxGrp setCombatMode "RED";
        private _cxWp = _cxGrp addWaypoint [_pos, 0];
        _cxWp setWaypointType "SAD";
        _cxWp setWaypointBehaviour "COMBAT";
        _cxWp setWaypointCombatMode "RED";
        _cxGrp setCurrentWaypoint _cxWp;
        diag_log format ["[ARC][INFO] ARC_fnc_iedServerDetonate: complex attack activated threat=%1 units=%2", _cxThreatId, count (units _cxGrp)];
    };
};

// Drive the mission spine (close-ready + follow-on lead)
[_pos, "IED_DEVICE", "PROX_TRIGGER"] call ARC_fnc_iedHandleDetonation;

true

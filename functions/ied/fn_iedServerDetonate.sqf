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

// Dedicated MP hardening: log remote invocation source.
if (!isNil "remoteExecutedOwner") then
{
    private _reo = remoteExecutedOwner;
    if (_reo > 0) then
    {
        diag_log format ["[ARC][SEC] ARC_fnc_iedServerDetonate: invoked via remoteExec from owner=%1 deviceId=%2", _reo, _deviceId];

        // S1 + S3: client-driven detonate must correspond to a TOC-approved EOD disposition
        // for the active task. Server-internal callers (proximity trigger, ticks) have no
        // remoteExecutedOwner and bypass this gate.
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
            diag_log format ["[ARC][SEC] ARC_fnc_iedServerDetonate: IED_DETONATE_DENIED no TOC EOD approval for active task. owner=%1 taskId=%2 deviceId=%3",
                _reo, _activeTaskId, _deviceId];
            false
        };
    };
};

// Guard: only detonate once per incident.
private _handled = ["activeIedDetonationHandled", false] call ARC_fnc_stateGet;
if (_handled isEqualType true && { _handled }) exitWith {false};

private _nid = ["activeObjectiveNetId", ""] call ARC_fnc_stateGet;
if (!(_nid isEqualType "")) then { _nid = ""; };

private _obj = objNull;
if (_nid isEqualType "" && { !(_nid isEqualTo "") }) then { _obj = objectFromNetId _nid; };

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
    // If the class doesn't accept damage well, deleting is still correct for Phase 1.
    deleteVehicle _obj;
};

// Drive the mission spine (close-ready + follow-on lead)
[_pos, "IED_DEVICE", "PROX_TRIGGER"] call ARC_fnc_iedHandleDetonation;

true

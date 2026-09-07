/*
    ARC_fnc_suicideBomberOnDetonate

    Server-only RPC: detonate a suicide bomber unit.

    Sender validation: checks remoteExecutedOwner.
    Applies explosion effects, transitions threat to DETONATED, emits leads.

    Params:
      0: STRING threatId
      1: STRING bomberNetId

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_threatId", "", [""]],
    ["_bomberNetId", "", [""]]
];

// Only server-local monitors (or server-origin remote calls) may invoke this.
if (isRemoteExecuted && { remoteExecutedOwner != 2 }) exitWith
{
    diag_log format ["[ARC][SEC] SB_DETONATE_DENIED owner=%1 threat=%2 object=%3 ts=%4", remoteExecutedOwner, _threatId, _bomberNetId, serverTime];
    ["ARC_fnc_suicideBomberOnDetonate", "SB_DETONATE_DENIED", remoteExecutedOwner] call ARC_fnc_securityDenyRecord;
    false
};
private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
private _activeThreat = ["activeIedThreatId", ""] call ARC_fnc_stateGet;
private _activeBomber = missionNamespace getVariable ["ARC_suicideBomberNetId", ""];
private _bomber = objectFromNetId _bomberNetId;
if (_taskId isEqualTo "" || { _threatId isEqualTo "" } || { !(_threatId isEqualTo _activeThreat) } ||
    { _bomberNetId isEqualTo "" } || { !(_bomberNetId isEqualTo _activeBomber) } || { isNull _bomber } ||
    { !(_bomber getVariable ["ARC_isSuicideBomber", false]) } ||
    { !((_bomber getVariable ["ARC_threatTaskId", ""]) isEqualTo _taskId) } ||
    { !((_bomber getVariable ["ARC_threatId", ""]) isEqualTo _threatId) }) exitWith
{
    diag_log format ["[ARC][SEC] SB_DETONATE_DENIED stale association task=%1 threat=%2 object=%3 ts=%4", _taskId, _threatId, _bomberNetId, serverTime];
    false
};

// Deduplicate (guard against double-fire)
if (missionNamespace getVariable ["ARC_suicideBomberDetonated", false]) exitWith {false};
missionNamespace setVariable ["ARC_suicideBomberDetonated", true];

private _pos = if (!isNull _bomber) then { getPosATL _bomber } else { ["activeExecPos", []] call ARC_fnc_stateGet };
if (!(_pos isEqualType []) || {(count _pos) < 2}) then { _pos = [0,0,0]; };
_pos = +_pos; _pos resize 3; _pos set [2, 0];

// Explosion effect
private _boomClass = "Bo_Mk82";
if !(isClass (configFile >> "CfgVehicles" >> _boomClass)) then { _boomClass = "HelicopterExploBig"; };
createVehicle [_boomClass, _pos, [], 0, "CAN_COLLIDE"];

// Visual effects (remoteExec to all clients)
if (!isNil "BIS_fnc_explosionEffects") then
{
    [_pos, 40, true] remoteExec ["BIS_fnc_explosionEffects", 0];
};

// Destroy bomber unit
if (!isNull _bomber) then { _bomber setDamage 1; };

// Transition threat state
if (!(_threatId isEqualTo "")) then
{
    [_threatId, "DETONATED", "suicide_bomber_detonated"] call ARC_fnc_threatUpdateState;
    diag_log format ["[ARC][INFO] ARC_fnc_suicideBomberOnDetonate: threat=%1 → DETONATED pos=%2", _threatId, mapGridPosition _pos];
}
else
{
    // Fallback: log OPS event without threat record
    private _meta = [
        ["event", "SB_DETONATED"],
        ["pos", _pos],
        ["grid", mapGridPosition _pos]
    ];
    ["OPS", format ["Suicide bomber detonated at %1.", mapGridPosition _pos], _pos, _meta] call ARC_fnc_intelLog;
};

true

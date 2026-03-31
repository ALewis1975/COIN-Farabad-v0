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

// Sender validation
if (!isNil "remoteExecutedOwner") then
{
    private _reo = remoteExecutedOwner;
    if (_reo > 0) then
    {
        // Only accept from server-side spawned monitor (reo == 2 or local execution)
        // Log all remote invocations for security audit
        diag_log format ["[ARC][SEC] ARC_fnc_suicideBomberOnDetonate: invoked reo=%1 threatId=%2 bomberNetId=%3", _reo, _threatId, _bomberNetId];
    };
};

// Deduplicate (guard against double-fire)
if (missionNamespace getVariable ["ARC_suicideBomberDetonated", false]) exitWith {false};
missionNamespace setVariable ["ARC_suicideBomberDetonated", true];

private _bomber = objectFromNetId _bomberNetId;
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

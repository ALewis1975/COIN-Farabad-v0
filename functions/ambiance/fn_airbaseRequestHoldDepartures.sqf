/*
    Server RPC: request hold on airbase departures.
    Params: [OBJECT caller]
*/

if (!isServer) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\\core\\fn_rpcValidateSender.sqf"; };
if (isNil "ARC_fnc_airbaseTowerAuthorize") then { ARC_fnc_airbaseTowerAuthorize = compile preprocessFileLineNumbers "functions\\core\\fn_airbaseTowerAuthorize.sqf"; };

params [["_caller", objNull, [objNull]]];

if (!([_caller, "ARC_fnc_airbaseRequestHoldDepartures", "Airbase hold request rejected: sender verification failed.", "AIRBASE_HOLD_SECURITY_DENIED"] call ARC_fnc_rpcValidateSender)) exitWith {false};

private _auth = [_caller, "HOLD"] call ARC_fnc_airbaseTowerAuthorize;
_auth params ["_ok", "_level", "_reason"];
if (!_ok) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { ["Airbase hold request denied: tower authorization required."] remoteExec ["ARC_fnc_clientHint", _owner]; };

    ["OPS", format ["AIRBASE CONTROL DENIED: HOLD by %1 (%2)", name _caller, _reason], getPosATL _caller, 0, [
        ["event", "AIRBASE_HOLD_AUTH_DENIED"],
        ["caller", name _caller],
        ["uid", getPlayerUID _caller],
        ["level", _level],
        ["reason", _reason]
    ]] call ARC_fnc_intelLog;
    false
};

["airbase_v1_holdDepartures", true] call ARC_fnc_stateSet;

["OPS", format ["AIRBASE CONTROL: HOLD departures requested by %1", name _caller], getPosATL _caller, 0, [
    ["event", "AIRBASE_HOLD_SET"],
    ["caller", name _caller],
    ["uid", getPlayerUID _caller],
    ["authLevel", _level],
    ["holdDepartures", true]
]] call ARC_fnc_intelLog;

true

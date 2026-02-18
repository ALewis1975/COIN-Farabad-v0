/*
    Server RPC: request release of airbase departures.
    Params: [OBJECT caller]
*/

if (!isServer) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\\core\\fn_rpcValidateSender.sqf"; };
if (isNil "ARC_fnc_airbaseTowerAuthorize") then { ARC_fnc_airbaseTowerAuthorize = compile preprocessFileLineNumbers "functions\\core\\fn_airbaseTowerAuthorize.sqf"; };

params [["_caller", objNull, [objNull]]];

if (!([_caller, "ARC_fnc_airbaseRequestReleaseDepartures", "Airbase release request rejected: sender verification failed.", "AIRBASE_RELEASE_SECURITY_DENIED"] call ARC_fnc_rpcValidateSender)) exitWith {false};

private _auth = [_caller, "RELEASE"] call ARC_fnc_airbaseTowerAuthorize;
_auth params ["_ok", "_level", "_reason"];
if (!_ok) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { ["Airbase release request denied: tower authorization required."] remoteExec ["ARC_fnc_clientHint", _owner]; };

    ["OPS", format ["AIRBASE CONTROL DENIED: RELEASE by %1 (%2)", name _caller, _reason], getPosATL _caller, 0, [
        ["event", "AIRBASE_RELEASE_AUTH_DENIED"],
        ["caller", name _caller],
        ["uid", getPlayerUID _caller],
        ["level", _level],
        ["reason", _reason]
    ]] call ARC_fnc_intelLog;
    false
};

["airbase_v1_holdDepartures", false] call ARC_fnc_stateSet;

["OPS", format ["AIRBASE CONTROL: RELEASE departures requested by %1", name _caller], getPosATL _caller, 0, [
    ["event", "AIRBASE_HOLD_RELEASED"],
    ["caller", name _caller],
    ["uid", getPlayerUID _caller],
    ["authLevel", _level],
    ["holdDepartures", false]
]] call ARC_fnc_intelLog;

true

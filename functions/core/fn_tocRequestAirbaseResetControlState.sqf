/*
    Server-side handler: reset AIRSUB control state.

    Called via remoteExec from clients.
    Params: [OBJECT caller, BOOL preserveHistory]
*/

if (!isServer) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\\core\\fn_rpcValidateSender.sqf"; };

params [
    ["_caller", objNull, [objNull]],
    ["_preserveHistory", true, [true]]
];

private _rpc = "ARC_fnc_tocRequestAirbaseResetControlState";
private _owner = if (!isNil "remoteExecutedOwner") then { remoteExecutedOwner } else { -1 };
private _requestor = _caller;

private _deny = {
    params ["_reason", ["_details", []], ["_notify", ""]];

    private _who = if (isNull _requestor) then {"<unknown>"} else {name _requestor};
    private _uid = if (isNull _requestor) then {""} else {getPlayerUID _requestor};

    ["OPS", format ["SECURITY: %1 denied (%2) owner=%3 caller=%4", _rpc, _reason, _owner, _who], [0,0,0],
        [["event", "TOC_AIRBASE_RESET_SECURITY_DENIED"], ["rpc", _rpc], ["reason", _reason], ["remoteOwner", _owner], ["callerName", _who], ["callerUID", _uid]] + _details
    ] call ARC_fnc_intelLog;

    if (_notify isNotEqualTo "" && { !isNull _requestor }) then {
        private _requestOwner = owner _requestor;
        if (_requestOwner > 0) then { [_notify] remoteExec ["ARC_fnc_clientHint", _requestOwner]; };
    };
};

if (!isNil "remoteExecutedOwner" && { _owner > 0 }) then {
    if (isNull _requestor) then {
        {
            if (owner _x == _owner) exitWith { _requestor = _x; };
        } forEach allPlayers;
    };

    if (!([_requestor, _rpc, "AIRBASE reset rejected: sender verification failed.", "TOC_AIRBASE_RESET_SECURITY_DENIED", true] call ARC_fnc_rpcValidateSender)) exitWith {false};

    private _isOmni = [_requestor, "OMNI"] call ARC_fnc_rolesHasGroupIdToken;
    private _can = _isOmni || { [_requestor] call ARC_fnc_rolesCanApproveQueue };
    if (!_can) exitWith {
        ["ROLE_DENIED", [], "Airbase reset denied: TOC approver or OMNI role required."] call _deny;
        false
    };
};

if (!(_preserveHistory isEqualType true) && !(_preserveHistory isEqualType false)) then {
    ["INVALID_PARAM_TYPE", [["param", "_preserveHistory"], ["receivedType", typeName _preserveHistory]], ""] call _deny;
    _preserveHistory = true;
};

private _reqName = if (isNull _requestor) then { "<server>" } else { name _requestor };
private _reqUid = if (isNull _requestor) then { "" } else { getPlayerUID _requestor };
diag_log format ["[ARC][AIRBASE][RESET] control reset requested. owner=%1 requester=%2 uid=%3 preserveHistory=%4", _owner, _reqName, _reqUid, _preserveHistory];

[_preserveHistory, _requestor] call ARC_fnc_airbaseAdminResetControlState;
true

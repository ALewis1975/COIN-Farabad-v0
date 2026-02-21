/*
    ARC_fnc_tocRequestCivsubSave

    Server: admin tool to force-save CIVSUB v1.
    Called from HQ/ADMIN tab.

    Params:
      0: OBJECT requester (optional)

    Returns: BOOL
*/

if (!isServer) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\core\fn_rpcValidateSender.sqf"; };

params [
    ["_requester", objNull, [objNull]]
];

private _rpc = "ARC_fnc_tocRequestCivsubSave";
private _owner = if (!isNil "remoteExecutedOwner") then { remoteExecutedOwner } else { -1 };

if (!(_requester isEqualType objNull)) then {
    _requester = objNull;
};

private _deny = {
    params ["_reason", ["_details", []], ["_notify", ""]];

    private _who = if (isNull _requester) then {"<unknown>"} else {name _requester};
    private _uid = if (isNull _requester) then {""} else {getPlayerUID _requester};

    ["OPS", format ["SECURITY: %1 denied (%2) owner=%3 caller=%4", _rpc, _reason, _owner, _who], [0,0,0],
        [["event", "TOC_CIVSUB_SAVE_SECURITY_DENIED"], ["rpc", _rpc], ["reason", _reason], ["remoteOwner", _owner], ["callerName", _who], ["callerUID", _uid]] + _details
    ] call ARC_fnc_intelLog;

    if (!(_notify isEqualTo "") && { !isNull _requester }) then {
        private _requestOwner = owner _requester;
        if (_requestOwner > 0) then { [_notify] remoteExec ["ARC_fnc_clientHint", _requestOwner]; };
    };
};

if (!isNil "remoteExecutedOwner" && { _owner > 0 }) then
{
    if (isNull _requester) then
    {
        {
            if (owner _x == _owner) exitWith { _requester = _x; };
        } forEach allPlayers;
    };

    if (!([_requester, _rpc, "CIVSUB save rejected: sender verification failed.", "TOC_CIVSUB_SAVE_SECURITY_DENIED", true] call ARC_fnc_rpcValidateSender)) exitWith {false};

    private _isOmni = [_requester, "OMNI"] call ARC_fnc_rolesHasGroupIdToken;
    private _can = _isOmni || { [_requester] call ARC_fnc_rolesCanApproveQueue };
    if (!_can) exitWith {
        ["ROLE_DENIED", [], "CIVSUB save denied: TOC approver or OMNI role required."] call _deny;
        false
    };
};

if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {
    ["DOMAIN_DISABLED", [["domain", "civsub_v1_enabled"]], ""] call _deny;
    false
};

[] call ARC_fnc_civsubPersistSave;

if (!isNull _requester) then
{
    ["CIVSUB state saved."] remoteExec ["ARC_fnc_clientToast", owner _requester];
};

true

/*
    ARC_fnc_tocRequestCivsubReset

    Server: admin tool to reset CIVSUB persistence and rebuild in-memory state.
    Called from HQ/ADMIN tab.

    Params:
      0: OBJECT requester

    Returns: BOOL
*/

if (!isServer) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\core\fn_rpcValidateSender.sqf"; };

params [
    ["_requester", objNull, [objNull]]
];

private _rpc = "ARC_fnc_tocRequestCivsubReset";
private _owner = if (!isNil "remoteExecutedOwner") then { remoteExecutedOwner } else { -1 };

if (!(_requester isEqualType objNull)) then {
    _requester = objNull;
};

private _deny = {
    params ["_reason", ["_details", []], ["_notify", ""]];

    private _who = if (isNull _requester) then {"<unknown>"} else {name _requester};
    private _uid = if (isNull _requester) then {""} else {getPlayerUID _requester};

    ["OPS", format ["SECURITY: %1 denied (%2) owner=%3 caller=%4", _rpc, _reason, _owner, _who], [0,0,0],
        [["event", "TOC_CIVSUB_RESET_SECURITY_DENIED"], ["rpc", _rpc], ["reason", _reason], ["remoteOwner", _owner], ["callerName", _who], ["callerUID", _uid]] + _details
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

    if (!([_requester, _rpc, "CIVSUB reset rejected: sender verification failed.", "TOC_CIVSUB_RESET_SECURITY_DENIED", true] call ARC_fnc_rpcValidateSender)) exitWith {false};

    private _isOmni = [_requester, "OMNI"] call ARC_fnc_rolesHasGroupIdToken;
    private _can = _isOmni || { [_requester] call ARC_fnc_rolesCanApproveQueue };
    if (!_can) exitWith {
        ["ROLE_DENIED", [], "CIVSUB reset denied: TOC approver or OMNI role required."] call _deny;
        false
    };
};

if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith
{
    ["DOMAIN_DISABLED", [["domain", "civsub_v1_enabled"]], "CIVSUB is disabled (civsub_v1_enabled=false)."] call _deny;

    if (!isNull _requester) then
    {
        ["CIVSUB is disabled (civsub_v1_enabled=false)."] remoteExec ["ARC_fnc_clientToast", owner _requester];
    };
    false
};

private _ok = [] call ARC_fnc_civsubPersistReset;

if (!isNull _requester) then
{
    if (_ok) then
    {
        private _cid = profileNamespace getVariable ["FARABAD_CIVSUB_V1_CAMPAIGN_ID", ""];
        [format ["CIVSUB campaign reset. New campaign_id=%1", _cid]] remoteExec ["ARC_fnc_clientToast", owner _requester];
    }
    else
    {
        ["CIVSUB campaign reset failed."] remoteExec ["ARC_fnc_clientToast", owner _requester];
    };
};

_ok

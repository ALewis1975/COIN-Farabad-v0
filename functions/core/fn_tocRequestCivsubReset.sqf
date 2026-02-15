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

if (!isNil "remoteExecutedOwner") then
{
    private _reo = remoteExecutedOwner;
    if (_reo > 0) then
    {
        if (isNull _requester) then
        {
            {
                if (owner _x == _reo) exitWith { _requester = _x; };
            } forEach allPlayers;
        };

        if (!([_requester, "ARC_fnc_tocRequestCivsubReset", "CIVSUB reset rejected: sender verification failed.", "TOC_CIVSUB_RESET_SECURITY_DENIED"] call ARC_fnc_rpcValidateSender)) exitWith {false};

        private _isOmni = [_requester, "OMNI"] call ARC_fnc_rolesHasGroupIdToken;
        private _can = _isOmni || { [_requester] call ARC_fnc_rolesCanApproveQueue };
        if (!_can) exitWith {false};
    };
};

if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith
{
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

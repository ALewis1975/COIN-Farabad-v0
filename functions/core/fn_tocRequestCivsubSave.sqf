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

        // RemoteExec-only validation path: requires remoteExecutedOwner context.
        if (!([_requester, "ARC_fnc_tocRequestCivsubSave", "CIVSUB save rejected: sender verification failed.", "TOC_CIVSUB_SAVE_SECURITY_DENIED", true] call ARC_fnc_rpcValidateSender)) exitWith {false};

        private _isOmni = [_requester, "OMNI"] call ARC_fnc_rolesHasGroupIdToken;
        private _can = _isOmni || { [_requester] call ARC_fnc_rolesCanApproveQueue };
        if (!_can) exitWith {false};
    };
};

if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

[] call ARC_fnc_civsubPersistSave;

if (!isNull _requester) then
{
    ["CIVSUB state saved."] remoteExec ["ARC_fnc_clientToast", owner _requester];
};

true

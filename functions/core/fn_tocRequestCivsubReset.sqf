/*
    ARC_fnc_tocRequestCivsubReset

    Server: admin tool to reset CIVSUB persistence and rebuild in-memory state.
    Called from HQ/ADMIN tab.

    Params:
      0: OBJECT requester

    Returns: BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_requester", objNull, [objNull]]
];

if (isNull _requester) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith
{
    ["CIVSUB is disabled (civsub_v1_enabled=false)."] remoteExec ["ARC_fnc_clientToast", owner _requester];
    false
};

private _ok = [] call ARC_fnc_civsubPersistReset;

if (_ok) then
{
    private _cid = profileNamespace getVariable ["FARABAD_CIVSUB_V1_CAMPAIGN_ID", ""];
    [format ["CIVSUB campaign reset. New campaign_id=%1", _cid]] remoteExec ["ARC_fnc_clientToast", owner _requester];
}
else
{
    ["CIVSUB campaign reset failed."] remoteExec ["ARC_fnc_clientToast", owner _requester];
};

_ok

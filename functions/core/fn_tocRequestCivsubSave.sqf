/*
    ARC_fnc_tocRequestCivsubSave

    Server: admin tool to force-save CIVSUB v1.
    Called from HQ/ADMIN tab.

    Params:
      0: OBJECT requester (optional)

    Returns: BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_requester", objNull, [objNull]]
];

if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

[] call ARC_fnc_civsubPersistSave;

if (!isNull _requester) then
{
    ["CIVSUB state saved."] remoteExec ["ARC_fnc_clientToast", owner _requester];
};

true

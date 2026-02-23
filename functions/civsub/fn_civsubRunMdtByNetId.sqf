/*
    ARC_fnc_civsubRunMdtByNetId

    Server: runs a civilian through the CIVSUB crime DB using the last shown ID card netId.

    Params:
      0: actor (object) - player requesting the run
      1: civNetId (string)

    Behavior:
      - resolves civ object from netId
      - performs a Crime DB check WITHOUT requiring compliance
      - uses method="MDT" so influence mapping can differ from forced searches
*/
if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

params [
    ["_actor", objNull, [objNull]],
    ["_netId", "", [""]]
];

if (isNull _actor || { !isPlayer _actor }) exitWith {false};
if (_netId isEqualTo "") exitWith {false};

// Dedicated MP hardening: bind actor identity to network sender.
if (!isNil "remoteExecutedOwner") then
{
    private _reo = remoteExecutedOwner;
    if (_reo > 0) then
    {
        if ((owner _actor) != _reo) exitWith
        {
            diag_log format ["[CIVSUB][SEC] %1 denied: sender-owner mismatch reo=%2 actorOwner=%3 actor=%4",
                "ARC_fnc_civsubRunMdtByNetId", _reo, owner _actor, name _actor];
            false
        };
    };
};

private _civ = objectFromNetId _netId;
if (isNull _civ) exitWith {
    ["CIVSUB: No target (ID no longer valid).", "CHAT"] remoteExecCall ["ARC_fnc_civsubClientMessage", _actor];
    false
};

[_actor, _civ, "MDT", false] call ARC_fnc_civsubInteractCheckPapers;
true

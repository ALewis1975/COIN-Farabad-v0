/*
    ARC_fnc_civsubInteractRelease

    Server-side handler: releases a previously detained civilian.

    Params:
      0: actor (object)
      1: civ (object)
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

params [
    ["_actor", objNull, [objNull]],
    ["_civ", objNull, [objNull]],
    ["_deferRestore", false, [false]],
    ["_silent", false, [false]]
];

if (isNull _actor || {isNull _civ}) exitWith {false};
if !(isPlayer _actor) exitWith {false};

// Dedicated MP hardening:
// If invoked via remoteExec, bind actor identity to network sender.
if (!isNil "remoteExecutedOwner") then
{
    private _reo = remoteExecutedOwner;
    if (_reo > 0) then
    {
        if ((owner _actor) != _reo) exitWith
        {
            diag_log format ["[CIVSUB][SEC] %1 denied: sender-owner mismatch reo=%2 actorOwner=%3 actor=%4",
                "ARC_fnc_civsubInteractRelease",
                _reo,
                owner _actor,
                name _actor
            ];
            false
        };
    };
};

private _did = _civ getVariable ["civsub_districtId", ""];
if (_did isEqualTo "") exitWith {false};

private _actorUid = getPlayerUID _actor;
private _civUid = _civ getVariable ["civ_uid", ""];
if (_civUid isEqualTo "") then {
    if (!_silent) then {
        ["CIVSUB: Unknown civilian identity.", "CHAT"] remoteExecCall ["ARC_fnc_civsubClientMessage", _actor];
    };
    false
};

private _rec = [_civUid] call ARC_fnc_civsubIdentityGet;
if !(_rec isEqualType createHashMap) then {
    _rec = [_did, _actorUid, _civUid, getPosATL _civ] call ARC_fnc_civsubIdentityTouch;
};
if !(_rec isEqualType createHashMap) exitWith {false};

_rec set ["status_detained", false];
_rec set ["status_releasedAt", serverTime];
_rec set ["status_handedOff", false];
_rec set ["status_handedOffAt", 0];
_rec set ["status_handedOffTo", ""]; 

[_civUid, _rec] call ARC_fnc_civsubIdentitySet;


// Allow sampler to manage the civilian again

// If this release is invoked from the dialog, keep the civilian stopped until the session ends.
// EndSession will restore mobility and clear pins when ARC_civsub_releasePending is set.
if (_deferRestore) then {
    _civ setVariable ["ARC_civsub_releasePending", true, true];
    _civ setCaptive false;
    doStop _civ;
    _civ disableAI "MOVE";
    _civ disableAI "PATH";
    _civ switchMove "AmovPercMstpSnonWnonDnon";
} else {
    // Allow sampler to manage the civilian again
    _civ setVariable ["civsub_v1_pinned", false, true];

    // Restore mobility/captive state if the unit was held in the custody pipeline
    _civ setCaptive false;
    _civ enableAI "MOVE";
    _civ enableAI "PATH";
    _civ switchMove "AmovPercMstpSnonWnonDnon";
};

_civ setVariable ["ARC_epw_inHolding", false, true];
_civ setVariable ["ARC_epw_stage", "", true];

// No locked delta for release in v1. Keep this as a state update only.
if (!_silent) then {
    ["CIVSUB: Civilian released.", "CHAT"] remoteExecCall ["ARC_fnc_civsubClientMessage", _actor];
};

true

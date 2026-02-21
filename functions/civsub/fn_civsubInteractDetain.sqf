/*
    ARC_fnc_civsubInteractDetain

    Server-side handler: marks a civilian as detained (v1).

    Params:
      0: actor (object)
      1: civ (object)

    Emits:
      DETENTION_INIT delta bundle
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

params [
    ["_actor", objNull, [objNull]],
    ["_civ", objNull, [objNull]],
    ["_silent", false, [false]]
];

if (isNull _actor || {isNull _civ}) exitWith {false};
if !(isPlayer _actor) exitWith {false};

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _hmFrom   = compile "params ['_pairs']; private _r = createHashMap; { _r set [_x select 0, _x select 1]; } forEach _pairs; _r";

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
                "ARC_fnc_civsubInteractDetain",
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

// Ensure the civilian is pinned immediately, even if the actor never used Order Stop.
// This does not set detained status by itself; it only freezes movement until session end.
[_civ, _actor] call ARC_fnc_civsubInteractOrderStop;

private _actorUid = getPlayerUID _actor;
private _civUid = _civ getVariable ["civ_uid", ""];
if (_civUid isEqualTo "") then {
    _civUid = [_did] call ARC_fnc_civsubIdentityGenerateUid;
    _civ setVariable ["civ_uid", _civUid, true];
};

private _rec = [_did, _actorUid, _civUid, getPosATL _civ] call ARC_fnc_civsubIdentityTouch;
if !(_rec isEqualType createHashMap) exitWith {false};

private _wl = [_rec, "wanted_level", 0] call _hg;
if !(_wl isEqualType 0) then { _wl = 0; };

_rec set ["status_detained", true];
_rec set ["status_detainedAt", serverTime];
_rec set ["status_detainedDistrictId", _did];

// Protect from CIVSUB sampler despawn while in custody pipeline
_civ setVariable ["civsub_v1_pinned", true, true];

// Also mark captive so protection survives any locality/variable edge cases until released/handed off.
_civ setCaptive true;
_civ setVariable ["ARC_epw_stage", "IN_CUSTODY", true];

// Visible surrender posture (server owns civ AI locality)
_civ switchMove "AmovPercMstpSsurWnonDnon";



[_civUid, _rec] call ARC_fnc_civsubIdentitySet;

[_did, "DETENTION_INIT", "IDENTITY", [[["civ_uid", _civUid], ["wanted_level", _wl]]] call _hmFrom, _actorUid] call ARC_fnc_civsubEmitDelta;

if (!_silent) then {
    ["CIVSUB: Civilian marked detained.", "CHAT"] remoteExecCall ["ARC_fnc_civsubClientMessage", _actor];
};

true

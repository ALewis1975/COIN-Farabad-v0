/*
    ARC_fnc_civsubInteractEndSession

    Server-side: ends a temporary interaction session and restores a civilian's movement
    ONLY if the civilian is not detained.

    Params:
      0: civ unit (object)
      1: actor (object, player)

    Rules:
      - If the identity record indicates the civilian is detained, do not restore movement.
      - Only the stop owner (by UID) can end the session.
*/

if (!isServer) exitWith {false};

params [
    ["_civ", objNull, [objNull]],
    ["_actor", objNull, [objNull]],
    ["_silent", false, [false]]
];
if (isNull _civ) exitWith {false};
if (isNull _actor) exitWith {false};

if !(_civ getVariable ["civsub_v1_isCiv", false]) exitWith {false};

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _actorUid = getPlayerUID _actor;
if (_actorUid isEqualTo "") exitWith {false};

private _ownerUid = _civ getVariable ["civsub_v1_stopOwnerUid", ""];
if !(_ownerUid isEqualTo "" || {_ownerUid isEqualTo _actorUid}) exitWith {false};

private _releasePending = _civ getVariable ["ARC_civsub_releasePending", false];

// If the civilian is detained, keep them pinned in place.
private _civUid = _civ getVariable ["civ_uid", ""];
if !(_civUid isEqualTo "") then {
    private _rec = [_civUid] call ARC_fnc_civsubIdentityGet;
    if (_rec isEqualType createHashMap) then {
        if ([_rec, "status_detained", false] call _hg) exitWith {
            if (!_silent) then {
                ["CIVSUB: Interaction ended. Civilian remains detained.", "CHAT"] remoteExecCall ["ARC_fnc_civsubClientMessage", _actor];
            };
            true
        };
    };
};

// If the player released the civilian inside the dialog, clear custody pins now.
if (_releasePending) then {
    _civ setVariable ["civsub_v1_pinned", false, true];
    _civ setVariable ["ARC_civsub_releasePending", false, true];
    _civ setCaptive false;
    _civ setVariable ["ARC_epw_stage", "", true];
};

// Restore movement
_civ enableAI "PATH";
_civ enableAI "MOVE";
_civ setVariable ["civsub_v1_stopped", false, true];
_civ setVariable ["civsub_v1_stopOwnerUid", "", true];
_civ setVariable ["civsub_v1_stopTs", 0, true];

if (!_silent) then {
    ["CIVSUB: Interaction ended. Civilian resumed movement.", "CHAT"] remoteExecCall ["ARC_fnc_civsubClientMessage", _actor];
};

true

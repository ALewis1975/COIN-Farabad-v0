/*
    ARC_fnc_civsubInteractOrderStop

    Server-side: applies a temporary stop lock to a CIVSUB-managed civilian
    and freezes its movement until the interaction session ends.

    Params:
      0: civ unit (object)
      1: actor (object, player)

    Notes:
      - Does not change detained state.
      - Stores stop owner so only that player can end the session.
*/

if (!isServer) exitWith {false};

params [
    ["_civ", objNull, [objNull]],
    ["_actor", objNull, [objNull]]
];
if (isNull _civ) exitWith {false};
if (isNull _actor) exitWith {false};

if !(_civ getVariable ["civsub_v1_isCiv", false]) exitWith {false};

private _uid = getPlayerUID _actor;
if (_uid isEqualTo "") exitWith {false};

_civ setVariable ["civsub_v1_stopOwnerUid", _uid, true];
_civ setVariable ["civsub_v1_stopTs", serverTime, true];
_civ setVariable ["civsub_v1_stopped", true, true];

// Freeze movement (server owns AI locality for these civilians)
doStop _civ;
_civ disableAI "PATH";
_civ disableAI "MOVE";

true

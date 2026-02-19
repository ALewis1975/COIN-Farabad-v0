/*
    ARC_fnc_civsubCivAddContactActions

    Client-side: attaches two ALiVE-style addActions to a CIVSUB-managed civilian.

    Actions:
      1) Order to Stop   -> server: ARC_fnc_civsubInteractOrderStop
      2) Interact        -> opens CIV interact dialog (Step 2 UI shell)

    Params:
      0: civ unit (object)

    Notes:
      - Uses a per-unit flag to avoid duplicates.
      - Safe no-op on headless/server.
*/

if (!hasInterface) exitWith {false};

params [
    ["_civ", objNull, [objNull]]
];
if (isNull _civ) exitWith {false};
if !(side _civ isEqualTo civilian) exitWith {false};
if !(_civ getVariable ["civsub_v1_isCiv", false]) exitWith {
    diag_log format ["[CIVSUB][CONTACT] Skipping addAction attach for unit netId=%1 reason=civsub_v1_isCiv false", netId _civ];
    false
};

if (_civ getVariable ["civsub_v1_contact_actions_added", false]) exitWith {true};
_civ setVariable ["civsub_v1_contact_actions_added", true];

private _cond = "alive _target && {player distance _target < 3} && {_target getVariable ['civsub_v1_isCiv',false]}";

_civ addAction [
    "Order to Stop",
    {
        params ["_target", "_caller"];
        if (isNull _target || {isNull _caller}) exitWith {};
        // server-owned stop lock + AI freeze
        [_target, _caller] remoteExecCall ["ARC_fnc_civsubInteractOrderStop", 2];
        ["CIVSUB: Ordered civilian to stop.", "CHAT"] call ARC_fnc_civsubClientMessage;
    },
    nil,
    6,
    true,
    true,
    "",
    _cond
];

_civ addAction [
    "Interact",
    {
        params ["_target", "_caller"];
        if (isNull _target || {isNull _caller}) exitWith {};

        // Ensure the civilian is stopped so the dialog remains usable even if the player didn't use "Order to Stop"
        [_target, _caller] remoteExecCall ["ARC_fnc_civsubInteractOrderStop", 2];

        // Open the CIV interact dialog (UI shell in Step 2)
        [_target] call ARC_fnc_civsubContactDialogOpen;
    },
    nil,
    5,
    true,
    true,
    "",
    _cond
];

true

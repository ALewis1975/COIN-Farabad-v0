/*
    ARC_fnc_civsubCivAddAceActions

    Client-side: attaches ACE interaction menu actions to a civilian unit.

    Params:
      0: civ unit (object)

    Policy (Phase 6):
      - Default: SHERIFF handoff is the only ACE action for civilians.
      - Optional legacy toggle (debug / fallback):
            missionNamespace setVariable ["ARC_civsubAceLegacyActions", true];
        When enabled, legacy CIVSUB ACE actions (Show/Check Papers, Detain, Release) are added.

    Notes:
      - Safe no-op if ACE interact menu is not present.
      - Uses a per-unit flag to avoid duplicate registration.
*/

if (!hasInterface) exitWith {false};

params [
    ["_civ", objNull, [objNull]]
];
if (isNull _civ) exitWith {false};
if !(side _civ isEqualTo civilian) exitWith {false};

// ACE present?
if (isNil "ace_interact_menu_fnc_createAction" || {isNil "ace_interact_menu_fnc_addActionToObject"}) exitWith {false};

if (_civ getVariable ["civsub_v1_ace_actions_added", false]) exitWith {true};
_civ setVariable ["civsub_v1_ace_actions_added", true];

private _path = ["ACE_MainActions"]; // target interaction root

// Phase 6 policy: only SHERIFF handoff by default
private _legacy = missionNamespace getVariable ["ARC_civsubAceLegacyActions", false];

if (_legacy) then {
    private _aShow = [
        "CIVSUB_SHOW_PAPERS",
        "CIVSUB: Show Papers",
        "",
        {
            [player, _target] remoteExecCall ["ARC_fnc_civsubInteractShowPapers", 2];
        },
        {true}
    ] call ace_interact_menu_fnc_createAction;
    [_civ, 0, _path, _aShow] call ace_interact_menu_fnc_addActionToObject;

    private _aCheck = [
        "CIVSUB_CHECK_PAPERS",
        "CIVSUB: Search & Check Papers",
        "",
        {
            [player, _target] remoteExecCall ["ARC_fnc_civsubInteractCheckPapers", 2];
        },
        {true}
    ] call ace_interact_menu_fnc_createAction;
    [_civ, 0, _path, _aCheck] call ace_interact_menu_fnc_addActionToObject;

    private _aDetain = [
        "CIVSUB_DETAIN",
        "CIVSUB: Mark Detained",
        "",
        {
            [player, _target] remoteExecCall ["ARC_fnc_civsubInteractDetain", 2];
        },
        {true}
    ] call ace_interact_menu_fnc_createAction;
    [_civ, 0, _path, _aDetain] call ace_interact_menu_fnc_addActionToObject;

    private _aRelease = [
        "CIVSUB_RELEASE",
        "CIVSUB: Release Civilian",
        "",
        {
            [player, _target] remoteExecCall ["ARC_fnc_civsubInteractRelease", 2];
        },
        {true}
    ] call ace_interact_menu_fnc_createAction;
    [_civ, 0, _path, _aRelease] call ace_interact_menu_fnc_addActionToObject;
};

// Always keep SHERIFF handoff
private _aHandoff = [
    "CIVSUB_HANDOFF_SHERIFF",
    "CIVSUB: Handoff to SHERIFF",
    "",
    {
        [player, _target] remoteExecCall ["ARC_fnc_civsubInteractHandoffSheriff", 2];
    },
    {true}
] call ace_interact_menu_fnc_createAction;
[_civ, 0, _path, _aHandoff] call ace_interact_menu_fnc_addActionToObject;

true

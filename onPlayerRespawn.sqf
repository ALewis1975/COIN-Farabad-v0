/*
    onPlayerRespawn.sqf
    Client-side player respawn hook.

    Minimal starter:
    - No-op-safe guards.
    - Re-initializes key client-side ARC systems after respawn.
    - Schedules init slightly delayed to let engine respawn settle.
*/

params [
    ["_unit", objNull, [objNull]],
    ["_corpse", objNull, [objNull]]
];

if (!hasInterface) exitWith {};
if (isNull _unit) exitWith {};
if (!local _unit) exitWith {};
if (_unit != player) exitWith {};

[_unit, _corpse] spawn {
    params ["_respawnedUnit", "_oldCorpse"];

    uiSleep 0.25;

    if (!alive _respawnedUnit) exitWith {};

    if (!isNil "ARC_fnc_intelInit") then { [] call ARC_fnc_intelInit; };
    if (!isNil "ARC_fnc_briefingInitClient") then { [] call ARC_fnc_briefingInitClient; };
    if (!isNil "ARC_fnc_tocInitPlayer") then { [] call ARC_fnc_tocInitPlayer; };
    if (!isNil "ARC_fnc_uiConsoleInitClient") then { [] call ARC_fnc_uiConsoleInitClient; };

    private _meta = [
        ["name", name _respawnedUnit],
        ["corpseNull", isNull _oldCorpse],
        ["position", getPosATL _respawnedUnit]
    ];

    if (!isNil "ARC_fnc_farabadInfo") then {
        ["LIFECYCLE", "onPlayerRespawn: client systems reinitialized", _meta] call ARC_fnc_farabadInfo;
    } else {
        diag_log format ["[ARC][LIFECYCLE][INFO] onPlayerRespawn reinit name=%1 corpseNull=%2", name _respawnedUnit, isNull _oldCorpse];
    };
};

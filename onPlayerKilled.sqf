/*
    onPlayerKilled.sqf
    Player death hook.

    Minimal starter:
    - No-op-safe parameter handling.
    - Emits structured telemetry for death events.
    - No gameplay-side mutation yet.
*/

params [
    ["_unit", objNull, [objNull]],
    ["_killer", objNull, [objNull]],
    ["_instigator", objNull, [objNull]],
    ["_useEffects", true, [true]]
];

if (isNull _unit) exitWith {};

private _killerName = if (isNull _killer) then { "<null>" } else { name _killer };
private _instigatorName = if (isNull _instigator) then { "<null>" } else { name _instigator };

private _meta = [
    ["unit", name _unit],
    ["unitIsPlayer", isPlayer _unit],
    ["killer", _killerName],
    ["instigator", _instigatorName],
    ["useEffects", _useEffects]
];

if (!isNil "ARC_fnc_farabadInfo") then {
    ["LIFECYCLE", "onPlayerKilled: player death event", _meta] call ARC_fnc_farabadInfo;
} else {
    diag_log format ["[ARC][LIFECYCLE][INFO] onPlayerKilled unit=%1 killer=%2 instigator=%3 useEffects=%4", name _unit, _killerName, _instigatorName, _useEffects];
};

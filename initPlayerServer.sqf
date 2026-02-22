if (!isServer) exitWith {};

/*
    initPlayerServer.sqf
    Server-side per-player join hook.

    Minimal starter:
    - Validates event payload.
    - Logs join metadata for audit/debug.
    - Leaves gameplay state unchanged.
*/

params [
    ["_player", objNull, [objNull]],
    ["_didJIP", false, [true]]
];

if (isNull _player) exitWith {};
if (!isPlayer _player) exitWith {};

private _uid = getPlayerUID _player;
private _name = name _player;

private _meta = [
    ["name", _name],
    ["uid", _uid],
    ["didJIP", _didJIP],
    ["owner", owner _player]
];

if (!isNil "ARC_fnc_farabadInfo") then {
    ["LIFECYCLE", format ["initPlayerServer: player joined (%1)", _name], _meta] call ARC_fnc_farabadInfo;
} else {
    diag_log format ["[ARC][LIFECYCLE][INFO] initPlayerServer join name=%1 uid=%2 didJIP=%3 owner=%4", _name, _uid, _didJIP, owner _player];
};

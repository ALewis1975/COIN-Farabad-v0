/*
    COIN Farabad - initPlayerServer.sqf

    Executed on the SERVER for each player that connects (initial join or JIP).

    Params (engine-supplied):
      _unit  : Object  – the connecting player's unit
      _isJip : Boolean – true when the player joined after mission start

    Authority: SERVER only.
    This script is the server-side counterpart to initPlayerLocal.sqf. All
    state writes here must go through ARC_fnc_stateSet or guarded server-side
    helpers — never direct missionNamespace writes from client context.
*/

if (!isServer) exitWith {};

params [
    ["_unit",  objNull, [objNull]],
    ["_isJip", false,   [false]]
];

if (isNull _unit) exitWith {};

private _playerName = name _unit;
private _playerUID  = getPlayerUID _unit;

diag_log format [
    "[ARC][INFO] initPlayerServer: player join | name=%1 uid=%2 isJip=%3",
    _playerName, _playerUID, _isJip
];

// ---------------------------------------------------------------------------
// Role registration hook.
// Guard with !isNil so the file is safe before ARC_fnc_registerPlayer is
// compiled (future feature hook).
// ---------------------------------------------------------------------------
if (!isNil "ARC_fnc_registerPlayer") then
{
    [_unit, _isJip] call ARC_fnc_registerPlayer;
};

// ---------------------------------------------------------------------------
// CIVSUB: log the joining player for attribution tracking.
// ---------------------------------------------------------------------------
if (missionNamespace getVariable ["civsub_v1_enabled", false]) then
{
    diag_log format [
        "[CIVSUB][INFO] initPlayerServer: registering player for CIVSUB attribution | name=%1 uid=%2",
        _playerName, _playerUID
    ];
};

// ---------------------------------------------------------------------------
// Ensure JIP players receive a fresh public state snapshot immediately.
// The snapshot watcher on the client will pick this up; remoteExec here
// provides an explicit trigger for worst-case timing.
// ---------------------------------------------------------------------------
if (_isJip && { !isNil "ARC_fnc_statePublishPublic" }) then
{
    [] call ARC_fnc_statePublishPublic;
    diag_log format [
        "[ARC][INFO] initPlayerServer: triggered state publish for JIP player | name=%1",
        _playerName
    ];
};

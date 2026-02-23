/*
    ARC_fnc_devToggleDebugMode

    Server-side: toggles all debug overrides on or off as a group.
    Mirrors the ARC_profile_devMode block in initServer.sqf.

    When toggling ON: enables all debug flags (same as dev profile).
    When toggling OFF: disables all debug flags (same as live profile).

    Params:
      0: requester (OBJECT) - player who requested the toggle

    Returns: true
*/

if (!isServer) exitWith { false };

params [
    ["_requester", objNull, [objNull]]
];

// Current state: check if debug is currently on
private _wasOn = missionNamespace getVariable ["ARC_debugLogEnabled", false];
private _newState = !_wasOn;

// Toggle all debug flags
missionNamespace setVariable ["ARC_debugLogEnabled", _newState, true];
missionNamespace setVariable ["ARC_debugLogToChat", _newState, true];
missionNamespace setVariable ["ARC_devDebugInspectorEnabled", _newState, true];
missionNamespace setVariable ["ARC_debugInspectorEnabled", _newState, true];
missionNamespace setVariable ["civsub_v1_debug", _newState, true];
missionNamespace setVariable ["civsub_v1_traffic_debug", _newState, true];
missionNamespace setVariable ["airbase_v1_tower_authDebug", _newState, true];

// Also update FARABAD log level to match
if (_newState) then {
    missionNamespace setVariable ["FARABAD_log_minLevel", "DEBUG", true];
} else {
    missionNamespace setVariable ["FARABAD_log_minLevel", "INFO", true];
};

diag_log format [
    "[ARC][DIAG] Debug mode toggled %1 by %2 (uid=%3)",
    if (_newState) then { "ON" } else { "OFF" },
    if (isNull _requester) then { "unknown" } else { name _requester },
    if (isNull _requester) then { "" } else { getPlayerUID _requester }
];

diag_log format [
    "[ARC][DEBUG] Effective toggles | ARC_debugLogEnabled=%1 | ARC_debugLogToChat=%2 | ARC_debugInspectorEnabled=%3 | FARABAD_log_minLevel=%4",
    _newState,
    _newState,
    _newState,
    missionNamespace getVariable ["FARABAD_log_minLevel", "INFO"]
];

// Notify the requesting client
private _owner = 0;
if (!isNull _requester) then { _owner = owner _requester; };
if (_owner <= 0 && { !isNil "remoteExecutedOwner" }) then { _owner = remoteExecutedOwner; };

if (_owner > 0) then {
    private _msg = format ["Debug mode is now %1.", if (_newState) then { "ON (all debug flags enabled, FARABAD log level=DEBUG)" } else { "OFF (all debug flags disabled, FARABAD log level=INFO)" }];
    [_msg] remoteExecCall ["ARC_fnc_clientHint", _owner];
};

true

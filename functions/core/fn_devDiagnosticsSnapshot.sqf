/*
    ARC_fnc_devDiagnosticsSnapshot

    Server-side diagnostics snapshot. Collects all debug toggle states,
    subsystem health indicators, and key runtime metrics into a structured
    HTML report sent to the requesting client.

    Params:
      0: requester (OBJECT) - used to route the report back via remoteExec

    Returns: true
*/

if (!isServer) exitWith { false };

params [
    ["_requester", objNull, [objNull]]
];

private _owner = 0;
if (!isNull _requester) then { _owner = owner _requester; };
if (_owner <= 0 && { !isNil "remoteExecutedOwner" }) then { _owner = remoteExecutedOwner; };

private _lines = [];

_lines pushBack "<t size='1.2' font='PuristaMedium'>Debug / Diagnostics Snapshot</t>";
_lines pushBack format ["<t size='0.9' color='#BDBDBD'>Server time:</t> <t size='0.9'>%1</t>", serverTime];
_lines pushBack format ["<t size='0.9' color='#BDBDBD'>Build:</t> <t size='0.9'>%1</t>", missionNamespace getVariable ["ARC_buildStamp", "UNKNOWN"]];
_lines pushBack "";

// --- Debug toggles ---
_lines pushBack "<t size='1.05' font='PuristaMedium'>DEBUG TOGGLES</t>";

private _toggles = [
    ["ARC_profile_devMode", "Dev Profile"],
    ["ARC_debugLogEnabled", "Debug Log"],
    ["ARC_debugLogToChat", "Debug Log → Chat"],
    ["ARC_debugInspectorEnabled", "Debug Inspector"],
    ["ARC_devDebugInspectorEnabled", "Dev Inspector Gate"],
    ["civsub_v1_debug", "CIVSUB Debug"],
    ["civsub_v1_traffic_debug", "CIVSUB Traffic Debug"],
    ["airbase_v1_tower_authDebug", "Airbase Tower Auth Debug"]
];

{
    _x params ["_var", "_label"];
    private _val = missionNamespace getVariable [_var, "<nil>"];
    private _c = if (_val isEqualTo true) then { "#6EE7B7" } else { "#BDBDBD" };
    _lines pushBack format ["<t color='%1'>%2</t>  <t size='0.9' color='#AAAAAA'>%3 = %4</t>", _c, _label, _var, _val];
} forEach _toggles;

_lines pushBack "";

// --- FARABAD Logger ---
_lines pushBack "<t size='1.05' font='PuristaMedium'>FARABAD LOGGER</t>";

private _logToggles = [
    ["FARABAD_log_enabled", true],
    ["FARABAD_log_minLevel", "INFO"],
    ["FARABAD_log_toRPT", true],
    ["FARABAD_log_toExtension", false],
    ["FARABAD_log_extensionName", ""]
];

{
    _x params ["_var", "_default"];
    private _val = missionNamespace getVariable [_var, _default];
    _lines pushBack format ["<t size='0.9'>%1 = %2</t>", _var, _val];
} forEach _logToggles;

_lines pushBack "";

// --- Safe Mode ---
_lines pushBack "<t size='1.05' font='PuristaMedium'>SAFE MODE</t>";
private _safeMode = missionNamespace getVariable ["ARC_safeModeEnabled", false];
private _safeModeColor = if (_safeMode isEqualTo true) then { "#FBBF24" } else { "#6EE7B7" };
_lines pushBack format ["<t color='%1'>ARC_safeModeEnabled = %2</t>", _safeModeColor, _safeMode];

_lines pushBack "";

// --- Subsystem Status ---
_lines pushBack "<t size='1.05' font='PuristaMedium'>SUBSYSTEM STATUS</t>";

private _subsystems = [
    ["ARC_serverReady", "Server Ready"],
    ["civsub_v1_enabled", "CIVSUB Enabled"],
    ["civsub_v1_civs_enabled", "CIVSUB Civs Enabled"],
    ["civsub_v1_scheduler_enabled", "CIVSUB Scheduler Enabled"],
    ["civsub_v1_traffic_enabled", "CIVSUB Traffic Enabled"],
    ["airbase_v1_runtime_enabled", "Airbase Runtime Enabled"],
    ["airbase_v1_ambiance_enabled", "Airbase Ambiance Enabled"],
    ["ARC_iedPhase1_siteSelectionEnabled", "IED Phase1 Enabled"],
    ["ARC_vbiedPhase3_enabled", "VBIED Phase3 Enabled"],
    ["ARC_patrolSpawnContactsEnabled", "Patrol Contacts Enabled"],
    ["ARC_worldTime_enabled", "World Time Enabled"],
    ["ARC_incidentLoopRunning", "Incident Loop Running"],
    ["ARC_execLoopRunning", "Exec Loop Running"]
];

{
    _x params ["_var", "_label"];
    private _val = missionNamespace getVariable [_var, "<nil>"];
    private _c = if (_val isEqualTo true) then { "#6EE7B7" } else {
        if (_val isEqualTo false) then { "#FF6B6B" } else { "#BDBDBD" }
    };
    _lines pushBack format ["<t color='%1'>%2</t>  <t size='0.9' color='#AAAAAA'>%3</t>", _c, _label, _val];
} forEach _subsystems;

_lines pushBack "";

// --- Key Metrics ---
_lines pushBack "<t size='1.05' font='PuristaMedium'>KEY METRICS</t>";

private _state = missionNamespace getVariable ["ARC_state", []];
private _stateCount = if (_state isEqualType []) then { count _state } else { -1 };
_lines pushBack format ["<t size='0.9'>ARC_state entries: %1</t>", _stateCount];

private _activeTask = missionNamespace getVariable ["ARC_activeTaskId", ""];
if (!(_activeTask isEqualType "")) then { _activeTask = str _activeTask; };
_lines pushBack format ["<t size='0.9'>Active Task: %1</t>", if (_activeTask isEqualTo "") then { "(none)" } else { _activeTask }];

private _pubUpdatedAt = missionNamespace getVariable ["ARC_pub_stateUpdatedAt", -1];
_lines pushBack format ["<t size='0.9'>Last Snapshot Broadcast: %1</t>", _pubUpdatedAt];

private _civIds = missionNamespace getVariable ["civsub_v1_identities", createHashMap];
private _civIdCount = if (_civIds isEqualType createHashMap) then { count _civIds } else {
    if (_civIds isEqualType []) then { count _civIds } else { -1 }
};
_lines pushBack format ["<t size='0.9'>CIVSUB Identities: %1</t>", _civIdCount];

private _playersOnline = count (allPlayers - entities "HeadlessClient_F");
_lines pushBack format ["<t size='0.9'>Players Online: %1</t>", _playersOnline];
_lines pushBack format ["<t size='0.9'>All Units: %1</t>", count allUnits];
_lines pushBack format ["<t size='0.9'>Server FPS: %1</t>", diag_fps];

_lines pushBack "";
_lines pushBack format ["<t size='0.9' color='#BDBDBD'>Generated at serverTime %1</t>", serverTime];

diag_log format ["[ARC][DIAG] Diagnostics snapshot requested by owner=%1", _owner];

private _report = _lines joinString "<br/>";
if (_owner > 0) then {
    [_report] remoteExecCall ["ARC_fnc_devDiagnosticsClientReceive", _owner];
};

true

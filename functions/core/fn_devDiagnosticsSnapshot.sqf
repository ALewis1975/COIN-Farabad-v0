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

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\core\fn_rpcValidateSender.sqf"; };

params [
    ["_requester", objNull, [objNull]]
];

private _owner = 0;
if (!isNull _requester) then { _owner = owner _requester; };
if (_owner <= 0 && { !isNil "remoteExecutedOwner" }) then { _owner = remoteExecutedOwner; };

// S1 + S3: sender validation and HQ role gate (diagnostics tools are approver-only).
if (!isNil "remoteExecutedOwner" && { _owner > 0 }) then
{
    private _requestor = _requester;
    if (isNull _requestor) then
    {
        { if (owner _x == _owner) exitWith { _requestor = _x; }; } forEach allPlayers;
    };
    private _reoOwner = if (!isNil "remoteExecutedOwner") then { remoteExecutedOwner } else { -1 };
    if (!([_requestor, "ARC_fnc_devDiagnosticsSnapshot", "Diagnostics denied: sender verification failed.", "DIAG_SNAPSHOT_SECURITY_DENIED", true, _reoOwner] call ARC_fnc_rpcValidateSender)) exitWith {false};
    private _isOmni = [_requestor, "OMNI"] call ARC_fnc_rolesHasGroupIdToken;
    private _can = _isOmni || { [_requestor] call ARC_fnc_rolesCanApproveQueue };
    if (!_can) exitWith {
        diag_log format ["[ARC][SEC] ARC_fnc_devDiagnosticsSnapshot: unauthorized caller owner=%1", _owner];
        false
    };
};

private _lines = [];
private _fncCountContainer = {
    params [["_value", nil]];
    if (_value isEqualType []) exitWith { count _value };
    if (_value isEqualType createHashMap) exitWith { count _value };
    -1
};
private _fncSnapshotAge = {
    params [["_updatedAt", -1]];
    if (!(_updatedAt isEqualType 0)) exitWith { -1 };
    if (_updatedAt < 0) exitWith { -1 };
    serverTime - _updatedAt
};
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _keysFn = compile "params ['_m']; keys _m";

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
_lines pushBack format ["<t size='0.9'>Snapshot age (s): %1</t>", [_pubUpdatedAt] call _fncSnapshotAge];

private _civIds = missionNamespace getVariable ["civsub_v1_identities", createHashMap];
private _civIdCount = [_civIds] call _fncCountContainer;
_lines pushBack format ["<t size='0.9'>CIVSUB Identities: %1</t>", _civIdCount];

private _playersOnline = count (allPlayers - entities "HeadlessClient_F");
private _aiUnitsCount = 0;
{
    if (!isPlayer _x) then { _aiUnitsCount = _aiUnitsCount + 1; };
} forEach allUnits;
_lines pushBack format ["<t size='0.9'>Players Online: %1</t>", _playersOnline];
_lines pushBack format ["<t size='0.9'>AI Units: %1</t>", _aiUnitsCount];
_lines pushBack format ["<t size='0.9'>Active Groups: %1</t>", count allGroups];
_lines pushBack format ["<t size='0.9'>All Units: %1</t>", count allUnits];
_lines pushBack format ["<t size='0.9'>Server FPS: %1</t>", diag_fps];

_lines pushBack "";
_lines pushBack "<t size='1.05' font='PuristaMedium'>RUNTIME REGISTRIES</t>";

private _civRegistry = missionNamespace getVariable ["civsub_v1_civ_registry", []];
_lines pushBack format ["<t size='0.9'>CIVSUB Civ Registry: %1</t>", [_civRegistry] call _fncCountContainer];

private _trafficMoving = missionNamespace getVariable ["civsub_v1_traffic_list_moving", []];
private _trafficParked = missionNamespace getVariable ["civsub_v1_traffic_list_parked", []];
_lines pushBack format ["<t size='0.9'>Traffic Moving: %1</t>", [_trafficMoving] call _fncCountContainer];
_lines pushBack format ["<t size='0.9'>Traffic Parked: %1</t>", [_trafficParked] call _fncCountContainer];
_lines pushBack format ["<t size='0.9'>Traffic Thread Running: %1</t>", missionNamespace getVariable ["civsub_v1_traffic_threadRunning", false]];

private _sitePopRegistry = missionNamespace getVariable ["ARC_sitePopRegistry", createHashMap];
_lines pushBack format ["<t size='0.9'>SitePop Registry: %1</t>", [_sitePopRegistry] call _fncCountContainer];

private _convoyIndex = missionNamespace getVariable ["ARC_convoyIndex", []];
_lines pushBack format ["<t size='0.9'>Convoy Index: %1</t>", [_convoyIndex] call _fncCountContainer];

private _leadPoolPublic = missionNamespace getVariable ["ARC_leadPoolPublic", []];
private _threadsPublic = missionNamespace getVariable ["ARC_threadsPublic", []];
private _queuePending = missionNamespace getVariable ["ARC_pub_queuePending", []];
private _ordersPublic = missionNamespace getVariable ["ARC_pub_orders", []];
_lines pushBack format ["<t size='0.9'>Active Leads: %1</t>", [_leadPoolPublic] call _fncCountContainer];
_lines pushBack format ["<t size='0.9'>Active Threads: %1</t>", [_threadsPublic] call _fncCountContainer];
_lines pushBack format ["<t size='0.9'>Queue Pending: %1</t>", [_queuePending] call _fncCountContainer];
_lines pushBack format ["<t size='0.9'>Published Orders: %1</t>", [_ordersPublic] call _fncCountContainer];

private _iedRecords = missionNamespace getVariable ["ARC_iedPhase1_deviceRecords", []];
private _vbiedRecords = missionNamespace getVariable ["ARC_vbiedPhase3_deviceRecords", []];
_lines pushBack format ["<t size='0.9'>IED Device Records: %1</t>", [_iedRecords] call _fncCountContainer];
_lines pushBack format ["<t size='0.9'>VBIED Device Records: %1</t>", [_vbiedRecords] call _fncCountContainer];

// --- Active CIVIL site density diagnostics --------------------------------
// Explicit, on-demand snapshot only. No tick loop, no spawns, no persistence of handles.
private _taskIdCivil = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (!(_taskIdCivil isEqualType "")) then { _taskIdCivil = ""; };
private _typeCivil = ["activeIncidentType", ""] call ARC_fnc_stateGet;
if (!(_typeCivil isEqualType "")) then { _typeCivil = ""; };
private _typeCivilU = toUpper _typeCivil;

if (_typeCivilU isEqualTo "CIVIL") then
{
    private _displayCivil = ["activeIncidentDisplayName", ""] call ARC_fnc_stateGet;
    if (!(_displayCivil isEqualType "")) then { _displayCivil = ""; };

    private _posCivil = ["activeIncidentPos", []] call ARC_fnc_stateGet;
    if (!(_posCivil isEqualType []) || { (count _posCivil) < 2 }) then { _posCivil = []; };
    if ((count _posCivil) < 2) then
    {
        private _mkrCivil = ["activeIncidentMarker", ""] call ARC_fnc_stateGet;
        if (_mkrCivil isEqualType "" && { !(_mkrCivil isEqualTo "") }) then
        {
            private _mResolved = [_mkrCivil] call ARC_fnc_worldResolveMarker;
            if (_mResolved in allMapMarkers) then { _posCivil = getMarkerPos _mResolved; };
        };
    };
    if ((count _posCivil) < 2) then { _posCivil = [0,0,0]; };
    _posCivil = +_posCivil;
    _posCivil resize 3;

    private _gridCivil = mapGridPosition _posCivil;
    private _didCivil = ["activeIncidentCivsubDistrictId", ""] call ARC_fnc_stateGet;
    if (!(_didCivil isEqualType "")) then { _didCivil = ""; };
    if (_didCivil isEqualTo "" && { !isNil "ARC_fnc_threadResolveDistrictId" }) then
    {
        _didCivil = [_posCivil] call ARC_fnc_threadResolveDistrictId;
        if (!(_didCivil isEqualType "")) then { _didCivil = ""; };
    };

    private _nearestSiteId = "";
    private _nearestSiteDist = 1e12;
    private _sitePopActive = false;
    private _sitePopUnits250 = 0;
    private _sitePopActiveMap = missionNamespace getVariable ["ARC_sitePopActive", createHashMap];

    if (_sitePopRegistry isEqualType createHashMap) then
    {
        {
            private _sid = _x;
            private _row = [_sitePopRegistry, _sid, []] call _hg;
            if (_row isEqualType [] && { (count _row) >= 7 }) then
            {
                private _sp = _row select 6;
                if (_sp isEqualType [] && { (count _sp) >= 2 }) then
                {
                    private _d = _posCivil distance2D _sp;
                    if (_d < _nearestSiteDist) then
                    {
                        _nearestSiteDist = _d;
                        _nearestSiteId = _sid;
                    };
                };
            };
        } forEach ([_sitePopRegistry] call _keysFn);
    };

    if (_sitePopActiveMap isEqualType createHashMap) then
    {
        private _nearestActiveRow = [_sitePopActiveMap, _nearestSiteId, []] call _hg;
        _sitePopActive = (_nearestActiveRow isEqualType [] && { (count _nearestActiveRow) > 0 });

        {
            private _sid = _x;
            private _row = [_sitePopActiveMap, _sid, []] call _hg;
            if (!(_row isEqualType []) || { (count _row) < 1 }) then { continue; };
            private _groups = _row select 0;
            if (!(_groups isEqualType [])) then { continue; };
            {
                if (isNull _x) then { continue; };
                {
                    if (!isNull _x && { alive _x } && { (_x distance2D _posCivil) <= 250 }) then
                    {
                        _sitePopUnits250 = _sitePopUnits250 + 1;
                    };
                } forEach (units _x);
            } forEach _groups;
        } forEach ([_sitePopActiveMap] call _keysFn);
    };

    private _overlayNetIds = ["activeOverlaySpawnNetIds", []] call ARC_fnc_stateGet;
    if (!(_overlayNetIds isEqualType [])) then { _overlayNetIds = []; };
    private _overlayUnitsAlive = 0;
    private _overlayObjectsAlive = 0;
    {
        if (!(_x isEqualType "")) then { continue; };
        private _e = objectFromNetId _x;
        if (isNull _e || { !alive _e }) then { continue; };
        if (_e isKindOf "Man") then
        {
            _overlayUnitsAlive = _overlayUnitsAlive + 1;
        }
        else
        {
            _overlayObjectsAlive = _overlayObjectsAlive + 1;
        };
    } forEach _overlayNetIds;

    private _civsub250 = 0;
    private _civsub500 = 0;
    if (_civRegistry isEqualType createHashMap) then
    {
        {
            private _row = [_civRegistry, _x, createHashMap] call _hg;
            if (!(_row isEqualType createHashMap)) then { continue; };
            private _u = [_row, "unit", objNull] call _hg;
            if (isNull _u || { !alive _u }) then { continue; };
            private _d = _u distance2D _posCivil;
            if (_d <= 250) then { _civsub250 = _civsub250 + 1; };
            if (_d <= 500) then { _civsub500 = _civsub500 + 1; };
        } forEach ([_civRegistry] call _keysFn);
    }
    else
    {
        {
            if (!isNull _x && { alive _x } && { _x getVariable ["civsub_v1_isCiv", false] }) then
            {
                private _d = _x distance2D _posCivil;
                if (_d <= 250) then { _civsub250 = _civsub250 + 1; };
                if (_d <= 500) then { _civsub500 = _civsub500 + 1; };
            };
        } forEach allUnits;
    };

    private _traffic300 = 0;
    private _traffic700 = 0;
    private _trafficAll = [];
    if (_trafficMoving isEqualType []) then { _trafficAll append _trafficMoving; };
    if (_trafficParked isEqualType []) then { _trafficAll append _trafficParked; };
    {
        if (isNull _x || { !alive _x }) then { continue; };
        private _d = _x distance2D _posCivil;
        if (_d <= 300) then { _traffic300 = _traffic300 + 1; };
        if (_d <= 700) then { _traffic700 = _traffic700 + 1; };
    } forEach _trafficAll;

    private _todPhase = "UNKNOWN";
    if (!isNil "ARC_fnc_dynamicTodGetPolicy") then
    {
        private _todPolicy = [] call ARC_fnc_dynamicTodGetPolicy;
        if (_todPolicy isEqualType createHashMap) then
        {
            _todPhase = [_todPolicy, "phase", "UNKNOWN"] call _hg;
            if (!(_todPhase isEqualType "")) then { _todPhase = "UNKNOWN"; };
        };
    };

    private _activeCivilSite = [
        ["taskId", _taskIdCivil],
        ["incidentType", _typeCivil],
        ["displayName", _displayCivil],
        ["pos", _posCivil],
        ["grid", _gridCivil],
        ["districtId", _didCivil],
        ["siteId", _nearestSiteId],
        ["sitePopActive", _sitePopActive],
        ["overlayNetIds", _overlayNetIds],
        ["overlayUnitsAlive", _overlayUnitsAlive],
        ["overlayObjectsAlive", _overlayObjectsAlive],
        ["sitePopUnitsNear250m", _sitePopUnits250],
        ["civsubCivsNear250m", _civsub250],
        ["civsubCivsNear500m", _civsub500],
        ["trafficNear300m", _traffic300],
        ["trafficNear700m", _traffic700],
        ["todPhase", _todPhase]
    ];
    missionNamespace setVariable ["ARC_lastActiveCivilSiteDiag", _activeCivilSite, false];

    _lines pushBack "";
    _lines pushBack "<t size='1.05' font='PuristaMedium'>ACTIVE CIVIL SITE</t>";
    _lines pushBack format ["<t size='0.9'>Task: %1 | %2 | %3</t>", _taskIdCivil, _displayCivil, _gridCivil];
    _lines pushBack format ["<t size='0.9'>District: %1 | SitePop site: %2 active=%3 | TOD=%4</t>", _didCivil, _nearestSiteId, _sitePopActive, _todPhase];
    _lines pushBack format ["<t size='0.9'>Overlay: units=%1 objects=%2 netIds=%3</t>", _overlayUnitsAlive, _overlayObjectsAlive, count _overlayNetIds];
    _lines pushBack format ["<t size='0.9'>Near 250m: SitePop=%1 CIVSUB=%2 | CIVSUB 500m=%3</t>", _sitePopUnits250, _civsub250, _civsub500];
    _lines pushBack format ["<t size='0.9'>Traffic: 300m=%1 700m=%2</t>", _traffic300, _traffic700];

    diag_log format ["[ARC][DIAG][CIVIL_SITE] task=%1 grid=%2 district=%3 site=%4 active=%5 overlayU=%6 overlayO=%7 sitePop250=%8 civsub250=%9 civsub500=%10 traffic300=%11 traffic700=%12 tod=%13",
        _taskIdCivil, _gridCivil, _didCivil, _nearestSiteId, _sitePopActive, _overlayUnitsAlive, _overlayObjectsAlive, _sitePopUnits250, _civsub250, _civsub500, _traffic300, _traffic700, _todPhase];
};

_lines pushBack "";
_lines pushBack "<t size='1.05' font='PuristaMedium'>SNAPSHOT FRESHNESS</t>";
private _ordersUpdatedAt = missionNamespace getVariable ["ARC_pub_ordersUpdatedAt", -1];
private _queueUpdatedAt = missionNamespace getVariable ["ARC_pub_queueUpdatedAt", -1];
private _intelUpdatedAt = missionNamespace getVariable ["ARC_pub_intelUpdatedAt", -1];
private _threadsUpdatedAt = missionNamespace getVariable ["ARC_threadsPublicUpdatedAt", -1];
private _leadsUpdatedAt = missionNamespace getVariable ["ARC_leadPoolPublicUpdatedAt", -1];
_lines pushBack format ["<t size='0.9'>Orders age (s): %1</t>", [_ordersUpdatedAt] call _fncSnapshotAge];
_lines pushBack format ["<t size='0.9'>Queue age (s): %1</t>", [_queueUpdatedAt] call _fncSnapshotAge];
_lines pushBack format ["<t size='0.9'>Intel age (s): %1</t>", [_intelUpdatedAt] call _fncSnapshotAge];
_lines pushBack format ["<t size='0.9'>Threads age (s): %1</t>", [_threadsUpdatedAt] call _fncSnapshotAge];
_lines pushBack format ["<t size='0.9'>Leads age (s): %1</t>", [_leadsUpdatedAt] call _fncSnapshotAge];

_lines pushBack "";
_lines pushBack format ["<t size='0.9' color='#BDBDBD'>Generated at serverTime %1</t>", serverTime];

diag_log format ["[ARC][INFO] ARC_fnc_devDiagnosticsSnapshot: diagnostics snapshot requested by owner=%1", _owner];

private _report = _lines joinString "<br/>";
if (_owner > 0) then {
    [_report] remoteExecCall ["ARC_fnc_devDiagnosticsClientReceive", _owner];
} else {
    diag_log "[ARC][WARN] ARC_fnc_devDiagnosticsSnapshot: snapshot generated but no valid owner target found.";
};

true
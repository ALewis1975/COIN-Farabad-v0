/*
    Server RPC: submit an airbase clearance request.
    Params: [OBJECT caller, STRING requestType, OBJECT aircraft, NUMBER priority, STRING source, STRING lane, STRING incidentType, STRING priorityClassOverride]

    Record shape:
    [
        requestId, type, callerUid, callerName,
        aircraftNetId, priority, status,
        createdAt, updatedAt,
        [decisionBy, decisionByUid, decisionAt, decisionAction, decisionReason],
        [meta pairs]
    ]
*/
if (!isServer) exitWith {false};
if !(["airbaseSubmitClearanceRequest"] call ARC_fnc_airbaseRuntimeEnabled) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\\core\\fn_rpcValidateSender.sqf"; };
if (isNil "ARC_fnc_airbaseTowerAuthorize") then { ARC_fnc_airbaseTowerAuthorize = compile preprocessFileLineNumbers "functions\\core\\fn_airbaseTowerAuthorize.sqf"; };

params [
    ["_caller", objNull, [objNull]],
    ["_requestType", "", [""]],
    ["_aircraft", objNull, [objNull]],
    ["_priority", 0, [0]],
    ["_source", "PLAYER", [""]],
    ["_lane", "", [""]],
    ["_incidentType", "", [""]],
    ["_priorityClassOverride", "", [""]]
];

// sqflint-compatible helpers
private _trimFn  = compile "params ['_s']; trim _s";
private _hmFrom  = compile "private _pairs = _this; private _r = createHashMap; { _r set [_x select 0, _x select 1]; } forEach _pairs; _r";
private _mapGet  = compile "params ['_h','_k']; _h get _k";

if (!([_caller, "ARC_fnc_airbaseSubmitClearanceRequest", "Airbase clearance request rejected: sender verification failed.", "AIRBASE_CLEARANCE_SUBMIT_SECURITY_DENIED"] call ARC_fnc_rpcValidateSender)) exitWith {false};

private _pilotTokens = missionNamespace getVariable ["airbase_v1_pilotGroupTokens", ["EFS", "HAWG", "VIPER", "PILOT"]];
if (!(_pilotTokens isEqualType [])) then { _pilotTokens = ["EFS", "HAWG", "VIPER", "PILOT"]; };

private _pilotGroup = group _caller;
private _pilotGroupName = if (isNull _pilotGroup) then {""} else { groupId _pilotGroup };
private _pilotRoleDesc = roleDescription _caller;
private _pilotAllowed = false;
{
    if (_x isEqualType "" && { [ _caller, _x ] call ARC_fnc_rolesHasGroupIdToken }) exitWith { _pilotAllowed = true; };
} forEach _pilotTokens;

private _allowBnCmd = missionNamespace getVariable ["airbase_v1_tower_allowBnCmd", false];
if (!(_allowBnCmd isEqualType true) && !(_allowBnCmd isEqualType false)) then { _allowBnCmd = false; };
if (!_pilotAllowed && _allowBnCmd) then {
    private _bnTokens = missionNamespace getVariable ["airbase_v1_tower_bnCommandTokens", ["BNCMD", "BN COMMAND", "BNHQ", "BN CO", "BNCO", "BN CDR", "REDFALCON 6", "REDFALCON6", "FALCON 6", "FALCON6"]];
    if (!(_bnTokens isEqualType [])) then { _bnTokens = ["BNCMD", "BN COMMAND", "BNHQ"]; };
    {
        if (_x isEqualType "" && { [_caller, _x] call ARC_fnc_rolesHasGroupIdToken }) exitWith { _pilotAllowed = true; };
    } forEach _bnTokens;
};

if !_pilotAllowed exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { ["Clearance request rejected: pilot group authorization required."] remoteExec ["ARC_fnc_clientHint", _owner]; };
    false
};

if (isNull _aircraft) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { ["Clearance request rejected: invalid aircraft context."] remoteExec ["ARC_fnc_clientHint", _owner]; };
    false
};

if ((_caller distance _aircraft) > 15) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { ["Clearance request rejected: you must be in aircraft context."] remoteExec ["ARC_fnc_clientHint", _owner]; };
    false
};
private _vehOwner = owner _aircraft;
private _callerOwner = owner _caller;
if ((_vehOwner > 0) && { _vehOwner != _callerOwner }) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { ["Clearance request rejected: aircraft ownership mismatch."] remoteExec ["ARC_fnc_clientHint", _owner]; };

    ["OPS", format ["AIRBASE CLEARANCE DENIED: submit owner mismatch by %1", name _caller], getPosATL _caller, [
        ["event", "AIRBASE_CLEARANCE_SUBMIT_OWNER_MISMATCH"],
        ["caller", name _caller],
        ["uid", getPlayerUID _caller],
        ["aircraftOwner", _vehOwner],
        ["callerOwner", _callerOwner]
    ]] call ARC_fnc_intelLog;

    false
};

if (!(_requestType isEqualType "")) then { _requestType = ""; };
_requestType = toUpper ([_requestType] call _trimFn);
private _legacyTypeMap = [
    ["TAKEOFF", "REQ_TAKEOFF"],
    ["LANDING", "REQ_LAND"],
    ["TAXI", "REQ_TAXI"],
    ["RUNWAY_CROSS", "REQ_TAXI"],
    ["PARKING", "REQ_TAXI"]
] call _hmFrom;
private _mappedType = [_legacyTypeMap, _requestType] call _mapGet;
if (!isNil "_mappedType") then { _requestType = _mappedType; };

if !(_requestType in ["REQ_TAXI", "REQ_TAKEOFF", "REQ_INBOUND", "REQ_LAND", "REQ_EMERGENCY"]) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { ["Clearance request rejected: unsupported request type."] remoteExec ["ARC_fnc_clientHint", _owner]; };
    false
};

private _callerVehicle = vehicle _caller;
private _isCrewContext = !isNull _callerVehicle && { _callerVehicle isEqualTo _aircraft };
if !_isCrewContext exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { ["Clearance request rejected: caller must be in the selected aircraft."] remoteExec ["ARC_fnc_clientHint", _owner]; };
    false
};


private _metaDistGet = {
    params ["_rows", "_k", "_def"];
    private _v = _def;
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { ((_x select 0)) isEqualTo _k }) exitWith { _v = _x select 1; };
    } forEach _rows;
    _v
};

if (_requestType isEqualTo "REQ_LAND") then {
    private _requestsExisting = ["airbase_v1_clearanceRequests", []] call ARC_fnc_stateGet;
    if !(_requestsExisting isEqualType []) then { _requestsExisting = []; };

    private _pilotUid = getPlayerUID _caller;
    private _aircraftNid = netId _aircraft;
    private _hasInbound = false;
    {
        if !(_x isEqualType []) then { continue; };
        private _rtype = toUpper (_x param [1, ""]);
        if !(_rtype isEqualTo "REQ_INBOUND") then { continue; };
        private _statusChk = toUpper (_x param [6, ""]);
        if (_statusChk in ["DENIED", "CANCELED", "COMPLETE"]) then { continue; };
        private _metaChk = _x param [10, []];
        if !(_metaChk isEqualType []) then { _metaChk = []; };
        private _metaPilotUid = [_metaChk, "pilotUid", ""] call _metaDistGet;
        private _metaAircraftNid = [_metaChk, "aircraftNetId", ""] call _metaDistGet;
        if ((_metaPilotUid isEqualTo _pilotUid) || {(!(_metaAircraftNid isEqualTo "")) && {_metaAircraftNid isEqualTo _aircraftNid}}) exitWith { _hasInbound = true; };
    } forEach _requestsExisting;

    if (!_hasInbound) exitWith {
        private _owner = owner _caller;
        if (_owner > 0) then { ["Landing clearance requires an active inbound request first."] remoteExec ["ARC_fnc_clientHint", _owner]; };
        false
    };
};
private _isPilotSeat = (driver _aircraft) isEqualTo _caller;
if ((_requestType in ["REQ_TAXI", "REQ_TAKEOFF", "REQ_INBOUND", "REQ_EMERGENCY"]) && {!_isPilotSeat}) exitWith {
    private _owner = owner _caller;
    if (_owner > 0) then { ["Clearance request rejected: pilot seat required for this request type."] remoteExec ["ARC_fnc_clientHint", _owner]; };
    false
};

if (!(_priority isEqualType 0)) then { _priority = 0; };
if (_priority < 0) then { _priority = 0; };
if (_priority > 100) then { _priority = 100; };

if (!(_source isEqualType "")) then { _source = "PLAYER"; };
_source = toUpper ([_source] call _trimFn);
if !(_source in ["PLAYER", "AMBIENT"]) then { _source = "PLAYER"; };

if (!(_lane isEqualType "")) then { _lane = ""; };
_lane = toUpper ([_lane] call _trimFn);
if (_lane isEqualTo "") then {
    _lane = switch (_requestType) do {
        case "REQ_TAXI": { "GROUND" };
        case "REQ_TAKEOFF": { "TOWER" };
        default { "ARRIVAL" };
    };
};
if !(_lane in ["GROUND", "TOWER", "ARRIVAL"]) then { _lane = "TOWER"; };

if (!(_incidentType isEqualType "")) then { _incidentType = ""; };
_incidentType = toUpper ([_incidentType] call _trimFn);

if (!(_priorityClassOverride isEqualType "")) then { _priorityClassOverride = ""; };
_priorityClassOverride = toUpper ([_priorityClassOverride] call _trimFn);

private _incidentPriorityMap = missionNamespace getVariable ["airbase_v1_incidentPriorityMap", [
    ["MASSCAS", "PRIORITY"],
    ["MEDEVAC", "PRIORITY"],
    ["QRF", "PRIORITY"],
    ["IED", "PRIORITY"]
]];
if (!(_incidentPriorityMap isEqualType [])) then { _incidentPriorityMap = []; };

private _autoPriorityClass = "ROUTINE";
if ((_requestType isEqualTo "REQ_EMERGENCY") || {_priority >= 100}) then {
    _autoPriorityClass = "PRIORITY";
} else {
    private _rowIdx = -1;
    {
        if ((_x isEqualType []) && { (count _x) >= 2 } && { ((_x param [0, ""]) isEqualTo _incidentType) }) exitWith { _rowIdx = _forEachIndex; };
    } forEach _incidentPriorityMap;
    if (_rowIdx >= 0) then {
        _autoPriorityClass = toUpper str ((_incidentPriorityMap select _rowIdx) param [1, "ROUTINE"]);
    };
};

private _priorityClass = _autoPriorityClass;
if (_priorityClassOverride in ["ROUTINE", "PRIORITY"]) then {
    _priorityClass = _priorityClassOverride;
};

private _requests = ["airbase_v1_clearanceRequests", []] call ARC_fnc_stateGet;
if (!(_requests isEqualType [])) then { _requests = []; };

private _history = ["airbase_v1_clearanceHistory", []] call ARC_fnc_stateGet;
if (!(_history isEqualType [])) then { _history = []; };


private _events = ["airbase_v1_events", []] call ARC_fnc_stateGet;
if (!(_events isEqualType [])) then { _events = []; };
private _eventsMax = missionNamespace getVariable ["airbase_v1_eventsMax", 60];
if (!(_eventsMax isEqualType 0) || { _eventsMax < 10 }) then { _eventsMax = 60; };

private _seq = ["airbase_v1_clearanceSeq", 0] call ARC_fnc_stateGet;
if (!(_seq isEqualType 0)) then { _seq = 0; };
_seq = _seq + 1;

private _requestId = format ["CLR-%1", _seq];
private _nowTs = serverTime;
private _callerUid = getPlayerUID _caller;
private _callerName = name _caller;
private _aircraftNetId = netId _aircraft;
if (!(_aircraftNetId isEqualType "")) then { _aircraftNetId = ""; };

private _laneAuto = toLower _lane;
if (!(_laneAuto in ["tower", "ground", "arrival"])) then {
    if (_requestType in ["REQ_INBOUND", "REQ_LAND", "REQ_EMERGENCY"]) then { _laneAuto = "arrival"; } else {
        if (_requestType isEqualTo "REQ_TAXI") then { _laneAuto = "ground"; } else { _laneAuto = "tower"; };
    };
};

private _record = [
    _requestId,
    _requestType,
    _callerUid,
    _callerName,
    _aircraftNetId,
    _priority,
    "QUEUED",
    _nowTs,
    _nowTs,
    ["", "", -1, "", ""],
    [
        ["callerOwner", _callerOwner],
        ["callerUnitNetId", netId _caller],
        ["pilotUid", _callerUid],
        ["pilotName", _callerName],
        ["pilotCallsign", _pilotRoleDesc],
        ["pilotGroupName", _pilotGroupName],
        ["aircraftNetId", _aircraftNetId],
        ["aircraftType", typeOf _aircraft],
        ["source", _source],
        ["lane", _laneAuto],
        ["decisionLane", _laneAuto],
        ["decisionMeta", "PENDING"],
        ["automationStatus", "Awaiting controller/automation triage"],
        ["automationEtaS", -1],
        ["automationDecisionAt", -1],
        ["incidentType", _incidentType],
        ["priorityClassAuto", _autoPriorityClass],
        ["priorityClass", _priorityClass],
        ["towerPriorityOverride", (_priorityClassOverride in ["ROUTINE", "PRIORITY"])],
        ["lifecycle_submit_at", _nowTs],
        ["lifecycle_queued_at", _nowTs],
        ["lifecycle_approved_at", -1],
        ["lifecycle_denied_at", -1],
        ["lifecycle_active_at", -1],
        ["lifecycle_complete_at", -1],
        ["submittedAt", _nowTs]
    ]
];

private _flowKind = if (_requestType in ["REQ_INBOUND", "REQ_LAND"]) then { "ARR" } else { "DEP" };
private _routeDecision = [_flowKind, "PLAYER", _requestId] call ARC_fnc_airbaseBuildRouteDecision;
private _routeOk = _routeDecision param [0, false];
private _routeMeta = _routeDecision param [1, []];
private _routeReason = _routeDecision param [2, "ROUTE_DECISION_FAILED"];
if (!_routeOk) exitWith {
    if (_callerOwner > 0) then { [format ["Clearance request rejected: invalid route (%1).", _routeReason]] remoteExec ["ARC_fnc_clientHint", _callerOwner]; };
    ["OPS", format ["AIRBASE CLEARANCE DENIED: %1 route invalid (%2)", _requestId, _routeReason], getPosATL _caller, [
        ["event", "AIRBASE_CLEARANCE_ROUTE_INVALID"],
        ["requestId", _requestId],
        ["requestType", _requestType],
        ["caller", _callerName],
        ["uid", _callerUid],
        ["reason", _routeReason]
    ]] call ARC_fnc_intelLog;
    false
};

private _meta = _record param [10, []];
if (!(_meta isEqualType [])) then { _meta = []; };
{ _meta pushBack _x; } forEach _routeMeta;
_record set [10, _meta];

_requests pushBack _record;
_requests = [_requests] call ARC_fnc_airbaseClearanceSortRequests;
_history pushBack _record;


_events pushBack [
    _nowTs,
    "SUBMIT",
    _requestId,
    _callerUid,
    "",
    [
        _requestType,
        _priority
    ]
];
if ((count _events) > _eventsMax) then {
    _events deleteRange [0, (count _events) - _eventsMax];
};

private _historyMax = missionNamespace getVariable ["airbase_v1_clearanceHistoryMax", 100];
if (!(_historyMax isEqualType 0) || { _historyMax < 10 }) then { _historyMax = 100; };
if ((count _history) > _historyMax) then {
    _history deleteRange [0, (count _history) - _historyMax];
};

["airbase_v1_clearanceSeq", _seq] call ARC_fnc_stateSet;
["airbase_v1_clearanceRequests", _requests] call ARC_fnc_stateSet;
["airbase_v1_clearanceHistory", _history] call ARC_fnc_stateSet;
["airbase_v1_events", _events] call ARC_fnc_stateSet;


private _controllerOwners = [];
{
    if !(isPlayer _x) then { continue; };
    if !(alive _x) then { continue; };
    private _authApprove = [_x, "APPROVE"] call ARC_fnc_airbaseTowerAuthorize;
    private _okApprove = _authApprove param [0, false];
    if (_okApprove) then {
        private _ow = owner _x;
        if (_ow > 0) then { _controllerOwners pushBackUnique _ow; };
        continue;
    };

    private _authFallback = [_x, "PRIORITIZE"] call ARC_fnc_airbaseTowerAuthorize;
    if ((_authFallback param [0, false])) then {
        private _ow2 = owner _x;
        if (_ow2 > 0) then { _controllerOwners pushBackUnique _ow2; };
    };
} forEach allPlayers;

private _toastBody = format ["%1 %2 (priority %3)", _requestId, toLower _requestType, _priority];
if (_callerOwner > 0) then {
    ["Airbase Clearance", format ["Request accepted and queued: %1", _toastBody], 5] remoteExec ["ARC_fnc_clientToast", _callerOwner];
};
{
    ["Airbase Tower", format ["Pending: %1", _toastBody], 5] remoteExec ["ARC_fnc_clientToast", _x];
} forEach _controllerOwners;

["OPS", format ["AIRBASE CLEARANCE: %1 submitted by %2", _requestId, _callerName], getPosATL _caller, [
    ["event", "AIRBASE_CLEARANCE_SUBMITTED"],
    ["requestId", _requestId],
    ["requestType", _requestType],
    ["caller", _callerName],
    ["uid", _callerUid],
    ["aircraftNetId", _aircraftNetId],
    ["priority", _priority]
]] call ARC_fnc_intelLog;

true

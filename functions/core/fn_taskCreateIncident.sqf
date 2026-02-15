/*
    Create the task entity for an incident.

    Params:
        0: STRING - taskId
        1: STRING - markerName (may be canonical or legacy, may be "" for lead-driven incidents)
        2: STRING - displayName
        3: STRING - incidentType
        4: ARRAY  - (optional) posATL override [x,y,z] (used when markerName is empty)
        5: STRING - (optional) threadId (used to nest the task under a case parent)

    Returns:
        BOOL
*/

params [
    "_taskId",
    ["_markerName", ""],
    ["_displayName", ""],
    ["_incidentType", ""],
    ["_posATL", []],
    ["_threadId", ""]
];

private _pos = [];
private _m = "";

if (_markerName isNotEqualTo "") then
{
    _m = [_markerName] call ARC_fnc_worldResolveMarker;
    if (_m in allMapMarkers) then
    {
        _pos = getMarkerPos _m;
    };
};

if (_pos isEqualTo [] && { _posATL isEqualType [] && { (count _posATL) >= 2 } }) then
{
    _pos = +_posATL;
    _pos resize 3;
};

if (_pos isEqualTo []) exitWith {false};

private _title = _displayName;
private _desc = [_taskId, _m, _displayName, _incidentType, _pos] call ARC_fnc_taskBuildDescription;

// Case/task nesting for intel threads
private _taskIdParam = _taskId;
if (_threadId isNotEqualTo "") then
{
    private _zoneBias = [_pos] call ARC_fnc_worldGetZoneForPos;
    private _parent = [_threadId, "GENERIC", _zoneBias, _pos] call ARC_fnc_taskEnsureThreadParent;
    if (_parent isNotEqualTo "") then
    {
        _taskIdParam = [_taskId, _parent];
    };
};

// Map incident types to task icons (Task Framework types)
private _taskType = switch (toUpper _incidentType) do
{
    case "RAID": {"ATTACK"};
    case "CMDNODE_RAID": {"ATTACK"};
    case "IED": {"MINE"};
    case "CIVIL": {"MEET"};
    case "CMDNODE_MEET": {"MEET"};
    case "LOGISTICS": {"TRUCK"};
    case "ESCORT": {"TRUCK"};
    case "CMDNODE_INTERCEPT": {"RUN"};
    case "DEFEND": {"DEFEND"};
    case "QRF": {"RUN"};
    case "RECON": {"SCOUT"};
    case "CHECKPOINT": {"MOVE"};
    default {"MOVE"};
};

// Assignment/acceptance workflow:
// - Initial tasks are created in CREATED state.
// - When TOC accepts an active incident, it is promoted to ASSIGNED.
// - On rehydrate after restart, preserve ASSIGNED if already accepted.
private _initState = "CREATED";
private _activeId = ["activeTaskId", ""] call ARC_fnc_stateGet;
private _accepted = ["activeIncidentAccepted", false] call ARC_fnc_stateGet;
if (_taskId isEqualTo _activeId && { _accepted isEqualType true && { _accepted } }) then
{
    _initState = "ASSIGNED";
};

// Syntax per Task Framework: [owner, taskId, description, destination, state, priority, showNotification, type, shared] call BIS_fnc_taskCreate
[true, _taskIdParam, [_desc, _title, ""], _pos, _initState, 1, true, _taskType, false] call BIS_fnc_taskCreate;
true

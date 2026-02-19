/*
    Client wrapper: submit an airbase clearance request to server.
    Params: [STRING requestType, OBJECT aircraft, NUMBER priority, STRING source, STRING lane, STRING incidentType, STRING priorityClassOverride]
*/
if (!hasInterface) exitWith {false};

params [
    ["_requestType", "", [""]],
    ["_aircraft", objNull, [objNull]],
    ["_priority", 0, [0]],
    ["_source", "PLAYER", [""]],
    ["_lane", "", [""]],
    ["_incidentType", "", [""]],
    ["_priorityClassOverride", "", [""]]
];

[player, _requestType, _aircraft, _priority, _source, _lane, _incidentType, _priorityClassOverride] remoteExec ["ARC_fnc_airbaseSubmitClearanceRequest", 2];
true

/*
    Client wrapper: submit an airbase clearance request to server.
    Params: [STRING requestType, OBJECT aircraft, NUMBER priority]
*/
if (!hasInterface) exitWith {false};

params [
    ["_requestType", "", [""]],
    ["_aircraft", objNull, [objNull]],
    ["_priority", 0, [0]]
];

[player, _requestType, _aircraft, _priority] remoteExec ["ARC_fnc_airbaseSubmitClearanceRequest", 2];
true

/* Client wrapper: request server prioritize queued flight. */
if (!hasInterface) exitWith {false};
params [["_flightId", "", [""]]];
[player, _flightId] remoteExec ["ARC_fnc_airbaseRequestPrioritizeFlight", 2];
true

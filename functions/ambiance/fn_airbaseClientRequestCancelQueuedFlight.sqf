/* Client wrapper: request server cancel queued flight. */
if (!hasInterface) exitWith {false};
params [["_flightId", "", [""]]];
[player, _flightId] remoteExec ["ARC_fnc_airbaseRequestCancelQueuedFlight", 2];
true

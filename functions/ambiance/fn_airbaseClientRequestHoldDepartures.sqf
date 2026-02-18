/* Client wrapper: request server hold departures. */
if (!hasInterface) exitWith {false};
[player] remoteExec ["ARC_fnc_airbaseRequestHoldDepartures", 2];
true

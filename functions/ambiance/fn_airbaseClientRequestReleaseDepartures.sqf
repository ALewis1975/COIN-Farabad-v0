/* Client wrapper: request server release departures. */
if (!hasInterface) exitWith {false};
[player] remoteExec ["ARC_fnc_airbaseRequestReleaseDepartures", 2];
true

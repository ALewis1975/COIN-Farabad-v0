/* Client wrapper: mark pending clearance request as emergency. Params: [STRING requestId] */
if (!hasInterface) exitWith {false};

params [["_requestId", "", [""]]];
[player, _requestId] remoteExec ["ARC_fnc_airbaseMarkClearanceEmergency", 2];
true

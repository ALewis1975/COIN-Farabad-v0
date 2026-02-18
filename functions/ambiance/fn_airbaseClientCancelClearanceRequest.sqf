/* Client wrapper: cancel a pending clearance request. Params: [STRING requestId] */
if (!hasInterface) exitWith {false};

params [["_requestId", "", [""]]];
[player, _requestId] remoteExec ["ARC_fnc_airbaseCancelClearanceRequest", 2];
true

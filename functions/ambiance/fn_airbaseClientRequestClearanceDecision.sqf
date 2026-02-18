params [
    ["_requestId", "", [""]],
    ["_approve", true, [true]],
    ["_reason", "", [""]]
];

[player, _requestId, _approve, _reason] remoteExec ["ARC_fnc_airbaseRequestClearanceDecision", 2];
true

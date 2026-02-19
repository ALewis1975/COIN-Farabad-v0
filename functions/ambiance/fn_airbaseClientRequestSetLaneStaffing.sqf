/* Client wrapper: request server lane staffing claim/release. */
if (!hasInterface) exitWith {false};
params [
    ["_laneId", "", [""]],
    ["_claim", true, [true]]
];
[player, _laneId, _claim] remoteExec ["ARC_fnc_airbaseRequestSetLaneStaffing", 2];
true

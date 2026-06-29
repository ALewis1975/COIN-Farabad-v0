/* Client wrapper: request server queue a specific parked asset for departure. */
if (!hasInterface) exitWith { false };
params [["_assetId", "", [""]]];
[player, _assetId] remoteExec ["ARC_fnc_airbaseRequestQueueParkedAsset", 2];
true

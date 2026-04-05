/*
    ARC_fnc_dynamicTodGetPolicy

    Returns current shared dynamic TOD policy.
    Server refreshes lazily if needed; clients read replicated values.

    Returns: HASHMAP
*/

private _has = !(isNil { missionNamespace getVariable "ARC_dynamic_tod_phase" });
if (isServer && { !_has }) then
{
    [] call ARC_fnc_dynamicTodRefresh;
};

private _out = createHashMap;
_out set ["phase", missionNamespace getVariable ["ARC_dynamic_tod_phase", "DAY"]];
_out set ["profile", missionNamespace getVariable ["ARC_dynamic_tod_profile", "STANDARD"]];
_out set ["tod", missionNamespace getVariable ["ARC_dynamic_tod_tod", dayTime]];
_out set ["canSpawnCivil", missionNamespace getVariable ["ARC_dynamic_tod_canSpawnCivil", true]];
_out set ["canSpawnAirbase", missionNamespace getVariable ["ARC_dynamic_tod_canSpawnAirbase", true]];
_out set ["canSpawnThreat", missionNamespace getVariable ["ARC_dynamic_tod_canSpawnThreat", true]];
_out set ["canSpawnOps", missionNamespace getVariable ["ARC_dynamic_tod_canSpawnOps", true]];
_out

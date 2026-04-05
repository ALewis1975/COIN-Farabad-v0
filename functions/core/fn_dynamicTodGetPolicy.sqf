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

private _phase = missionNamespace getVariable ["ARC_dynamic_tod_phase", "DAY"];
private _profile = missionNamespace getVariable ["ARC_dynamic_tod_profile", "STANDARD"];
private _tod = missionNamespace getVariable ["ARC_dynamic_tod_tod", dayTime];
private _canSpawnCivil = missionNamespace getVariable ["ARC_dynamic_tod_canSpawnCivil", true];
private _canSpawnAirbase = missionNamespace getVariable ["ARC_dynamic_tod_canSpawnAirbase", true];
private _canSpawnThreat = missionNamespace getVariable ["ARC_dynamic_tod_canSpawnThreat", true];
private _canSpawnOps = missionNamespace getVariable ["ARC_dynamic_tod_canSpawnOps", true];

if (!(_phase isEqualType "")) then { _phase = "DAY"; };
if (!(_profile isEqualType "")) then { _profile = "STANDARD"; };
if (!(_tod isEqualType 0)) then { _tod = dayTime; };
if (!(_canSpawnCivil isEqualType true) && !(_canSpawnCivil isEqualType false)) then { _canSpawnCivil = true; };
if (!(_canSpawnAirbase isEqualType true) && !(_canSpawnAirbase isEqualType false)) then { _canSpawnAirbase = true; };
if (!(_canSpawnThreat isEqualType true) && !(_canSpawnThreat isEqualType false)) then { _canSpawnThreat = true; };
if (!(_canSpawnOps isEqualType true) && !(_canSpawnOps isEqualType false)) then { _canSpawnOps = true; };

private _out = createHashMap;
_out set ["phase", _phase];
_out set ["profile", _profile];
_out set ["tod", _tod];
_out set ["canSpawnCivil", _canSpawnCivil];
_out set ["canSpawnAirbase", _canSpawnAirbase];
_out set ["canSpawnThreat", _canSpawnThreat];
_out set ["canSpawnOps", _canSpawnOps];
_out

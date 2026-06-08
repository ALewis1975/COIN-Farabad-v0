/*
    ARC_fnc_dynamicTodGetPolicy

    Legacy compatibility adapter for the canonical Time / Tempo Policy getter.
    Existing callers keep receiving the original dynamic TOD payload shape.

    Returns: HASHMAP
*/

if (isNil "ARC_fnc_timePolicyGet") then {
    ARC_fnc_timePolicyGet = compile preprocessFileLineNumbers "functions\\core\\fn_timePolicyGet.sqf";
};

private _policy = [] call ARC_fnc_timePolicyGet;
if (!(_policy isEqualType createHashMap)) then { _policy = createHashMap; };

private _phase = _policy getOrDefault ["phase", "DAY"];
private _profile = _policy getOrDefault ["profile", "STANDARD"];
private _tod = _policy getOrDefault ["tod", dayTime];
private _canSpawnCivil = _policy getOrDefault ["canSpawnCivil", true];
private _canSpawnAirbase = _policy getOrDefault ["canSpawnAirbase", true];
private _canSpawnThreat = _policy getOrDefault ["canSpawnThreat", true];
private _canSpawnOps = _policy getOrDefault ["canSpawnOps", true];

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
_out;

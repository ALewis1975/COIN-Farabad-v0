/*
    ARC_fnc_baseServicesInit

    Initializes base-services campaign actor state.
*/

if (!isServer) exitWith {false};

private _enabled = ["baseServices_v1_enabled", true] call ARC_fnc_stateGet;
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
["baseServices_v1_enabled", _enabled] call ARC_fnc_stateSet;
missionNamespace setVariable ["baseServices_v1_enabled", _enabled, true];
if (!_enabled) exitWith {false};

private _version = ["baseServices_v1_version", 1] call ARC_fnc_stateGet;
if (!(_version isEqualType 0) || { _version < 1 }) then { _version = 1; };
["baseServices_v1_version", _version] call ARC_fnc_stateSet;

private _services = ["baseServices_v1_services", []] call ARC_fnc_stateGet;
if (!(_services isEqualType []) || { (count _services) == 0 }) then
{
    _services = [
        ["MAYOR", "COMMAND", 1.0, "Base command and civil-military coordination"],
        ["S1", "MANPOWER", 1.0, "Personnel accountability and replacement flow"],
        ["S4", "SUPPLY", 1.0, "Supply, fuel, ammunition, and equipment throughput"],
        ["MED", "MEDICAL", 1.0, "Aid station and CASEVAC coordination"]
    ];
};
["baseServices_v1_services", _services] call ARC_fnc_stateSet;

private _snapshot = [] call ARC_fnc_baseServicesSnapshot;
["baseServices_v1_snapshot", _snapshot] call ARC_fnc_stateSet;
missionNamespace setVariable ["ARC_pub_baseServices", _snapshot, true];

true

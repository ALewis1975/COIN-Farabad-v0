/*
    ARC_fnc_civsubCivRegisterSpawn

    Registers a spawned civilian into the CIVSUB registry.

    Params:
      0: unit (object)
      1: districtId (string)

    Returns: key (string)
*/

if (!isServer) exitWith {""};

params [
    ["_unit", objNull, [objNull]],
    ["_districtId", "", [""]]
];
if (isNull _unit) exitWith {""};

private _districtIdNorm = toUpper (trim _districtId);
if !([_districtIdNorm] call ARC_fnc_worldIsValidDistrictId) then
{
    _districtIdNorm = [getPosATL _unit] call ARC_fnc_threadResolveDistrictId;
    if !([_districtIdNorm] call ARC_fnc_worldIsValidDistrictId) then { _districtIdNorm = ""; };
};

private _key = netId _unit;
if (_key isEqualTo "") then { _key = str _unit; };

private _reg = missionNamespace getVariable ["civsub_v1_civ_registry", createHashMap];
if !(_reg isEqualType createHashMap) then { _reg = createHashMap; };

private _row = createHashMap;
_row set ["unit", _unit];
_row set ["districtId", _districtIdNorm];
_row set ["civ_uid", _unit getVariable ["civ_uid", ""]];
_row set ["spawnPos", getPosATL _unit];
_row set ["spawnTs", serverTime];

_reg set [_key, _row];
missionNamespace setVariable ["civsub_v1_civ_registry", _reg, true];

_key

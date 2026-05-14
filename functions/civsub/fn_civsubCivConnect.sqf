/*
    ARC_fnc_civsubCivConnect

    Server-side idempotent CIVSUB hookup for any civilian unit, regardless of
    which mission subsystem spawned it.

    Params:
      0: unit (object)
      1: districtId override (string, optional)
      2: source label (string, optional)

    Returns: bool
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

params [
    ["_unit", objNull, [objNull]],
    ["_districtId", "", [""]],
    ["_source", "AUTO", [""]]
];

if (isNull _unit) exitWith {false};
if !(alive _unit) exitWith {false};
if (isPlayer _unit) exitWith {false};
if !(_unit isKindOf "CAManBase") exitWith {false};
if !(side _unit isEqualTo civilian) exitWith {false};

private _trimFn = compile "params ['_s']; trim _s";
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _did = toUpper ([_districtId] call _trimFn);

if !([_did] call ARC_fnc_worldIsValidDistrictId) then
{
    private _existingDid = _unit getVariable ["civsub_districtId", ""];
    if (_existingDid isEqualType "") then
    {
        _existingDid = toUpper ([_existingDid] call _trimFn);
        if ([_existingDid] call ARC_fnc_worldIsValidDistrictId) then { _did = _existingDid; };
    };
};

if !([_did] call ARC_fnc_worldIsValidDistrictId) then
{
    _did = [getPosATL _unit] call ARC_fnc_civsubDistrictsFindByPos;
};

if !([_did] call ARC_fnc_worldIsValidDistrictId) exitWith
{
    diag_log format ["[CIVSUB][WARN] ARC_fnc_civsubCivConnect: skipped source=%1 unit=%2 pos=%3 reason=no district", _source, _unit, getPosATL _unit];
    false
};

private _assigned = [_unit, _did] call ARC_fnc_civsubCivAssignIdentity;
if (!_assigned) exitWith
{
    diag_log format ["[CIVSUB][WARN] ARC_fnc_civsubCivConnect: identity assignment failed source=%1 unit=%2 district=%3", _source, _unit, _did];
    false
};

private _key = [_unit, _did] call ARC_fnc_civsubCivRegisterSpawn;
if (_key isEqualTo "") exitWith
{
    diag_log format ["[CIVSUB][WARN] ARC_fnc_civsubCivConnect: registry insert failed source=%1 unit=%2 district=%3", _source, _unit, _did];
    false
};

private _reg = missionNamespace getVariable ["civsub_v1_civ_registry", createHashMap];
if (_reg isEqualType createHashMap) then
{
    private _row = [_reg, _key, createHashMap] call _hg;
    if (_row isEqualType createHashMap) then
    {
        _row set ["connectSource", _source];
        _row set ["connectTs", serverTime];
        _reg set [_key, _row];
        missionNamespace setVariable ["civsub_v1_civ_registry", _reg, true];
    };
};

_unit setVariable ["civsub_v1_connectSource", _source, true];
if (true) exitWith {true};

/*
    ARC_fnc_civsubOnCivKilled

    Server-side: CIVSUB civilian casualty attribution + delta emission.

    Params:
      0: civ unit (object)
      1: killer (object)
      2: instigator (object)
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

params [
    ["_civ", objNull, [objNull]],
    ["_killer", objNull, [objNull]],
    ["_instigator", objNull, [objNull]]
];

if (isNull _civ) exitWith {false};

// sqflint-compat helpers
private _hmFrom   = compile "params ['_pairs']; private _r = createHashMap; { _r set [_x select 0, _x select 1]; } forEach _pairs; _r";

private _src = if (!isNull _instigator) then { _instigator } else { _killer };

private _attribSide = "UNKNOWN";
private _attribConf = 0.30;

if (!isNull _instigator) then { _attribConf = 1.00; } else {
    if (!isNull _killer) then { _attribConf = 0.70; };
};

if (!isNull _src) then
{
    switch (side _src) do
    {
        case west: { _attribSide = "BLUFOR"; };
        case east: { _attribSide = "OPFOR"; };
        default { _attribSide = "OTHER"; };
    };
};

private _did = _civ getVariable ["civsub_districtId", ""];
if (_did isEqualTo "") then {
    _did = [getPosATL _civ] call ARC_fnc_civsubDistrictsFindByPos;
};
if (_did isEqualTo "") exitWith {false};

private _actorUid = "";
if (!isNull _src && {isPlayer _src}) then { _actorUid = getPlayerUID _src; };

private _payload = [[
    ["attrib_side", _attribSide],
    ["attrib_conf", _attribConf]
]] call _hmFrom;

[_did, "CIV_KILLED", "HARM", _payload, _actorUid] call ARC_fnc_civsubEmitDelta;

true

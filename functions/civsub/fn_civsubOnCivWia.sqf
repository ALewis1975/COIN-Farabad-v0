/*
    ARC_fnc_civsubOnCivWia

    Server-side: CIVSUB civilian WIA attribution + delta emission.

    Params:
      0: civ unit (object)
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

params [
    ["_civ", objNull, [objNull]]
];

if (isNull _civ) exitWith {false};
if !(alive _civ) exitWith {false};
if !(side _civ isEqualTo civilian) exitWith {false};
if !(_civ getVariable ["civsub_v1_isCiv", false]) exitWith {false};

// Best-effort: ACE stores last damage source on the unit.
// Var name differs across older scripts/builds; we check both.
private _src = _civ getVariable ["ace_medical_lastDamageSource", objNull];
if (isNull _src) then { _src = _civ getVariable ["ACE_medical_lastDamageSource", objNull]; };

private _attribSide = "UNKNOWN";
private _attribConf = 0.30;
if (!isNull _src) then { _attribConf = 0.70; };

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

private _payload = createHashMapFromArray [
    ["attrib_side", _attribSide],
    ["attrib_conf", _attribConf]
];

[_did, "CIV_WIA", "HARM", _payload, _actorUid] call ARC_fnc_civsubEmitDelta;

true

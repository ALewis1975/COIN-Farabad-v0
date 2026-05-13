/*
    Infer normalized threat family from type/subtype while preserving legacy inputs.

    Params:
      0: STRING type
      1: STRING subtype

    Returns:
      STRING family ("IED" | "VBIED" | "SUICIDE" | "NON_IED")
*/

params [
    ["_type", "", [""]],
    ["_subtype", "", [""]]
];

private _trimFn = compile "params ['_s']; trim _s";
private _typeU = toUpper ([_type] call _trimFn);
private _subtypeU = toUpper ([_subtype] call _trimFn);

private _family = "NON_IED";

if (_subtypeU isEqualTo "VBIED" || { (_subtypeU find "VBIED_") isEqualTo 0 }) exitWith { "VBIED" };
if (_subtypeU isEqualTo "SUICIDE" || { (_subtypeU find "SUICIDE_") isEqualTo 0 } || { (_subtypeU find "SB_") isEqualTo 0 }) exitWith { "SUICIDE" };
if ((_subtypeU find "IED_") isEqualTo 0) exitWith { "IED" };
if (_typeU in ["IED", "VBIED", "SUICIDE"]) then { _family = _typeU; };

_family

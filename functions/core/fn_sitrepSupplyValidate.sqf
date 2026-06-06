/* Validate and sanitize client-submitted SITREP Supply Annex payload. */
params [["_payload", [], [[]]]];
private _trimFn = compile "params ['_s']; trim _s";

private _get = {
    params ["_pairs", "_key", "_def"];
    private _out = _def;
    if (_pairs isEqualType []) then
    {
        { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _out = _x select 1; }; } forEach _pairs;
    };
    _out
};
private _enum = {
    params ["_v", "_allowed", "_def"];
    if (!(_v isEqualType "")) then { _v = _def; };
    _v = toUpper ([_v] call _trimFn);
    if !(_v in _allowed) then { _v = _def; };
    _v
};
private _txt = {
    params ["_v", ["_max", 400]];
    if (!(_v isEqualType "")) then { _v = ""; };
    _v = [_v] call _trimFn;
    if ((count _v) > _max) then { _v = _v select [0, _max]; };
    _v
};
private _num = {
    params ["_v"];
    if (_v isEqualType "") then { _v = parseNumber _v; };
    if (!(_v isEqualType 0)) then { _v = 0; };
    (round _v) max 0
};
private _bool = {
    params ["_v"];
    if (_v isEqualType true || { _v isEqualType false }) exitWith { _v };
    if (_v isEqualType "") exitWith { (toUpper ([_v] call _trimFn)) in ["YES", "TRUE", "1"] };
    false
};

private _expAllowed = ["NONE", "LIGHT", "MODERATE", "HEAVY", "CRITICAL"];
private _medAllowed = ["NONE", "LIGHT", "MODERATE", "HEAVY"];
private _laceAllowed = ["GREEN", "AMBER", "RED"];
private _exp = [_payload, "ammo_expended", []] call _get;
private _ending = [_payload, "ending_lace", []] call _get;

[
    ["ammo_expended", [
        ["small_arms", [[_exp, "small_arms", "NONE"] call _get, _expAllowed, "NONE"] call _enum],
        ["mg", [[_exp, "mg", "NONE"] call _get, _expAllowed, "NONE"] call _enum],
        ["launcher", [[_exp, "launcher", "NONE"] call _get, _expAllowed, "NONE"] call _enum],
        ["grenades", [[_exp, "grenades", "NONE"] call _get, _expAllowed, "NONE"] call _enum],
        ["smoke", [[_exp, "smoke", "NONE"] call _get, _expAllowed, "NONE"] call _enum],
        ["explosives", [[_exp, "explosives", "NONE"] call _get, _expAllowed, "NONE"] call _enum]
    ]],
    ["medical_used", [[_payload, "medical_used", "NONE"] call _get, _medAllowed, "NONE"] call _enum],
    ["equipment_lost", [[_payload, "equipment_lost", ""] call _get, 400] call _txt],
    ["equipment_damaged", [[_payload, "equipment_damaged", ""] call _get, 400] call _txt],
    ["vehicle_damage_notes", [[_payload, "vehicle_damage_notes", ""] call _get, 400] call _txt],
    ["casualties", [
        ["kia", [[_payload, "kia", 0] call _get] call _num],
        ["wia", [[_payload, "wia", 0] call _get] call _num],
        ["unconscious", [[_payload, "unconscious", 0] call _get] call _num],
        ["casevac_required", [[_payload, "casevac_required", false] call _get] call _bool]
    ]],
    ["ending_lace", [
        ["liquids", [[_ending, "liquids", "GREEN"] call _get, _laceAllowed, "GREEN"] call _enum],
        ["ammo", [[_ending, "ammo", "GREEN"] call _get, _laceAllowed, "GREEN"] call _enum],
        ["casualties", [[_ending, "casualties", "GREEN"] call _get, _laceAllowed, "GREEN"] call _enum],
        ["equipment", [[_ending, "equipment", "GREEN"] call _get, _laceAllowed, "GREEN"] call _enum],
        ["overall", [[_ending, "overall", "GREEN"] call _get, _laceAllowed, "GREEN"] call _enum]
    ]],
    ["remaining_limitations", [[_payload, "remaining_limitations", ""] call _get, 500] call _txt],
    ["refit_recommended", [[_payload, "refit_recommended", false] call _get] call _bool],
    ["resupply_recommended", [[_payload, "resupply_recommended", false] call _get] call _bool]
]

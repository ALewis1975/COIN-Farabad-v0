/* Format Supply Annex and readiness/METT-TC lines for SITREP details. */
params [["_annex", [], [[]]], ["_delta", [], [[]]], ["_mett", [], [[]]]];
private _get = {
    params ["_pairs", "_key", "_def"];
    private _out = _def;
    { if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _key }) exitWith { _out = _x select 1; }; } forEach _pairs;
    _out
};
private _exp = [_annex, "ammo_expended", []] call _get;
private _cas = [_annex, "casualties", []] call _get;
private _lace = [_annex, "ending_lace", []] call _get;
private _lines = ["SUPPLY ANNEX"];
_lines pushBack format ["STARTDISP: %1", [_annex, "startdisp_id", "NONE"] call _get];
_lines pushBack format ["AMMO EXPENDED: SA=%1 | MG=%2 | LDR=%3 | GRN=%4 | SMK=%5 | EXP=%6", [_exp, "small_arms", "NONE"] call _get, [_exp, "mg", "NONE"] call _get, [_exp, "launcher", "NONE"] call _get, [_exp, "grenades", "NONE"] call _get, [_exp, "smoke", "NONE"] call _get, [_exp, "explosives", "NONE"] call _get];
_lines pushBack format ["MEDICAL USED: %1", [_annex, "medical_used", "NONE"] call _get];
_lines pushBack format ["CASUALTIES: KIA=%1 | WIA=%2 | UNCON=%3 | CASEVAC=%4", [_cas, "kia", 0] call _get, [_cas, "wia", 0] call _get, [_cas, "unconscious", 0] call _get, if ([_cas, "casevac_required", false] call _get) then { "YES" } else { "NO" }];
_lines pushBack format ["ENDING LACE: L=%1 | A=%2 | C=%3 | E=%4 | OVERALL=%5", [_lace, "liquids", "GREEN"] call _get, [_lace, "ammo", "GREEN"] call _get, [_lace, "casualties", "GREEN"] call _get, [_lace, "equipment", "GREEN"] call _get, [_lace, "overall", "GREEN"] call _get];
private _lost = [_annex, "equipment_lost", ""] call _get;
private _dam = [_annex, "equipment_damaged", ""] call _get;
private _veh = [_annex, "vehicle_damage_notes", ""] call _get;
private _lim = [_annex, "remaining_limitations", ""] call _get;
if !(_lost isEqualTo "") then { _lines pushBack format ["EQUIPMENT LOST: %1", _lost]; };
if !(_dam isEqualTo "") then { _lines pushBack format ["EQUIPMENT DAMAGED: %1", _dam]; };
if !(_veh isEqualTo "") then { _lines pushBack format ["VEHICLE DAMAGE/LOSS: %1", _veh]; };
if !(_lim isEqualTo "") then { _lines pushBack format ["REMAINING LIMITATIONS: %1", _lim]; };
_lines pushBack format ["RECOMMENDATIONS: REFIT=%1 | RESUPPLY=%2", if ([_annex, "refit_recommended", false] call _get) then { "YES" } else { "NO" }, if ([_annex, "resupply_recommended", false] call _get) then { "YES" } else { "NO" }];
_lines pushBack "READINESS DELTA";
{ if (_x isEqualType [] && { (count _x) >= 4 }) then { _lines pushBack format ["%1: %2 -> %3 (delta %4)", toUpper (_x select 0), _x select 1, _x select 2, _x select 3]; }; } forEach ([_delta, "lace_delta", []] call _get);
_lines pushBack format ["METT-TC FOLLOW-ON BIAS: %1 | PRESSURE: %2", [_mett, "recommended_follow_on_bias", "PROCEED"] call _get, [_mett, "supply_pressure", "NORMAL"] call _get];
_lines

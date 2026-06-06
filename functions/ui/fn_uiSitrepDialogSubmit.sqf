/*
    ARC_fnc_uiSitrepDialogSubmit

    Client: collect inputs from ARC_SitrepDialog and store the result.

    Result format (uiNamespace var ARC_sitrepDialog_result):
      [
        okBool,
        summary,
        enemy,
        friendly,
        taskStatus,
        aceAmmo,
        aceCas,
        aceEq,
        requests,
        notes
      ]
*/

if (!hasInterface) exitWith {false};

private _disp = findDisplay 77301;
if (isNull _disp) exitWith {false};
private _trimFn = compile "params ['_s']; trim _s";

private _getText = {
    params ["_idc"];
    private _c = _disp displayCtrl _idc;
    if (isNull _c) exitWith {""};
    ctrlText _c
};

private _summary  = [[77310] call _getText] call _trimFn;
private _enemy    = [[77311] call _getText] call _trimFn;
private _friendly = [[77312] call _getText] call _trimFn;
private _task     = [[77313] call _getText] call _trimFn;
private _req      = [[77314] call _getText] call _trimFn;
private _notes    = [[77315] call _getText] call _trimFn;

private _cA = _disp displayCtrl 77321;
private _cC = _disp displayCtrl 77322;
private _cE = _disp displayCtrl 77323;

private _aceAmmo = if (isNull _cA) then {"GREEN"} else { _cA lbText (lbCurSel _cA) };
private _aceCas  = if (isNull _cC) then {"GREEN"} else { _cC lbText (lbCurSel _cC) };
private _aceEq   = if (isNull _cE) then {"GREEN"} else { _cE lbText (lbCurSel _cE) };

_aceAmmo = toUpper ([_aceAmmo] call _trimFn);
_aceCas  = toUpper ([_aceCas] call _trimFn);
_aceEq   = toUpper ([_aceEq] call _trimFn);

private _comboText = {
    params ["_idc", ["_def", "NONE"]];
    private _c = _disp displayCtrl _idc;
    if (isNull _c) exitWith { _def };
    private _i = lbCurSel _c;
    if (_i < 0) exitWith { _def };
    toUpper ([_c lbText _i] call _trimFn)
};
private _numText = {
    params ["_idc"];
    private _v = parseNumber ([_idc] call _getText);
    (round _v) max 0
};
private _yesNo = {
    params ["_idc"];
    (([_idc, "NO"] call _comboText) isEqualTo "YES")
};

private _overallLace = "GREEN";
if (_aceAmmo isEqualTo "RED" || { _aceCas isEqualTo "RED" || { _aceEq isEqualTo "RED" } }) then
{
    _overallLace = "RED";
}
else
{
    if (_aceAmmo isEqualTo "AMBER" || { _aceCas isEqualTo "AMBER" || { _aceEq isEqualTo "AMBER" } }) then { _overallLace = "AMBER"; };
};

private _supplyPayload = [
    ["ammo_expended", [["small_arms", [77331, "NONE"] call _comboText], ["grenades", [77332, "NONE"] call _comboText], ["smoke", [77333, "NONE"] call _comboText], ["mg", "NONE"], ["launcher", "NONE"], ["explosives", "NONE"]]],
    ["medical_used", [77334, "NONE"] call _comboText],
    ["equipment_lost", [[77335] call _getText] call _trimFn],
    ["equipment_damaged", [[77336] call _getText] call _trimFn],
    ["vehicle_damage_notes", [[77337] call _getText] call _trimFn],
    ["kia", [77338] call _numText],
    ["wia", [77339] call _numText],
    ["unconscious", 0],
    ["casevac_required", [77343] call _yesNo],
    ["ending_lace", [["liquids", "GREEN"], ["ammo", _aceAmmo], ["casualties", _aceCas], ["equipment", _aceEq], ["overall", _overallLace]]],
    ["remaining_limitations", [[77340] call _getText] call _trimFn],
    ["refit_recommended", [77344] call _yesNo],
    ["resupply_recommended", [77345] call _yesNo]
];

uiNamespace setVariable [
    "ARC_sitrepDialog_result",
    [true, _summary, _enemy, _friendly, _task, _aceAmmo, _aceCas, _aceEq, _req, _notes, _supplyPayload]
];
closeDialog 1;
true

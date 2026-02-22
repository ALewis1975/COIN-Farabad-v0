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

private _getText = {
    params ["_idc"];
    private _c = _disp displayCtrl _idc;
    if (isNull _c) exitWith {""};
    ctrlText _c
};

private _summary  = trim ([77310] call _getText);
private _enemy    = trim ([77311] call _getText);
private _friendly = trim ([77312] call _getText);
private _task     = trim ([77313] call _getText);
private _req      = trim ([77314] call _getText);
private _notes    = trim ([77315] call _getText);

private _cA = _disp displayCtrl 77321;
private _cC = _disp displayCtrl 77322;
private _cE = _disp displayCtrl 77323;

private _aceAmmo = if (isNull _cA) then {"GREEN"} else { _cA lbText (lbCurSel _cA) };
private _aceCas  = if (isNull _cC) then {"GREEN"} else { _cC lbText (lbCurSel _cC) };
private _aceEq   = if (isNull _cE) then {"GREEN"} else { _cE lbText (lbCurSel _cE) };

_aceAmmo = toUpper (trim _aceAmmo);
_aceCas  = toUpper (trim _aceCas);
_aceEq   = toUpper (trim _aceEq);

uiNamespace setVariable [
    "ARC_sitrepDialog_result",
    [true, _summary, _enemy, _friendly, _task, _aceAmmo, _aceCas, _aceEq, _req, _notes]
];
closeDialog 1;
true

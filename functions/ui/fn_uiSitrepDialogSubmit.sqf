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

// sqflint-compatible helpers
private _trimFn  = compile "params ['_s']; trim _s";
    private _c = _disp displayCtrl _idc;
    if (isNull _c) exitWith {""};
    ctrlText _c
};

private _summary  = [([77310] call _getText)] call _trimFn;
private _enemy    = [([77311] call _getText)] call _trimFn;
private _friendly = [([77312] call _getText)] call _trimFn;
private _task     = [([77313] call _getText)] call _trimFn;
private _req      = [([77314] call _getText)] call _trimFn;
private _notes    = [([77315] call _getText)] call _trimFn;

private _cA = _disp displayCtrl 77321;
private _cC = _disp displayCtrl 77322;
private _cE = _disp displayCtrl 77323;

private _aceAmmo = if (isNull _cA) then {"GREEN"} else { _cA lbText (lbCurSel _cA) };
private _aceCas  = if (isNull _cC) then {"GREEN"} else { _cC lbText (lbCurSel _cC) };
private _aceEq   = if (isNull _cE) then {"GREEN"} else { _cE lbText (lbCurSel _cE) };

_aceAmmo = toUpper ([_aceAmmo] call _trimFn);
_aceCas  = toUpper ([_aceCas] call _trimFn);
_aceEq   = toUpper ([_aceEq] call _trimFn);

uiNamespace setVariable [
    "ARC_sitrepDialog_result",
    [true, _summary, _enemy, _friendly, _task, _aceAmmo, _aceCas, _aceEq, _req, _notes]
];
closeDialog 1;
true

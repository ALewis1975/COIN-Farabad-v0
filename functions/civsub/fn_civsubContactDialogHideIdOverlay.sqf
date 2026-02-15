/*
    ARC_fnc_civsubContactDialogHideIdOverlay

    Client-side: hides the embedded ID card overlay and returns to the normal action/question view.
*/
if (!hasInterface) exitWith { true };

private _d = uiNamespace getVariable ["ARC_civsubInteract_display", displayNull];
if (isNull _d) then { _d = findDisplay 78300; };
if (isNull _d) exitWith { true };

{
    private _c = _d displayCtrl _x;
    if (!isNull _c) then { _c ctrlShow false; };
} forEach [78360, 78361, 78362];



private _btnExec = _d displayCtrl 78330;
private _btnClose = _d displayCtrl 78331;
if (!isNull _btnExec) then { _btnExec ctrlEnable true; };
if (!isNull _btnClose) then { _btnClose ctrlEnable true; };

private _lbA = _d displayCtrl 78310;
if (!isNull _lbA) then { ctrlSetFocus _lbA; };

true
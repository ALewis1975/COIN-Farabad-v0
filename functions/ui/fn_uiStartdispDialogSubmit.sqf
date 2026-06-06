/* Collect STARTDISP dialog input and submit to server. */
if (!hasInterface) exitWith { false };
private _disp = findDisplay 77401;
if (isNull _disp) exitWith { false };
private _trimFn = compile "params ['_s']; trim _s";
private _comboText = {
    params ["_idc", ["_def", "GREEN"]];
    private _c = _disp displayCtrl _idc;
    if (isNull _c) exitWith { _def };
    private _i = lbCurSel _c;
    if (_i < 0) exitWith { _def };
    toUpper ([_c lbText _i] call _trimFn)
};
private _getText = {
    params ["_idc"];
    private _c = _disp displayCtrl _idc;
    if (isNull _c) exitWith { "" };
    [ctrlText _c] call _trimFn
};
private _confirmed = (([77441, "NO"] call _comboText) isEqualTo "YES");
if (!_confirmed) exitWith
{
    ["STARTDISP", "Confirm acceptance before submitting."] call ARC_fnc_clientToast;
    false
};
private _addReq = (([77431, "NO"] call _comboText) isEqualTo "YES");
private _lace = [
    ["liquids", [77421, "GREEN"] call _comboText],
    ["ammo", [77422, "GREEN"] call _comboText],
    ["casualties", [77423, "GREEN"] call _comboText],
    ["equipment", [77424, "GREEN"] call _comboText],
    ["overall", [77425, "GREEN"] call _comboText]
];
private _def = [77411] call _getText;
private _notes = [77412] call _getText;
["INCIDENT_ACCEPT", "SUBMITTING", "STARTDISP submitted; awaiting server acceptance.", 10] call ARC_fnc_uiConsoleOpsActionStatus;
[player, _lace, _def, _addReq, _notes] remoteExec ["ARC_fnc_startdispSubmitAndAccept", 2];
closeDialog 1;
true

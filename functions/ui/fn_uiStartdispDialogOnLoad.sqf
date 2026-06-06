/* Initialize STARTDISP dialog controls. */
if (!hasInterface) exitWith { false };
params [["_display", displayNull]];
if (isNull _display) exitWith { false };
private _fillLace = {
    params ["_ctrl"];
    if (isNull _ctrl) exitWith {};
    lbClear _ctrl;
    _ctrl lbAdd "GREEN";
    _ctrl lbAdd "AMBER";
    _ctrl lbAdd "RED";
    _ctrl lbSetCurSel 0;
};
{ [_display displayCtrl _x] call _fillLace; } forEach [77421, 77422, 77423, 77424, 77425];
{
    private _yn = _display displayCtrl _x;
    if (!isNull _yn) then { lbClear _yn; _yn lbAdd "NO"; _yn lbAdd "YES"; _yn lbSetCurSel 0; };
} forEach [77431, 77441];
private _hdr = _display displayCtrl 77492;
if (!isNull _hdr) then
{
    private _task = missionNamespace getVariable ["ARC_activeIncidentDisplayName", "Active Incident"];
    _hdr ctrlSetStructuredText parseText format ["<t size='0.95' color='#DDDDDD'>Record starting LACE and known deficiencies before accepting: %1.</t>", _task];
};
true

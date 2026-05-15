/*
    ARC_fnc_recruitDialogOnLoad

    Client: populate the AI recruitment dialog with public infantry classes from
    the player's current faction.

    Params:
      0: DISPLAY recruitment dialog

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

params [
    ["_display", displayNull, [displayNull]]
];

if (isNull _display) then { _display = findDisplay 78400; };
if (isNull _display) exitWith {false};

uiNamespace setVariable ["ARC_recruitDialog_display", _display];

private _list = _display displayCtrl 78410;
private _qty = _display displayCtrl 78420;
private _header = _display displayCtrl 78411;
private _status = _display displayCtrl 78412;

if (isNull _list || { isNull _qty } || { isNull _header } || { isNull _status }) exitWith
{
    diag_log "[ARC][WARN][RECRUIT] ARC_fnc_recruitDialogOnLoad: missing dialog controls";
    false
};

private _container = uiNamespace getVariable ["ARC_recruitDialog_container", objNull];
private _grp = group player;
private _side = side _grp;
private _sideNum = 1;
if (_side isEqualTo east) then { _sideNum = 0; };
if (_side isEqualTo west) then { _sideNum = 1; };
if (_side isEqualTo independent) then { _sideNum = 2; };
if (_side isEqualTo civilian) then { _sideNum = 3; };

private _faction = faction player;
private _cap = missionNamespace getVariable ["ARC_recruitGroupMaxUnits", 12];
if (!(_cap isEqualType 0)) then { _cap = 12; };
_cap = (_cap max 1) min 24;

private _current = 0;
{
    if (alive _x && { _x getVariable ["ARC_recruitedAI", false] }) then
    {
        _current = _current + 1;
    };
} forEach (units _grp);

private _remaining = _cap - _current;
if (_remaining < 0) then { _remaining = 0; };

_header ctrlSetStructuredText parseText format [
    "<t size='1.1'>Recruit AI</t><br/><t size='0.85'>Faction: %1 | Recruited AI: %2/%3</t>",
    _faction,
    _current,
    _cap
];

lbClear _list;
private _cfgVehicles = configFile >> "CfgVehicles";
{
    private _cfg = _x;
    private _class = configName _cfg;
    if ((getNumber (_cfg >> "scope")) < 2) then { continue; };
    if (!(_class isKindOf "CAManBase")) then { continue; };
    if ((getNumber (_cfg >> "side")) != _sideNum) then { continue; };
    if (!((getText (_cfg >> "faction")) isEqualTo _faction)) then { continue; };

    private _label = getText (_cfg >> "displayName");
    if (_label isEqualTo "") then { _label = _class; };

    private _idx = _list lbAdd _label;
    _list lbSetData [_idx, _class];
    _list lbSetTooltip [_idx, _class];
} forEach ("true" configClasses _cfgVehicles);

if ((lbSize _list) > 0) then { _list lbSetCurSel 0; };

lbClear _qty;
if (_remaining <= 0) then
{
    private _idxZero = _qty lbAdd "0";
    _qty lbSetValue [_idxZero, 0];
    _qty lbSetCurSel _idxZero;
}
else
{
    private _maxQty = _remaining min 12;
    for "_i" from 1 to _maxQty do
    {
        private _idxQty = _qty lbAdd str _i;
        _qty lbSetValue [_idxQty, _i];
    };
    _qty lbSetCurSel 0;
};

private _statusText = uiNamespace getVariable ["ARC_recruitDialog_status", ""];
if (_statusText isEqualTo "") then
{
    if (isNull _container) then
    {
        _statusText = "Recruitment object unavailable.";
    }
    else
    {
        if ((lbSize _list) <= 0) then
        {
            _statusText = "No infantry units found for your faction.";
        }
        else
        {
            _statusText = "Select an infantry type and quantity, then press Recruit.";
        };
    };
};

_status ctrlSetStructuredText parseText format ["<t size='0.9'>%1</t>", _statusText];

true

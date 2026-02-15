/*
    ARC_fnc_uiSitrepDialogOnLoad

    Client: initialize the structured SITREP dialog.

    Defaults are passed through uiNamespace variables:
      ARC_sitrepDialog_header
      ARC_sitrepDialog_defaultSummary
      ARC_sitrepDialog_defaultEnemy
      ARC_sitrepDialog_defaultFriendly
      ARC_sitrepDialog_defaultTask
      ARC_sitrepDialog_defaultRequests
      ARC_sitrepDialog_defaultNotes
      ARC_sitrepDialog_defaultACE  -> [ammoIdx, casIdx, eqIdx]
*/

if (!hasInterface) exitWith {false};

params ["_display"];
if (isNull _display) exitWith {false};

private _hdr = uiNamespace getVariable ["ARC_sitrepDialog_header", ""]; 
private _sum = uiNamespace getVariable ["ARC_sitrepDialog_defaultSummary", ""]; 
private _enemy = uiNamespace getVariable ["ARC_sitrepDialog_defaultEnemy", ""]; 
private _fr = uiNamespace getVariable ["ARC_sitrepDialog_defaultFriendly", ""]; 
private _task = uiNamespace getVariable ["ARC_sitrepDialog_defaultTask", ""]; 
private _req = uiNamespace getVariable ["ARC_sitrepDialog_defaultRequests", ""]; 
private _notes = uiNamespace getVariable ["ARC_sitrepDialog_defaultNotes", ""]; 

private _aceDef = uiNamespace getVariable ["ARC_sitrepDialog_defaultACE", [0,0,0]];
if (!(_aceDef isEqualType []) || { (count _aceDef) < 3 }) then { _aceDef = [0,0,0]; };

// Header
private _ctrlHdr = _display displayCtrl 77392;
if (!isNull _ctrlHdr) then
{
    if (_hdr isEqualTo "") then
    {
        _hdr = "<t size='0.95' color='#DDDDDD'>Provide a short, structured SITREP. Each field becomes a separate line in the report.</t>";
    };
    _ctrlHdr ctrlSetStructuredText parseText _hdr;
};

// Edits
{ 
    _x params ["_idc","_val"]; 
    private _c = _display displayCtrl _idc; 
    if (!isNull _c) then { _c ctrlSetText _val; }; 
} forEach [
    [77310, _sum],
    [77311, _enemy],
    [77312, _fr],
    [77313, _task],
    [77314, _req],
    [77315, _notes]
];

// ACE combos: Green / Yellow / Red
private _fillCombo = {
    params ["_ctrl", "_idx"]; 
    if (isNull _ctrl) exitWith {};
    lbClear _ctrl;
    _ctrl lbAdd "GREEN";
    _ctrl lbAdd "YELLOW";
    _ctrl lbAdd "RED";
    private _i = _idx;
    if !(_i isEqualType 0) then { _i = 0; };
    if (_i < 0 || {_i > 2}) then { _i = 0; };
    _ctrl lbSetCurSel _i;
};

[_display displayCtrl 77321, _aceDef # 0] call _fillCombo;
[_display displayCtrl 77322, _aceDef # 1] call _fillCombo;
[_display displayCtrl 77323, _aceDef # 2] call _fillCombo;

// Clear previous result
uiNamespace setVariable ["ARC_sitrepDialog_result", nil];

true

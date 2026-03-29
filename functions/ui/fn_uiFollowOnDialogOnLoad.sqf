/*
    ARC_fnc_uiFollowOnDialogOnLoad

    Client: onLoad handler for ARC_FollowOnDialog (IDD 78100).

    Populates dropdowns, applies defaults, and updates visibility based on request type.

    Result is stored in uiNamespace variable ARC_followOn_result by Submit/Cancel handlers.
*/

if (!hasInterface) exitWith {false};

params [
    ["_display", displayNull, [displayNull]]
];

if (isNull _display) exitWith {false};

// Clear any previous result
uiNamespace setVariable ["ARC_followOn_result", nil];

private _ctrlHeader = _display displayCtrl 78192;
private _ctrlTitle = _display displayCtrl 78191;

// Optional title override (used by TOC issue-order flow)
private _titleOverride = uiNamespace getVariable ["ARC_followOn_title", ""];
if (!(_titleOverride isEqualType "")) then { _titleOverride = ""; };
_titleOverride = trim _titleOverride;
if (!isNull _ctrlTitle && { !(_titleOverride isEqualTo "") }) then { _ctrlTitle ctrlSetText _titleOverride; };
private _cReq = _display displayCtrl 78102;
private _cPurpose = _display displayCtrl 78104;
private _cHoldIntent = _display displayCtrl 78106;
private _eHoldMin = _display displayCtrl 78108;
private _cProceed = _display displayCtrl 78110;

private _eRat = _display displayCtrl 78112;
private _eCon = _display displayCtrl 78114;
private _eSup = _display displayCtrl 78116;
private _eNote = _display displayCtrl 78118;

// Header context (best-effort)
private _taskName = missionNamespace getVariable ["ARC_activeIncidentDisplayName", ""]; 
if (!(_taskName isEqualType "")) then { _taskName = ""; };
_taskName = trim _taskName;
if (_taskName isEqualTo "") then { _taskName = "Active Task"; };

private _pos = getPosATL player;
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = [0,0,0]; };
_pos = +_pos; _pos resize 3;

private _grid = "";
if !((_pos select 0) isEqualTo 0 && {(_pos select 1) isEqualTo 0}) then { _grid = mapGridPosition _pos; };

private _grp = groupId (group player);
private _hdrTxt = format [
    "<t size='1.05' font='PuristaMedium'>%1</t><br/><t size='0.9' color='#CCCCCC'>From: %2%3</t>",
    _taskName,
    _grp,
    if (_grid isEqualTo "") then { "" } else { format [" | Grid: %1", _grid] }
];
private _hdrOverride = uiNamespace getVariable ["ARC_followOn_headerOverride", ""]; 
if (!(_hdrOverride isEqualType "")) then { _hdrOverride = ""; };
_hdrOverride = trim _hdrOverride;

if (!isNull _ctrlHeader) then
{
    if (!(_hdrOverride isEqualTo "")) then
    {
        _ctrlHeader ctrlSetStructuredText parseText _hdrOverride;
    }
    else
    {
        _ctrlHeader ctrlSetStructuredText parseText _hdrTxt;
    };
};

// Defaults
private _dReq = uiNamespace getVariable ["ARC_followOn_defaultRequest", "RTB"]; 
if (!(_dReq isEqualType "")) then { _dReq = "RTB"; };
_dReq = toUpper (trim _dReq);
if !(_dReq in ["RTB","HOLD","PROCEED"]) then { _dReq = "RTB"; };

private _dPurpose = uiNamespace getVariable ["ARC_followOn_defaultPurpose", "REFIT"]; 
if (!(_dPurpose isEqualType "")) then { _dPurpose = "REFIT"; };
_dPurpose = toUpper (trim _dPurpose);
if !(_dPurpose in ["REFIT","INTEL","EPW"]) then { _dPurpose = "REFIT"; };

private _dHoldIntent = uiNamespace getVariable ["ARC_followOn_defaultHoldIntent", "SECURITY"]; 
if (!(_dHoldIntent isEqualType "")) then { _dHoldIntent = "SECURITY"; };
_dHoldIntent = toUpper (trim _dHoldIntent);

private _dProceed = uiNamespace getVariable ["ARC_followOn_defaultProceedIntent", "NEXT TASK"]; 
if (!(_dProceed isEqualType "")) then { _dProceed = "NEXT TASK"; };
_dProceed = toUpper (trim _dProceed);

private _dHoldMin = uiNamespace getVariable ["ARC_followOn_defaultHoldMinutes", 30];
if (!(_dHoldMin isEqualType 0)) then { _dHoldMin = 30; };
_dHoldMin = (_dHoldMin max 0) min 240;

// Populate request combo
if (!isNull _cReq) then
{
    lbClear _cReq;
    _cReq lbAdd "RTB";
    _cReq lbAdd "HOLD";
    _cReq lbAdd "PROCEED";

    private _sel = ["RTB","HOLD","PROCEED"] find _dReq;
    if (_sel < 0) then { _sel = 0; };
    _cReq lbSetCurSel _sel;
};

// Populate RTB purpose combo
if (!isNull _cPurpose) then
{
    lbClear _cPurpose;
    _cPurpose lbAdd "REFIT";
    _cPurpose lbAdd "INTEL";
    _cPurpose lbAdd "EPW";

    private _selP = ["REFIT","INTEL","EPW"] find _dPurpose;
    if (_selP < 0) then { _selP = 0; };
    _cPurpose lbSetCurSel _selP;
};

// Populate HOLD intent combo
if (!isNull _cHoldIntent) then
{
    lbClear _cHoldIntent;
    _cHoldIntent lbAdd "SECURITY";
    _cHoldIntent lbAdd "OVERWATCH";
    _cHoldIntent lbAdd "PRESENCE";
    _cHoldIntent lbAdd "LINKUP";
    _cHoldIntent lbAdd "OTHER";

    private _selH = ["SECURITY","OVERWATCH","PRESENCE","LINKUP","OTHER"] find _dHoldIntent;
    if (_selH < 0) then { _selH = 0; };
    _cHoldIntent lbSetCurSel _selH;
};

// Populate PROCEED intent combo
if (!isNull _cProceed) then
{
    lbClear _cProceed;
    _cProceed lbAdd "NEXT TASK";
    _cProceed lbAdd "NEXT LEAD";
    _cProceed lbAdd "CONTINUE ROUTE";
    _cProceed lbAdd "OTHER";

    private _selPR = ["NEXT TASK","NEXT LEAD","CONTINUE ROUTE","OTHER"] find _dProceed;
    if (_selPR < 0) then { _selPR = 0; };
    _cProceed lbSetCurSel _selPR;
};

// Hold minutes
if (!isNull _eHoldMin) then
{
    _eHoldMin ctrlSetText str _dHoldMin;
};

// Free text fields
private _dRat = uiNamespace getVariable ["ARC_followOn_defaultRationale", ""]; if (!(_dRat isEqualType "")) then { _dRat = ""; };
private _dCon = uiNamespace getVariable ["ARC_followOn_defaultConstraints", ""]; if (!(_dCon isEqualType "")) then { _dCon = ""; };
private _dSup = uiNamespace getVariable ["ARC_followOn_defaultSupport", ""]; if (!(_dSup isEqualType "")) then { _dSup = ""; };
private _dNote = uiNamespace getVariable ["ARC_followOn_defaultNotes", ""]; if (!(_dNote isEqualType "")) then { _dNote = ""; };

if (!isNull _eRat) then { _eRat ctrlSetText _dRat; };
if (!isNull _eCon) then { _eCon ctrlSetText _dCon; };
if (!isNull _eSup) then { _eSup ctrlSetText _dSup; };
if (!isNull _eNote) then { _eNote ctrlSetText _dNote; };

// Apply visibility rules for the default selection
[] call ARC_fnc_uiFollowOnDialogUpdate;

true

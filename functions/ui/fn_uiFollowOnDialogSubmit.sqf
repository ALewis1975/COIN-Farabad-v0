/*
    ARC_fnc_uiFollowOnDialogSubmit

    Client: collect Follow-on dialog inputs and store result in uiNamespace.

    Result format (uiNamespace var ARC_followOn_result):
      [
        okBool,
        request,        // RTB|HOLD|PROCEED
        purpose,        // REFIT|INTEL|EPW (RTB only)
        rationale,
        constraints,
        support,
        notes,
        holdIntent,
        holdMinutes,
        proceedIntent
      ]
*/

if (!hasInterface) exitWith {false};

private _trimFn = compile "params ['_s']; trim _s";

private _disp = findDisplay 78100;
if (isNull _disp) exitWith {false};

private _cReq = _disp displayCtrl 78102;
private _cPurpose = _disp displayCtrl 78104;
private _cHoldIntent = _disp displayCtrl 78106;
private _eHoldMin = _disp displayCtrl 78108;
private _cProceed = _disp displayCtrl 78110;

private _eRat = _disp displayCtrl 78112;
private _eCon = _disp displayCtrl 78114;
private _eSup = _disp displayCtrl 78116;
private _eNote = _disp displayCtrl 78118;

private _request = "RTB";
if (!isNull _cReq) then
{
    private _t = _cReq lbText (lbCurSel _cReq);
    if (_t isEqualType "") then { _request = toUpper ([_t] call _trimFn); };
};
if !(_request in ["RTB","HOLD","PROCEED"]) then { _request = "RTB"; };

private _purpose = "REFIT";
if (_request isEqualTo "RTB") then
{
    if (!isNull _cPurpose) then
    {
        private _t = _cPurpose lbText (lbCurSel _cPurpose);
        if (_t isEqualType "") then { _purpose = toUpper ([_t] call _trimFn); };
    };
    if !(_purpose in ["REFIT","INTEL","EPW"]) then { _purpose = "REFIT"; };
};

private _holdIntent = "";
private _holdMinutes = 0;
if (_request isEqualTo "HOLD") then
{
    if (!isNull _cHoldIntent) then
    {
        private _t = _cHoldIntent lbText (lbCurSel _cHoldIntent);
        if (_t isEqualType "") then { _holdIntent = toUpper ([_t] call _trimFn); };
    };

    if (!isNull _eHoldMin) then
    {
        private _n = parseNumber (ctrlText _eHoldMin);
        if (_n isEqualType 0) then
        {
            _holdMinutes = round _n;
            if (_holdMinutes < 0) then { _holdMinutes = 0; };
            if (_holdMinutes > 240) then { _holdMinutes = 240; };
        };
    };
};

private _proceedIntent = "";
if (_request isEqualTo "PROCEED") then
{
    if (!isNull _cProceed) then
    {
        private _t = _cProceed lbText (lbCurSel _cProceed);
        if (_t isEqualType "") then { _proceedIntent = toUpper ([_t] call _trimFn); };
    };
};

private _rationale = if (isNull _eRat) then {""} else { [(ctrlText _eRat)] call _trimFn };
private _constraints = if (isNull _eCon) then {""} else { [(ctrlText _eCon)] call _trimFn };
private _support = if (isNull _eSup) then {""} else { [(ctrlText _eSup)] call _trimFn };
private _notes = if (isNull _eNote) then {""} else { [(ctrlText _eNote)] call _trimFn };

uiNamespace setVariable [
    "ARC_followOn_result",
    [true, _request, _purpose, _rationale, _constraints, _support, _notes, _holdIntent, _holdMinutes, _proceedIntent]
];

closeDialog 1;
true

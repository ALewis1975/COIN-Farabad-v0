/*
    ARC_fnc_uiFollowOnDialogUpdate

    Client: show/hide Follow-on dialog controls based on request type.

    Request type control:
      - IDC 78102 (ComboRequest)
*/

if (!hasInterface) exitWith {false};

// sqflint-compat helpers
private _trimFn     = compile "params ['_s']; trim _s";

private _disp = findDisplay 78100;
if (isNull _disp) exitWith {false};

private _cReq = _disp displayCtrl 78102;
private _req = "RTB";

if (!isNull _cReq) then
{
    private _t = _cReq lbText (lbCurSel _cReq);
    if (_t isEqualType "") then { _req = toUpper ([_t] call _trimFn); };
};

if !(_req in ["RTB","HOLD","PROCEED"]) then { _req = "RTB"; };

private _showRtb = (_req isEqualTo "RTB");
private _showHold = (_req isEqualTo "HOLD");
private _showProceed = (_req isEqualTo "PROCEED");

// RTB purpose controls
{ private _c = _disp displayCtrl _x; if (!isNull _c) then { _c ctrlShow _showRtb; }; } forEach [78103, 78104];

// HOLD intent + minutes controls
{ private _c = _disp displayCtrl _x; if (!isNull _c) then { _c ctrlShow _showHold; }; } forEach [78105, 78106, 78107, 78108];

// PROCEED intent controls
{ private _c = _disp displayCtrl _x; if (!isNull _c) then { _c ctrlShow _showProceed; }; } forEach [78109, 78110];

true

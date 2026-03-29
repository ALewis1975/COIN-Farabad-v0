/*
    ARC_fnc_uiConsoleS2Paint

    Client: paints the S2 Ops tab using the list+details pane.

    Purpose:
      - Bring the legacy S2 scroll-menu actions into the UI:
          * Log Sighting/HUMINT/ISR (map click + note)
          * Log cursor target sighting
          * Request intel refresh
          * Create lead requests (RECON/PATROL/CHECKPOINT/CIVIL/IED)

    Params:
      0: DISPLAY
      1: BOOL rebuild list (default true)

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

params [
    ["_display", displayNull, [displayNull]],
    ["_rebuild", true, [true]]
];

if (isNull _display) exitWith {false};

private _ctrlMain    = _display displayCtrl 78010;
private _ctrlMainGrp = _display displayCtrl 78015;
private _ctrlList    = _display displayCtrl 78011;
private _ctrlDetails = _display displayCtrl 78012;
private _ctrlDetailsGrp = _display displayCtrl 78016;

private _b1 = _display displayCtrl 78021;
private _b2 = _display displayCtrl 78022;

// Flip pane visibility: list/details on, main off
if (!isNull _ctrlMainGrp) then { _ctrlMainGrp ctrlShow false; };
if (!isNull _ctrlMain) then { _ctrlMain ctrlShow false; };
if (!isNull _ctrlList) then { _ctrlList ctrlShow true; };
if (!isNull _ctrlDetailsGrp) then { _ctrlDetailsGrp ctrlShow true; };
if (!isNull _ctrlDetails) then { _ctrlDetails ctrlShow true; };

if (isNull _ctrlList || { isNull _ctrlDetails }) exitWith {false};

// Preserve selection by data string
private _prevData = "";
private _prevSel = lbCurSel _ctrlList;
if (_prevSel >= 0) then { _prevData = _ctrlList lbData _prevSel; };

if (_rebuild) then
{
    lbClear _ctrlList;

    private _add = {
        params ["_label", "_data"];
        private _i = _ctrlList lbAdd _label;
        _ctrlList lbSetData [_i, _data];
    };

    // Intel logging
    ["Log Intel (Map): SIGHTING", "INTEL_MAP|SIGHTING"] call _add;
    ["Log Intel (Map): HUMINT TIP", "INTEL_MAP|HUMINT"] call _add;
    ["Log Intel (Map): ISR REPORT", "INTEL_MAP|ISR"] call _add;

    ["Log Sighting: Cursor Target", "CURSOR_SIGHTING|"] call _add;

    // Lead requests (map click)
    ["Create Lead Request (Map): RECON", "LEAD_REQ|RECON"] call _add;
    ["Create Lead Request (Map): PATROL", "LEAD_REQ|PATROL"] call _add;
    ["Create Lead Request (Map): CHECKPOINT", "LEAD_REQ|CHECKPOINT"] call _add;
    ["Create Lead Request (Map): CIVIL", "LEAD_REQ|CIVIL"] call _add;
    ["Create Lead Request (Map): IED", "LEAD_REQ|IED"] call _add;

    // Refresh
    ["Request Intel Refresh (TOC)", "REFRESH_INTEL|"] call _add;

    // Restore selection
    private _set = -1;
    if (!(_prevData isEqualTo "")) then
    {
        for "_n" from 0 to ((lbSize _ctrlList) - 1) do
        {
            if ((_ctrlList lbData _n) isEqualTo _prevData) exitWith { _set = _n; };
        };
    };
    if (_set < 0) then { _set = 0; };
    _ctrlList lbSetCurSel _set;
};

// Buttons
if (!isNull _b1) then { _b1 ctrlShow true; _b1 ctrlSetText "EXECUTE"; _b1 ctrlEnable true; };
if (!isNull _b2) then { _b2 ctrlShow true; _b2 ctrlSetText "TOC QUEUE"; _b2 ctrlEnable true; };

// Details
private _sel = lbCurSel _ctrlList;
private _data = if (_sel >= 0) then { _ctrlList lbData _sel } else { "" };
if (!(_data isEqualType "")) then { _data = ""; };

private _parts = _data splitString "|";
private _kind = if ((count _parts) > 0) then { toUpper (_parts # 0) } else { "NONE" };
private _arg  = if ((count _parts) > 1) then { toUpper (_parts # 1) } else { "" };

private _civsubEnabled = missionNamespace getVariable ["civsub_v1_enabled", false];
if (!(_civsubEnabled isEqualType true) && !(_civsubEnabled isEqualType false)) then { _civsubEnabled = false; };
private _intelLog = missionNamespace getVariable ["ARC_pub_intelLog", []];
if (!(_intelLog isEqualType [])) then { _intelLog = []; };
private _threatHits = 0;
{
    if (!(_x isEqualType []) || { (count _x) < 4 }) then { continue; };
    private _cat = toUpper (trim (_x # 2));
    private _sum = toUpper (trim (_x # 3));
    if (_cat in ["THREAT", "OPS"] && { (_sum find "THREAT") >= 0 || { (_sum find "IED") >= 0 } }) then
    {
        _threatHits = _threatHits + 1;
    };
} forEach _intelLog;
private _threatTxt = if (_threatHits >= 6) then {"HIGH"} else { if (_threatHits >= 3) then {"MEDIUM"} else {"LOW"} };
private _threatColor = if (_threatTxt isEqualTo "HIGH") then {"#FF7A7A"} else { if (_threatTxt isEqualTo "MEDIUM") then {"#FFD166"} else {"#9FE870"} };

private _txt = "<t size='1.15' font='PuristaMedium'>S2 OPS</t><br/><t size='0.9' color='#DDDDDD'>INTEL LOGGING + LEAD GENERATION</t><br/><br/>" +
    format ["<t size='0.9' color='#B89B6B'>CIVSUB:</t> <t size='0.9' color='%1'>%2</t>  <t size='0.9' color='#B89B6B'>THREAT:</t> <t size='0.9' color='%3'>%4</t><br/><br/>",
        if (_civsubEnabled) then {"#9FE870"} else {"#FF7A7A"},
        if (_civsubEnabled) then {"ENABLED"} else {"OFFLINE"},
        _threatColor,
        _threatTxt
    ];

switch (_kind) do
{
    case "INTEL_MAP":
    {
        _txt = _txt + format [
            "<t size='1.0' font='PuristaMedium'>Log Intel (Map Click): %1</t><br/><br/>", _arg
        ];
        _txt = _txt + "<t size='0.95'>What happens</t><br/>- Map opens<br/>- Click a position to log<br/>- Enter a short note<br/><br/>";
        _txt = _txt + "<t size='0.9' color='#DDDDDD'>Use this for observed enemy/civilian activity, HUMINT tips, or ISR reports.</t>";
    };

    case "CURSOR_SIGHTING":
    {
        _txt = _txt + "<t size='1.0' font='PuristaMedium'>Log Sighting: Cursor Target</t><br/><br/>";
        _txt = _txt + "<t size='0.95'>What happens</t><br/>- Logs the unit/object under your cursor (if valid)<br/><br/>";
        _txt = _txt + "<t size='0.9' color='#DDDDDD'>Use this when you have a direct visual on a subject and want a quick record.</t>";
    };

    case "LEAD_REQ":
    {
        _txt = _txt + format ["<t size='1.0' font='PuristaMedium'>Create Lead Request (Map Click): %1</t><br/><br/>", _arg];
        _txt = _txt + "<t size='0.95'>What happens</t><br/>- Map opens<br/>- Click a position to seed a lead request<br/>- TOC generates/queues a lead based on type<br/><br/>";
        _txt = _txt + "<t size='0.9' color='#DDDDDD'>Use this to steer the lead pool toward areas you want to investigate.</t>";
    };

    case "REFRESH_INTEL":
    {
        _txt = _txt + "<t size='1.0' font='PuristaMedium'>Request Intel Refresh</t><br/><br/>";
        _txt = _txt + "<t size='0.95'>What happens</t><br/>- Server broadcasts the latest lead pool + intel objects snapshot<br/><br/>";
    };

    default
    {
        _txt = _txt + "<t size='0.95' color='#DDDDDD'>Select an action. Primary executes it.</t>";
    };
};

_ctrlDetails ctrlSetStructuredText parseText _txt;

// Auto-fit + clamp to viewport so the controls group can scroll when needed.
[_ctrlDetails] call BIS_fnc_ctrlFitToTextHeight;
private _grp = _display displayCtrl 78016;
private _minH = if (!isNull _grp) then { (ctrlPosition _grp) # 3 } else { 0.74 };
private _p = ctrlPosition _ctrlDetails;
_p set [3, (_p # 3) max _minH];
_ctrlDetails ctrlSetPosition _p;
_ctrlDetails ctrlCommit 0;

true

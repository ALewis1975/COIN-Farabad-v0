/*
    ARC_fnc_tocShowLatestIntel

    Client-side debug helper: display the latest intel log entry.

    Primary use:
      - Prevent UI tools (S2/HQ) from hard-erroring if the operator wants a quick
        sanity check that intel logging is working.

    Behavior:
      - If the Farabad Console is open, writes the output to the right-hand
        details pane.
      - Otherwise falls back to a local hint.

    Reads:
      missionNamespace "ARC_pub_intelLog"

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

private _intelLog = missionNamespace getVariable ["ARC_pub_intelLog", []];
if (!(_intelLog isEqualType [])) then { _intelLog = []; };

if (_intelLog isEqualTo []) exitWith
{
    ["Intel", "No intel entries yet."] call ARC_fnc_clientToast;
    hint "Latest Intel\n\n(no entries yet)";
    false
};

private _e = _intelLog # ((count _intelLog) - 1);
if (!(_e isEqualType [] && { (count _e) >= 6 })) exitWith
{
    ["Intel", "Latest intel entry malformed."] call ARC_fnc_clientToast;
    false
};

_e params ["_id", "_t", "_cat", "_sum", "_pos", "_meta"];

private _catTxt = if (_cat isEqualType "") then { toUpper _cat } else { toUpper (str _cat) };

private _grid = if (_pos isEqualType [] && { (count _pos) >= 2 }) then { mapGridPosition _pos } else { "(n/a)" };

private _metaTxt = "";
if (_meta isEqualType [] && { (count _meta) > 0 }) then
{
    {
        if (_x isEqualType [] && { (count _x) >= 2 }) then
        {
            private _k = _x # 0;
            private _v = _x # 1;
            _metaTxt = _metaTxt + format ["<br/><t color='#AAAAAA'>%1:</t> %2", _k, _v];
        };
    } forEach _meta;
};

private _txt = format [
    "<t size='1.15' font='PuristaMedium'>Latest Intel</t><br/><br/>" +
    "<t color='#AAAAAA'>Category:</t> %1<br/>" +
    "<t color='#AAAAAA'>Grid:</t> %2<br/>" +
    "<t color='#AAAAAA'>ID:</t> %3<br/><br/>" +
    "<t color='#DDDDDD'>%4</t>%5",
    _catTxt,
    _grid,
    _id,
    _sum,
    _metaTxt
];

private _disp = uiNamespace getVariable ["ARC_console_display", displayNull];
if (!isNull _disp) then
{
    private _details = _disp displayCtrl 78012;
    if (!isNull _details) then
    {
        _details ctrlSetStructuredText parseText _txt;
        ["Intel", "Displayed latest intel in the console."] call ARC_fnc_clientToast;
        true
    }
    else
    {
        hint ("Latest Intel\n\n" + _sum);
        true
    };
}
else
{
    hint ("Latest Intel\n\n" + _sum);
    true
};

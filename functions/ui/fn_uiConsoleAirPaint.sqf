/*
    ARC_fnc_uiConsoleAirPaint

    Paint AIR tab list/details from ARC_pub_state airbase snapshot.

    Params:
      0: DISPLAY
      1: BOOL rebuild list (default false)
*/

if (!hasInterface) exitWith {false};

params [
    ["_display", displayNull, [displayNull]],
    ["_rebuild", false, [true]]
];
if (isNull _display) exitWith {false};

private _ctrlList = _display displayCtrl 78011;
private _ctrlDetails = _display displayCtrl 78012;
if (isNull _ctrlList || { isNull _ctrlDetails }) exitWith {false};

private _owner = uiNamespace getVariable ["ARC_console_mainListOwner", ""];
if (!(_owner isEqualType "")) then { _owner = ""; };
_owner = toUpper _owner;
private _preserveSelection = (_owner == "AIR");
if (_owner != "AIR") then { _rebuild = true; };
uiNamespace setVariable ["ARC_console_mainListOwner", "AIR"];

private _pub = missionNamespace getVariable ["ARC_pub_state", []];
if (!(_pub isEqualType [])) then { _pub = []; };

private _getPub = {
    params ["_pairs", "_k", "_def"];
    private _idx = _pairs findIf { (_x isEqualType []) && { (count _x) >= 2 } && { ((_x select 0) == _k) } };
    if (_idx < 0) exitWith { _def };
    (_pairs select _idx) select 1
};

private _air = [_pub, "airbase", []] call _getPub;
if (!(_air isEqualType [])) then { _air = []; };

private _depQueued = [_air, "depQueued", 0] call _getPub;
if (!(_depQueued isEqualType 0)) then { _depQueued = 0; };

private _arrQueued = [_air, "arrQueued", 0] call _getPub;
if (!(_arrQueued isEqualType 0)) then { _arrQueued = 0; };

private _totalQueued = [_air, "totalQueued", 0] call _getPub;
if (!(_totalQueued isEqualType 0)) then { _totalQueued = 0; };

private _execActive = [_air, "execActive", false] call _getPub;
if (!(_execActive isEqualType true) && !(_execActive isEqualType false)) then { _execActive = false; };

private _execFid = [_air, "execFid", ""] call _getPub;
if (!(_execFid isEqualType "")) then { _execFid = ""; };

private _runwayState = [_air, "runwayState", "UNKNOWN"] call _getPub;
if (!(_runwayState isEqualType "")) then { _runwayState = "UNKNOWN"; };

private _runwayOwner = [_air, "runwayOwner", ""] call _getPub;
if (!(_runwayOwner isEqualType "")) then { _runwayOwner = ""; };

private _hold = [_air, "holdDepartures", false] call _getPub;
if (!(_hold isEqualType true) && !(_hold isEqualType false)) then { _hold = false; };
uiNamespace setVariable ["ARC_console_airHoldDepartures", _hold];

private _nextItems = [_air, "nextItems", []] call _getPub;
if (!(_nextItems isEqualType [])) then { _nextItems = []; };

if (_rebuild) then
{
    private _prevSelData = "";
    if (_preserveSelection) then
    {
        private _prevSel = lbCurSel _ctrlList;
        if (_prevSel >= 0) then
        {
            _prevSelData = _ctrlList lbData _prevSel;
            if (!(_prevSelData isEqualType "")) then { _prevSelData = ""; };
        };
    };

    lbClear _ctrlList;

    private _i = _ctrlList lbAdd format ["SUMMARY  DEP:%1 ARR:%2 TOTAL:%3", _depQueued, _arrQueued, _totalQueued];
    _ctrlList lbSetData [_i, "AIR_SUMMARY"];

    {
        if !(_x isEqualType []) then { continue; };
        private _fid = _x param [0, ""];
        private _kind = _x param [1, ""];
        private _asset = _x param [2, ""];
        if (!(_fid isEqualType "")) then { _fid = ""; };
        if (!(_kind isEqualType "")) then { _kind = ""; };
        if (!(_asset isEqualType "")) then { _asset = ""; };

        private _lbl = format ["%1  [%2] %3", _fid, _kind, _asset];
        private _row = _ctrlList lbAdd _lbl;
        _ctrlList lbSetData [_row, format ["AIR_FID|%1|%2|%3", _fid, _kind, _asset]];
    } forEach _nextItems;

    if ((lbSize _ctrlList) > 0) then
    {
        private _restoreSel = -1;

        if (_preserveSelection && { _prevSelData != "" }) then
        {
            _restoreSel = lbFind [_ctrlList, _prevSelData];

            if (_restoreSel < 0 && { (_prevSelData find "AIR_FID|") == 0 } && { (lbSize _ctrlList) > 1 }) then
            {
                // Preserve flight-row intent when the exact FID disappeared between refresh ticks.
                _restoreSel = 1;
            };
        };

        if (_restoreSel < 0) then { _restoreSel = 0; };
        _ctrlList lbSetCurSel _restoreSel;
    };
};

private _sel = lbCurSel _ctrlList;
if (_sel < 0 && { (lbSize _ctrlList) > 0 }) then { _sel = 0; _ctrlList lbSetCurSel 0; };

private _selData = if (_sel >= 0) then { _ctrlList lbData _sel } else { "" };
if (!(_selData isEqualType "")) then { _selData = ""; };

private _selectedFid = "";
if ((_selData find "AIR_FID|") == 0) then
{
    private _parts = _selData splitString "|";
    if ((count _parts) >= 2) then { _selectedFid = _parts select 1; };
};
uiNamespace setVariable ["ARC_console_airSelectedFid", _selectedFid];

private _canAirControl = ["ARC_console_airCanControl", false] call ARC_fnc_uiNsGetBool;
private _canText = if (_canAirControl) then { "TOWER CONTROL: ENABLED" } else { "TOWER CONTROL: READ-ONLY" };
private _holdText = if (_hold) then { "HOLD ACTIVE" } else { "DEPARTURES OPEN" };
private _execText = if (_execActive) then { format ["EXEC ACTIVE: %1", _execFid] } else { "EXEC ACTIVE: none" };
private _rwOwnerText = if (_runwayOwner == "") then { "-" } else { _runwayOwner };

private _actionHint = if (_canAirControl) then {
    if (_selectedFid == "") then {
        "Select a queued flight to use EXPEDITE/CANCEL."
    } else {
        if (_sel == 1) then {
            "Secondary will CANCEL the first queued flight."
        } else {
            "Secondary will EXPEDITE selected flight to front of queue."
        };
    };
} else {
    "Read-only mode: tower-designated roles can HOLD/RELEASE or EXPEDITE/CANCEL."
};

private _details = format [
    "<t size='1.05' color='#B89B6B'>AIRBASE SNAPSHOT</t>"
    + "<br/><t color='#CFCFCF'>%1 | %2</t>"
    + "<br/><br/><t color='#B89B6B'>Queue</t>"
    + "<br/>Departures queued: <t color='#FFFFFF'>%3</t>"
    + "<br/>Arrivals queued: <t color='#FFFFFF'>%4</t>"
    + "<br/>Total queued: <t color='#FFFFFF'>%5</t>"
    + "<br/><br/><t color='#B89B6B'>Runway</t>"
    + "<br/>State: <t color='#FFFFFF'>%6</t>"
    + "<br/>Owner: <t color='#FFFFFF'>%7</t>"
    + "<br/>Execution: <t color='#FFFFFF'>%8</t>"
    + "<br/><br/><t color='#B89B6B'>Action Hint</t>"
    + "<br/><t color='#CFCFCF'>%9</t>",
    _canText,
    _holdText,
    _depQueued,
    _arrQueued,
    _totalQueued,
    _runwayState,
    _rwOwnerText,
    _execText,
    _actionHint
];

_ctrlDetails ctrlSetStructuredText parseText _details;
true

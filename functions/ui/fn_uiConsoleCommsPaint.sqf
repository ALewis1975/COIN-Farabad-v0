/*
    ARC_fnc_uiConsoleCommsPaint

    Client: paint the read-only COMMS/MED integration panel.
    Data is sourced from ARC_ConsoleVM_v1 sections published by the server.

    Params:
      0: DISPLAY

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

params [
    ["_display", displayNull, [displayNull]]
];

if (isNull _display) exitWith {false};

private _ctrlMain = _display displayCtrl 78010;
private _ctrlDetails = _display displayCtrl 78012;
if (isNull _ctrlMain) exitWith {false};

private _trimFn = compile "params ['_s']; trim _s";

private _fmtNumPct = {
    params ["_v"];
    if (!(_v isEqualType 0)) exitWith {"--"};
    format ["%1%2", round (((_v max 0) min 1) * 100), "%"]
};

private _fmtLead = {
    params ["_lead"];
    if (!(_lead isEqualType []) || { (count _lead) < 4 }) exitWith {""};
    private _disp = _lead select 2;
    private _pos = _lead select 3;
    private _strength = if ((count _lead) > 4) then { _lead select 4 } else { 0 };
    if (!(_disp isEqualType "")) then { _disp = "CASEVAC"; };
    if (!(_pos isEqualType [])) then { _pos = []; };
    if (!(_strength isEqualType 0)) then { _strength = 0; };
    private _grid = if ((count _pos) >= 2) then { mapGridPosition _pos } else { "GRID?" };
    format ["<t color='#FF7A7A'>%1</t> <t color='#AAAAAA'>%2 urgency %3</t>", _disp, _grid, [_strength] call _fmtNumPct]
};

private _useVm = (!isNil "ARC_fnc_consoleVmAdapterV1");

private _commandNets = if (_useVm) then { ["comms", "command_nets", []] call ARC_fnc_consoleVmAdapterV1 } else { [] };
private _prc152 = if (_useVm) then { ["comms", "prc152_plan", []] call ARC_fnc_consoleVmAdapterV1 } else { [] };
private _shortRange = if (_useVm) then { ["comms", "short_range_buckets", []] call ARC_fnc_consoleVmAdapterV1 } else { [] };
private _roleHint = if (_useVm) then { ["comms", "role_hint", ""] call ARC_fnc_consoleVmAdapterV1 } else { "" };
private _tfarRequired = if (_useVm) then { ["comms", "tfar_required", false] call ARC_fnc_consoleVmAdapterV1 } else { false };
if (!(_commandNets isEqualType [])) then { _commandNets = []; };
if (!(_prc152 isEqualType [])) then { _prc152 = []; };
if (!(_shortRange isEqualType [])) then { _shortRange = []; };
if (!(_roleHint isEqualType "")) then { _roleHint = ""; };
if (!(_tfarRequired isEqualType true) && !(_tfarRequired isEqualType false)) then { _tfarRequired = false; };

private _medicalSnapshot = if (_useVm) then { ["medical", "snapshot", []] call ARC_fnc_consoleVmAdapterV1 } else { [] };
private _activeCasevac = if (_useVm) then { ["medical", "active_casevac", []] call ARC_fnc_consoleVmAdapterV1 } else { [] };
private _cooldown = if (_useVm) then { ["medical", "casevac_cooldown_remaining", 0] call ARC_fnc_consoleVmAdapterV1 } else { 0 };
private _recentMedEvents = if (_useVm) then { ["medical", "recent_events", []] call ARC_fnc_consoleVmAdapterV1 } else { [] };
if (!(_medicalSnapshot isEqualType [])) then { _medicalSnapshot = []; };
if (!(_activeCasevac isEqualType [])) then { _activeCasevac = []; };
if (!(_cooldown isEqualType 0)) then { _cooldown = 0; };
if (!(_recentMedEvents isEqualType [])) then { _recentMedEvents = []; };

private _baseMed = [_medicalSnapshot, "base_med", -1] call ARC_fnc_uiConsoleGetPair;
private _civCas = [_medicalSnapshot, "civ_casualties", 0] call ARC_fnc_uiConsoleGetPair;
private _baseCas = [_medicalSnapshot, "base_casualties", 0] call ARC_fnc_uiConsoleGetPair;
private _isCritical = [_medicalSnapshot, "is_critical", false] call ARC_fnc_uiConsoleGetPair;
if (!(_baseMed isEqualType 0)) then { _baseMed = -1; };
if (!(_civCas isEqualType 0)) then { _civCas = 0; };
if (!(_baseCas isEqualType 0)) then { _baseCas = 0; };
if (!(_isCritical isEqualType true) && !(_isCritical isEqualType false)) then { _isCritical = false; };

private _ctabMarker = if (_useVm) then { ["ctab", "casevac_marker", ""] call ARC_fnc_consoleVmAdapterV1 } else { "" };
private _taskMarker = if (_useVm) then { ["ctab", "active_task_marker", ""] call ARC_fnc_consoleVmAdapterV1 } else { "" };
if (!(_ctabMarker isEqualType "")) then { _ctabMarker = ""; };
if (!(_taskMarker isEqualType "")) then { _taskMarker = ""; };

private _netLines = [];
{
    if (!(_x isEqualType []) || { (count _x) < 3 }) then { continue; };
    private _ch = _x select 0;
    private _label = _x select 1;
    private _call = _x select 2;
    if (!(_ch isEqualType "")) then { _ch = ""; };
    if (!(_label isEqualType "")) then { _label = ""; };
    if (!(_call isEqualType "")) then { _call = ""; };
    _netLines pushBack format ["<t color='#B89B6B'>%1</t> %2 — %3", _ch, _label, _call];
} forEach _commandNets;
if ((count _netLines) > 8) then { _netLines = _netLines select [0, 8]; };

private _casevacLines = [];
{
    private _line = [_x] call _fmtLead;
    if (_line != "") then { _casevacLines pushBack _line; };
} forEach _activeCasevac;

private _main = "";
_main = _main + "<t size='1.15' color='#B89B6B' font='PuristaMedium'>COMMS / MEDICAL C2</t><br/>";
_main = _main + "<t color='#AAAAAA'>Read-only integration panel. TFAR, ACE/KAT, and cTab support command workflow; server state remains authoritative.</t><br/><br/>";

_main = _main + "<t color='#B89B6B'>TFAR / SOI</t><br/>";
_main = _main + format ["TFAR status: <t color='%1'>%2</t><br/>", if (_tfarRequired) then {"#9FE870"} else {"#FFD166"}, if (_tfarRequired) then {"loaded"} else {"not detected / static plan"}];
_main = _main + ((_netLines joinString "<br/>") + "<br/><br/>");

_main = _main + "<t color='#B89B6B'>ACE/KAT Medical</t><br/>";
_main = _main + format [
    "Base MED: <t color='%1'>%2</t>  Base casualties: %3  Civilian casualties: %4<br/>",
    if (_isCritical) then {"#FF7A7A"} else {"#9FE870"},
    [_baseMed] call _fmtNumPct,
    _baseCas,
    _civCas
];
_main = _main + format ["CASEVAC cooldown: %1s remaining<br/>", round _cooldown];
if ((count _casevacLines) isEqualTo 0) then
{
    _main = _main + "<t color='#BBBBBB'>No active CASEVAC leads in the current lead pool.</t><br/>";
}
else
{
    _main = _main + (_casevacLines joinString "<br/>") + "<br/>";
};

_ctrlMain ctrlSetStructuredText parseText _main;
[_ctrlMain] call BIS_fnc_ctrlFitToTextHeight;

if (!isNull _ctrlDetails) then
{
    private _detail = "";
    _detail = _detail + "<t size='1.05' color='#B89B6B'>Tablet / cTab aids</t><br/>";
    _detail = _detail + format ["Active task marker: <t color='#DDDDDD'>%1</t><br/>", if (([_taskMarker] call _trimFn) isEqualTo "") then {"none"} else {_taskMarker}];
    _detail = _detail + format ["Latest CASEVAC marker: <t color='#DDDDDD'>%1</t><br/><br/>", if (([_ctabMarker] call _trimFn) isEqualTo "") then {"none"} else {_ctabMarker}];

    _detail = _detail + "<t size='1.05' color='#B89B6B'>AN/PRC-152 quick plan</t><br/>";
    _detail = _detail + ((_prc152 select [0, (count _prc152) min 8]) joinString "<br/>") + "<br/><br/>";
    _detail = _detail + "<t size='1.05' color='#B89B6B'>TFAR short-range buckets</t><br/>";
    _detail = _detail + ((_shortRange select [0, (count _shortRange) min 6]) joinString "<br/>") + "<br/><br/>";
    _detail = _detail + format ["<t color='#AAAAAA'>%1</t>", _roleHint];

    if ((count _recentMedEvents) > 0) then
    {
        _detail = _detail + "<br/><br/><t size='1.05' color='#B89B6B'>Recent MED events</t><br/>";
        {
            if (!(_x isEqualType []) || { (count _x) < 4 }) then { continue; };
            private _summary = _x select 3;
            if (!(_summary isEqualType "")) then { _summary = "MED event"; };
            _detail = _detail + format ["- %1<br/>", _summary];
        } forEach _recentMedEvents;
    };

    _ctrlDetails ctrlSetStructuredText parseText _detail;
    [_ctrlDetails] call BIS_fnc_ctrlFitToTextHeight;
};

true

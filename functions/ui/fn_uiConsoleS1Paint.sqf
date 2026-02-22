/*
    ARC_fnc_uiConsoleS1Paint

    Client: paint the S-1 personnel registry snapshot view (read-only).
*/

if (!hasInterface) exitWith {false};

params [
    ["_display", displayNull, [displayNull]]
];

if (isNull _display) exitWith {false};

private _ctrlMain = _display displayCtrl 78010;
private _ctrlList = _display displayCtrl 78011;
private _ctrlDetails = _display displayCtrl 78012;
if (isNull _ctrlMain || {isNull _ctrlList} || {isNull _ctrlDetails}) exitWith {false};

private _trimFn = compile "params ['_s']; trim _s";
private _getPair = {
    params ["_pairs", "_key", "_default"];
    if (!(_pairs isEqualType [])) exitWith { _default };
    private _idx = _pairs findIf { (_x isEqualType []) && { (count _x) >= 2 } && { ((_x # 0) isEqualTo _key) } };
    if (_idx < 0) exitWith { _default };
    (_pairs # _idx) # 1
};

private _registry = missionNamespace getVariable ["ARC_pub_s1_registry", []];
if (!(_registry isEqualType [])) then { _registry = []; };
private _updatedAt = missionNamespace getVariable ["ARC_pub_s1_registryUpdatedAt", -1];
if (!(_updatedAt isEqualType 0)) then { _updatedAt = -1; };

private _groups = [_registry, "groups", []] call _getPair;
private _units = [_registry, "units", []] call _getPair;
if (!(_groups isEqualType [])) then { _groups = []; };
if (!(_units isEqualType [])) then { _units = []; };

private _statusRows = missionNamespace getVariable ["ARC_pub_unitStatuses", []];
if (!(_statusRows isEqualType [])) then { _statusRows = []; };

private _activeTask = missionNamespace getVariable ["ARC_activeTaskId", ""];
if (!(_activeTask isEqualType "")) then { _activeTask = ""; };
private _activePos = missionNamespace getVariable ["ARC_activeIncidentPos", []];
if (!(_activePos isEqualType []) || { (count _activePos) < 2 }) then { _activePos = []; };
private _activeZone = if ((count _activePos) >= 2) then { [_activePos] call ARC_fnc_worldGetZoneForPos } else { "" };
if (!(_activeZone isEqualType "")) then { _activeZone = ""; };
if (_activeZone isEqualTo "") then { _activeZone = "Unknown"; };

private _statusByGroup = createHashMap;
{
    if (_x isEqualType [] && { (count _x) >= 2 }) then
    {
        private _gid = _x # 0;
        private _st = _x # 1;
        if (_gid isEqualType "" && { _st isEqualType "" }) then
        {
            _statusByGroup set [_gid, toUpper ([_st] call _trimFn)];
        };
    };
} forEach _statusRows;

private _prevSelGid = "";
private _prevSelIdx = lbCurSel _ctrlList;
if (_prevSelIdx >= 0) then
{
    _prevSelGid = _ctrlList lbData _prevSelIdx;
};
if (!(_prevSelGid isEqualType "")) then { _prevSelGid = ""; };
if (_prevSelGid isEqualTo "") then
{
    _prevSelGid = uiNamespace getVariable ["ARC_console_s1SelectedGid", ""];
    if (!(_prevSelGid isEqualType "")) then { _prevSelGid = ""; };
};

lbClear _ctrlList;
private _listRows = [];

{
    if (!(_x isEqualType [])) then { continue; };
    private _gid = [_x, "groupId", ""] call _getPair;
    if (!(_gid isEqualType "")) then { _gid = ""; };

    private _callsign = [_x, "callsign", ""] call _getPair;
    if (!(_callsign isEqualType "")) then { _callsign = ""; };

    private _company = [_x, "company", ""] call _getPair;
    if (!(_company isEqualType "")) then { _company = ""; };
    if (_company isEqualTo "") then { _company = "UNK"; };

    private _countUnits = 0;
    {
        if (_x isEqualType [] && { ([_x, "groupId", ""] call _getPair) isEqualTo _gid }) then { _countUnits = _countUnits + 1; };
    } forEach _units;

    private _availability = _statusByGroup getOrDefault [_gid, "UNAVAILABLE"];
    if (_availability isEqualTo "OFFLINE") then { _availability = "UNAVAILABLE"; };

    private _label = format ["[%1] %2 | %3 | %4 pax", _company, if (_callsign isEqualTo "") then {_gid} else {_callsign}, _availability, _countUnits];
    private _idx = _ctrlList lbAdd _label;
    _ctrlList lbSetData [_idx, _gid];
    _listRows pushBack [_gid, _x, _availability, _countUnits];
} forEach _groups;

if ((count _listRows) isEqualTo 0) then
{
    _ctrlList lbAdd "No S-1 registry snapshot yet.";
    _ctrlList lbSetData [0, "__EMPTY__"];
    _ctrlList lbSetCurSel 0;
}
else
{
    private _sel = _listRows findIf { (_x # 0) isEqualTo _prevSelGid };
    if (_sel < 0) then { _sel = 0; };

    uiNamespace setVariable ["ARC_console_s1SuppressSelChanged", true];
    _ctrlList lbSetCurSel _sel;
};

private _selIdx = lbCurSel _ctrlList;
if (_selIdx < 0) then { _selIdx = 0; };
private _selGid = _ctrlList lbData _selIdx;
uiNamespace setVariable ["ARC_console_s1SelectedGid", _selGid];

private _main = "<t size='1.15' color='#B89B6B' font='PuristaMedium'>S-1 / Personnel Registry</t><br/>";
if (_updatedAt < 0 || { (count _groups) isEqualTo 0 }) then
{
    _main = _main + "<t color='#FFD166'>Snapshot unavailable (cold join / JIP sync pending).</t><br/>";
    _main = _main + "<t color='#AAAAAA'>Wait for server broadcast, then refresh.</t><br/>";
}
else
{
    _main = _main + format ["<t color='#DDDDDD'>Updated at T+%1s</t><br/>", round _updatedAt];
    _main = _main + format ["<t color='#DDDDDD'>Groups:</t> %1 <t color='#DDDDDD'>| Units:</t> %2 <t color='#DDDDDD'>| Active zone:</t> %3<br/>", count _groups, count _units, _activeZone];
};
_ctrlMain ctrlSetStructuredText parseText _main;

private _details = "<t size='1.05' color='#B89B6B' font='PuristaMedium'>Roster Detail</t><br/>";
if (_selGid isEqualTo "__EMPTY__") then
{
    _details = _details + "<t color='#AAAAAA'>No roster rows available yet.</t>";
}
else
{
    private _gRec = [];
    {
        if (_x isEqualType [] && { ([_x, "groupId", ""] call _getPair) isEqualTo _selGid }) exitWith { _gRec = _x; };
    } forEach _groups;

    private _company = [_gRec, "company", "UNK"] call _getPair;
    if (!(_company isEqualType "")) then { _company = "UNK"; };
    private _callsign = [_gRec, "callsign", ""] call _getPair;
    if (!(_callsign isEqualType "")) then { _callsign = ""; };
    private _availability = _statusByGroup getOrDefault [_selGid, "UNAVAILABLE"];

    _details = _details + format ["<t color='#B89B6B'>Group:</t> <t color='#FFFFFF'>%1</t><br/>", _selGid];
    _details = _details + format ["<t color='#B89B6B'>Callsign:</t> <t color='#FFFFFF'>%1</t><br/>", if (_callsign isEqualTo "") then {"(none)"} else {_callsign}];
    _details = _details + format ["<t color='#B89B6B'>Company:</t> <t color='#FFFFFF'>%1</t><br/>", _company];
    _details = _details + format ["<t color='#B89B6B'>Availability:</t> <t color='#FFFFFF'>%1</t><br/>", _availability];
    _details = _details + format ["<t color='#B89B6B'>Active Task:</t> <t color='#FFFFFF'>%1</t><br/>", if (_activeTask isEqualTo "") then {"None"} else {_activeTask}];
    _details = _details + format ["<t color='#B89B6B'>Last Known HQ/Zone:</t> <t color='#FFFFFF'>HQ / %1</t><br/><br/>", _activeZone];

    _details = _details + "<t color='#B89B6B' font='PuristaMedium'>Unit Roster</t><br/>";
    private _rows = [];
    {
        if (!(_x isEqualType [])) then { continue; };
        if (([_x, "groupId", ""] call _getPair) isNotEqualTo _selGid) then { continue; };

        private _role = [_x, "role", "RIFLEMAN"] call _getPair;
        if (!(_role isEqualType "")) then { _role = "RIFLEMAN"; };
        private _task = [_x, "currentTaskId", ""] call _getPair;
        if (!(_task isEqualType "")) then { _task = ""; };
        private _readiness = [_x, "readiness", 0] call _getPair;
        if (!(_readiness isEqualType 0)) then { _readiness = 0; };
        private _state = [_x, "virtualStatus", "UNKNOWN"] call _getPair;
        if (!(_state isEqualType "")) then { _state = "UNKNOWN"; };

        private _rdTxt = format ["%1%%", round (_readiness * 100)];
        private _taskTxt = if (_task isEqualTo "") then { "None" } else { _task };
        _rows pushBack format ["<t color='#DDDDDD'>- %1</t> <t color='#AAAAAA'>(%2 | Readiness %3 | Task %4)</t>", _role, _state, _rdTxt, _taskTxt];
    } forEach _units;

    if ((count _rows) isEqualTo 0) then
    {
        _details = _details + "<t color='#AAAAAA'>No units indexed for this group.</t>";
    }
    else
    {
        _details = _details + (_rows joinString "<br/>");
    };
};

_ctrlDetails ctrlSetStructuredText parseText _details;

private _lastSnapshotAt = uiNamespace getVariable ["ARC_console_s1LastSnapshotAt", -1];
if (!(_lastSnapshotAt isEqualType 0)) then { _lastSnapshotAt = -1; };
if (_updatedAt > _lastSnapshotAt) then
{
    uiNamespace setVariable ["ARC_console_s1LastSnapshotAt", _updatedAt];

    if (_updatedAt >= 0) then
    {
        ["S-1", format ["Registry sync updated (%1 groups / %2 units).", count _groups, count _units]] call ARC_fnc_clientToast;
    }
    else
    {
        ["S-1", "Waiting for personnel snapshot broadcast."] call ARC_fnc_clientHint;
    };
};

true

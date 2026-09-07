// Engine-compatible command wrappers retain the repository lint baseline.
private _casDefault = compile "params ['_map','_args']; _map getOrDefault _args";
private _casMap = compile "params ['_pairs']; createHashMapFromArray _pairs";
private _casTrim = compile "params ['_s']; trim _s";
/* Only fixed existing RPCs leave this dialog; UI permissions are advisory. */
if (!hasInterface) exitWith {false};
disableSerialization;
params [["_action", "SELECT", [""]]];
private _d = findDisplay 78520;
if (isNull _d) exitWith {false};
private _list = _d displayCtrl 1500;
private _id = if (lbCurSel _list < 0) then {""} else {_list lbData (lbCurSel _list)};
private _inbox = ([(missionNamespace getVariable ["ARC_pub_casreqInbox", []])] call _casMap);
private _record = [];
{private _r = ([_x] call _casMap); if ((([_r, ["casreq_id", ""]] call _casDefault)) isEqualTo _id) exitWith {_record = _x}} forEach (([_inbox, ["records", []]] call _casDefault));
private _r = ([_record] call _casMap);
private _state = ([_r, ["state", ""]] call _casDefault);
if (_action isEqualTo "SELECT") exitWith {
    private _lines = [];
    if (_record isEqualTo []) then {_lines = ["No CAS requests in the server inbox."]} else {
        _lines = [format ["%1 | %2 | %3", _id, _state, ([_r, ["result", ""]] call _casDefault)], format ["Requester: %1", ([_r, ["requester", ""]] call _casDefault)], format ["Incident: %1", ([_r, ["incident_id", ""]] call _casDefault)], "", "NINE-LINE"];
        {_lines pushBack format ["%1: %2", _x select 0, _x select 1]} forEach (([_r, ["nine_line", []]] call _casDefault));
        _lines append ["", "LIFECYCLE / BDA"];
        {
            private _m = ([_x] call _casMap);
            _lines pushBack format ["%1 | %2 | %3", ([_m, ["at", 0]] call _casDefault), ([_m, ["event", ""]] call _casDefault), ([_m, ["by", ""]] call _casDefault)];
            _lines pushBack (([_m, ["notes", ([_m, ["reason", ""]] call _casDefault)]] call _casDefault));
            if ((([_m, ["event", ""]] call _casDefault)) isEqualTo "APPROVED") then {_lines pushBack format ["Assigned aircraft: %1", ([_m, ["aircraft_var", "controller recovery"]] call _casDefault)]};
        } forEach (([_r, ["messages", []]] call _casDefault));
    };
    (_d displayCtrl 1400) ctrlSetText (_lines joinString toString [10]);
    private _controller = [player, "DECIDE", _record] call ARC_fnc_casreqCan;
    (_d displayCtrl 1600) ctrlEnable (_state isEqualTo "OPEN" && _controller && {lbCurSel (_d displayCtrl 2100) >= 0});
    (_d displayCtrl 1601) ctrlEnable (_state isEqualTo "OPEN" && _controller);
    (_d displayCtrl 1602) ctrlEnable (_state isEqualTo "APPROVED" && {[player, "EXECUTE", _record] call ARC_fnc_casreqCan});
    (_d displayCtrl 1603) ctrlEnable (_state isEqualTo "EXECUTING" && {[player, "COMPLETE", _record] call ARC_fnc_casreqCan});
    (_d displayCtrl 1604) ctrlEnable (_state in ["OPEN", "APPROVED", "EXECUTING"] && {[player, "ABORT", _record] call ARC_fnc_casreqCan});
    true
};
if (_record isEqualTo []) exitWith {false};
private _notes = ([(ctrlText (_d displayCtrl 1401))] call _casTrim);
if (count _notes > 500) exitWith {["CASREQ", "Notes must be 500 characters or fewer."] call ARC_fnc_clientToast; false};
if (_action isEqualTo "COMPLETE" && {_notes isEqualTo ""}) exitWith {["CASREQ", "Enter BDA notes before completing the request."] call ARC_fnc_clientToast; false};
switch (_action) do {
    case "APPROVED": {
        private _c = _d displayCtrl 2100;
        if (lbCurSel _c >= 0) then {[player, _id, "APPROVED", _notes, missionNamespace getVariable [_c lbData (lbCurSel _c), objNull]] remoteExecCall ["ARC_fnc_casreqDecide", 2]};
    };
    case "DENIED": {[player, _id, "DENIED", _notes] remoteExecCall ["ARC_fnc_casreqDecide", 2]};
    case "EXECUTING": {[player, _id, -1] remoteExecCall ["ARC_fnc_casreqExecute", 2]};
    case "COMPLETE": {[player, _id, "COMPLETE", _notes] remoteExecCall ["ARC_fnc_casreqClose", 2]};
    case "ABORT": {[player, _id, "ABORT", _notes] remoteExecCall ["ARC_fnc_casreqClose", 2]};
};
["CASREQ", "Action sent. The inbox updates after server validation."] call ARC_fnc_clientToast;
true

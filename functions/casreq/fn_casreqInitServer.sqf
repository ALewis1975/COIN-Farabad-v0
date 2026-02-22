/*
    ARC_fnc_casreqInitServer

    Server-owned CASREQ v1 store initialization.
*/

if (!isServer) exitWith {false};

private _enabled = missionNamespace getVariable ["casreq_v1_enabled", true];
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
missionNamespace setVariable ["casreq_v1_enabled", _enabled, true];
if (!_enabled) exitWith { false };

private _schemaVersion = missionNamespace getVariable ["casreq_v1_schemaVersion", 1];
if (!(_schemaVersion isEqualType 0) || { _schemaVersion < 1 }) then { _schemaVersion = 1; };
missionNamespace setVariable ["casreq_v1_schemaVersion", _schemaVersion, true];

private _idPattern = "^CAS:D[0-9]{2}:[0-9]{6}$";
missionNamespace setVariable ["casreq_v1_idPattern", _idPattern, true];

private _records = ["casreq_v1_records", createHashMap] call ARC_fnc_stateGet;
if !(_records isEqualType createHashMap) then { _records = createHashMap; };
["casreq_v1_records", _records] call ARC_fnc_stateSet;

private _openIndex = ["casreq_v1_open_index", []] call ARC_fnc_stateGet;
if !(_openIndex isEqualType []) then { _openIndex = []; };
["casreq_v1_open_index", _openIndex] call ARC_fnc_stateSet;

private _closedIndex = ["casreq_v1_closed_index", []] call ARC_fnc_stateGet;
if !(_closedIndex isEqualType []) then { _closedIndex = []; };
["casreq_v1_closed_index", _closedIndex] call ARC_fnc_stateSet;

private _seq = ["casreq_v1_seq", 0] call ARC_fnc_stateGet;
if (!(_seq isEqualType 0) || { _seq < 0 }) then { _seq = 0; };
["casreq_v1_seq", _seq] call ARC_fnc_stateSet;

missionNamespace setVariable ["ARC_pub_casreqBundle", [
    ["meta", [["rev", 0], ["updatedAt", -1], ["actor", "SERVER_INIT"]]],
    ["payload", [["casreq_id", ""], ["casreq_snapshot", []]]]
], true];

true

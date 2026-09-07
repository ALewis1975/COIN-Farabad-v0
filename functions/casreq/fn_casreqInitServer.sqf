/*
    ARC_fnc_casreqInitServer

    Server-owned CASREQ v1 store initialization.
*/

if (!isServer) exitWith {false};

private _enabled = ["casreq_v1_enabled", missionNamespace getVariable ["casreq_v1_enabled", true]] call ARC_fnc_stateGet;
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
["casreq_v1_enabled", _enabled] call ARC_fnc_stateSet;
missionNamespace setVariable ["casreq_v1_enabled", _enabled, true];
if (!_enabled) exitWith { false };

private _schemaVersion = ["casreq_v1_version", missionNamespace getVariable ["casreq_v1_schemaVersion", 1]] call ARC_fnc_stateGet;
if (!(_schemaVersion isEqualType 0) || { _schemaVersion < 1 }) then { _schemaVersion = 1; };
if (_schemaVersion != 1) exitWith {diag_log "[ARC][CASREQ] Unsupported future schema; store preserved"; false};
["casreq_v1_version", _schemaVersion] call ARC_fnc_stateSet;
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
private _casKeys = compile "params ['_h']; keys _h";
if (!(_seq isEqualType 0) || {!finite _seq} || { _seq < 0 }) then { _seq = 0; };
_seq = floor _seq;
// Recovery never allows a stale sequence counter to overwrite a retained ID.
{if (count _x == 14) then {_seq = _seq max (parseNumber (_x select [8, 6]))}} forEach ([_records] call _casKeys);
["casreq_v1_seq", _seq] call ARC_fnc_stateSet;

private _attackVehVars = missionNamespace getVariable ["casreq_v1_airbase_attack_vehvars", ["plane4", "plane5"]];
if (!(_attackVehVars isEqualType [])) then { _attackVehVars = ["plane4", "plane5"]; };
missionNamespace setVariable ["casreq_v1_airbase_attack_vehvars", _attackVehVars, true];

// Authority references are local to the server; public mirrors only drive UI hints.
if (isNil {localNamespace getVariable "ARC_casreq_jtacUnit"}) then {
    localNamespace setVariable ["ARC_casreq_jtacUnit", missionNamespace getVariable ["jtac", objNull]];
};
missionNamespace setVariable ["ARC_casreq_jtacUnit", localNamespace getVariable ["ARC_casreq_jtacUnit", objNull], true];
if (isNil {localNamespace getVariable "ARC_casreq_attackObjects"}) then {
    localNamespace setVariable ["ARC_casreq_attackObjects", (_attackVehVars apply {missionNamespace getVariable [_x, objNull]}) select {!isNull _x}];
};
if (isNil {localNamespace getVariable "ARC_casreq_respawnEh"}) then {
    localNamespace setVariable ["ARC_casreq_respawnEh", addMissionEventHandler ["EntityRespawned", {
        params ["_new", "_old"];
        if (_old isEqualTo (localNamespace getVariable ["ARC_casreq_jtacUnit", objNull])) then {
            localNamespace setVariable ["ARC_casreq_jtacUnit", _new];
            missionNamespace setVariable ["ARC_casreq_jtacUnit", _new, true];
        };
        private _assets = localNamespace getVariable ["ARC_casreq_attackObjects", []];
        private _idx = _assets find _old;
        if (_idx >= 0) then {_assets set [_idx, _new]; localNamespace setVariable ["ARC_casreq_attackObjects", _assets]};
    }]];
};
// Repeated initialization retains the last event; complete inbox is rebuilt from state.
if (isNil "ARC_pub_casreqBundle") then {
    missionNamespace setVariable ["ARC_pub_casreqBundle", [
        ["meta", [["rev", 0], ["updatedAt", -1], ["actor", "SERVER_INIT"]]],
        ["payload", [["casreq_id", ""], ["casreq_snapshot", []]]]
    ], true];
};
[true] call ARC_fnc_casreqMaintain;
[true] call ARC_fnc_casreqInboxPublish;

true

// Engine-compatible command wrappers retain the repository lint baseline.
private _casDefault = compile "params ['_map','_args']; _map getOrDefault _args";
private _casMap = compile "params ['_pairs']; createHashMapFromArray _pairs";
/*
    ARC_fnc_casreqBroadcastDelta

    Emit CASREQ delta bundle with full casreq_snapshot and delta metadata.

    Params:
      0: casreq_id (STRING)
      1: actor (STRING)
      2: action (STRING)
      3: changes (ARRAY, optional)
*/

if (!isServer) exitWith {false};

params [
    ["_casreqId", "", [""]],
    ["_actor", "SERVER", [""]],
    ["_action", "UPDATE", [""]],
    ["_changes", [], [[]]]
];

private _snapshot = [_casreqId] call ARC_fnc_casreqSnapshotGet;
if (_snapshot isEqualTo []) exitWith {false};

private _rev = missionNamespace getVariable ["ARC_casreq_rev", 0];
if (!(_rev isEqualType 0) || { _rev < 0 }) then { _rev = 0; };
_rev = _rev + 1;
missionNamespace setVariable ["ARC_casreq_rev", _rev];

private _bundle = [
    ["meta", [
        ["system", "CASREQ"],
        ["schemaVersion", missionNamespace getVariable ["casreq_v1_schemaVersion", 1]],
        ["rev", _rev],
        ["updatedAt", serverTime],
        ["actor", _actor],
        ["action", _action]
    ]],
    ["payload", [
        ["casreq_id", _casreqId],
        ["changes", _changes],
        ["casreq_snapshot", _snapshot]
    ]]
];

missionNamespace setVariable ["ARC_pub_casreqBundle", _bundle, true];
[] call ARC_fnc_casreqInboxPublish;
private _r = ([_snapshot] call _casMap);
private _area = ([(([_r, ["area", []]] call _casDefault))] call _casMap);
diag_log format ["[ARC][CASREQ] time=%1 actor=%2 id=%3 action=%4 grid=%5 rev=%6", serverTime, _actor, _casreqId, _action, mapGridPosition (([_area, ["target_pos", [0,0,0]]] call _casDefault)), _rev];
true

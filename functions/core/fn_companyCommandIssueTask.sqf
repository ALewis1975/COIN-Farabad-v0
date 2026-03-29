/*
    ARC_fnc_companyCommandIssueTask

    Server-only writer for company command tasking records.

    Task format (companyCommandTasking):
      [
        taskId, createdAt, status,
        nodeId, commanderToken,
        intent, posture,
        hqMarker, hqPosATL, hqZone,
        metaPairs
      ]
*/

if (!isServer) exitWith {false};

params [
    ["_node", [], [[]]],
    ["_intent", "", [""]],
    ["_posture", "", [""]],
    ["_meta", [], [[]]]
];

if (!(_node isEqualType []) || { (count _node) < 6 }) exitWith {false};

private _nodeId = _node # 0;
private _cmdToken = _node # 1;
private _hqMarker = _node # 3;
private _hqPos = _node # 4;
private _hqZone = _node # 5;

if (!(_meta isEqualType [])) then { _meta = []; };

private _counter = ["companyCommandCounter", 0] call ARC_fnc_stateGet;
if (!(_counter isEqualType 0) || { _counter < 0 }) then { _counter = 0; };
_counter = _counter + 1;
["companyCommandCounter", _counter] call ARC_fnc_stateSet;

private _taskId = format ["ARC_ccmd_%1", _counter];
private _now = serverTime;

private _rec = [
    _taskId,
    _now,
    "ISSUED",
    _nodeId,
    _cmdToken,
    toUpper (trim _intent),
    toUpper (trim _posture),
    _hqMarker,
    _hqPos,
    _hqZone,
    _meta
];

private _tasking = ["companyCommandTasking", []] call ARC_fnc_stateGet;
if (!(_tasking isEqualType [])) then { _tasking = []; };

// One open task per node; close old one before appending a fresh record.
for "_i" from 0 to ((count _tasking) - 1) do
{
    private _r = _tasking # _i;
    if (_r isEqualType [] && { (count _r) >= 4 }) then
    {
        if ((_r # 3) isEqualTo _nodeId && { toUpper (_r # 2) isEqualTo "ISSUED" }) then
        {
            _r set [2, "SUPERSEDED"];
            _tasking set [_i, _r];
        };
    };
};

_tasking pushBack _rec;

private _cap = missionNamespace getVariable ["ARC_companyCommandTaskingCap", 40];
if (!(_cap isEqualType 0)) then { _cap = 40; };
_cap = (_cap max 10) min 200;
while { (count _tasking) > _cap } do { _tasking deleteAt 0; };

["companyCommandTasking", _tasking] call ARC_fnc_stateSet;

["OPS", format ["COMPANY CMD: %1 issued %2/%3 (%4).", _cmdToken, toUpper (trim _intent), toUpper (trim _posture), _taskId], _hqPos,
    [["event", "COMPANY_COMMAND_TASK_ISSUED"], ["taskId", _taskId], ["nodeId", _nodeId], ["zone", _hqZone]]
] call ARC_fnc_intelLog;

_taskId

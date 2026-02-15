/*
    Find an existing intel thread near a position, or create a new one.

    Threads represent evolving OPFOR networks (cells) being investigated.
    Leads and lead-driven incidents attach to a thread so we can:
      - build confidence (how well we know the commander/location)
      - accumulate heat (how aware the cell is that it's being hunted)
      - eventually spawn a Command Node opportunity when multiple factors converge

    Params:
        0: STRING - threadType (e.g. "IED_CELL", "INSIDER_NETWORK", "SMUGGLING_RING")
        1: ARRAY  - center/base position [x,y,z]
        2: STRING - zoneBias (optional)

    Returns:
        STRING - threadId
*/

if (!isServer) exitWith {""};

params [
    ["_threadType", "GENERIC"],
    ["_pos", []],
    ["_zoneBias", ""]
];

if (!(_pos isEqualType []) || { (count _pos) < 2 }) exitWith {""};

private _threads = ["threads", []] call ARC_fnc_stateGet;
if (!(_threads isEqualType [])) then { _threads = []; };

private _typeU = toUpper _threadType;
private _center = +_pos;
_center resize 3;

// Try to attach to a nearby existing thread of the same type.
private _bestIdx = -1;
private _bestScore = -1;
private _radius = 2500;

{
    if !(_x isEqualType []) then { continue; };
    if ((count _x) < 14) then { continue; };

    private _id   = _x # 0;
    private _t    = toUpper (_x # 1);
    private _base = _x # 3;
    private _conf = _x # 4;
    private _heat = _x # 5;
    private _st   = toUpper (_x # 6);

    if (_t isNotEqualTo _typeU) then { continue; };
    if (_st isEqualTo "DORMANT") then { continue; };

    if (!(_base isEqualType []) || { (count _base) < 2 }) then { continue; };

    private _d = _base distance2D _center;
    if (_d > _radius) then { continue; };

    // Prefer closer + higher confidence threads.
    private _score = (1 - (_d / _radius)) + (0.4 * _conf) - (0.2 * _heat);

    if (_score > _bestScore) then
    {
        _bestScore = _score;
        _bestIdx = _forEachIndex;
    };

} forEach _threads;

if (_bestIdx >= 0) exitWith
{
    private _thr = _threads # _bestIdx;
    private _id = _thr # 0;

    // Lightly pull the thread base toward the new activity.
    private _base = _thr # 3;
    if (_base isEqualType [] && { (count _base) >= 2 }) then
    {
        private _newBase = [
            ((_base # 0) * 0.75) + ((_center # 0) * 0.25),
            ((_base # 1) * 0.75) + ((_center # 1) * 0.25),
            0
        ];
        _thr set [3, _newBase];
        _threads set [_bestIdx, _thr];
        ["threads", _threads] call ARC_fnc_stateSet;
    };

    // Ensure parent task exists (safe on repeat)
    private _parentTaskId = [_id, _threadType, _zoneBias, (_thr # 3)] call ARC_fnc_taskEnsureThreadParent;
    if (_parentTaskId isNotEqualTo "") then
    {
        _thr set [13, _parentTaskId];
        _threads set [_bestIdx, _thr];
        ["threads", _threads] call ARC_fnc_stateSet;
    };

    [] call ARC_fnc_threadBroadcast;
    _id
};

// --- Create new thread ---------------------------------------------------------
private _counter = ["threadCounter", 0] call ARC_fnc_stateGet;
_counter = _counter + 1;
["threadCounter", _counter] call ARC_fnc_stateSet;

private _id = format ["ARC_thr_%1", _counter];
private _parentTaskId = [_id, _threadType, _zoneBias, _center] call ARC_fnc_taskEnsureThreadParent;

private _now = serverTime;

private _thread = [
    _id,                // 0 id
    _threadType,        // 1 type
    _zoneBias,          // 2 zone bias
    _center,            // 3 base pos
    0.12,               // 4 confidence (starts low)
    0.08,               // 5 heat (starts low)
    "OPERATING",        // 6 commander state
    [],                 // 7 evidence
    0,                  // 8 follow-up successes
    0,                  // 9 follow-up failures
    _now,               // 10 last touched
    -1,                 // 11 cooldown until
    -1,                 // 12 last command node
    _parentTaskId       // 13 parent task id
];

_threads pushBack _thread;
["threads", _threads] call ARC_fnc_stateSet;

[] call ARC_fnc_threadBroadcast;

_id

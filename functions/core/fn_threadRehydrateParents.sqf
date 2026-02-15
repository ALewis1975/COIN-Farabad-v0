/*
    Server: after loading persisted state, ensure case parent tasks exist
    for any saved threads.

    Tasks are not persisted by Arma, so after a restart we must recreate
    the parent "case" tasks or child tasks won't have an anchor.

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

private _threads = ["threads", []] call ARC_fnc_stateGet;
if (!(_threads isEqualType [])) then { _threads = []; };

if (_threads isEqualTo []) exitWith { [] call ARC_fnc_threadBroadcast; true };

private _changed = false;

{
    if !(_x isEqualType []) then { continue; };
    if ((count _x) < 14) then { continue; };

    private _id = _x # 0;
    private _type = _x # 1;
    private _zone = _x # 2;
    private _base = _x # 3;

    private _parent = [_id, _type, _zone, _base] call ARC_fnc_taskEnsureThreadParent;
    if (_parent isNotEqualTo "" && { (_x # 13) isNotEqualTo _parent }) then
    {
        _x set [13, _parent];
        _threads set [_forEachIndex, _x];
        _changed = true;
    };

} forEach _threads;

if (_changed) then
{
    ["threads", _threads] call ARC_fnc_stateSet;
};

[] call ARC_fnc_threadBroadcast;
true

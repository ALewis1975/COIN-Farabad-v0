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
    private _thr = [_x] call ARC_fnc_threadNormalizeRecord;
    if (_thr isEqualTo []) then { continue; };

    private _id = _thr # 0;
    private _type = _thr # 1;
    private _zone = _thr # 2;
    private _base = _thr # 3;
    private _districtId = _thr # 14;
    if (_districtId isEqualTo "") then
    {
        _districtId = [_base] call ARC_fnc_threadResolveDistrictId;
        _thr set [14, _districtId];
        _threads set [_forEachIndex, _thr];
        _changed = true;
    };

    private _parent = [_id, _type, _zone, _base] call ARC_fnc_taskEnsureThreadParent;
    if (_parent isNotEqualTo "" && { (_thr # 13) isNotEqualTo _parent }) then
    {
        _thr set [13, _parent];
        _threads set [_forEachIndex, _thr];
        _changed = true;
    };

} forEach _threads;

if (_changed) then
{
    ["threads", _threads] call ARC_fnc_stateSet;
};

[] call ARC_fnc_threadBroadcast;
true

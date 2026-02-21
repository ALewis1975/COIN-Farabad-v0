/*
    Server: register one or more spawned entities for deferred cleanup.

    The cleanup system deletes registered objects once no alive players are
    within a given radius of an anchor position.

    Intended use: keep convoy/raid props around while players are on-scene,
    then despawn them after the team moves on (performance + immersion).

    Params:
        0: OBJECT | ARRAY - object, netId string, or array of objects/netIds
        1: ARRAY  - (optional) anchorPosATL [x,y,z]. If empty, uses object position.
        2: NUMBER - (optional) radius meters. Default: missionNamespace ARC_cleanupRadiusM (1000)
        3: NUMBER - (optional) minDelay seconds before cleanup is allowed (default 20, clamped 0..3600)
        4: STRING - (optional) label for logging/debug

    Returns:
        NUMBER - count registered
*/

if (!isServer) exitWith {0};

params [
    ["_items", objNull],
    ["_anchor", []],
    ["_radius", -1],
    ["_minDelay", 20],
    ["_label", ""]
];

private _queue = ["cleanupQueue", []] call ARC_fnc_stateGet;
if (!(_queue isEqualType [])) then { _queue = []; };

if (!(_radius isEqualType 0) || { _radius <= 0 }) then
{
    _radius = missionNamespace getVariable ["ARC_cleanupRadiusM", 1000];
};
_radius = (_radius max 200) min 5000;

if (!(_minDelay isEqualType 0) || { _minDelay < 0 }) then { _minDelay = 20; };
_minDelay = (_minDelay max 0) min 3600;

private _now = serverTime;
private _earliest = _now + _minDelay;

private _list = [];
if (_items isEqualType []) then
{
    _list = +_items;
}
else
{
    if (_items isEqualType objNull && { !isNull _items }) then
    {
        _list = [_items];
    };
};

private _count = 0;

{
    private _nid = "";
    private _obj = objNull;

    if (_x isEqualType "") then
    {
        _nid = _x;
        _obj = objectFromNetId _nid;
    }
    else
    {
        if (_x isEqualType objNull) then
        {
            _obj = _x;
            if (!isNull _obj) then { _nid = netId _obj; };
        };
    };

    if (_nid isEqualTo "") then { continue; };


    // Do not register persistent AO compositions (ex: checkpoints) for cleanup.
    if (!isNull _obj) then
    {
        private _persist = _obj getVariable ["ARC_persistInAO", false];
        if (_persist isEqualType true && { _persist }) then { continue; };
    };
    // Avoid duplicates
    if (([_queue, { (_x select 0) isEqualTo _nid }] call _findIfFn) >= 0) then { continue; };

    private _a = _anchor;
    if (!(_a isEqualType []) || { (count _a) < 2 }) then
    {
        if (!isNull _obj) then
        {
            _a = getPosATL _obj;
        }
        else
        {
            _a = [];
        };
    };

    if (!(_a isEqualType []) || { (count _a) < 2 }) then { continue; };
    _a = +_a; _a resize 3;

    _queue pushBack [_nid, _a, _radius, _earliest, _label];
    _count = _count + 1;
} forEach _list;

["cleanupQueue", _queue] call ARC_fnc_stateSet;

_count

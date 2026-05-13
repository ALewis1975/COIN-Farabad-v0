/*
    ARC_fnc_guardPost

    Per-unit guard post scanning loop. Server-owned.
    Spawned once per qualifying unit at mission start.

    Parameters:
        _unit   - Object : unit to guard [<OBJECT>]
        _range  - Number : scan arc in degrees 0-360 [180]
        _beh    - String : initial behaviour (CARELESS/SAFE/AWARE/COMBAT/STEALTH) ["CARELESS"]
        _stance - String : unit stance (UP/DOWN/MIDDLE/AUTO) ["AUTO"]
        _height - Bool   : allow vertical look variation [false]
        _delay  - Number : minimum sleep between scans in seconds [1]

    Returns: Nothing
*/

if (!isServer) exitWith {};

params [
    ["_unit",   objNull, [objNull]],
    ["_range",  180,     [0]],
    ["_beh",    "CARELESS", [""]],
    ["_stance", "AUTO",  [""]],
    ["_height", false,   [false]],
    ["_delay",  1,       [0]]
];

if (isNull _unit) exitWith {
    diag_log "[ARC][WARN] ARC_fnc_guardPost: called with null unit — exiting.";
};

private _enemy    = if (side _unit == east) then {west} else {east};
private _startdir = getDir _unit;
private _zaxis    = 0;

// Detection radius used for nearEntities spatial pre-filter.
private _detectRadius = 500;

if (_range < 0) then {_range = 0};
if (_range > 360) then {_range = 360};

if (_beh in ["CARELESS", "SAFE", "AWARE", "COMBAT", "STEALTH"])
    then {_unit setBehaviour _beh}
    else {_unit setBehaviour "SAFE"};

_unit setUnitPos _stance;


// Start scanning
while {alive _unit} do
{
    private _left  = _startdir - (_range / 2);
    private _right = _startdir + (_range / 2);

    if (_left > _right) then {_left = _startdir - (_range / 2); _right = _startdir + (_range / 2)};

    _left  = round _left;
    _right = round _right;

    private _dir = random (_right - _left) + _left;
    if (_dir < 0) then {_dir = _dir + 360};

    private _pos = position _unit;
    if (_height) then {_zaxis = random 20};
    if (!_height) then {_zaxis = _pos select 2};
    _pos = [(_pos select 0) + 50 * sin _dir, (_pos select 1) + 50 * cos _dir, _zaxis];

    _unit doWatch _pos;

    // Combat check: nearEntities pre-filters by radius using the engine spatial index,
    // avoiding a full allUnits scan (O(N)) per guard unit each tick.
    private _nearUnits = _unit nearEntities [["Man"], _detectRadius];
    private _engaging = false;
    {
        if ((side _x == _enemy) && { _unit knowsAbout _x > 1.4 }) exitWith { _engaging = true; };
    } forEach _nearUnits;

    if (_engaging) then
    {
        // Poll at 5 s intervals (reduced from 1 s) to limit server cost during sustained combat.
        waitUntil {
            sleep 5;
            private _nearUnits2 = _unit nearEntities [["Man"], _detectRadius];
            private _anyLow = false;
            {
                if ((side _x == _enemy) && { _unit knowsAbout _x < 4 }) exitWith { _anyLow = true; };
            } forEach _nearUnits2;
            _anyLow
        };
    };

    private _wait = (random 10) + _delay;
    sleep _wait;
};

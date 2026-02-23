//	Simple Guard Post Script 1.0
//	by Tophe of �stg�ta Ops
//
//	Usage with default values:
//	nul = [this] execVM "GuardPost.sqf"
//
//	Optional settings:
//	nul = [unit, range in degrees, behaviour, stance (up/down/middle/auto), look up/down, min delay] execVM "GuardPost.sqf"
//
//	Default values:
//	nul = [this, 360, "SAFE", "AUTO", false, 1] execVM "GuardPost.sqf";
//  nul = [this, 360, "AWARE", "AUTO", false, 1] execVM "GuardPost.sqf";
//	For feedback and support - check thread in the BIS forums. 
//	http://forums.bistudio.com/showthread.php?p=1681721



if (!isServer) exitWith {};

private _unit 		= _this select 0;
private _range	 	= if (count _this > 1) then {_this select 1} else {180};
private _beh		= if (count _this > 2) then {_this select 2} else {"CARELESS"};
private _stance		= if (count _this > 3) then {_this select 3} else {"AUTO"};
private _height		= if (count _this > 4) then {_this select 4} else {false};
private _delay 		= if (count _this > 5) then {_this select 5} else {1};	

private _enemy 		= if (side _unit == east) then {west} else {east};
private _startdir	= getDir _unit;
private _zaxis 		= 0;

// Detection radius: knowsAbout is expensive, skip units beyond this range
private _detectRadius = 500;

if (_range < 0) then {_range = 0};
if (_range > 360) then {_range = 360};

if 	(_beh == "CARELESS" || _beh == "SAFE" || _beh == "AWARE" || _beh == "COMBAT" || _beh == "STEALTH") 
	then 
	{_unit setBehaviour _beh} else {_unit setBehaviour "SAFE"};

_unit setUnitPos _stance;


// Start scanning 
while {alive _unit} do
{
	private _left = _startdir - (_range/2);
	private _right = _startdir + (_range/2);

	if (_left > _right) then {_left = _startdir - (_range/2); _right = _startdir + (_range/2)};	

	_left = round _left;
	_right = round _right;

	private _dir = random (_right - _left) + _left;
	if (_dir < 0) then {_dir = _dir + 360}; 

	private _pos  = position _unit;
	if (_height) then {_zaxis = random 20};
	if (!_height) then {_zaxis = _pos select 2};
	_pos = [(_pos select 0) + 50*sin _dir, (_pos select 1) + 50*cos _dir, _zaxis];

	_unit doWatch _pos;

	// Pause if unit is engaging — pre-filter by side + distance before expensive knowsAbout
	private _engaging = false;
	{
		if ((side _x == _enemy) && {(_unit distance _x) < _detectRadius} && {_unit knowsAbout _x > 1.4}) exitWith { _engaging = true; };
	} forEach allUnits;

	if (_engaging) then
	{
		waitUntil {
			sleep 1;
			private _anyLow = false;
			{
				if ((side _x == _enemy) && {(_unit distance _x) < _detectRadius} && {_unit knowsAbout _x < 4}) exitWith { _anyLow = true; };
			} forEach allUnits;
			_anyLow
		};
	};
	
	private _wait = (random 10) + _delay;
	sleep _wait;
};
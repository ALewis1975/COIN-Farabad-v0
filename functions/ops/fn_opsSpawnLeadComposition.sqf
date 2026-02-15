/*
    Server-side helper for spawning "lead sites" (safehouse, cache, meeting spot, etc.).

    This is a thin wrapper around ARC_fnc_opsSpawnComposition with a simple naming
    convention:
      data\compositions\leads\<name>.sqf

    Params:
      0: STRING - composition name (without path/extension)
      1: ARRAY  - anchor position ATL [x,y,z]
      2: NUMBER - azimuth (degrees)
      3: NUMBER - randomizer (optional)
      4: BOOL   - register spawned entities for cleanup (optional)

    Returns:
      ARRAY - created objects
*/

params [
    ["_name", "", ["" ]],
    ["_posATL", [], [[]]],
    ["_dir", 0, [0]],
    ["_randomizer", 0, [0]],
    ["_registerCleanup", true, [true]]
];

if (!isServer) exitWith {[]};
if (_name isEqualTo "") exitWith {[]};
if (_posATL isEqualTo [] || {count _posATL < 2}) exitWith {[]};

private _file = format ["data\\compositions\\leads\\%1.sqf", _name];
private _objs = [_file, _posATL, _dir, _randomizer] call ARC_fnc_opsSpawnComposition;

if (_registerCleanup) then
{
    // Keep lead-site props around while teams are operating; clean up after they leave.
    [_objs, _posATL, -1, 30 * 60, format ["leadComp:%1", _name]] call ARC_fnc_cleanupRegister;
};

_objs

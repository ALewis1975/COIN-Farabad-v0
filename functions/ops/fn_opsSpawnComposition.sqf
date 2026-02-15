/*
    Server-side composition spawner.

    Expected workflow:
      1) Build a micro-site (safehouse, cache, meeting) in Eden.
      2) Export it to the clipboard using BIS_fnc_objectsGrabber.
      3) Paste the output into a mission file (e.g. data\compositions\leads\lead_cache_01.sqf).
      4) Spawn it at runtime with BIS_fnc_ObjectsMapper.

    Params:
      0: STRING - path to composition .sqf file (mission-relative)
      1: ARRAY  - anchor position ATL [x,y,z]
      2: NUMBER - azimuth (degrees)
      3: NUMBER - randomizer (optional). 0.0 = spawn all objects.

    Returns:
      ARRAY - created objects (empty on failure)
*/

params [
    ["_file", "", [""]],
    ["_posATL", [], [[]]],
    ["_dir", 0, [0]],
    ["_randomizer", 0, [0]]
];

if (!isServer) exitWith {[]};
if (_file isEqualTo "") exitWith {[]};
if (_posATL isEqualTo [] || {count _posATL < 2}) exitWith {[]};

private _src = preprocessFileLineNumbers _file;
if (_src isEqualTo "") exitWith {[]};

private _template = call compile _src;
if !(_template isEqualType []) exitWith {[]};

private _created = [_posATL, _dir, _template, _randomizer] call BIS_fnc_ObjectsMapper;
if !(_created isEqualType []) exitWith {[]};

_created

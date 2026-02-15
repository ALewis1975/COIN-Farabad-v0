/*
    ARC_fnc_civsubIsDistrictActive

    District active definition (exact, locked v1):
      dist = minDistance(allPlayers, district.centroid)
      active if dist <= (radius_m + 200)

    Params:
      0: district (HashMap)

    Returns:
      bool
*/

if (!isServer) exitWith {false};

params [["_d", createHashMap, [createHashMap]]];
if !(_d isEqualType createHashMap) exitWith {false};

private _c = _d getOrDefault ["centroid", [0,0]];
private _r = _d getOrDefault ["radius_m", 0];
if !(_c isEqualType []) exitWith {false};
if ((count _c) < 2) exitWith {false};

private _players = allPlayers;
if ((count _players) == 0) exitWith {false};

private _min = 1e12;
{
    private _p = getPosATL _x;
    private _d2 = (_p distance2D [_c # 0, _c # 1, 0]);
    if (_d2 < _min) then { _min = _d2; };
} forEach _players;

_min <= (_r + 200)

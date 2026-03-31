/*
    ARC_fnc_civsubTrafficResolveSpawnCenter

    Resolves a stable traffic spawn center for a district.
    Priority:
      1) Explicit missionNamespace anchor override map (districtId -> [x,y,z]/[x,y])
      2) Player centroid for the district (spawns traffic near where players operate)
      3) District centroid

    Params:
      0: districtId (string)
      1: districtState (HashMap)
      2: playerPositions (array of [x,y,z], optional) — positions of players in this district

    Returns: [x,y,z]
*/

if (!isServer) exitWith {[0,0,0]};

params [
    ["_districtId", "", [""]],
    ["_d", createHashMap, [createHashMap]],
    ["_playerPositions", [], [[]]]
];

private _center = [0,0,0];

if (_d isEqualType createHashMap) then
{
    private _c = _d getOrDefault ["centroid", [0,0]];
    if (_c isEqualType [] && { (count _c) >= 2 }) then
    {
        _center = [_c # 0, _c # 1, 0];
    };
};

if (_districtId isEqualTo "") exitWith {_center};

// Priority 1: explicit static anchor override
private _anchors = missionNamespace getVariable ["civsub_v1_traffic_spawnAnchors", createHashMap];
private _anchorFound = false;
private _anchorResult = [0,0,0];
if (_anchors isEqualType createHashMap) then
{
    private _anchor = _anchors getOrDefault [_districtId, []];
    if (_anchor isEqualType [] && { (count _anchor) >= 2 }) then
    {
        _anchorFound = true;
        _anchorResult = [_anchor # 0, _anchor # 1, if ((count _anchor) >= 3) then { _anchor # 2 } else { 0 }];
    };
};
if (_anchorFound) exitWith { _anchorResult };

// Priority 2: player centroid — spawn traffic near where players actually are
if ((count _playerPositions) > 0) exitWith
{
    private _sx = 0;
    private _sy = 0;
    {
        if (_x isEqualType [] && { (count _x) >= 2 }) then
        {
            _sx = _sx + (_x # 0);
            _sy = _sy + (_x # 1);
        };
    } forEach _playerPositions;
    [_sx / (count _playerPositions), _sy / (count _playerPositions), 0]
};

// Priority 3: district centroid
_center


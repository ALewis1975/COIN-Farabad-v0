/*
    ARC_fnc_civsubTrafficResolveSpawnCenter

    Resolves a stable traffic spawn center for a district.
    Priority:
      1) Explicit missionNamespace anchor override map (districtId -> [x,y,z]/[x,y])
      2) District centroid

    Params:
      0: districtId (string)
      1: districtState (HashMap)

    Returns: [x,y,z]
*/

if (!isServer) exitWith {[0,0,0]};

params [
    ["_districtId", "", [""]],
    ["_d", createHashMap, [createHashMap]]
];


// sqflint-compatible helpers
private _hg      = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _center = [0,0,0];

if (_d isEqualType createHashMap) then
{
    private _c = [_d, "centroid", [0,0]] call _hg;
    if (_c isEqualType [] && { (count _c) >= 2 }) then
    {
        _center = [_c select 0, _c select 1, 0];
    };
};

if (_districtId isEqualTo "") exitWith {_center};

private _anchors = missionNamespace getVariable ["civsub_v1_traffic_spawnAnchors", createHashMap];
if !(_anchors isEqualType createHashMap) exitWith {_center};

private _anchor = [_anchors, _districtId, []] call _hg;
if !(_anchor isEqualType []) exitWith {_center};
if ((count _anchor) < 2) exitWith {_center};

[_anchor select 0, _anchor select 1, if ((count _anchor) >= 3) then { _anchor select 2 } else { 0 }]


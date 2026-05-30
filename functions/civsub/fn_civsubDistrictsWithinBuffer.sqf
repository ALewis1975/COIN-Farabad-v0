/*
    ARC_fnc_civsubDistrictsWithinBuffer

    Buffered, multi-match analogue of ARC_fnc_civsubDistrictsFindByPos.
    Returns every district whose activation area contains the given position,
    where the activation area is the district centroid expanded by
    (radius_m + buffer). This matches the canonical activation definition in
    ARC_fnc_civsubIsDistrictActive (dist <= radius_m + 200) so that a stationary
    player just outside a — often small — district radius still counts as present
    in that district. Unlike ARC_fnc_civsubDistrictsFindByPos (which returns only
    the single strictly-containing district, dist <= radius_m), this returns ALL
    buffer-adjacent districts.

    Shared by:
      - ARC_fnc_civsubBubbleGetActiveDistricts (civilian sampler activation)
      - ARC_fnc_civsubTrafficTick (traffic district activation)

    Params:
      0: position [x,y,z] (or [x,y])
      1: buffer (number, optional) — defaults to civsub_v1_activeDistrict_buffer_m (200)

    Returns: array of districtId strings (may be empty)
*/

if (!isServer) exitWith {[]};

params [
    ["_pos", [0,0,0], [[]]],
    ["_buffer", -1, [0]]
];

if (!(_pos isEqualType []) || { (count _pos) < 2 }) exitWith {[]};

if (_buffer < 0) then {
    _buffer = missionNamespace getVariable ["civsub_v1_activeDistrict_buffer_m", 200];
    if (!(_buffer isEqualType 0)) then { _buffer = 200; };
};
if (_buffer < 0) then { _buffer = 0; };

private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if !(_districts isEqualType createHashMap) exitWith {[]};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";
private _keysFn = compile "params ['_m']; keys _m";

private _p2 = [_pos select 0, _pos select 1, 0];

private _out = [];
{
    private _did = _x;
    private _rec = [_districts, _did, createHashMap] call _hg;
    if (_rec isEqualType []) then { _rec = [_rec] call _hmCreate; };
    if (_rec isEqualType createHashMap) then {
        private _c = [_rec, "centroid", [0,0]] call _hg;
        private _r = [_rec, "radius_m", 0] call _hg;
        if ((_c isEqualType []) && { (count _c) >= 2 } && { _r > 0 }) then {
            private _cc = [_c select 0, _c select 1, 0];
            if ((_p2 distance2D _cc) <= (_r + _buffer)) then {
                _out pushBack _did;
            };
        };
    };
} forEach ([_districts] call _keysFn);

_out

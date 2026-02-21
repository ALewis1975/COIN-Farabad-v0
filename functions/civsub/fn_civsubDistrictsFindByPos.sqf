/*
    ARC_fnc_civsubDistrictsFindByPos

    Finds the district containing the position (centroid + radius).

    Params:
      0: position [x,y,z]

    Returns: districtId string or "".
*/

if (!isServer) exitWith {""};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {""};

params [
    ["_pos", [0,0,0], [[]]]
];

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; [(_h), _k, _d] call _hg";
private _mapGet   = compile "params ['_h','_k']; _h get _k";
private _keysFn   = compile "params ['_m']; keys _m";
private _hmFrom   = compile "params ['_pairs']; private _r = createHashMap; { _r set [_x select 0, _x select 1]; } forEach _pairs; _r";


private _zone = "";
if (!isNil "ARC_fnc_worldGetZoneForPos") then {
    _zone = toUpper ([_pos] call ARC_fnc_worldGetZoneForPos);
};
if (_zone isEqualTo "AIRBASE") exitWith {""};
private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if !(_districts isEqualType createHashMap) exitWith {""};

private _best = "";
private _bestD = 1e12;

{
    private _rec = [_districts, _x] call _mapGet;
    if (_rec isEqualType []) then {
        // stored as array-of-pairs; normalize to HashMap on the fly
        _rec = [_rec] call _hmFrom;
    };
    if (_rec isEqualType createHashMap) then {
        private _c = [_rec, "centroid", [0,0] call _hg];
        private _r = [_rec, "radius_m", 0] call _hg;
        if ((_c isEqualType []) && { _r > 0 }) then {
            private _d = (_pos distance2D _c);
            if (_d <= _r && { _d < _bestD }) then {
                _bestD = _d;
                _best = _x;
            };
        };
    };
} forEach ([_districts] call _keysFn);

_best

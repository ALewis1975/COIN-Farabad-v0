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


private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";

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
    private _rec = _districts get _x;
    if (_rec isEqualType []) then {
        // stored as array-of-pairs; normalize to HashMap on the fly
        _rec = [_rec] call _hmCreate;
    };
    if (_rec isEqualType createHashMap) then {
        private _c = _rec getOrDefault ["centroid", [0,0]];
        private _r = _rec getOrDefault ["radius_m", 0];
        if ((_c isEqualType []) && { _r > 0 }) then {
            private _d = (_pos distance2D _c);
            if (_d <= _r && { _d < _bestD }) then {
                _bestD = _d;
                _best = _x;
            };
        };
    };
} forEach (keys _districts);

_best

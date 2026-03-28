/*
    ARC_fnc_civsubCivPickSpawnPos

    Picks a spawn position for a civilian in a district.

    Behavior:
      - Uses per-district spawn cache (area-based): buildings first, then roads
      - Respects airbase exclusion zones already handled by CivFindSpawnPos as fallback

    Params:
      0: districtId (string)

    Returns: position array [x,y,z]
*/

if (!isServer) exitWith {[0,0,0]};

params [["_did","",[""]]];
if (_did isEqualTo "") exitWith {[0,0,0]};

private _row = [_did] call ARC_fnc_civsubSpawnCacheEnsure;
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _bld = [_row, "bldPos", []] call _hg;

private _road = [_row, "roadPos", []] call _hg;
if !(_bld isEqualType []) then { _bld = []; };
if !(_road isEqualType []) then { _road = []; };

private _pB = missionNamespace getVariable ["civsub_v1_spawn_prob_building", 0.7];
if !(_pB isEqualType 0) then { _pB = 0.7; };

// Phase 2 helpers (defined in civsubInitServer)
private _posIsRoadish = missionNamespace getVariable ["ARC_civsub_fnc_posIsRoadish", { params ["_p"]; isOnRoad _p }];
private _findOffRoad = missionNamespace getVariable ["ARC_civsub_fnc_findPosOffRoad", { params ["_p"]; _p }];

private _pos = [];
if ((count _bld) > 0 && {(random 1) < _pB}) then {
    _pos = selectRandom _bld;
} else {
    if ((count _road) > 0) then { _pos = selectRandom _road; } else { if ((count _bld) > 0) then { _pos = selectRandom _bld; }; };
};

if !(_pos isEqualType [] && {(count _pos) >= 2}) then { _pos = [0,0,0]; };
if ((count _pos) == 2) then { _pos = [_pos#0,_pos#1,0]; };

// Phase 2: enforce off-road placement (never return a road placement)
if (_pos isEqualType [] && {(count _pos) >= 2} && {!(_pos isEqualTo [0,0,0])}) then
{
    if ([_pos] call _posIsRoadish) then
    {
        private _fixed = [_pos, 2, 18, 12] call _findOffRoad;
        if !(_fixed isEqualTo [0,0,0]) then { _pos = _fixed; } else {
            // If we picked from road cache and can't nudge it, fall back to any building pos.
            if ((count _bld) > 0) then
            {
                private _bp = selectRandom _bld;
                if (!([_bp] call _posIsRoadish)) then { _pos = _bp; } else { _pos = [0,0,0]; };
            } else {
                _pos = [0,0,0];
            };
        };
    };
};

_pos
